import { Timestamp } from 'firebase-admin/firestore';
import type { DocumentData, DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { dayTimestamp, isoDate, todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { nextNumber } from '../shared/keys';
import { defineCallable, failed, id, missing } from '../shared/masters';

/** Where a fine or incident happened: the copy's title, library and campus (a loan or copy document has all four). */
export const copyFields = (source: DocumentData) => ({
  catalogueId: source.catalogueId,
  accessionNumber: source.accessionNumber,
  libraryId: source.libraryId,
  campusId: source.campusId,
});

/** Block fields for a fine; a hand-set block keeps its own origin so paying fines never lifts it. */
export const fineBlock = (member: DocumentData) => ({
  blocked: true,
  blockedBy: member.blocked && member.blockedBy === 'manual' ? 'manual' : 'fine',
});

/** Queues an outstanding fine against a member. Callers block the member and notify. */
export async function raiseFine(
  context: CallableContext,
  fine: {
    id: string;
    type: string;
    amount: number;
    memberId: string;
    member: DocumentData;
    source: DocumentData;
    calculation: Record<string, unknown>;
    loanId?: string | null;
    incidentId?: string;
  },
): Promise<DocumentReference> {
  const ref = context.doc(`libraryFines/${fine.id}`);
  context.set(ref, {
    fineNumber: await nextNumber(context, 'FIN'),
    ...(fine.incidentId ? { incidentId: fine.incidentId } : {}),
    loanId: fine.loanId ?? null,
    memberId: fine.memberId,
    memberType: fine.member.memberType,
    personErpId: fine.member.personErpId,
    ...copyFields(fine.source),
    type: fine.type,
    amount: fine.amount,
    waived: 0,
    paid: 0,
    outstanding: fine.amount,
    status: 'outstanding',
    fineCalculation: fine.calculation,
    waivers: [],
    payments: [],
    createdAt: serverTimestamp(),
    createdBy: context.uid,
    updatedAt: serverTimestamp(),
  });
  return ref;
}

async function loadFine(context: CallableContext, fineId: string) {
  const ref = context.doc(`libraryFines/${fineId}`);
  const snapshot = await context.transaction.get(ref);
  if (!snapshot.exists) throw missing('libraryFine');
  const fine = snapshot.data()!;
  context.requireCampus(fine.campusId);
  return { ref, fine };
}

async function checkUnblockMember(
  context: CallableContext,
  memberId: string,
  currentFineId: string,
) {
  const otherFines = await context.transaction.get(
    context
      .coll('libraryFines')
      .where('memberId', '==', memberId)
      .where('status', 'in', ['outstanding', 'partially_paid'])
      .limit(2),
  );
  const hasOther = otherFines.docs.some((doc) => doc.id !== currentFineId);
  if (!hasOther) {
    const mRef = context.doc(`libraryMembers/${memberId}`);
    const mSnap = await context.transaction.get(mRef);
    if (mSnap.exists && mSnap.data()?.blocked && mSnap.data()?.blockedBy !== 'manual') {
      context.update(mRef, { blocked: false, blockedBy: null, updatedAt: serverTimestamp() });
    }
  }
}

export const fines = {
  /**
   * Waives all or part of an outstanding fine (FRS 11.13). Requires `library.fines.waive`.
   * When no open fines remain, unblocks the member.
   */
  fineWaive: defineCallable({
    name: 'library.fine.waive',
    permission: 'library.fines.waive',
    input: z.object({
      id,
      amount: z.number().min(0.01).max(10_000_000),
      reason: z.string().trim().min(1).max(500),
    }),
    handler: async (context, i) => {
      const { ref, fine } = await loadFine(context, i.id);
      if (fine.status === 'paid' || fine.status === 'waived' || (fine.outstanding ?? 0) <= 0) {
        throw failed(`Fine is already ${fine.status}`);
      }
      if (i.amount > fine.outstanding) {
        throw failed('Waived amount cannot exceed outstanding balance');
      }

      const waived = Math.round(((fine.waived ?? 0) + i.amount) * 100) / 100;
      const outstanding = Math.round((fine.outstanding - i.amount) * 100) / 100;
      const status =
        outstanding > 0
          ? (fine.paid ?? 0) > 0
            ? 'partially_paid'
            : 'outstanding'
          : (fine.paid ?? 0) > 0
            ? 'paid'
            : 'waived';
      const waivers = [
        ...(fine.waivers ?? []),
        {
          amount: i.amount,
          reason: i.reason,
          performedBy: context.uid,
          performedAt: Timestamp.now(),
        },
      ];

      if (outstanding <= 0 && fine.memberId) {
        await checkUnblockMember(context, fine.memberId, ref.id);
      }

      context.update(ref, { waived, outstanding, status, waivers, updatedAt: serverTimestamp() });
      context.audit({
        action: 'libraryFine.waive',
        documentPath: ref.path,
        before: { waived: fine.waived, outstanding: fine.outstanding, status: fine.status },
        after: { waived, outstanding, status, reason: i.reason },
      });
      return { id: ref.id, outstanding, status };
    },
  }),

  /**
   * Records a payment against a fine (FRS 11.13, Finance reference only).
   * When outstanding reaches 0 and no other open fines remain, unblocks the member.
   */
  fineSetPayment: defineCallable({
    name: 'library.fine.setPayment',
    permission: 'library.circulation.operate',
    input: z.object({
      id,
      paidAmount: z.number().min(0.01).max(10_000_000),
      reference: z.string().trim().max(60).nullish(),
      paidDate: isoDate.optional(),
    }),
    handler: async (context, i) => {
      const { ref, fine } = await loadFine(context, i.id);
      if (fine.status === 'paid' || fine.status === 'waived' || (fine.outstanding ?? 0) <= 0) {
        throw failed(`Fine is already ${fine.status}`);
      }
      if (i.paidAmount > fine.outstanding) {
        throw failed('Payment amount cannot exceed outstanding balance');
      }

      const paid = Math.round(((fine.paid ?? 0) + i.paidAmount) * 100) / 100;
      const outstanding = Math.round((fine.outstanding - i.paidAmount) * 100) / 100;
      const status = outstanding <= 0 ? 'paid' : 'partially_paid';
      const payments = [
        ...(fine.payments ?? []),
        {
          amount: i.paidAmount,
          reference: i.reference ?? null,
          date: dayTimestamp(i.paidDate ?? todayIST()),
          performedBy: context.uid,
        },
      ];

      if (outstanding <= 0 && fine.memberId) {
        await checkUnblockMember(context, fine.memberId, ref.id);
      }

      context.update(ref, { paid, outstanding, status, payments, updatedAt: serverTimestamp() });
      context.audit({
        action: 'libraryFine.setPayment',
        documentPath: ref.path,
        before: { paid: fine.paid, outstanding: fine.outstanding, status: fine.status },
        after: { paid, outstanding, status, reference: i.reference ?? null },
      });
      return { id: ref.id, outstanding, status };
    },
  }),
};
