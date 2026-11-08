import { type DocumentData, type DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import {
  Collections,
  LoanStatus,
  type LibraryLoan,
  type LoanPolicySnapshot,
} from '../shared/contracts';
import { todayIST, addDays, daysBetween, dayTimestamp, timestampDay } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { nextNumber } from '../shared/keys';
import { defineCallable, failed, id, missing, optionalText } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { fineBlock, raiseFine } from './fines';
import { openIncident } from './incidents';
import {
  applicablePolicy,
  ineligibleReason,
  memberId,
  personInput,
  writeBorrower,
} from './members';
import { memberTo } from './notify';
import { release, waitingQuery } from './reservations';

/** Policy values copied onto the loan so later policy edits never move its due date (FRS 11.8). */
const SNAPSHOT = [
  'name',
  'maxBooks',
  'loanDays',
  'maxRenewals',
  'fineType',
  'fineAmount',
  'graceDays',
  'maxFine',
] as const satisfies (keyof LoanPolicySnapshot)[];

/** Overdue fine from the loan's policy snapshot (FRS 11.13): per day or flat after the grace days, capped at `maxFine`. */
function overdueFineAmount(policy: Record<string, unknown>, overdueDays: number): number {
  const grace = (policy.graceDays as number) ?? 0;
  if (overdueDays <= grace) return 0;
  const rate = (policy.fineAmount as number) ?? 0;
  let amount = 0;
  if (policy.fineType === 'per_day') amount = (overdueDays - grace) * rate;
  else if (policy.fineType === 'flat') amount = rate;
  const max = policy.maxFine as number | null | undefined;
  if (typeof max === 'number' && max > 0 && amount > max) amount = max;
  return Math.round(amount * 100) / 100;
}

/** Queues the overdue fine document and its notification; the caller blocks the member. */
async function raiseOverdueFine(
  context: CallableContext,
  fineId: string,
  loanId: string,
  loan: DocumentData,
  memberId: string,
  member: DocumentData,
  amount: number,
  overdueDays: number,
): Promise<void> {
  const policy = loan.policySnapshot ?? {};
  const fRef = await raiseFine(context, {
    id: fineId,
    type: 'overdue',
    amount,
    memberId,
    member,
    source: loan,
    barcode: loan.barcode,
    loanId,
    calculation: {
      overdueDays,
      graceDays: policy.graceDays ?? 0,
      fineType: policy.fineType,
      fineAmount: policy.fineAmount,
      maxFine: policy.maxFine,
    },
  });
  await enqueue(context, `library-fine__${fineId}`, {
    to: memberTo(member.memberType, member.personErpId),
    category: 'library.fine',
    title: 'Fine recorded',
    body: `${loan.barcode}: overdue fine of ${amount} for ${overdueDays} day(s).`,
    data: { fineId: fRef.id },
  });
}

async function loadLoan(context: CallableContext, loanId: string) {
  const ref = context.doc(`${Collections.libraryLoans}/${loanId}`);
  const snapshot = await context.transaction.get(ref);
  if (!snapshot.exists) throw missing('libraryLoan');
  const loan = snapshot.data()!;
  context.requireCampus(loan.campusId);
  if (loan.status !== LoanStatus.active) throw failed(`Loan is ${loan.status}`);
  return { ref, loan };
}

export const loans = {
  /** Issues one copy to a member (FRS 11.9). Checks member, policy, limit, restriction and copy in one transaction. */
  loanIssue: defineCallable({
    name: 'library.loan.issue',
    permission: 'library.circulation.operate',
    input: z.object({ person: personInput, barcode: id, remarks: optionalText }),
    handler: async (context, i) => {
      const today = todayIST();
      const memberKey = memberId(i.person.memberType, i.person.personErpId);
      const mRef = context.doc(`libraryMembers/${memberKey}`);
      const cRef = context.doc(`libraryCopies/${i.barcode}`);
      const [memberSnapshot, copySnapshot] = await Promise.all([
        context.transaction.get(mRef),
        context.transaction.get(cRef),
      ]);
      if (!copySnapshot.exists) throw missing('libraryCopy');
      // A person the Library has not seen before is created at the end of this issue.
      const member = memberSnapshot.data();
      const copy = copySnapshot.data()!;
      context.requireCampus(copy.campusId);

      const ineligible = ineligibleReason(member);
      if (ineligible) throw failed(ineligible);
      // A held copy goes only to the member it is held for, within the hold period (FRS 11.12).
      let held: DocumentReference | undefined;
      if (copy.status === 'reserved') {
        held = context.doc(`libraryReservations/${copy.heldReservationId}`);
        const reservation = (await context.transaction.get(held)).data();
        if (reservation?.memberId !== memberKey || reservation.status !== 'ready')
          throw failed('Copy is held for another member');
        if (!reservation.holdUntil || timestampDay(reservation.holdUntil) < today)
          throw failed('The hold on this copy has expired');
      } else if (copy.status !== 'available' || copy.activeLoanId)
        throw failed(`Copy is ${copy.status}`);

      const title = (
        await context.transaction.get(context.doc(`libraryCatalogue/${copy.catalogueId}`))
      ).data();
      if (!title) throw missing('libraryCatalogue');
      const found = await applicablePolicy(
        context,
        copy.libraryId,
        i.person.memberType,
        title.categoryId,
      );
      if (!found) throw failed('No active borrowing policy for this member and book category');
      const policy = found.data;
      // The limit counts only the loans held under this same policy.
      const underPolicy = await context.transaction.get(
        context
          .coll(Collections.libraryLoans)
          .where('memberId', '==', memberKey)
          .where('status', '==', LoanStatus.active)
          .where('policySnapshot.policyId', '==', found.id),
      );
      if (underPolicy.size >= policy.maxBooks)
        throw failed(`Borrowing limit of ${policy.maxBooks} reached`);

      const loan = context.newDoc(Collections.libraryLoans);
      const number = await nextNumber(context, 'LIS');
      const snapshot = Object.fromEntries([
        ['policyId', found.id],
        ...SNAPSHOT.map((field) => [field, policy[field] ?? null]),
      ]) as unknown as LoanPolicySnapshot;
      const after = {
        number,
        memberId: memberKey,
        memberType: i.person.memberType,
        personErpId: i.person.personErpId,
        memberName: i.person.name,
        barcode: copySnapshot.id,
        catalogueId: copy.catalogueId,
        libraryId: copy.libraryId,
        campusId: copy.campusId,
        issuedDate: dayTimestamp(today),
        dueDate: dayTimestamp(addDays(today, policy.loanDays)),
        remarks: i.remarks ?? null,
        renewals: [],
        policySnapshot: snapshot,
        status: LoanStatus.active,
      } satisfies Partial<LibraryLoan>;
      context.set(loan, { ...after, issuedBy: context.uid, issuedAt: serverTimestamp() });
      context.update(cRef, {
        status: 'issued',
        activeLoanId: loan.id,
        heldReservationId: null,
        updatedAt: serverTimestamp(),
      });
      if (held)
        context.update(held, {
          status: 'fulfilled',
          fulfilledLoanId: loan.id,
          fulfilledBarcode: copySnapshot.id,
          fulfilledAt: serverTimestamp(),
        });
      writeBorrower(context, mRef, member, i.person, copy.campusId, 1);
      await enqueue(context, `library-issued__${loan.id}`, {
        to: memberTo(i.person.memberType, i.person.personErpId),
        category: 'library.loan',
        title: 'Book issued',
        body: `${title?.title ?? copySnapshot.id}: due back ${timestampDay(after.dueDate)}.`,
        data: { loanId: loan.id },
      });
      context.audit({ action: 'libraryLoan.issue', documentPath: loan.path, after });
      return { id: loan.id, number, dueDate: timestampDay(after.dueDate) };
    },
  }),

  /**
   * Returns a book against its active loan (FRS 11.10). A damaged copy is never made available;
   * overdue days are stored and the fine is raised by Lib-6.
   */
  loanReturn: defineCallable({
    name: 'library.loan.return',
    permission: 'library.circulation.operate',
    input: z.object({ id, condition: z.enum(['good', 'damaged']), remarks: optionalText }),
    handler: async (context, i) => {
      const { ref, loan } = await loadLoan(context, i.id);
      const cRef = context.doc(`libraryCopies/${loan.barcode}`);
      const mRef = context.doc(`libraryMembers/${loan.memberId}`);
      const [snapshot, memberSnapshot] = await Promise.all([
        context.transaction.get(cRef),
        context.transaction.get(mRef),
      ]);
      if (snapshot.data()?.activeLoanId !== ref.id) throw failed('Copy is not on this loan');
      const today = todayIST();
      const overdueDays = Math.max(0, daysBetween(timestampDay(loan.dueDate), today));
      const returnNumber = await nextNumber(context, 'LRT');
      const after = {
        status: LoanStatus.returned,
        returnNumber,
        returnedDate: dayTimestamp(today),
        condition: i.condition,
        overdueDays,
        returnRemarks: i.remarks ?? null,
      } satisfies Partial<LibraryLoan>;
      context.update(ref, { ...after, receivedBy: context.uid, returnedAt: serverTimestamp() });

      const fineAmount = overdueFineAmount(loan.policySnapshot ?? {}, overdueDays);
      if (fineAmount > 0 && memberSnapshot.exists) {
        await raiseOverdueFine(
          context,
          `${ref.id}__overdue`,
          ref.id,
          loan,
          memberSnapshot.id,
          memberSnapshot.data()!,
          fineAmount,
          overdueDays,
        );
      }

      if (i.condition === 'damaged') {
        context.update(cRef, {
          status: 'damaged',
          activeLoanId: null,
          updatedAt: serverTimestamp(),
        });
        await openIncident(context, {
          type: 'damaged',
          copy: snapshot.data()!,
          barcode: snapshot.id,
          memberId: memberSnapshot.exists ? memberSnapshot.id : null,
          member: memberSnapshot.exists ? memberSnapshot.data()! : null,
          loanId: ref.id,
          severity: 'moderate',
          description: i.remarks ?? 'Returned in damaged condition',
          charge: 0,
          repairStatus: 'none',
          title: 'Damaged book recorded',
          body: `${loan.barcode} was returned damaged.`,
        });
      } else {
        await release(context, cRef, loan);
      }
      await enqueue(context, `library-returned__${ref.id}`, {
        to: memberTo(loan.memberType, loan.personErpId),
        category: 'library.loan',
        title: 'Book returned',
        body: `${loan.barcode} was returned${overdueDays ? ` ${overdueDays} day(s) late` : ''}.`,
        data: { loanId: ref.id },
      });

      if (memberSnapshot.exists) {
        const member = memberSnapshot.data()!;
        const activeLoans = Math.max(0, (member.activeLoans ?? 0) - 1);
        context.update(mRef, {
          activeLoans,
          ...(fineAmount > 0 ? fineBlock(member) : {}),
          updatedAt: serverTimestamp(),
        });
      }

      context.audit({
        action: 'libraryLoan.return',
        documentPath: ref.path,
        before: { status: LoanStatus.active },
        after,
      });
      return { id: ref.id, returnNumber, overdueDays };
    },
  }),

  /**
   * Marks a book lost during loan (FRS 11.14). The loan and copy are marked lost,
   * replacement charge is fined to the member, member is blocked, and an incident is recorded.
   */
  loanMarkLost: defineCallable({
    name: 'library.loan.markLost',
    permission: 'library.circulation.operate',
    input: z.object({
      id,
      reason: optionalText,
      charge: z.number().min(0).max(10_000_000).nullish(),
    }),
    handler: async (context, i) => {
      const { ref, loan } = await loadLoan(context, i.id);
      const cRef = context.doc(`libraryCopies/${loan.barcode}`);
      const mRef = context.doc(`libraryMembers/${loan.memberId}`);
      const [snapshot, memberSnapshot] = await Promise.all([
        context.transaction.get(cRef),
        context.transaction.get(mRef),
      ]);
      if (!snapshot.exists) throw missing('libraryCopy');
      const copy = snapshot.data()!;
      const member = memberSnapshot.exists ? memberSnapshot.data()! : null;
      if (copy.activeLoanId !== ref.id) throw failed('Copy is not on this loan');

      const today = todayIST();
      const charge = i.charge ?? copy.price ?? 0;
      const after = {
        status: LoanStatus.lost,
        lostDate: dayTimestamp(today),
        lostRemarks: i.reason ?? null,
        charge,
      };
      context.update(ref, { ...after, receivedBy: context.uid, returnedAt: serverTimestamp() });
      context.update(cRef, { status: 'lost', activeLoanId: null, updatedAt: serverTimestamp() });

      if (member) {
        const activeLoans = Math.max(0, (member.activeLoans ?? 0) - 1);
        context.update(mRef, {
          activeLoans,
          ...(charge > 0 ? fineBlock(member) : {}),
          updatedAt: serverTimestamp(),
        });
      }

      if (member && charge > 0) {
        const fRef = await raiseFine(context, {
          id: `${ref.id}__lost`,
          type: 'lost',
          amount: charge,
          memberId: memberSnapshot.id,
          member,
          source: loan,
          barcode: loan.barcode,
          loanId: ref.id,
          calculation: { copyPrice: copy.price, charge },
        });
        await enqueue(context, `library-fine__${ref.id}__lost`, {
          to: memberTo(member.memberType, member.personErpId),
          category: 'library.fine',
          title: 'Fine recorded',
          body: `${loan.barcode}: replacement charge of ${charge}.`,
          data: { fineId: fRef.id },
        });
      }

      await openIncident(context, {
        type: 'lost',
        copy,
        barcode: snapshot.id,
        memberId: member ? memberSnapshot.id : null,
        member,
        loanId: ref.id,
        severity: null,
        description: i.reason ?? 'Marked lost during loan',
        charge,
        repairStatus: null,
        title: 'Lost book recorded',
        body: `${loan.barcode} was marked lost.`,
      });

      context.audit({
        action: 'libraryLoan.markLost',
        documentPath: ref.path,
        before: { status: LoanStatus.active },
        after,
      });
      return { id: ref.id, charge };
    },
  }),

  /** Extends the due date by the loan's own `loanDays` (FRS 11.11), counted from the later of due date and today. */
  loanRenew: defineCallable({
    name: 'library.loan.renew',
    permission: 'library.circulation.operate',
    input: z.object({ id }),
    handler: async (context, i) => {
      const { ref, loan } = await loadLoan(context, i.id);
      const member = (
        await context.transaction.get(context.doc(`libraryMembers/${loan.memberId}`))
      ).data();
      if (!member || member.blocked) throw failed('Member cannot renew');
      const policy = loan.policySnapshot;
      const today = todayIST();
      if (loan.renewals.length >= policy.maxRenewals)
        throw failed(`Renewal limit of ${policy.maxRenewals} reached`);
      const currentDue = timestampDay(loan.dueDate);
      if (currentDue < today) throw failed('Overdue loans cannot be renewed');
      if (!(await waitingQuery(context, loan.catalogueId, loan.libraryId, 1)).empty)
        throw failed('Another member is waiting for this title');
      const dueDay = addDays(currentDue, policy.loanDays);
      const dueDate = dayTimestamp(dueDay);
      const renewals = [
        ...loan.renewals,
        {
          renewedDate: dayTimestamp(today),
          previousDueDate: loan.dueDate,
          newDueDate: dueDate,
          performedBy: context.uid,
        },
      ];
      context.update(ref, { dueDate, renewals, updatedAt: serverTimestamp() });
      context.audit({
        action: 'libraryLoan.renew',
        documentPath: ref.path,
        before: { dueDate: loan.dueDate },
        after: { dueDate, count: renewals.length },
      });
      return { id: ref.id, dueDate: dueDay };
    },
  }),
};
