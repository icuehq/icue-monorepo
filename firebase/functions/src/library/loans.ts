import { FieldValue, type DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { todayIST, addDays, daysBetween } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { nextNumber } from '../shared/keys';
import { defineCallable, failed, id, missing, optionalText } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { policyId } from './members';
import { memberAndLibrarians, memberTo } from './notify';
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
  'overdueRenewal',
] as const;

async function loadLoan(context: CallableContext, loanId: string) {
  const ref = context.doc(`libraryLoans/${loanId}`);
  const snapshot = await context.transaction.get(ref);
  if (!snapshot.exists) throw missing('libraryLoan');
  const loan = snapshot.data()!;
  context.requireCampus(loan.campusId);
  if (loan.status !== 'active') throw failed(`Loan is ${loan.status}`);
  return { ref, loan };
}

export const loans = {
  /** Issues one copy to a member (FRS 11.9). Checks member, policy, limit, restriction and copy in one transaction. */
  loanIssue: defineCallable({
    name: 'library.loan.issue',
    permission: 'library.circulation.operate',
    input: z.object({ memberId: id, copyId: id, remarks: optionalText }),
    handler: async (context, i) => {
      const today = todayIST();
      const mRef = context.doc(`libraryMembers/${i.memberId}`);
      const cRef = context.doc(`libraryCopies/${i.copyId}`);
      const [memberSnapshot, copySnapshot] = await Promise.all([
        context.transaction.get(mRef),
        context.transaction.get(cRef),
      ]);
      if (!memberSnapshot.exists) throw missing('libraryMember');
      if (!copySnapshot.exists) throw missing('libraryCopy');
      const member = memberSnapshot.data()!;
      const copy = copySnapshot.data()!;
      context.requireCampus(copy.campusId);

      if (member.status !== 'active') throw failed('Member is inactive');
      if (member.blocked) throw failed('Member is blocked');
      if (member.start > today || (member.end && member.end < today))
        throw failed('Membership is not valid today');
      if (!member.libraryIds.includes(copy.libraryId))
        throw failed('Member has no access to this library');
      // A held copy goes only to the member it is held for, within the hold period (FRS 11.12).
      let held: DocumentReference | undefined;
      if (copy.status === 'reserved') {
        held = context.doc(`libraryReservations/${copy.heldReservationId}`);
        const reservation = (await context.transaction.get(held)).data();
        if (reservation?.memberId !== memberSnapshot.id || reservation.status !== 'ready')
          throw failed('Copy is held for another member');
        if (reservation.holdUntil < today) throw failed('The hold on this copy has expired');
      } else if (copy.status !== 'available' || copy.activeLoanId)
        throw failed(`Copy is ${copy.status}`);

      const policy = (
        await context.transaction.get(
          context.doc(
            `libraryBorrowingPolicies/${policyId(copy.libraryId, member.memberCategory)}`,
          ),
        )
      ).data();
      if (!policy || policy.status !== 'active')
        throw failed('No active borrowing policy for this member');
      if (member.activeLoans >= policy.maxBooks)
        throw failed(`Borrowing limit of ${policy.maxBooks} reached`);
      const title = (
        await context.transaction.get(context.doc(`libraryCatalogue/${copy.catalogueId}`))
      ).data();
      if (title && policy.restrictedCategoryIds.includes(title.categoryId))
        throw failed('This category is restricted for the member');

      const loan = context.newDoc('libraryLoans');
      const number = await nextNumber(context, 'ISS');
      const snapshot = Object.fromEntries(SNAPSHOT.map((field) => [field, policy[field] ?? null]));
      const after = {
        number,
        memberId: memberSnapshot.id,
        memberType: member.memberType,
        personErpId: member.personErpId,
        copyId: copySnapshot.id,
        accessionNumber: copy.accessionNumber,
        catalogueId: copy.catalogueId,
        libraryId: copy.libraryId,
        campusId: copy.campusId,
        issuedDate: today,
        dueDate: addDays(today, policy.loanDays),
        remarks: i.remarks ?? null,
        renewals: [],
        policySnapshot: snapshot,
        status: 'active',
      };
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
          fulfilledCopyId: copySnapshot.id,
          fulfilledAt: serverTimestamp(),
        });
      context.update(mRef, { activeLoans: FieldValue.increment(1), updatedAt: serverTimestamp() });
      await enqueue(context, `library-issued__${loan.id}`, {
        to: memberTo(member.memberType, member.personErpId),
        category: 'library.loan',
        title: 'Book issued',
        body: `${title?.title ?? copy.accessionNumber}: due back ${after.dueDate}.`,
        data: { loanId: loan.id },
      });
      context.audit({ action: 'libraryLoan.issue', documentPath: loan.path, after });
      return { id: loan.id, number, dueDate: after.dueDate };
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
      const cRef = context.doc(`libraryCopies/${loan.copyId}`);
      const mRef = context.doc(`libraryMembers/${loan.memberId}`);
      const [snapshot, memberSnapshot] = await Promise.all([
        context.transaction.get(cRef),
        context.transaction.get(mRef),
      ]);
      if (snapshot.data()?.activeLoanId !== ref.id) throw failed('Copy is not on this loan');
      const today = todayIST();
      const overdueDays = Math.max(0, daysBetween(loan.dueDate, today));
      const returnNumber = await nextNumber(context, 'RET');
      const after = {
        status: 'returned',
        returnNumber,
        returnedDate: today,
        condition: i.condition,
        overdueDays,
        returnRemarks: i.remarks ?? null,
      };
      context.update(ref, { ...after, receivedBy: context.uid, returnedAt: serverTimestamp() });

      const policy = loan.policySnapshot ?? {};
      const grace = (policy.graceDays as number) ?? 0;
      let fineAmount = 0;
      if (overdueDays > grace) {
        const rate = (policy.fineAmount as number) ?? 0;
        if (policy.fineType === 'per_day') {
          fineAmount = (overdueDays - grace) * rate;
        } else if (policy.fineType === 'flat') {
          fineAmount = rate;
        }
        const max = policy.maxFine as number | null | undefined;
        if (typeof max === 'number' && max > 0 && fineAmount > max) {
          fineAmount = max;
        }
        fineAmount = Math.round(fineAmount * 100) / 100;
      }

      if (fineAmount > 0 && memberSnapshot.exists) {
        const member = memberSnapshot.data()!;
        const fineNumber = await nextNumber(context, 'FIN');
        const fRef = context.doc(`libraryFines/${ref.id}__overdue`);
        context.set(fRef, {
          fineNumber,
          loanId: ref.id,
          memberId: memberSnapshot.id,
          memberType: member.memberType,
          personErpId: member.personErpId,
          catalogueId: loan.catalogueId,
          accessionNumber: loan.accessionNumber,
          libraryId: loan.libraryId,
          campusId: loan.campusId,
          type: 'overdue',
          amount: fineAmount,
          waived: 0,
          paid: 0,
          outstanding: fineAmount,
          status: 'outstanding',
          fineCalculation: {
            overdueDays,
            graceDays: grace,
            fineType: policy.fineType,
            fineAmount: policy.fineAmount,
            maxFine: policy.maxFine,
          },
          waivers: [],
          payments: [],
          createdAt: serverTimestamp(),
          createdBy: context.uid,
          updatedAt: serverTimestamp(),
        });
        await enqueue(context, `library-fine__${ref.id}__overdue`, {
          to: memberTo(member.memberType, member.personErpId),
          category: 'library.fine',
          title: 'Fine recorded',
          body: `${loan.accessionNumber}: overdue fine of ${fineAmount} for ${overdueDays} day(s).`,
          data: { fineId: fRef.id },
        });
      }

      if (i.condition === 'damaged') {
        context.update(cRef, {
          status: 'damaged',
          activeLoanId: null,
          updatedAt: serverTimestamp(),
        });
        const incidentNumber = await nextNumber(context, 'INC');
        const incRef = context.newDoc('libraryIncidents');
        const member = memberSnapshot.exists ? memberSnapshot.data()! : null;
        const copy = snapshot.data()!;
        context.set(incRef, {
          incidentNumber,
          type: 'damaged',
          copyId: snapshot.id,
          accessionNumber: copy.accessionNumber,
          catalogueId: copy.catalogueId,
          libraryId: copy.libraryId,
          campusId: copy.campusId,
          memberId: memberSnapshot.exists ? memberSnapshot.id : null,
          memberType: member ? member.memberType : null,
          personErpId: member ? member.personErpId : null,
          loanId: ref.id,
          reportedDate: today,
          reportedBy: context.uid,
          severity: 'moderate',
          description: i.remarks ?? 'Returned in damaged condition',
          photos: [],
          charge: 0,
          repairStatus: 'none',
          status: 'open',
          resolution: null,
          resolvedAt: null,
          createdAt: serverTimestamp(),
          createdBy: context.uid,
          updatedAt: serverTimestamp(),
        });
        await enqueue(context, `library-incident__${incRef.id}`, {
          to: memberAndLibrarians(
            member?.memberType ?? '',
            member?.personErpId ?? null,
            copy.campusId,
          ),
          category: 'library.incident',
          title: 'Damaged book recorded',
          body: `${copy.accessionNumber} was returned damaged.`,
          data: { incidentId: incRef.id },
        });
      } else {
        await release(context, cRef, loan);
      }
      await enqueue(context, `library-returned__${ref.id}`, {
        to: memberTo(loan.memberType, loan.personErpId),
        category: 'library.loan',
        title: 'Book returned',
        body: `${loan.accessionNumber} was returned${overdueDays ? ` ${overdueDays} day(s) late` : ''}.`,
        data: { loanId: ref.id },
      });

      if (memberSnapshot.exists) {
        const member = memberSnapshot.data()!;
        const activeLoans = Math.max(0, (member.activeLoans ?? 0) - 1);
        const blocked = fineAmount > 0 ? true : member.blocked;
        context.update(mRef, { activeLoans, blocked, updatedAt: serverTimestamp() });
      }

      context.audit({
        action: 'libraryLoan.return',
        documentPath: ref.path,
        before: { status: 'active' },
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
      const cRef = context.doc(`libraryCopies/${loan.copyId}`);
      const mRef = context.doc(`libraryMembers/${loan.memberId}`);
      const [snapshot, memberSnapshot] = await Promise.all([
        context.transaction.get(cRef),
        context.transaction.get(mRef),
      ]);
      if (!snapshot.exists) throw missing('libraryCopy');
      if (!memberSnapshot.exists) throw missing('libraryMember');
      const copy = snapshot.data()!;
      const member = memberSnapshot.data()!;
      if (copy.activeLoanId !== ref.id) throw failed('Copy is not on this loan');

      const today = todayIST();
      const charge = i.charge ?? copy.price ?? 0;
      const after = {
        status: 'lost',
        lostDate: today,
        lostRemarks: i.reason ?? null,
        charge,
      };
      context.update(ref, { ...after, receivedBy: context.uid, returnedAt: serverTimestamp() });
      context.update(cRef, { status: 'lost', activeLoanId: null, updatedAt: serverTimestamp() });

      const activeLoans = Math.max(0, (member.activeLoans ?? 0) - 1);
      const blocked = charge > 0 ? true : member.blocked;
      context.update(mRef, { activeLoans, blocked, updatedAt: serverTimestamp() });

      if (charge > 0) {
        const fineNumber = await nextNumber(context, 'FIN');
        const fRef = context.doc(`libraryFines/${ref.id}__lost`);
        context.set(fRef, {
          fineNumber,
          loanId: ref.id,
          memberId: memberSnapshot.id,
          memberType: member.memberType,
          personErpId: member.personErpId,
          catalogueId: loan.catalogueId,
          accessionNumber: loan.accessionNumber,
          libraryId: loan.libraryId,
          campusId: loan.campusId,
          type: 'lost',
          amount: charge,
          waived: 0,
          paid: 0,
          outstanding: charge,
          status: 'outstanding',
          fineCalculation: { copyPrice: copy.price, charge },
          waivers: [],
          payments: [],
          createdAt: serverTimestamp(),
          createdBy: context.uid,
          updatedAt: serverTimestamp(),
        });
        await enqueue(context, `library-fine__${ref.id}__lost`, {
          to: memberTo(member.memberType, member.personErpId),
          category: 'library.fine',
          title: 'Fine recorded',
          body: `${loan.accessionNumber}: replacement charge of ${charge}.`,
          data: { fineId: fRef.id },
        });
      }

      const incidentNumber = await nextNumber(context, 'INC');
      const incRef = context.newDoc('libraryIncidents');
      await enqueue(context, `library-incident__${incRef.id}`, {
        to: memberAndLibrarians(member.memberType, member.personErpId, loan.campusId),
        category: 'library.incident',
        title: 'Lost book recorded',
        body: `${loan.accessionNumber} was marked lost.`,
        data: { incidentId: incRef.id },
      });
      context.set(incRef, {
        incidentNumber,
        type: 'lost',
        copyId: snapshot.id,
        accessionNumber: copy.accessionNumber,
        catalogueId: copy.catalogueId,
        libraryId: copy.libraryId,
        campusId: copy.campusId,
        memberId: memberSnapshot.id,
        memberType: member.memberType,
        personErpId: member.personErpId,
        loanId: ref.id,
        reportedDate: today,
        reportedBy: context.uid,
        severity: null,
        description: i.reason ?? 'Marked lost during loan',
        photos: [],
        charge,
        repairStatus: null,
        status: 'open',
        resolution: null,
        resolvedAt: null,
        createdAt: serverTimestamp(),
        createdBy: context.uid,
        updatedAt: serverTimestamp(),
      });

      context.audit({
        action: 'libraryLoan.markLost',
        documentPath: ref.path,
        before: { status: 'active' },
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
      if (member?.status !== 'active' || member.blocked) throw failed('Member cannot renew');
      const policy = loan.policySnapshot;
      const today = todayIST();
      if (loan.renewals.length >= policy.maxRenewals)
        throw failed(`Renewal limit of ${policy.maxRenewals} reached`);
      if (loan.dueDate < today && !policy.overdueRenewal)
        throw failed('Overdue loans cannot be renewed');
      if (!(await waitingQuery(context, loan.catalogueId, loan.libraryId, 1)).empty)
        throw failed('Another member is waiting for this title');
      const dueDate = addDays(loan.dueDate > today ? loan.dueDate : today, policy.loanDays);
      const renewals = [
        ...loan.renewals,
        {
          renewedDate: today,
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
      return { id: ref.id, dueDate };
    },
  }),
};
