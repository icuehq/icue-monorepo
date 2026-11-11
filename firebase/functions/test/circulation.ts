import { DocumentReference, Timestamp, type DocumentData } from 'firebase-admin/firestore';
import { z } from 'zod';
import {
  applicablePolicy,
  ineligibleReason,
  personInput,
  writeBorrower,
} from '../src/library/members';
import { memberTo } from '../src/library/notify';
import type { CallableContext } from '../src/shared/callable';
import {
  Collections,
  LoanStatus,
  type LibraryLoan,
  type LoanPolicySnapshot,
} from '../src/shared/contracts';
import { todayIST, addDays, dayTimestamp, isoDate, timestampDay } from '../src/shared/dates';
import { serverTimestamp } from '../src/shared/firestore';
import { nextNumber } from '../src/shared/keys';
import { defineCallable, failed, id, missing, optionalText } from '../src/shared/masters';
import { enqueue } from '../src/shared/outbox';

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

      const ineligible = ineligibleReason(member);
      if (ineligible) throw failed(ineligible);
      if (copy.status !== 'available' || copy.activeLoanId) throw failed(`Copy is ${copy.status}`);

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
        updatedAt: serverTimestamp(),
      });
      writeBorrower(context, mRef, member, i.person, 1);
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
      const overdueDays = Math.max(
        0,
        Math.round((Date.parse(today) - Date.parse(timestampDay(loan.dueDate))) / 86_400_000),
      );
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
        context.update(cRef, {
          status: 'available',
          activeLoanId: null,
          updatedAt: serverTimestamp(),
        });
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

