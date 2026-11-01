import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { def, failed, id, missing, name, setStatusDef, status, usable } from '../shared/masters';

const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
/** Member category key ("primary", "teacher"…): what a member and a policy are matched on. */
const category = z.string().trim().toLowerCase().regex(/^[a-z0-9_-]{1,30}$/, 'Use letters, digits, - or _');
const FINES = ['none', 'per_day', 'flat'] as const;
const UP = () => FieldValue.serverTimestamp();

export const policyId = (libraryId: string, memberCategory: string) => `${libraryId}_${memberCategory}`;
export const memberId = (type: string, erpId: number) => `${type}_${erpId}`;

export const members = {
  /**
   * One policy per library and member category (FRS 11.8); the ID is `<libraryId>_<category>`,
   * so saving again edits it. Circulation (Lib-4) copies the values onto each loan at issue,
   * so edits never move existing due dates.
   */
  policyUpsert: def({
    name: 'lib.policy.upsert',
    perm: 'lib.settings',
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
    handler: async (ctx, i) => {
      const ref = ctx.doc(`libPolicies/${policyId(i.libraryId, i.memberCategory)}`);
      const before = (await ctx.tx.get(ref)).data();
      const lib = usable(await ctx.tx.get(ctx.doc(`libLibraries/${i.libraryId}`)), 'Library', !!before);
      ctx.requireCampus(lib.campusId);
      const restricted = [...new Set(i.restrictedCategoryIds)];
      for (const c of restricted) {
        if (!(await ctx.tx.get(ctx.doc(`libCategories/${c}`))).exists) throw failed('Restricted category not found');
      }
      const after = {
        name: i.name,
        libraryId: i.libraryId,
        campusId: lib.campusId,
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
        ctx.update(ref, { ...after, updatedAt: UP() });
        ctx.audit({ action: 'libPolicy.update', ref: ref.path, before, after });
      } else {
        ctx.set(ref, { ...after, status: 'active', createdAt: UP(), createdBy: ctx.uid, updatedAt: UP() });
        ctx.audit({ action: 'libPolicy.create', ref: ref.path, after });
      }
      return { id: ref.id };
    },
  }),
  policySetStatus: setStatusDef('lib.policy.setStatus', 'lib.settings', 'libPolicies', 'libPolicy'),

  /**
   * Enrols a student or teacher (FRS 11.7). The ERP person stays the source of truth: only the
   * ID is stored, and the document ID `<type>_<erpId>` makes a duplicate impossible.
   */
  memberUpsert: def({
    name: 'lib.member.upsert',
    perm: 'lib.circulation.operate',
    input: z
      .object({
        memberType: z.enum(['student', 'teacher']),
        erpId: z.number().int().min(1),
        classId: z.number().int().nullish(),
        memberCategory: category,
        libraryIds: z.array(id).min(1).max(20),
        start: day,
        end: day.nullish(),
      })
      .refine((i) => !i.end || i.end >= i.start, 'End date is before the start date'),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`libMembers/${memberId(i.memberType, i.erpId)}`);
      const before = (await ctx.tx.get(ref)).data();
      if (before) for (const c of before.campusIds as number[]) ctx.requireCampus(c);
      const libraryIds = [...new Set(i.libraryIds)];
      const campusIds = new Set<number>();
      for (const l of libraryIds) {
        const lib = usable(await ctx.tx.get(ctx.doc(`libLibraries/${l}`)), 'Library', before?.libraryIds?.includes(l));
        ctx.requireCampus(lib.campusId);
        campusIds.add(lib.campusId);
      }
      const after = {
        memberType: i.memberType,
        erpId: i.erpId,
        classId: i.memberType === 'student' ? (i.classId ?? null) : null,
        memberCategory: i.memberCategory,
        libraryIds,
        campusIds: [...campusIds],
        start: i.start,
        end: i.end ?? null,
      };
      if (before) {
        ctx.update(ref, { ...after, updatedAt: UP() });
        ctx.audit({ action: 'libMember.update', ref: ref.path, before, after });
      } else {
        ctx.set(ref, { ...after, status: 'active', activeLoans: 0, blocked: false, createdAt: UP(), createdBy: ctx.uid, updatedAt: UP() });
        ctx.audit({ action: 'libMember.create', ref: ref.path, after });
      }
      return { id: ref.id };
    },
  }),

  /** Inactive members cannot borrow (checked at issue in Lib-4); their loans stay visible. */
  memberSetStatus: def({
    name: 'lib.member.setStatus',
    perm: 'lib.circulation.operate',
    input: z.object({ id, status }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`libMembers/${i.id}`);
      const snap = await ctx.tx.get(ref);
      if (!snap.exists) throw missing('libMember');
      const d = snap.data()!;
      for (const c of d.campusIds as number[]) ctx.requireCampus(c);
      if (d.status === i.status) return { id: ref.id };
      ctx.update(ref, { status: i.status, updatedAt: UP() });
      ctx.audit({ action: 'libMember.status', ref: ref.path, before: { status: d.status }, after: { status: i.status } });
      return { id: ref.id };
    },
  }),
};
