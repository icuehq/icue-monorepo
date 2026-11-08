import {
  getFirestore,
  type DocumentData,
  type DocumentReference,
  type DocumentSnapshot,
} from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { CallableContext } from '../shared/callable';
import { todayIST, addDays, dayTimestamp, timestampDay } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { enqueue } from '../shared/outbox';
import { forEachSchool } from '../shared/scheduled';
import { ineligibleReason } from './members';
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
  const waiting = (await waitingQuery(context, catalogueId, libraryId, count + LOOKAHEAD)).docs;
  if (!waiting.length) return [];
  // One batched read of the distinct members, then the queue is walked in order.
  const personIds = [...new Set(waiting.map((snapshot) => snapshot.data().personErpId as number))];
  const members = new Map(
    (
      await context.transaction.getAll(
        ...personIds.map((personErpId) => context.doc(`libraryMembers/${personErpId}`)),
      )
    ).map((member) => [Number(member.id), member.data()]),
  );
  return waiting
    .filter((snapshot) => {
      const member = members.get(snapshot.data().personErpId);
      return member && !ineligibleReason(member);
    })
    .slice(0, count);
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
  barcode: string,
  days: number,
): Promise<void> {
  const reservation = reservationSnapshot.data()!;
  const holdUntilDay = addDays(todayIST(), days);
  context.update(reservationSnapshot.ref, {
    status: 'ready',
    heldBarcode: barcode,
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

/** Releases the copy held for [reservationId], unless it has meanwhile been taken by something else. */
async function freeHeld(
  context: CallableContext,
  barcode: string,
  reservationId: string,
): Promise<void> {
  const cRef = context.doc(`libraryCopies/${barcode}`);
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
      await freeHeld(context, reservation.heldBarcode, snapshot.id);
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
