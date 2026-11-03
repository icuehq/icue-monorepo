import { z } from 'zod';
import { isoDate } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import {
  defineCallable,
  failed,
  id,
  missing,
  name,
  defineSetStatus,
  status,
  usable,
} from '../shared/masters';

/** Member category key ("primary", "teacher"…): what a member and a policy are matched on. */
const category = z
  .string()
  .trim()
  .toLowerCase()
  .regex(/^[a-z0-9_-]{1,30}$/, 'Use letters, digits, - or _');
const FINES = ['none', 'per_day', 'flat'] as const;

export const policyId = (libraryId: string, memberCategory: string) =>
  `${libraryId}_${memberCategory}`;
/** Why [member] cannot borrow or reserve in [libraryId] today, or null when they can. */
export function ineligibleReason(
  member: {
    status?: string;
    blocked?: boolean;
    start?: string;
    end?: string | null;
    libraryIds?: string[];
  },
  libraryId: string,
  today: string,
): string | null {
  if (member.status !== 'active') return 'Member is inactive';
  if (member.blocked) return 'Member is blocked';
  if ((member.start && member.start > today) || (member.end && member.end < today))
    return 'Membership is not valid today';
  if (!member.libraryIds?.includes(libraryId)) return 'Member has no access to this library';
  return null;
}

export const memberId = (type: string, personErpId: number) => `${type}_${personErpId}`;

export const members = {
  /**
   * One policy per library and member category (FRS 11.8); the ID is `<libraryId>_<category>`,
   * so saving again edits it. Circulation (Lib-4) copies the values onto each loan at issue,
   * so edits never move existing due dates.
   */
  policyUpsert: defineCallable({
    name: 'library.policy.upsert',
    permission: 'library.settings',
    input: z
      .object({
        libraryId: id,
        memberCategory: category,
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
        `libraryBorrowingPolicies/${policyId(i.libraryId, i.memberCategory)}`,
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
        memberCategory: i.memberCategory,
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

  /**
   * Enrols a student or teacher (FRS 11.7). The ERP person stays the source of truth: only the
   * ID is stored, and the document ID `<type>_<personErpId>` makes a duplicate impossible.
   */
  memberUpsert: defineCallable({
    name: 'library.member.upsert',
    permission: 'library.circulation.operate',
    input: z
      .object({
        memberType: z.enum(['student', 'teacher']),
        personErpId: z.number().int().min(1),
        classId: z.number().int().nullish(),
        memberCategory: category,
        libraryIds: z.array(id).min(1).max(20),
        start: isoDate,
        end: isoDate.nullish(),
      })
      .refine((i) => !i.end || i.end >= i.start, 'End date is before the start date'),
    handler: async (context, i) => {
      const ref = context.doc(`libraryMembers/${memberId(i.memberType, i.personErpId)}`);
      const before = (await context.transaction.get(ref)).data();
      if (before)
        for (const campusId of before.campusIds as number[]) context.requireCampus(campusId);
      const libraryIds = [...new Set(i.libraryIds)];
      const campusIds = new Set<number>();
      for (const libraryId of libraryIds) {
        const library = usable(
          await context.transaction.get(context.doc(`libraries/${libraryId}`)),
          'Library',
          before?.libraryIds?.includes(libraryId),
        );
        context.requireCampus(library.campusId);
        campusIds.add(library.campusId);
      }
      const after = {
        memberType: i.memberType,
        personErpId: i.personErpId,
        classId: i.memberType === 'student' ? (i.classId ?? null) : null,
        memberCategory: i.memberCategory,
        libraryIds,
        campusIds: [...campusIds],
        start: i.start,
        end: i.end ?? null,
      };
      if (before) {
        context.update(ref, { ...after, updatedAt: serverTimestamp() });
        context.audit({ action: 'libraryMember.update', documentPath: ref.path, before, after });
      } else {
        context.set(ref, {
          ...after,
          status: 'active',
          activeLoans: 0,
          blocked: false,
          createdAt: serverTimestamp(),
          createdBy: context.uid,
          updatedAt: serverTimestamp(),
        });
        context.audit({ action: 'libraryMember.create', documentPath: ref.path, after });
      }
      return { id: ref.id };
    },
  }),

  /** Inactive members cannot borrow (checked at issue in Lib-4); their loans stay visible. */
  memberSetStatus: defineCallable({
    name: 'library.member.setStatus',
    permission: 'library.circulation.operate',
    input: z.object({ id, status }),
    handler: async (context, i) => {
      const ref = context.doc(`libraryMembers/${i.id}`);
      const snapshot = await context.transaction.get(ref);
      if (!snapshot.exists) throw missing('libraryMember');
      const member = snapshot.data()!;
      for (const campusId of member.campusIds as number[]) context.requireCampus(campusId);
      if (member.status === i.status) return { id: ref.id };
      context.update(ref, { status: i.status, updatedAt: serverTimestamp() });
      context.audit({
        action: 'libraryMember.status',
        documentPath: ref.path,
        before: { status: member.status },
        after: { status: i.status },
      });
      return { id: ref.id };
    },
  }),

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
