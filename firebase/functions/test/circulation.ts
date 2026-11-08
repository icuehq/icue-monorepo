import { Timestamp, type DocumentData, type DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../src/shared/callable';
import {
  Collections,
  LoanStatus,
  type LibraryLoan,
  type LoanPolicySnapshot,
} from '../src/shared/contracts';
import {
  todayIST,
  addDays,
  daysBetween,
  dayTimestamp,
  isoDate,
  timestampDay,
} from '../src/shared/dates';
import { serverTimestamp } from '../src/shared/firestore';
import { nextNumber } from '../src/shared/keys';
import { defineCallable, failed, id, missing, optionalText, usable } from '../src/shared/masters';
import { enqueue } from '../src/shared/outbox';
import { fineBlock, raiseFine } from '../src/library/fines';
import { openIncident } from '../src/library/incidents';
import {
  applicablePolicy,
  ineligibleReason,
  personInput,
  writeBorrower,
} from '../src/library/members';
import { memberTo } from '../src/library/notify';
import { release, waitingQuery } from '../src/library/reservations';

/** Policy values copied onto the loan so later policy edits never move its due date (FRS 11.8). */
const SNAPSHOT = [
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
  member: DocumentData,
  amount: number,
  overdueDays: number,
): Promise<void> {
  const policy = loan.policySnapshot;
  const fRef = await raiseFine(context, {
    id: fineId,
    type: 'overdue',
    amount,
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

/**
 * Circulation seeders for tests: issuing, returning, renewing and losing a book are client transactions
 * (`LoanWrites`) whose notices come from `src/library/notices.ts`. These callables mirror them so the
 * other library tests can build their state.
 */
export const loans = {
  /** Issues one copy to a member (FRS 11.9). Checks member, policy, limit, restriction and copy in one transaction. */
  loanIssue: defineCallable({
    name: 'library.loan.issue',
    input: z.object({ person: personInput, barcode: id, remarks: optionalText }),
    handler: async (context, i) => {
      const today = todayIST();
      const { personErpId } = i.person;
      const mRef = context.doc(`libraryMembers/${personErpId}`);
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
        if (reservation?.personErpId !== personErpId || reservation.status !== 'ready')
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
          .where('personErpId', '==', personErpId)
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
      context.set(loan, { ...after, issuedBy: context.uid });
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
    input: z.object({ id, condition: z.enum(['good', 'damaged']), remarks: optionalText }),
    handler: async (context, i) => {
      const { ref, loan } = await loadLoan(context, i.id);
      const cRef = context.doc(`libraryCopies/${loan.barcode}`);
      const mRef = context.doc(`libraryMembers/${loan.personErpId}`);
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
      context.update(ref, { ...after, receivedBy: context.uid });

      const fineAmount = overdueFineAmount(loan.policySnapshot, overdueDays);
      if (fineAmount > 0 && memberSnapshot.exists) {
        await raiseOverdueFine(
          context,
          `${ref.id}__overdue`,
          ref.id,
          loan,
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
    input: z.object({
      id,
      reason: optionalText,
      charge: z.number().min(0).max(10_000_000).nullish(),
    }),
    handler: async (context, i) => {
      const { ref, loan } = await loadLoan(context, i.id);
      const cRef = context.doc(`libraryCopies/${loan.barcode}`);
      const mRef = context.doc(`libraryMembers/${loan.personErpId}`);
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
      context.update(ref, { ...after, receivedBy: context.uid });
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
    input: z.object({ id }),
    handler: async (context, i) => {
      const { ref, loan } = await loadLoan(context, i.id);
      const member = (
        await context.transaction.get(context.doc(`libraryMembers/${loan.personErpId}`))
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

/** Mirrors of `LoanWrites.reserve` / `cancelReservation`, for tests that build reservations. */
export const reservations = {
  /**
   * Joins the waiting list of a title (FRS 11.12). Only when no copy is on the shelf, and only for an
   * eligible member whose policy allows reserving; one live reservation per member and title.
   */
  reservationCreate: defineCallable({
    name: 'library.reservation.create',
    input: z.object({ person: personInput, catalogueId: id, libraryId: id }),
    handler: async (context, i) => {
      const { personErpId } = i.person;
      const [snapshot, libraryDocument, category] = await Promise.all([
        context.transaction.get(context.doc(`libraryMembers/${personErpId}`)),
        context.transaction.get(context.doc(`libraries/${i.libraryId}`)),
        context.transaction.get(context.doc(`libraryCatalogue/${i.catalogueId}`)),
      ]);
      const member = snapshot.data();
      const library = usable(libraryDocument, 'Library', false);
      context.requireCampus(library.campusId);
      const title = usable(category, 'Title', false);

      const ineligible = ineligibleReason(member);
      if (ineligible) throw failed(ineligible);
      if (!(await applicablePolicy(context, i.libraryId, i.person.memberType, title.categoryId)))
        throw failed('No active borrowing policy for this member and book category');

      const live = await context.transaction.get(
        context
          .coll('libraryReservations')
          .where('personErpId', '==', personErpId)
          .where('catalogueId', '==', i.catalogueId)
          .where('status', 'in', ['waiting', 'ready'])
          .limit(1),
      );
      if (!live.empty) throw failed('Member already has a reservation for this title');
      const loans = await context.transaction.get(
        context
          .coll('libraryLoans')
          .where('personErpId', '==', personErpId)
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
        memberType: i.person.memberType,
        personErpId: i.person.personErpId,
        memberName: i.person.name,
        catalogueId: i.catalogueId,
        title: title.title,
        libraryId: i.libraryId,
        campusId: library.campusId,
        status: 'waiting',
        heldBarcode: null,
        holdUntil: null,
        fulfilledLoanId: null,
        fulfilledBarcode: null,
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
    input: z.object({ id }),
    handler: async (context, i) => {
      const ref = context.doc(`libraryReservations/${i.id}`);
      const snapshot = await context.transaction.get(ref);
      if (!snapshot.exists) throw missing('libraryReservation');
      const reservation = snapshot.data()!;
      context.requireCampus(reservation.campusId);
      if (reservation.status !== 'waiting' && reservation.status !== 'ready')
        throw failed(`Reservation is ${reservation.status}`);
      if (reservation.status === 'ready') await freeHeld(context, reservation.heldBarcode, ref.id);
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
  barcode: string,
  reservationId: string,
): Promise<void> {
  const cRef = context.doc(`libraryCopies/${barcode}`);
  const copy = (await context.transaction.get(cRef)).data();
  if (copy?.heldReservationId === reservationId) await release(context, cRef, copy);
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
  personErpId: number,
  currentFineId: string,
) {
  const otherFines = await context.transaction.get(
    context
      .coll('libraryFines')
      .where('personErpId', '==', personErpId)
      .where('status', 'in', ['outstanding', 'partially_paid'])
      .limit(2),
  );
  const hasOther = otherFines.docs.some((doc) => doc.id !== currentFineId);
  if (!hasOther) {
    const mRef = context.doc(`libraryMembers/${personErpId}`);
    const mSnap = await context.transaction.get(mRef);
    if (mSnap.exists && mSnap.data()?.blocked && mSnap.data()?.blockedBy !== 'manual') {
      context.update(mRef, { blocked: false, blockedBy: null, updatedAt: serverTimestamp() });
    }
  }
}

/** Mirrors of `LoanWrites.waiveFine` / `recordFinePayment`, for tests that settle fines. */
export const fines = {
  /**
   * Waives all or part of an outstanding fine (FRS 11.13). Requires `library.fines.waive`.
   * When no open fines remain, unblocks the member.
   */
  fineWaive: defineCallable({
    name: 'library.fine.waive',
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

      if (outstanding <= 0 && fine.personErpId) {
        await checkUnblockMember(context, fine.personErpId, ref.id);
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

      if (outstanding <= 0 && fine.personErpId) {
        await checkUnblockMember(context, fine.personErpId, ref.id);
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
