import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { dayTimestamp, todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { nextNumber } from '../shared/keys';
import { defineCallable, failed, id, missing, optionalText, usable } from '../shared/masters';
import { enqueue } from '../shared/outbox';

// Known limit: copy IDs live in arrays on the session doc (1 MiB limit); narrow by shelf for larger libraries.
const MAX_COPIES = 2000;
/** Physically on the shelf (or in the workshop) when nobody has borrowed it. */
const SHELF = ['available', 'reserved', 'under_maintenance', 'damaged'];
/** Statuses where marking a missing copy lost is safe; reserved copies would orphan their reservation. */
const LOSABLE = ['available', 'under_maintenance', 'damaged'];

const list = (session: Record<string, unknown>, field: string) =>
  (session[field] as string[] | undefined) ?? [];

async function loadSession(context: CallableContext, sessionId: string) {
  const ref = context.doc(`libraryVerifications/${sessionId}`);
  const snapshot = await context.transaction.get(ref);
  if (!snapshot.exists) throw missing('libraryVerification');
  const session = snapshot.data()!;
  context.requireCampus(session.campusId);
  return { ref, verification: session };
}

/** Library stock verification (FRS 11.16): expected list → scan → review missing/unexpected → approve corrections. */
export const verification = {
  /** Snapshots the copies expected on the shelf; issued copies are listed apart (`onLoanCopyIds`) and need no scan. */
  verificationCreate: defineCallable({
    name: 'library.verification.create',
    permission: 'library.catalogue.manage',
    input: z.object({
      libraryId: id,
      shelf: z.string().trim().min(1).max(120).nullish(),
      remarks: optionalText,
    }),
    handler: async (context, i) => {
      const library = usable(
        await context.transaction.get(context.doc(`libraries/${i.libraryId}`)),
        'Library',
        false,
      );
      context.requireCampus(library.campusId);
      let copy = context.coll('libraryCopies').where('libraryId', '==', i.libraryId);
      if (i.shelf) copy = copy.where('shelf', '==', i.shelf);
      const docs = (await context.transaction.get(copy.limit(MAX_COPIES + 1))).docs;
      if (docs.length > MAX_COPIES)
        throw failed(`More than ${MAX_COPIES} copies in scope; verify one shelf at a time`);
      const expected = docs
        .filter((shelfCopy) => SHELF.includes(shelfCopy.data().status))
        .map((shelfCopy) => shelfCopy.id);
      const onLoanCopyIds = docs
        .filter((shelfCopy) => shelfCopy.data().status === 'issued')
        .map((shelfCopy) => shelfCopy.id);
      if (!expected.length) throw failed('No copies in scope');
      const ref = context.newDoc('libraryVerifications');
      const number = await nextNumber(context, 'LVR');
      const after = {
        number,
        libraryId: i.libraryId,
        libraryName: library.name,
        campusId: library.campusId,
        shelf: i.shelf ?? null,
        remarks: i.remarks ?? null,
        expected,
        onLoanCopyIds,
        scanned: [],
        missing: [],
        unexpected: [],
        status: 'counting',
        verifiedDate: dayTimestamp(todayIST()),
      };
      context.set(ref, {
        ...after,
        createdBy: context.uid,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      context.audit({
        action: 'libraryVerification.create',
        documentPath: ref.path,
        after: { number, expected: expected.length, onLoanCopyIds: onLoanCopyIds.length },
      });
      return { id: ref.id, number };
    },
  }),

  /** Records scanned accession numbers. A scanned copy outside the expected list (or shown as issued) is `unexpected`. */
  verificationScan: defineCallable({
    name: 'library.verification.scan',
    permission: 'library.catalogue.manage',
    input: z.object({ id, accessionNumbers: z.array(id).min(1).max(100) }),
    handler: async (context, i) => {
      const { ref, verification: session } = await loadSession(context, i.id);
      if (session.status !== 'counting') throw failed(`Verification is ${session.status}`);
      const expected = new Set(list(session, 'expected'));
      const scanned = new Set(list(session, 'scanned'));
      const unexpected = new Set(list(session, 'unexpected'));
      const fresh = [...new Set(i.accessionNumbers)].filter(
        (accessionNumber) => !scanned.has(accessionNumber),
      );
      const unknown = fresh.filter((accessionNumber) => !expected.has(accessionNumber));
      const snapshots = unknown.length
        ? await context.transaction.getAll(
            ...unknown.map((accessionNumber) => context.doc(`libraryCopies/${accessionNumber}`)),
          )
        : [];
      const gone = snapshots.filter((snapshot) => !snapshot.exists).map((snapshot) => snapshot.id);
      if (gone.length) throw failed(`Unknown accession number: ${gone.join(', ')}`);
      fresh.forEach((accessionNumber) => scanned.add(accessionNumber));
      unknown.forEach((accessionNumber) => unexpected.add(accessionNumber));
      context.update(ref, {
        scanned: [...scanned],
        unexpected: [...unexpected],
        updatedAt: serverTimestamp(),
      });
      return {
        id: ref.id,
        scanned: scanned.size,
        expected: expected.size,
        unexpected: unexpected.size,
      };
    },
  }),

  /** Closes counting. Nothing missing or unexpected means nothing to approve. */
  verificationSubmit: defineCallable({
    name: 'library.verification.submit',
    permission: 'library.catalogue.manage',
    input: z.object({ id }),
    handler: async (context, i) => {
      const { ref, verification: session } = await loadSession(context, i.id);
      if (session.status !== 'counting') throw failed(`Verification is ${session.status}`);
      const scanned = new Set(list(session, 'scanned'));
      const missingIds = list(session, 'expected').filter(
        (accessionNumber) => !scanned.has(accessionNumber),
      );
      const unexpected = list(session, 'unexpected');
      const status = missingIds.length || unexpected.length ? 'submitted' : 'approved';
      context.update(ref, {
        status,
        missing: missingIds,
        submittedBy: context.uid,
        submittedDate: dayTimestamp(todayIST()),
        updatedAt: serverTimestamp(),
      });
      if (status === 'submitted') {
        await enqueue(context, `library-verification-submit__${ref.id}`, {
          to: { permission: 'library.settings', campusId: session.campusId },
          category: 'library.verification',
          title: 'Stock verification to review',
          body: `${session.number}: ${missingIds.length} missing, ${unexpected.length} unexpected.`,
          data: { verificationId: ref.id },
        });
      }
      context.audit({
        action: 'libraryVerification.submit',
        documentPath: ref.path,
        after: { status, missing: missingIds.length, unexpected: unexpected.length },
      });
      return { id: ref.id, status, missing: missingIds.length, unexpected: unexpected.length };
    },
  }),

  /**
   * Applies the reviewed corrections through the same status rules as manual changes: `lost` marks a missing
   * copy lost, `move` brings an unexpected available copy into this library. Missing copies left alone stay
   * recorded as under investigation; accession history is never rewritten.
   */
  verificationApprove: defineCallable({
    name: 'library.verification.approve',
    permission: 'library.settings',
    input: z.object({
      id,
      lost: z.array(id).max(MAX_COPIES).default([]),
      move: z.array(id).max(MAX_COPIES).default([]),
    }),
    handler: async (context, i) => {
      const { ref, verification: session } = await loadSession(context, i.id);
      if (session.status !== 'submitted') throw failed(`Verification is ${session.status}`);
      const missingIds = new Set(list(session, 'missing'));
      const unexpected = new Set(list(session, 'unexpected'));
      if (i.lost.some((copyId) => !missingIds.has(copyId)))
        throw failed('Only missing copies can be marked lost');
      if (i.move.some((copyId) => !unexpected.has(copyId)))
        throw failed('Only unexpected copies can be moved');
      const touched = [...i.lost, ...i.move];
      const snapshots = touched.length
        ? await context.transaction.getAll(
            ...touched.map((copyId) => context.doc(`libraryCopies/${copyId}`)),
          )
        : [];
      const library = i.move.length
        ? usable(
            await context.transaction.get(context.doc(`libraries/${session.libraryId}`)),
            'Library',
            true,
          )
        : null;
      for (const snapshot of snapshots) {
        const copyDocument = snapshot.data();
        if (!copyDocument) throw missing('libraryCopy');
        context.requireCampus(copyDocument.campusId);
        if (i.lost.includes(snapshot.id)) {
          if (!LOSABLE.includes(copyDocument.status))
            throw failed(`${snapshot.id} is ${copyDocument.status}`);
          context.update(snapshot.ref, { status: 'lost', updatedAt: serverTimestamp() });
        } else {
          if (copyDocument.status !== 'available')
            throw failed(`${snapshot.id} is ${copyDocument.status}`);
          context.update(snapshot.ref, {
            libraryId: session.libraryId,
            campusId: library!.campusId,
            shelf: session.shelf ?? null,
            updatedAt: serverTimestamp(),
          });
        }
      }
      const investigate = [...missingIds].filter((copyId) => !i.lost.includes(copyId));
      context.update(ref, {
        status: 'approved',
        lost: i.lost,
        moved: i.move,
        investigate,
        approvedBy: context.uid,
        approvedDate: dayTimestamp(todayIST()),
        updatedAt: serverTimestamp(),
      });
      context.audit({
        action: 'libraryVerification.approve',
        documentPath: ref.path,
        before: { status: session.status },
        after: { status: 'approved', lost: i.lost, moved: i.move, investigate },
      });
      return { id: ref.id };
    },
  }),
};
