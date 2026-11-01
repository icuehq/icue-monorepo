import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { todayIST } from '../inventory/stock';
import type { Ctx } from '../shared/callable';
import { def, failed, id, missing } from '../shared/masters';

const UP = () => FieldValue.serverTimestamp();
const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

async function loadFine(ctx: Ctx, fineId: string) {
  const ref = ctx.doc(`libFines/${fineId}`);
  const snap = await ctx.tx.get(ref);
  if (!snap.exists) throw missing('libFine');
  const d = snap.data()!;
  ctx.requireCampus(d.campusId);
  return { ref, d };
}

async function checkUnblockMember(ctx: Ctx, memberId: string, currentFineId: string) {
  const otherFines = await ctx.tx.get(
    ctx.coll('libFines').where('memberId', '==', memberId).where('status', 'in', ['outstanding', 'partially_paid']).limit(2),
  );
  const hasOther = otherFines.docs.some((doc) => doc.id !== currentFineId);
  if (!hasOther) {
    const mRef = ctx.doc(`libMembers/${memberId}`);
    const mSnap = await ctx.tx.get(mRef);
    if (mSnap.exists && mSnap.data()?.blocked) {
      ctx.update(mRef, { blocked: false, updatedAt: UP() });
    }
  }
}

export const fines = {
  /**
   * Waives all or part of an outstanding fine (FRS 11.13). Requires `lib.fines.waive`.
   * When no open fines remain, unblocks the member.
   */
  fineWaive: def({
    name: 'lib.fine.waive',
    perm: 'lib.fines.waive',
    input: z.object({
      id,
      amount: z.number().min(0.01).max(10_000_000),
      reason: z.string().trim().min(1).max(500),
    }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadFine(ctx, i.id);
      if (d.status === 'paid' || d.status === 'waived' || (d.outstanding ?? 0) <= 0) {
        throw failed(`Fine is already ${d.status}`);
      }
      if (i.amount > d.outstanding) {
        throw failed('Waived amount cannot exceed outstanding balance');
      }

      const waived = Math.round(((d.waived ?? 0) + i.amount) * 100) / 100;
      const outstanding = Math.round((d.outstanding - i.amount) * 100) / 100;
      const status = outstanding <= 0 ? 'waived' : (d.paid ?? 0) > 0 ? 'partially_paid' : 'outstanding';
      const waivals = [...(d.waivals ?? []), { amount: i.amount, reason: i.reason, by: ctx.uid, at: todayIST() }];

      if (outstanding <= 0 && d.memberId) {
        await checkUnblockMember(ctx, d.memberId, ref.id);
      }

      ctx.update(ref, { waived, outstanding, status, waivals, updatedAt: UP() });
      ctx.audit({
        action: 'libFine.waive',
        ref: ref.path,
        before: { waived: d.waived, outstanding: d.outstanding, status: d.status },
        after: { waived, outstanding, status, reason: i.reason },
      });
      return { id: ref.id, outstanding, status };
    },
  }),

  /**
   * Records a payment against a fine (FRS 11.13, Finance reference only).
   * When outstanding reaches 0 and no other open fines remain, unblocks the member.
   */
  fineSetPayment: def({
    name: 'lib.fine.setPayment',
    perm: 'lib.circulation.operate',
    input: z.object({
      id,
      paidAmount: z.number().min(0.01).max(10_000_000),
      reference: z.string().trim().max(60).nullish(),
      paidDate: day.optional(),
    }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadFine(ctx, i.id);
      if (d.status === 'paid' || d.status === 'waived' || (d.outstanding ?? 0) <= 0) {
        throw failed(`Fine is already ${d.status}`);
      }
      if (i.paidAmount > d.outstanding) {
        throw failed('Payment amount cannot exceed outstanding balance');
      }

      const paid = Math.round(((d.paid ?? 0) + i.paidAmount) * 100) / 100;
      const outstanding = Math.round((d.outstanding - i.paidAmount) * 100) / 100;
      const status = outstanding <= 0 ? 'paid' : 'partially_paid';
      const payments = [
        ...(d.payments ?? []),
        { amount: i.paidAmount, reference: i.reference ?? null, date: i.paidDate ?? todayIST(), by: ctx.uid },
      ];

      if (outstanding <= 0 && d.memberId) {
        await checkUnblockMember(ctx, d.memberId, ref.id);
      }

      ctx.update(ref, { paid, outstanding, status, payments, updatedAt: UP() });
      ctx.audit({
        action: 'libFine.setPayment',
        ref: ref.path,
        before: { paid: d.paid, outstanding: d.outstanding, status: d.status },
        after: { paid, outstanding, status, reference: i.reference },
      });
      return { id: ref.id, outstanding, status };
    },
  }),
};
