import { FieldValue, type DocumentData, type DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { serverTimestamp } from '../shared/firestore';

const MEMBER_TYPES = ['student', 'teacher'] as const;

/** Why [member] cannot borrow, or null when they can. A person never seen before can. */
export function ineligibleReason(member: { blocked?: boolean } | undefined): string | null {
  return member?.blocked ? 'Member is blocked' : null;
}

/**
 * The active policy of a person type in a library that covers a book of [categoryId]: one naming the
 * category, else one naming its parent, else the catch-all (no categories); policies of the person type
 * win over the library's default for everyone ('all'). Saving refuses overlaps, so each level has at
 * most one. Null means the member cannot borrow this book.
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