async function loadFine(context: CallableContext, fineId: string) {
  const ref = context.doc(`libraryFines/${fineId}`);
  const snapshot = await context.transaction.get(ref);
  if (!snapshot.exists) throw missing('libraryFine');
  const fine = snapshot.data()!;
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

      const waived = Math.round((Number(fine.waived ?? 0) + i.amount) * 100) / 100;
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

      const paid = Math.round((Number(fine.paid ?? 0) + i.paidAmount) * 100) / 100;
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

/** Where a fine or incident happened: the copy's title, library and campus (a loan or copy document has all four). */
export const copyFields = (source: DocumentData) => ({
  catalogueId: source.catalogueId,
  libraryId: source.libraryId,
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
    member: DocumentData;
    source: DocumentData;
    barcode: string;
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
    memberType: fine.member.memberType,
    personErpId: fine.member.personErpId,
    memberName: fine.member.name ?? null,
    barcode: fine.barcode,
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

const INCIDENT_TYPES = ['lost', 'damaged'] as const;
const SEVERITIES = ['minor', 'moderate', 'severe'] as const;
const RESOLUTIONS = ['repaired', 'replaced', 'written_off', 'charged', 'dismissed'] as const;

/** Queues an open incident for a copy (and the member held responsible, if any) with its notification. */
export async function openIncident(
  context: CallableContext,
  incident: {
    type: (typeof INCIDENT_TYPES)[number];
    copy: DocumentData;
    barcode: string;
    member?: DocumentData | null;
    loanId?: string | null;
    severity: string | null;
    description: string | null;
    charge: number;
    repairStatus: string | null;
    title: string;
    body: string;
  },
) {
  const ref = context.newDoc('libraryIncidents');
  const incidentNumber = await nextNumber(context, 'INC');
  const member = incident.member ?? null;
  const after = {
    incidentNumber,
    type: incident.type,
    barcode: incident.barcode,
    ...copyFields(incident.copy),
    memberType: member ? member.memberType : null,
    personErpId: member ? member.personErpId : null,
    memberName: member ? (member.name ?? null) : null,
    ...(incident.loanId ? { loanId: incident.loanId } : {}),
    severity: incident.severity,
    description: incident.description,
    photos: [],
    charge: incident.charge,
    repairStatus: incident.repairStatus,
    status: 'open',
    resolution: null,
    resolvedAt: null,
    reportedDate: dayTimestamp(todayIST()),
    reportedBy: context.uid,
  };
  context.set(ref, {
    ...after,
    createdAt: serverTimestamp(),
    createdBy: context.uid,
    updatedAt: serverTimestamp(),
  });
  await enqueue(context, `library-incident__${ref.id}`, {
    to: member ? memberTo(member.memberType as string, member.personErpId as number) : {},
    category: 'library.incident',
    title: incident.title,
    body: incident.body,
    data: { incidentId: ref.id },
  });
  return { ref, incidentNumber, after };
}

async function loadIncident(context: CallableContext, incidentId: string) {
  const ref = context.doc(`libraryIncidents/${incidentId}`);
  const snapshot = await context.transaction.get(ref);
  if (!snapshot.exists) throw missing('libraryIncident');
  const incident = snapshot.data()!;
  return { ref, incident };
}

/** Mirrors of `LoanWrites.reportIncident` / `resolveIncident`, for tests that report and resolve incidents. */
export const incidents = {
  /**
   * Reports a lost or damaged book copy (FRS 11.14).
   * Updates the physical copy status; if a member is held responsible and charge > 0,
   * creates a fine and blocks the member.
   */
  incidentReport: defineCallable({
    name: 'library.incident.report',
    input: z.object({
      barcode: id,
      personErpId: z.number().int().min(1).nullish(),
      type: z.enum(INCIDENT_TYPES),
      severity: z.enum(SEVERITIES).default('moderate'),
      description: optionalText,
      charge: z.number().min(0).max(10_000_000).default(0),
    }),
    handler: async (context, i) => {
      const cRef = context.doc(`libraryCopies/${i.barcode}`);
      const cSnap = await context.transaction.get(cRef);
      if (!cSnap.exists) throw missing('libraryCopy');
      const copy = cSnap.data()!;
      if (copy.status === 'lost' || copy.status === 'withdrawn') {
        throw failed(`Copy is already ${copy.status}`);
      }
      if (copy.activeLoanId) {
        throw failed(
          'Copy is on loan; use Mark lost / return as damaged first',
        );
      }
      const open = await context.transaction.get(
        context
          .coll('libraryIncidents')
          .where('barcode', '==', i.barcode)
          .where('status', '==', 'open')
          .limit(1),
      );
      if (!open.empty) throw failed('Copy already has an open incident');

      let member: Record<string, unknown> | null = null;
      let mRef = null;
      if (i.personErpId) {
        mRef = context.doc(`libraryMembers/${i.personErpId}`);
        const mSnap = await context.transaction.get(mRef);
        if (!mSnap.exists) throw missing('libraryMember');
        member = mSnap.data()!;
      }

      const {
        ref: incRef,
        incidentNumber,
        after,
      } = await openIncident(context, {
        type: i.type,
        copy,
        barcode: cRef.id,
        member,
        severity: i.type === 'damaged' ? i.severity : null,
        description: i.description ?? null,
        charge: i.charge,
        repairStatus: i.type === 'damaged' ? 'none' : null,
        title: `${i.type === 'lost' ? 'Lost' : 'Damaged'} book recorded`,
        body: `${cRef.id} was reported ${i.type}.`,
      });

      // Lost or damaged copies are taken off circulation.
      context.update(cRef, {
        status: i.type === 'lost' ? 'lost' : 'damaged',
        activeLoanId: null,
        updatedAt: serverTimestamp(),
      });

      if (member && mRef && i.charge > 0) {
        await raiseFine(context, {
          id: `inc_${incRef.id}__${i.type}`,
          type: i.type,
          amount: i.charge,
          member,
          source: copy,
          barcode: cRef.id,
          incidentId: incRef.id,
          calculation: { incidentNumber, type: i.type, severity: i.severity, charge: i.charge },
        });
        context.update(mRef, { ...fineBlock(member), updatedAt: serverTimestamp() });
      }

      context.audit({ action: 'libraryIncident.report', documentPath: incRef.path, after });
      return { id: incRef.id, number: incidentNumber };
    },
  }),

  /**
   * Resolves a lost or damaged book incident (FRS 11.14).
   * Repaired copies are returned to the shelf; written-off copies are withdrawn.
   */
  resolve: defineCallable({
    name: 'library.incident.resolve',
    input: z.object({
      id,
      resolution: z.enum(RESOLUTIONS),
      repairCost: z.number().min(0).max(10_000_000).nullish(),
      charge: z.number().min(0).max(10_000_000).nullish(),
      remarks: optionalText,
    }),
    handler: async (context, i) => {
      const { ref, incident } = await loadIncident(context, i.id);
      if (incident.status !== 'open') throw failed(`Incident is already ${incident.status}`);

      const cRef = context.doc(`libraryCopies/${incident.barcode}`);
      const cSnap = await context.transaction.get(cRef);
      if (!cSnap.exists) throw missing('libraryCopy');
      const copy = cSnap.data()!;

      if (i.resolution === 'repaired' && incident.type !== 'damaged')
        throw failed('Only a damaged copy can be repaired');
      const charge = i.charge ?? incident.charge ?? 0;
      if (charge < (incident.charge ?? 0))
        throw failed('Charge cannot be lowered on resolve; waive the fine instead');

      let repairStatus = incident.repairStatus;
      if (i.resolution === 'repaired' || i.resolution === 'dismissed') {
        // dismissed = no fault found (or the lost book turned up): back to shelf unless already withdrawn
        if (i.resolution === 'repaired') repairStatus = 'repaired';
        if (copy.status === 'damaged' || copy.status === 'lost') context.update(cRef, {
          status: 'available',
          activeLoanId: null,
          updatedAt: serverTimestamp(),
        });
      } else if (i.resolution === 'written_off') {
        repairStatus = 'writeoff';
        context.update(cRef, { status: 'withdrawn', updatedAt: serverTimestamp() });
      } else if (
        (i.resolution === 'replaced' || i.resolution === 'charged') &&
        (i.resolution === 'replaced' || copy.status === 'lost')
      ) {
        // A replaced or paid-for lost copy is gone for good (a replacement comes in as a new book entry).
        context.update(cRef, { status: 'withdrawn', updatedAt: serverTimestamp() });
      }

      // If additional charge is levied and member is on incident and not already charged
      if (charge > (incident.charge ?? 0) && incident.personErpId) {
        const difference = charge - (incident.charge ?? 0);
        const mRef = context.doc(`libraryMembers/${incident.personErpId}`);
        const mSnap = await context.transaction.get(mRef);
        if (mSnap.exists) {
          await raiseFine(context, {
            id: `inc_${ref.id}__penalty`,
            type: incident.type,
            amount: difference,
            member: mSnap.data()!,
            source: incident,
            barcode: incident.barcode,
            loanId: incident.loanId ?? null,
            incidentId: ref.id,
            calculation: {
              incidentNumber: incident.incidentNumber,
              resolution: i.resolution,
              charge: difference,
            },
          });
          context.update(mRef, { ...fineBlock(mSnap.data()!), updatedAt: serverTimestamp() });
        }
      }

      const update = {
        status: 'resolved',
        resolution: i.resolution,
        resolutionRemarks: i.remarks ?? null,
        repairCost: i.repairCost ?? null,
        charge,
        repairStatus: repairStatus ?? null,
        resolvedBy: context.uid,
        resolvedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };
      context.update(ref, update);
      context.audit({
        action: 'libraryIncident.resolve',
        documentPath: ref.path,
        before: { status: 'open' },
        after: update,
      });
      return { id: ref.id };
    },
  }),
};
