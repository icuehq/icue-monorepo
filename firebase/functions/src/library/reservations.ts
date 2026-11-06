import {
  getFirestore,
  type DocumentData,
  type DocumentReference,
  type DocumentSnapshot,
} from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { z } from 'zod';
import { CallableContext } from '../shared/callable';
import { todayIST, addDays, dayTimestamp, timestampDay } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { nextNumber } from '../shared/keys';
import { defineCallable, failed, id, missing, usable } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { forEachSchool } from '../shared/scheduled';
import { ineligibleReason, memberId, personInput, policyId, writeBorrower } from './members';
import { memberTo } from './notify';

const DEFAULT_HOLD_DAYS = 3;
/** Waiting rows read per freed copy; members who are no longer eligible are skipped, so read a few extra. */
const LOOKAHEAD = 10;

/** Waiting reservations of a title in a library, oldest first (FRS 11.12 queue order). */
export const waitingQuery = (
  context: CallableContext,
  catalogueId: string,
  libraryId: string,
  limit: number,
) =>
  context.transaction.get(
    context
      .coll('libraryReservations')
      .where('status', '==', 'waiting')
      .where('catalogueId', '==', catalogueId)
      .where('libraryId', '==', libraryId)
      .orderBy('createdAt')
      .limit(limit),
  );

/** The first `n` waiting reservations whose member can still borrow; the rest keep their place. */
export async function nextWaiting(
  context: CallableContext,
  catalogueId: string,
  libraryId: string,
  count: number,
): Promise<DocumentSnapshot[]> {
  const out: DocumentSnapshot[] = [];
  for (const snapshot of (await waitingQuery(context, catalogueId, libraryId, count + LOOKAHEAD))
    .docs) {
    if (out.length === count) break;
    const member = (
      await context.transaction.get(context.doc(`libraryMembers/${snapshot.data().memberId}`))
    ).data();
    if (member && !ineligibleReason(member)) out.push(snapshot);
  }
  return out;
}

export async function holdDays(context: CallableContext): Promise<number> {
  const configuredDays = (
    await context.transaction.get(context.doc('config/librarySettings'))
  ).data()?.holdDays;
  return typeof configuredDays === 'number' && configuredDays >= 1
    ? configuredDays
    : DEFAULT_HOLD_DAYS;
}

/** Holds a copy for a reservation and tells the member (the student's parent, or the teacher). */
export async function hold(
  context: CallableContext,
  reservationSnapshot: DocumentSnapshot,
  copyRef: DocumentReference,
  copyId: string,
  days: number,
): Promise<void> {
  const reservation = reservationSnapshot.data()!;
  const holdUntilDay = addDays(todayIST(), days);
  context.update(reservationSnapshot.ref, {
    status: 'ready',
    heldCopyId: copyId,
    holdUntil: dayTimestamp(holdUntilDay),
    readyAt: serverTimestamp(),
  });
  context.update(copyRef, {
    status: 'reserved',
    heldReservationId: reservationSnapshot.id,
    activeLoanId: null,
    updatedAt: serverTimestamp(),
  });
  await enqueue(context, `library-reservation-ready__${reservationSnapshot.id}`, {
    to: memberTo(reservation.memberType, reservation.personErpId),
    category: 'library.reservation',
    title: 'Reserved book is ready',
    body: `${reservation.title}: collect it by ${holdUntilDay}.`,
    data: { reservationId: reservationSnapshot.id },
  });
}

/**
 * A copy came free (returned, repaired, cancelled or expired hold): the next eligible member in the
 * queue gets it, otherwise it goes back on the shelf.
 */
export async function release(
  context: CallableContext,
  copyRef: DocumentReference,
  copy: DocumentData,
): Promise<void> {
  const [next] = await nextWaiting(context, copy.catalogueId, copy.libraryId, 1);
  if (next) await hold(context, next, copyRef, copyRef.id, await holdDays(context));
  else
    context.update(copyRef, {
      status: 'available',
      heldReservationId: null,
      activeLoanId: null,
      updatedAt: serverTimestamp(),
    });
}

