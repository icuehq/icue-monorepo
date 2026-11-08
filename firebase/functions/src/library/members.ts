import { FieldValue, type DocumentData, type DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { serverTimestamp } from '../shared/firestore';
import { defineCallable, failed, id, missing, name, status, usable } from '../shared/masters';

const FINES = ['none', 'per_day', 'flat'] as const;
const MEMBER_TYPES = ['student', 'teacher'] as const;
/** A policy may also be the library's default for everyone ('all'), used when none names the person type. */
const POLICY_MEMBER_TYPES = [...MEMBER_TYPES, 'all'] as const;

/** Why [member] cannot borrow or reserve, or null when they can. A person never seen before can. */
export function ineligibleReason(member: { blocked?: boolean } | undefined): string | null {
  return member?.blocked ? 'Member is blocked' : null;
}

/**
 * The active policy of a person type in a library that covers a book of [categoryId]: one naming the
 * category, else one naming its parent, else the catch-all (no categories); policies of the person type
 * win over the library's default for everyone ('all'). Saving refuses overlaps, so each level has at
 * most one. Null means the member cannot borrow or reserve this book.
 */
export async function applicablePolicy(
  context: CallableContext,
  libraryId: string,
  memberType: string,
  categoryId: string,
): Promise<{ id: string; data: DocumentData } | null> {
  const policies = (
    await context.transaction.get(
      context
        .coll('libraryBorrowingPolicies')
        .where('libraryId', '==', libraryId)
        .where('memberType', 'in', [memberType, 'all'])
        .where('status', '==', 'active'),
    )
  ).docs;
  const parentId = (
    await context.transaction.get(context.doc(`libraryCategories/${categoryId}`))
  ).data()?.parentId;
  let found: (typeof policies)[number] | undefined;
  for (const type of [memberType, 'all']) {
    const own = policies.filter((policy) => policy.data().memberType === type);
    const covering = (categoryIds: (string | undefined)[]) =>
      own.find((policy) =>
        categoryIds.some((category) => category && policy.data().categoryIds.includes(category)),
      );
    found =
      covering([categoryId]) ??
      covering([parentId]) ??
      own.find((policy) => !policy.data().categoryIds.length);
    if (found) break;
  }
  return found ? { id: found.id, data: found.data() } : null;
}

/** Refuses [categoryIds] (empty: the catch-all) when another active policy of the library and person type already covers them. */
async function assertNoOverlap(
  context: CallableContext,
  libraryId: string,
  memberType: string,
  categoryIds: string[],
  selfId: string,
): Promise<void> {
  const others = (
    await context.transaction.get(
      context
        .coll('libraryBorrowingPolicies')
        .where('libraryId', '==', libraryId)
        .where('memberType', '==', memberType)
        .where('status', '==', 'active'),
    )
  ).docs.filter((other) => other.id !== selfId);
  for (const other of others) {
    const taken: string[] = other.data().categoryIds;
    if (!categoryIds.length && !taken.length)
      throw failed(`"${other.data().name}" already covers all other categories`);
    if (categoryIds.some((categoryId) => taken.includes(categoryId)))
      throw failed(`A selected category already belongs to "${other.data().name}"`);
  }
}

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
   * A borrowing policy (FRS 11.8): the rules of one person type in one library for the listed book
   * categories, or for every category not named by another policy when none are listed. Within a
   * library and person type a category (or the catch-all) belongs to one policy. Circulation copies the
   * values onto each loan at issue, so edits never move existing due dates. [id] edits; omitted creates.
   */
  policyUpsert: defineCallable({
    name: 'library.policy.upsert',
    input: z
      .object({
        id: id.optional(),
        libraryId: id,
        memberType: z.enum(POLICY_MEMBER_TYPES),
        name,
        maxBooks: z.number().int().min(1).max(100),
        loanDays: z.number().int().min(1).max(365),
        maxRenewals: z.number().int().min(0).max(20),
        fineType: z.enum(FINES),
        fineAmount: z.number().min(0).max(100_000).default(0),
        graceDays: z.number().int().min(0).max(60).default(0),
        maxFine: z.number().min(0).max(10_000_000).nullish(),
        categoryIds: z.array(id).max(50).default([]),
      })
      .refine((i) => i.fineType === 'none' || i.fineAmount > 0, 'A fine needs an amount'),
    handler: async (context, i) => {
      const ref = i.id
        ? context.doc(`libraryBorrowingPolicies/${i.id}`)
        : context.newDoc('libraryBorrowingPolicies');
      const before = i.id ? (await context.transaction.get(ref)).data() : undefined;
      if (i.id && !before) throw missing('libraryBorrowingPolicy');
      if (before && (before.libraryId !== i.libraryId || before.memberType !== i.memberType))
        throw failed('The library and member type of a policy cannot change');
      const library = usable(
        await context.transaction.get(context.doc(`libraries/${i.libraryId}`)),
        'Library',
        !!before,
      );
      context.requireCampus(library.campusId);
      const categoryIds = [...new Set(i.categoryIds)];
      for (const categoryId of categoryIds) {
        if (!(await context.transaction.get(context.doc(`libraryCategories/${categoryId}`))).exists)
          throw failed('Category not found');
      }
      await assertNoOverlap(context, i.libraryId, i.memberType, categoryIds, ref.id);
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
        categoryIds,
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
  policySetStatus: defineCallable({
    name: 'library.policy.setStatus',
    input: z.object({ id, status }),
    handler: async (context, i) => {
      const ref = context.doc(`libraryBorrowingPolicies/${i.id}`);
      const policy = (await context.transaction.get(ref)).data();
      if (!policy) throw missing('libraryBorrowingPolicy');
      context.requireCampus(policy.campusId);
      if (policy.status === i.status) return { id: i.id };
      if (i.status === 'active')
        await assertNoOverlap(
          context,
          policy.libraryId,
          policy.memberType,
          policy.categoryIds,
          i.id,
        );
      context.update(ref, { status: i.status, updatedAt: serverTimestamp() });
      context.audit({
        action: 'libraryPolicy.status',
        documentPath: ref.path,
        before: { status: policy.status },
        after: { status: i.status },
      });
      return { id: i.id };
    },
  }),

  /** Hand-set block (or lift). Fines block members on their own; this one is never lifted by paying them. */
  memberSetBlocked: defineCallable({
    name: 'library.member.setBlocked',
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
