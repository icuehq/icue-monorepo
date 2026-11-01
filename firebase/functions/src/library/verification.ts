import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { todayIST } from '../inventory/stock';
import type { Ctx } from '../shared/callable';
import { nextNumber } from '../shared/keys';
import { def, failed, id, missing, note, usable } from '../shared/masters';

const UP = () => FieldValue.serverTimestamp();
// ponytail: copy IDs live in arrays on the session doc (1 MiB limit); narrow by shelf for larger libraries.
const MAX_COPIES = 2000;
/** Physically on the shelf (or in the workshop) when nobody has borrowed it. */
const SHELF = ['available', 'reserved', 'under_maintenance', 'damaged'];
/** Statuses where marking a missing copy lost is safe; reserved copies would orphan their reservation. */
const LOSABLE = ['available', 'under_maintenance', 'damaged'];

const list = (v: Record<string, unknown>, k: string) => (v[k] as string[] | undefined) ?? [];

async function loadSession(ctx: Ctx, sessionId: string) {
  const ref = ctx.doc(`libVerifications/${sessionId}`);
  const snap = await ctx.tx.get(ref);
  if (!snap.exists) throw missing('libVerification');
  const d = snap.data()!;
  ctx.requireCampus(d.campusId);
  return { ref, d };
}