export const reservations = {
  /**
   * Joins the waiting list of a title (FRS 11.12). Only when no copy is on the shelf, and only for an
   * eligible member whose policy allows reserving; one live reservation per member and title.
   */
  reservationCreate: defineCallable({
    name: 'library.reservation.create',
    permission: 'library.circulation.operate',
    input: z.object({ person: personInput, catalogueId: id, libraryId: id }),
    handler: async (context, i) => {
      const memberKey = memberId(i.person.memberType, i.person.personErpId);
      const [snapshot, libraryDocument, category] = await Promise.all([
        context.transaction.get(context.doc(`libraryMembers/${memberKey}`)),
        context.transaction.get(context.doc(`libraries/${i.libraryId}`)),
        context.transaction.get(context.doc(`libraryCatalogue/${i.catalogueId}`)),
      ]);
      const member = snapshot.data();
      const library = usable(libraryDocument, 'Library', false);
      context.requireCampus(library.campusId);
      const title = usable(category, 'Title', false);

      const ineligible = ineligibleReason(member);
      if (ineligible) throw failed(ineligible);
      const policy = (
        await context.transaction.get(
          context.doc(`libraryBorrowingPolicies/${policyId(i.libraryId, i.person.memberType)}`),
        )
      ).data();
      if (!policy || policy.status !== 'active')
        throw failed('No active borrowing policy for this member');
      if (!policy.canReserve) throw failed('This member category cannot reserve');
      if (policy.restrictedCategoryIds.includes(title.categoryId))
        throw failed('This category is restricted for the member');

      const live = await context.transaction.get(
        context
          .coll('libraryReservations')
          .where('memberId', '==', memberKey)
          .where('catalogueId', '==', i.catalogueId)
          .where('status', 'in', ['waiting', 'ready'])
          .limit(1),
      );
      if (!live.empty) throw failed('Member already has a reservation for this title');
      const loans = await context.transaction.get(
        context
          .coll('libraryLoans')
          .where('memberId', '==', memberKey)
          .where('catalogueId', '==', i.catalogueId)
          .where('status', '==', 'active')
          .limit(1),
      );
      if (!loans.empty) throw failed('Member already has this title on loan');
      const shelf = await context.transaction.get(
        context
          .coll('libraryCopies')
          .where('catalogueId', '==', i.catalogueId)
          .where('libraryId', '==', i.libraryId)
          .where('status', '==', 'available')
          .limit(1),
      );
      if (!shelf.empty) throw failed('A copy is available; issue it instead');

      const ref = context.newDoc('libraryReservations');
      const number = await nextNumber(context, 'RSV');
      const after = {
        number,
        memberId: memberKey,
        memberType: i.person.memberType,
        personErpId: i.person.personErpId,
        memberName: i.person.name,
        catalogueId: i.catalogueId,
        title: title.title,
        libraryId: i.libraryId,
        campusId: library.campusId,
        status: 'waiting',
        heldCopyId: null,
        holdUntil: null,
        fulfilledLoanId: null,
        fulfilledCopyId: null,
      };
      writeBorrower(context, snapshot.ref, member, i.person, library.campusId, 0);
      context.set(ref, { ...after, createdBy: context.uid, createdAt: serverTimestamp() });
      context.audit({ action: 'libraryReservation.create', documentPath: ref.path, after });
      return { id: ref.id, number };
    },
  }),

  /** Cancels a waiting or ready reservation; a held copy moves on to the next member. */
  reservationCancel: defineCallable({
    name: 'library.reservation.cancel',
    permission: 'library.circulation.operate',
    input: z.object({ id }),
    handler: async (context, i) => {
      const ref = context.doc(`libraryReservations/${i.id}`);
      const snapshot = await context.transaction.get(ref);
      if (!snapshot.exists) throw missing('libraryReservation');
      const reservation = snapshot.data()!;
      context.requireCampus(reservation.campusId);
      if (reservation.status !== 'waiting' && reservation.status !== 'ready')
        throw failed(`Reservation is ${reservation.status}`);
      if (reservation.status === 'ready') await freeHeld(context, reservation.heldCopyId, ref.id);
      context.update(ref, {
        status: 'cancelled',
        cancelledBy: context.uid,
        cancelledAt: serverTimestamp(),
      });
      context.audit({
        action: 'libraryReservation.cancel',
        documentPath: ref.path,
        before: { status: reservation.status },
        after: { status: 'cancelled' },
      });
      return { id: ref.id };
    },
  }),
};

/** Releases the copy held for [reservationId], unless it has meanwhile been taken by something else. */
async function freeHeld(
  context: CallableContext,
  copyId: string,
  reservationId: string,
): Promise<void> {
  const cRef = context.doc(`libraryCopies/${copyId}`);
  const copy = (await context.transaction.get(cRef)).data();
  if (copy?.heldReservationId === reservationId) await release(context, cRef, copy);
}

/** Expires holds past `holdUntil` and passes each copy to the next member. Re-checked per row, so reruns are no-ops. */
export async function runHoldExpiry(schoolId: string, today = todayIST()): Promise<void> {
  const db = getFirestore();
  const due = await db
    .collection(`schools/${schoolId}/libraryReservations`)
    .where('status', '==', 'ready')
    .where('holdUntil', '<', dayTimestamp(today))
    .get();
  for (const snapshot of due.docs) {
    await db.runTransaction(async (transaction) => {
      const context = new CallableContext(transaction, schoolId, 'system', {
        permissions: [],
        campusIds: [],
        hasAllCampuses: true,
      });
      const reservation = (await transaction.get(snapshot.ref)).data();
      if (reservation?.status !== 'ready' || timestampDay(reservation.holdUntil) >= today) return;
      await freeHeld(context, reservation.heldCopyId, snapshot.id);
      context.update(snapshot.ref, { status: 'expired', expiredAt: serverTimestamp() });
      context.flush();
    });
  }
}

/** Hourly, every school (architecture §5.2). */
export const holdExpiry = onSchedule(
  { schedule: '0 * * * *', timeZone: 'Asia/Kolkata', timeoutSeconds: 540 },
  async () => {
    await forEachSchool(runHoldExpiry);
  },
);
