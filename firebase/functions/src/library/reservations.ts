import '../region';
import { FieldValue, getFirestore, type DocumentData, type DocumentReference, type DocumentSnapshot } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { z } from 'zod';
import { todayIST } from '../inventory/stock';
import { Ctx } from '../shared/callable';
import { nextNumber } from '../shared/keys';
import { def, failed, id, missing, usable } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { policyId } from './members';

const UP = () => FieldValue.serverTimestamp();
const addDays = (d: string, n: number) => new Date(Date.parse(`${d}T00:00:00Z`) + n * 86_400_000).toISOString().slice(0, 10);
const DEFAULT_HOLD_DAYS = 3;
/** Waiting rows read per freed copy; members who are no longer eligible are skipped, so read a few extra. */
const LOOKAHEAD = 10;

const coll = (ctx: Ctx, name: string) => getFirestore().collection(`schools/${ctx.sid}/${name}`);

/** Waiting reservations of a title in a library, oldest first (FRS 11.12 queue order). */
export const waitingQuery = (ctx: Ctx, catalogueId: string, libraryId: string, limit: number) =>
  ctx.tx.get(
    coll(ctx, 'libReservations')
      .where('status', '==', 'waiting')
      .where('catalogueId', '==', catalogueId)
      .where('libraryId', '==', libraryId)
      .orderBy('createdAt')
      .limit(limit),
  );

/** The first `n` waiting reservations whose member can still borrow; the rest keep their place. */
export async function nextWaiting(ctx: Ctx, catalogueId: string, libraryId: string, n: number): Promise<DocumentSnapshot[]> {
  const today = todayIST();
  const out: DocumentSnapshot[] = [];
  for (const r of (await waitingQuery(ctx, catalogueId, libraryId, n + LOOKAHEAD)).docs) {
    if (out.length === n) break;
    const m = (await ctx.tx.get(ctx.doc(`libMembers/${r.data().memberId}`))).data();
    if (m?.status === 'active' && !m.blocked && m.start <= today && (!m.end || m.end >= today)) out.push(r);
  }
  return out;
}

export async function holdDays(ctx: Ctx): Promise<number> {
  const d = (await ctx.tx.get(ctx.doc('config/librarySettings'))).data()?.holdDays;
  return typeof d === 'number' && d >= 1 ? d : DEFAULT_HOLD_DAYS;
}

/** Holds a copy for a reservation and tells the member (the student's parent, or the teacher). */
export async function hold(ctx: Ctx, res: DocumentSnapshot, copyRef: DocumentReference, copyId: string, days: number): Promise<void> {
  const r = res.data()!;
  const holdUntil = addDays(todayIST(), days);
  ctx.update(res.ref, { status: 'ready', heldCopyId: copyId, holdUntil, readyAt: UP() });
  ctx.update(copyRef, { status: 'reserved', heldReservationId: res.id, activeLoanId: null, updatedAt: UP() });
  await enqueue(ctx, `rsv-ready__${res.id}`, {
    to: r.memberType === 'student' ? { wards: [r.personErpId] } : { eids: [r.personErpId] },
    category: 'lib.reservation',
    title: 'Reserved book is ready',
    body: `${r.title}: collect it by ${holdUntil}.`,
    data: { reservationId: res.id },
  });
}

/**
 * A copy came free (returned, repaired, cancelled or expired hold): the next eligible member in the
 * queue gets it, otherwise it goes back on the shelf.
 */
export async function release(ctx: Ctx, copyRef: DocumentReference, copy: DocumentData): Promise<void> {
  const [next] = await nextWaiting(ctx, copy.catalogueId, copy.libraryId, 1);
  if (next) await hold(ctx, next, copyRef, copyRef.id, await holdDays(ctx));
  else ctx.update(copyRef, { status: 'available', heldReservationId: null, activeLoanId: null, updatedAt: UP() });
}