/** Library stock verification (FRS 11.16): expected list → scan → review missing/unexpected → approve corrections. */
export const verification = {
  /** Snapshots the copies expected on the shelf; issued copies are listed apart (`onLoan`) and need no scan. */
  verificationCreate: def({
    name: 'lib.verification.create',
    perm: 'lib.catalogue.manage',
    input: z.object({ libraryId: id, shelf: z.string().trim().min(1).max(120).nullish(), remarks: note }),
    handler: async (ctx, i) => {
      const lib = usable(await ctx.tx.get(ctx.doc(`libLibraries/${i.libraryId}`)), 'Library', false);
      ctx.requireCampus(lib.campusId);
      let q = ctx.coll('libCopies').where('libraryId', '==', i.libraryId);
      if (i.shelf) q = q.where('shelf', '==', i.shelf);
      const docs = (await ctx.tx.get(q.limit(MAX_COPIES + 1))).docs;
      if (docs.length > MAX_COPIES) throw failed(`More than ${MAX_COPIES} copies in scope; verify one shelf at a time`);
      const expected = docs.filter((d) => SHELF.includes(d.data().status)).map((d) => d.id);
      const onLoan = docs.filter((d) => d.data().status === 'issued').map((d) => d.id);
      if (!expected.length) throw failed('No copies in scope');
      const ref = ctx.newDoc('libVerifications');
      const number = await nextNumber(ctx, 'LVR');
      const after = {
        number,
        libraryId: i.libraryId,
        libraryName: lib.name,
        campusId: lib.campusId,
        shelf: i.shelf ?? null,
        remarks: i.remarks ?? null,
        expected,
        onLoan,
        scanned: [],
        missing: [],
        unexpected: [],
        status: 'counting',
        verifiedOn: todayIST(),
      };
      ctx.set(ref, { ...after, createdBy: ctx.uid, createdAt: UP(), updatedAt: UP() });
      ctx.audit({ action: 'libVerification.create', ref: ref.path, after: { number, expected: expected.length, onLoan: onLoan.length } });
      return { id: ref.id, number };
    },
  }),

  /** Records scanned accession numbers. A scanned copy outside the expected list (or shown as issued) is `unexpected`. */
  verificationScan: def({
    name: 'lib.verification.scan',
    perm: 'lib.catalogue.manage',
    input: z.object({ id, accessionNos: z.array(id).min(1).max(100) }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadSession(ctx, i.id);
      if (d.status !== 'counting') throw failed(`Verification is ${d.status}`);
      const expected = new Set(list(d, 'expected'));
      const scanned = new Set(list(d, 'scanned'));
      const unexpected = new Set(list(d, 'unexpected'));
      const fresh = [...new Set(i.accessionNos)].filter((a) => !scanned.has(a));
      const unknown = fresh.filter((a) => !expected.has(a));
      const snaps = unknown.length ? await ctx.tx.getAll(...unknown.map((a) => ctx.doc(`libCopies/${a}`))) : [];
      const gone = snaps.filter((s) => !s.exists).map((s) => s.id);
      if (gone.length) throw failed(`Unknown accession number: ${gone.join(', ')}`);
      fresh.forEach((a) => scanned.add(a));
      unknown.forEach((a) => unexpected.add(a));
      ctx.update(ref, { scanned: [...scanned], unexpected: [...unexpected], updatedAt: UP() });
      return { id: ref.id, scanned: scanned.size, expected: expected.size, unexpected: unexpected.size };
    },
  }),

  /** Closes counting. Nothing missing or unexpected means nothing to approve. */
  verificationSubmit: def({
    name: 'lib.verification.submit',
    perm: 'lib.catalogue.manage',
    input: z.object({ id }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadSession(ctx, i.id);
      if (d.status !== 'counting') throw failed(`Verification is ${d.status}`);
      const scanned = new Set(list(d, 'scanned'));
      const missingIds = list(d, 'expected').filter((c) => !scanned.has(c));
      const unexpected = list(d, 'unexpected');
      const status = missingIds.length || unexpected.length ? 'submitted' : 'approved';
      ctx.update(ref, { status, missing: missingIds, submittedBy: ctx.uid, submittedOn: todayIST(), updatedAt: UP() });
      ctx.audit({ action: 'libVerification.submit', ref: ref.path, after: { status, missing: missingIds.length, unexpected: unexpected.length } });
      return { id: ref.id, status, missing: missingIds.length, unexpected: unexpected.length };
    },
  }),

  /**
   * Applies the reviewed corrections through the same status rules as manual changes: `lost` marks a missing
   * copy lost, `move` brings an unexpected available copy into this library. Missing copies left alone stay
   * recorded as under investigation; accession history is never rewritten.
   */
  verificationApprove: def({
    name: 'lib.verification.approve',
    perm: 'lib.settings',
    input: z.object({ id, lost: z.array(id).max(MAX_COPIES).default([]), move: z.array(id).max(MAX_COPIES).default([]) }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadSession(ctx, i.id);
      if (d.status !== 'submitted') throw failed(`Verification is ${d.status}`);
      const missingIds = new Set(list(d, 'missing'));
      const unexpected = new Set(list(d, 'unexpected'));
      if (i.lost.some((c) => !missingIds.has(c))) throw failed('Only missing copies can be marked lost');
      if (i.move.some((c) => !unexpected.has(c))) throw failed('Only unexpected copies can be moved');
      const touched = [...i.lost, ...i.move];
      const snaps = touched.length ? await ctx.tx.getAll(...touched.map((c) => ctx.doc(`libCopies/${c}`))) : [];
      const lib = i.move.length ? usable(await ctx.tx.get(ctx.doc(`libLibraries/${d.libraryId}`)), 'Library', true) : null;
      for (const s of snaps) {
        const c = s.data();
        if (!c) throw missing('libCopy');
        ctx.requireCampus(c.campusId);
        if (i.lost.includes(s.id)) {
          if (!LOSABLE.includes(c.status)) throw failed(`${s.id} is ${c.status}`);
          ctx.update(s.ref, { status: 'lost', updatedAt: UP() });
        } else {
          if (c.status !== 'available') throw failed(`${s.id} is ${c.status}`);
          ctx.update(s.ref, { libraryId: d.libraryId, campusId: lib!.campusId, shelf: d.shelf ?? null, updatedAt: UP() });
        }
      }
      const investigate = [...missingIds].filter((c) => !i.lost.includes(c));
      ctx.update(ref, { status: 'approved', lost: i.lost, moved: i.move, investigate, approvedBy: ctx.uid, approvedOn: todayIST(), updatedAt: UP() });
      ctx.audit({
        action: 'libVerification.approve',
        ref: ref.path,
        before: { status: d.status },
        after: { status: 'approved', lost: i.lost, moved: i.move, investigate },
      });
      return { id: ref.id };
    },
  }),
};
