import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { todayIST } from '../inventory/stock';
import type { Ctx } from '../shared/callable';
import { nextNumber } from '../shared/keys';
import { def, failed, id, missing, note } from '../shared/masters';
import { policyId } from './members';

const UP = () => FieldValue.serverTimestamp();
const addDays = (d: string, n: number) => new Date(Date.parse(`${d}T00:00:00Z`) + n * 86_400_000).toISOString().slice(0, 10);
const daysBetween = (from: string, to: string) => Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);

/** Policy values copied onto the loan so later policy edits never move its due date (FRS 11.8). */
const SNAPSHOT = ['name', 'maxBooks', 'loanDays', 'maxRenewals', 'fineType', 'fineAmount', 'graceDays', 'maxFine', 'overdueRenewal'] as const;

async function loadLoan(ctx: Ctx, loanId: string) {
  const ref = ctx.doc(`libLoans/${loanId}`);
  const snap = await ctx.tx.get(ref);
  if (!snap.exists) throw missing('libLoan');
  const d = snap.data()!;
  ctx.requireCampus(d.campusId);
  if (d.status !== 'active') throw failed(`Loan is ${d.status}`);
  return { ref, d };
}

export const loans = {
  /** Issues one copy to a member (FRS 11.9). Checks member, policy, limit, restriction and copy in one transaction. */
  loanIssue: def({
    name: 'lib.loan.issue',
    perm: 'lib.circulation.operate',
    input: z.object({ memberId: id, copyId: id, remarks: note }),
    handler: async (ctx, i) => {
      const today = todayIST();
      const mRef = ctx.doc(`libMembers/${i.memberId}`);
      const cRef = ctx.doc(`libCopies/${i.copyId}`);
      const [m, c] = await Promise.all([ctx.tx.get(mRef), ctx.tx.get(cRef)]);
      if (!m.exists) throw missing('libMember');
      if (!c.exists) throw missing('libCopy');
      const member = m.data()!;
      const copy = c.data()!;
      ctx.requireCampus(copy.campusId);

      if (member.status !== 'active') throw failed('Member is inactive');
      if (member.blocked) throw failed('Member is blocked');
      if (member.start > today || (member.end && member.end < today)) throw failed('Membership is not valid today');
      if (!member.libraryIds.includes(copy.libraryId)) throw failed('Member has no access to this library');
      if (copy.status !== 'available' || copy.activeLoanId) throw failed(`Copy is ${copy.status}`);

      const policy = (await ctx.tx.get(ctx.doc(`libPolicies/${policyId(copy.libraryId, member.memberCategory)}`))).data();
      if (!policy || policy.status !== 'active') throw failed('No active borrowing policy for this member');
      if (member.activeLoans >= policy.maxBooks) throw failed(`Borrowing limit of ${policy.maxBooks} reached`);
      const title = (await ctx.tx.get(ctx.doc(`libCatalogue/${copy.catalogueId}`))).data();
      if (title && policy.restrictedCategoryIds.includes(title.categoryId)) throw failed('This category is restricted for the member');

      const loan = ctx.newDoc('libLoans');
      const number = await nextNumber(ctx, 'ISS');
      const snapshot = Object.fromEntries(SNAPSHOT.map((k) => [k, policy[k] ?? null]));
      const after = {
        number,
        memberId: m.id,
        memberType: member.memberType,
        personErpId: member.erpId,
        copyId: c.id,
        accessionNo: copy.accessionNo,
        catalogueId: copy.catalogueId,
        libraryId: copy.libraryId,
        campusId: copy.campusId,
        issuedOn: today,
        dueOn: addDays(today, policy.loanDays),
        remarks: i.remarks ?? null,
        renewals: [],
        policySnapshot: snapshot,
        status: 'active',
      };
      ctx.set(loan, { ...after, issuedBy: ctx.uid, issuedAt: UP() });
      ctx.update(cRef, { status: 'issued', activeLoanId: loan.id, updatedAt: UP() });
      ctx.update(mRef, { activeLoans: FieldValue.increment(1), updatedAt: UP() });
      ctx.audit({ action: 'libLoan.issue', ref: loan.path, after });
      return { id: loan.id, number, dueOn: after.dueOn };
    },
  }),

  /**
   * Returns a book against its active loan (FRS 11.10). A damaged copy is never made available;
   * overdue days are stored and the fine is raised by Lib-6.
   */
  loanReturn: def({
    name: 'lib.loan.return',
    perm: 'lib.circulation.operate',
    input: z.object({ id, condition: z.enum(['good', 'damaged']), remarks: note }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadLoan(ctx, i.id);
      const cRef = ctx.doc(`libCopies/${d.copyId}`);
      const mRef = ctx.doc(`libMembers/${d.memberId}`);
      const [c, m] = await Promise.all([ctx.tx.get(cRef), ctx.tx.get(mRef)]);
      if (c.data()?.activeLoanId !== ref.id) throw failed('Copy is not on this loan');
      const today = todayIST();
      const overdueDays = Math.max(0, daysBetween(d.dueOn, today));
      const returnNumber = await nextNumber(ctx, 'RET');
      const after = { status: 'returned', returnNumber, returnedOn: today, condition: i.condition, overdueDays, returnRemarks: i.remarks ?? null };
      ctx.update(ref, { ...after, receivedBy: ctx.uid, returnedAt: UP() });
      ctx.update(cRef, { status: i.condition === 'damaged' ? 'damaged' : 'available', activeLoanId: null, updatedAt: UP() });
      if (m.exists) ctx.update(mRef, { activeLoans: Math.max(0, (m.data()!.activeLoans ?? 0) - 1), updatedAt: UP() });
      ctx.audit({ action: 'libLoan.return', ref: ref.path, before: { status: 'active' }, after });
      return { id: ref.id, returnNumber, overdueDays };
    },
  }),

  /** Extends the due date by the loan's own `loanDays` (FRS 11.11), counted from the later of due date and today. */
  loanRenew: def({
    name: 'lib.loan.renew',
    perm: 'lib.circulation.operate',
    input: z.object({ id }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadLoan(ctx, i.id);
      const member = (await ctx.tx.get(ctx.doc(`libMembers/${d.memberId}`))).data();
      if (member?.status !== 'active' || member.blocked) throw failed('Member cannot renew');
      const p = d.policySnapshot;
      const today = todayIST();
      if (d.renewals.length >= p.maxRenewals) throw failed(`Renewal limit of ${p.maxRenewals} reached`);
      if (d.dueOn < today && !p.overdueRenewal) throw failed('Overdue loans cannot be renewed');
      // ponytail: reservation conflicts are checked once reservations exist (Lib-5).
      const dueOn = addDays(d.dueOn > today ? d.dueOn : today, p.loanDays);
      const renewals = [...d.renewals, { on: today, from: d.dueOn, to: dueOn, by: ctx.uid }];
      ctx.update(ref, { dueOn, renewals, updatedAt: UP() });
      ctx.audit({ action: 'libLoan.renew', ref: ref.path, before: { dueOn: d.dueOn }, after: { dueOn, count: renewals.length } });
      return { id: ref.id, dueOn };
    },
  }),
};