export const reservations = {
  /**
   * Joins the waiting list of a title (FRS 11.12). Only when no copy is on the shelf, and only for an
   * eligible member whose policy allows reserving; one live reservation per member and title.
   */
  reservationCreate: def({
    name: 'lib.reservation.create',
    perm: 'lib.circulation.operate',
    input: z.object({ memberId: id, catalogueId: id, libraryId: id }),
    handler: async (ctx, i) => {
      const today = todayIST();
      const [m, lib, cat] = await Promise.all([
        ctx.tx.get(ctx.doc(`libMembers/${i.memberId}`)),
        ctx.tx.get(ctx.doc(`libLibraries/${i.libraryId}`)),
        ctx.tx.get(ctx.doc(`libCatalogue/${i.catalogueId}`)),
      ]);
      if (!m.exists) throw missing('libMember');
      const member = m.data()!;
      const library = usable(lib, 'Library', false);
      ctx.requireCampus(library.campusId);
      const title = usable(cat, 'Title', false);

      if (member.status !== 'active') throw failed('Member is inactive');
      if (member.blocked) throw failed('Member is blocked');
      if (member.start > today || (member.end && member.end < today)) throw failed('Membership is not valid today');
      if (!member.libraryIds.includes(i.libraryId)) throw failed('Member has no access to this library');
      const policy = (await ctx.tx.get(ctx.doc(`libPolicies/${policyId(i.libraryId, member.memberCategory)}`))).data();
      if (!policy || policy.status !== 'active') throw failed('No active borrowing policy for this member');
      if (!policy.canReserve) throw failed('This member category cannot reserve');
      if (policy.restrictedCategoryIds.includes(title.categoryId)) throw failed('This category is restricted for the member');

      const live = await ctx.tx.get(coll(ctx, 'libReservations').where('memberId', '==', m.id).where('catalogueId', '==', i.catalogueId).where('status', 'in', ['waiting', 'ready']).limit(1));
      if (!live.empty) throw failed('Member already has a reservation for this title');
      const loans = await ctx.tx.get(coll(ctx, 'libLoans').where('memberId', '==', m.id).where('catalogueId', '==', i.catalogueId).where('status', '==', 'active').limit(1));
      if (!loans.empty) throw failed('Member already has this title on loan');
      const shelf = await ctx.tx.get(
        coll(ctx, 'libCopies').where('catalogueId', '==', i.catalogueId).where('libraryId', '==', i.libraryId).where('status', '==', 'available').limit(1),
      );
      if (!shelf.empty) throw failed('A copy is available; issue it instead');

      const ref = ctx.newDoc('libReservations');
      const number = await nextNumber(ctx, 'RSV');
      const after = {
        number,
        memberId: m.id,
        memberType: member.memberType,
        personErpId: member.erpId,
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
      ctx.set(ref, { ...after, createdBy: ctx.uid, createdAt: UP() });
      ctx.audit({ action: 'libReservation.create', ref: ref.path, after });
      return { id: ref.id, number };
    },
  }),

  /** Cancels a waiting or ready reservation; a held copy moves on to the next member. */
  reservationCancel: def({
    name: 'lib.reservation.cancel',
    perm: 'lib.circulation.operate',
    input: z.object({ id }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`libReservations/${i.id}`);
      const snap = await ctx.tx.get(ref);
      if (!snap.exists) throw missing('libReservation');
      const d = snap.data()!;
      ctx.requireCampus(d.campusId);
      if (d.status !== 'waiting' && d.status !== 'ready') throw failed(`Reservation is ${d.status}`);
      if (d.status === 'ready') await freeHeld(ctx, d.heldCopyId, ref.id);
      ctx.update(ref, { status: 'cancelled', cancelledBy: ctx.uid, cancelledAt: UP() });
      ctx.audit({ action: 'libReservation.cancel', ref: ref.path, before: { status: d.status }, after: { status: 'cancelled' } });
      return { id: ref.id };
    },
  }),
};

/** Releases the copy held for [reservationId], unless it has meanwhile been taken by something else. */
async function freeHeld(ctx: Ctx, copyId: string, reservationId: string): Promise<void> {
  const cRef = ctx.doc(`libCopies/${copyId}`);
  const copy = (await ctx.tx.get(cRef)).data();
  if (copy?.heldReservationId === reservationId) await release(ctx, cRef, copy);
}

/** Expires holds past `holdUntil` and passes each copy to the next member. Re-checked per row, so reruns are no-ops. */
export async function runHoldExpiry(sid: string, today = todayIST()): Promise<void> {
  const db = getFirestore();
  const due = await db.collection(`schools/${sid}/libReservations`).where('status', '==', 'ready').where('holdUntil', '<', today).get();
  for (const d of due.docs) {
    await db.runTransaction(async (tx) => {
      const ctx = new Ctx(tx, sid, 'system', { perms: [], cmp: [], all: true });
      const r = (await tx.get(d.ref)).data();
      if (r?.status !== 'ready' || r.holdUntil >= today) return;
      await freeHeld(ctx, r.heldCopyId, d.id);
      ctx.update(d.ref, { status: 'expired', expiredAt: UP() });
      ctx.flush();
    });
  }
}

/** Hourly, every school (architecture §5.2). */
export const holdExpiry = onSchedule({ schedule: '0 * * * *', timeZone: 'Asia/Kolkata' }, async () => {
  for (const school of await getFirestore().collection('schools').listDocuments()) await runHoldExpiry(school.id);
});
