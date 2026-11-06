import {
  FieldValue,
  type DocumentData,
  type DocumentReference,
} from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { serverTimestamp } from '../shared/firestore';
import {
  defineCallable,
  failed,
  id,
  missing,
  name,
  defineSetStatus,
  usable,
} from '../shared/masters';

const FINES = ['none', 'per_day', 'flat'] as const;
const MEMBER_TYPES = ['student', 'teacher'] as const;

export const policyId = (libraryId: string, memberType: string) => `${libraryId}_${memberType}`;
/** Why [member] cannot borrow or reserve, or null when they can. A person never seen before can. */
export function ineligibleReason(member: { blocked?: boolean } | undefined): string | null {
  return member?.blocked ? 'Member is blocked' : null;
}

export const memberId = (type: string, personErpId: number) => `${type}_${personErpId}`;

/**
 * The borrower as the desk found them in the ERP (Node). Only what the Library shows is kept; the ERP
 * stays the source of truth, so the record is created on first use and its name and class refreshed after.
 */
export const personInput = z.object({
  memberType: z.enum(MEMBER_TYPES),
  personErpId: z.number().int().min(1),
  name: z.string().trim().min(1).max(200),
  classId: z.number().int().nullish(),
});
export type Person = z.infer<typeof personInput>;

/**
 * Creates the borrower record on first use, else refreshes it and adds [campusId] to the campuses it was
 * seen on; [loanDelta] adjusts the number of books on loan. Returns the record as it will be.
 */
export function writeBorrower(
  context: CallableContext,
  ref: DocumentReference,
  existing: DocumentData | undefined,
  person: Person,
  campusId: number,
  loanDelta: number,
): DocumentData {
  const shown = {
    name: person.name,
    classId: person.memberType === 'student' ? (person.classId ?? null) : null,
  };
  if (existing) {
    context.update(ref, {
      ...shown,
      campusIds: FieldValue.arrayUnion(campusId),
      activeLoans: FieldValue.increment(loanDelta),
      updatedAt: serverTimestamp(),
    });
    return { ...existing, ...shown };
  }
  const created = {
    memberType: person.memberType,
    personErpId: person.personErpId,
    ...shown,
    campusIds: [campusId],
    activeLoans: loanDelta,
    blocked: false,
  };
  context.set(ref, {
    ...created,
    createdAt: serverTimestamp(),
    createdBy: context.uid,
    updatedAt: serverTimestamp(),
  });
  return created;
}

export const members = {
  /**
   * One policy per library and person type (FRS 11.8); the ID is `<libraryId>_<student|teacher>`,
   * so saving again edits it. Circulation (Lib-4) copies the values onto each loan at issue,
   * so edits never move existing due dates.
   */
  policyUpsert: defineCallable({
    name: 'library.policy.upsert',
    permission: 'library.settings',
    input: z
      .object({
        libraryId: id,
        memberType: z.enum(MEMBER_TYPES),
        name,
        maxBooks: z.number().int().min(1).max(100),
        loanDays: z.number().int().min(1).max(365),
        maxRenewals: z.number().int().min(0).max(20),
        fineType: z.enum(FINES),
        fineAmount: z.number().min(0).max(100_000).default(0),
        graceDays: z.number().int().min(0).max(60).default(0),
        maxFine: z.number().min(0).max(10_000_000).nullish(),
        canReserve: z.boolean(),
        overdueRenewal: z.boolean().default(false),
        restrictedCategoryIds: z.array(id).max(50).default([]),
      })
      .refine((i) => i.fineType === 'none' || i.fineAmount > 0, 'A fine needs an amount'),
    handler: async (context, i) => {
      const ref = context.doc(
        `libraryBorrowingPolicies/${policyId(i.libraryId, i.memberType)}`,
      );
      const before = (await context.transaction.get(ref)).data();
      const library = usable(
        await context.transaction.get(context.doc(`libraries/${i.libraryId}`)),
        'Library',
        !!before,
      );
      context.requireCampus(library.campusId);
      const restricted = [...new Set(i.restrictedCategoryIds)];
      for (const categoryId of restricted) {
        if (!(await context.transaction.get(context.doc(`libraryCategories/${categoryId}`))).exists)
          throw failed('Restricted category not found');
      }
      const after = {
        name: i.name,
        libraryId: i.libraryId,
        campusId: library.campusId,
        memberType: i.memberType,
        maxBooks: i.maxBooks,
        loanDays: i.loanDays,
        maxRenewals: i.maxRenewals,
        fineType: i.fineType,
        fineAmount: i.fineType === 'none' ? 0 : i.fineAmount,
        graceDays: i.graceDays,
        maxFine: i.fineType === 'none' ? null : (i.maxFine ?? null),
        canReserve: i.canReserve,
        overdueRenewal: i.overdueRenewal,
        restrictedCategoryIds: restricted,
      };
      if (before) {
        context.update(ref, { ...after, updatedAt: serverTimestamp() });
        context.audit({ action: 'libraryPolicy.update', documentPath: ref.path, before, after });
      } else {
        context.set(ref, {
          ...after,
          status: 'active',
          createdAt: serverTimestamp(),
          createdBy: context.uid,
          updatedAt: serverTimestamp(),
        });
        context.audit({ action: 'libraryPolicy.create', documentPath: ref.path, after });
      }
      return { id: ref.id };
    },
  }),
  policySetStatus: defineSetStatus(
    'library.policy.setStatus',
    'library.settings',
    'libraryBorrowingPolicies',
    'libraryPolicy',
  ),

  /** Hand-set block (or lift). Fines block members on their own; this one is never lifted by paying them. */
  memberSetBlocked: defineCallable({
    name: 'library.member.setBlocked',
    permission: 'library.circulation.operate',
    input: z.object({
      id,
      blocked: z.boolean(),
      reason: z.string().trim().max(500).nullish(),
    }),
    handler: async (context, i) => {
      const ref = context.doc(`libraryMembers/${i.id}`);
      const snapshot = await context.transaction.get(ref);
      if (!snapshot.exists) throw missing('libraryMember');
      const member = snapshot.data()!;
      for (const campusId of member.campusIds as number[]) context.requireCampus(campusId);
      if (i.blocked && !i.reason) throw failed('A reason is required to block a member');
      context.update(ref, {
        blocked: i.blocked,
        blockedBy: i.blocked ? 'manual' : null,
        blockReason: i.blocked ? i.reason : null,
        updatedAt: serverTimestamp(),
      });
      context.audit({
        action: 'libraryMember.block',
        documentPath: ref.path,
        before: { blocked: member.blocked ?? false },
        after: { blocked: i.blocked },
        reason: i.reason ?? undefined,
      });
      return { id: ref.id };
    },
  }),
};
