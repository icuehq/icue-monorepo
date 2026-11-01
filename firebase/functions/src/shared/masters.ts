import { DocumentData, FieldValue } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import type { CallableDef, Ctx } from './callable';
import { claimUniqueKey } from './keys';
import type { Permission } from './permissions';

/** Helpers shared by the inventory and library master-data callables. */

export const def = <S extends z.ZodType, R>(d: CallableDef<S, R>) => d;

export const id = z.string().min(1).max(100);
export const code = z.string().trim().min(1).max(30);
export const name = z.string().trim().min(1).max(120);
export const note = z.string().trim().max(500).nullish();
export const status = z.enum(['active', 'inactive']);

export const failed = (msg: string) => new HttpsError('failed-precondition', msg);
export const missing = (what: string) => new HttpsError('not-found', `${what} not found`);

/**
 * Creates (no `id`) or edits (`id`) a master document. Codes are immutable once
 * created (their `uniqueKeys` entry is never released).
 * `build` runs after the existing doc is loaded and returns the fields to write.
 */
export async function saveMaster(
  ctx: Ctx,
  o: {
    coll: string;
    kind: string;
    id?: string;
    code?: string;
    build: (before: DocumentData | undefined, code: string) => Promise<Record<string, unknown>>;
  },
): Promise<{ id: string }> {
  const now = FieldValue.serverTimestamp();
  if (o.id) {
    const ref = ctx.doc(`${o.coll}/${o.id}`);
    const snap = await ctx.tx.get(ref);
    if (!snap.exists) throw missing(o.kind);
    const before = snap.data()!;
    if (o.code && o.code.toLowerCase() !== String(before.code).toLowerCase()) throw failed('Code cannot be changed');
    const after = await o.build(before, before.code);
    ctx.update(ref, { ...after, updatedAt: now });
    ctx.audit({ action: `${o.kind}.update`, ref: ref.path, before, after });
    return { id: ref.id };
  }
  if (!o.code) throw new HttpsError('invalid-argument', 'code required');
  const ref = ctx.newDoc(o.coll);
  await claimUniqueKey(ctx, o.kind, o.code, ref.path);
  const after = await o.build(undefined, o.code);
  ctx.set(ref, { status: 'active', ...after, code: o.code, createdAt: now, createdBy: ctx.uid, updatedAt: now });
  ctx.audit({ action: `${o.kind}.create`, ref: ref.path, after });
  return { id: ref.id };
}

export function setStatusDef(fn: string, perm: Permission, coll: string, kind: string) {
  return def({
    name: fn,
    perm,
    input: z.object({ id, status }),
    handler: async (ctx, input) => {
      const ref = ctx.doc(`${coll}/${input.id}`);
      const snap = await ctx.tx.get(ref);
      if (!snap.exists) throw missing(kind);
      if (snap.data()!.status === input.status) return { id: input.id };
      ctx.update(ref, { status: input.status, updatedAt: FieldValue.serverTimestamp() });
      ctx.audit({ action: `${kind}.status`, ref: ref.path, before: { status: snap.data()!.status }, after: { status: input.status } });
      return { id: input.id };
    },
  });
}

/** Active, unless it is the value the record already holds (existing records keep deactivated masters). */
export function usable(snap: { exists: boolean; data(): DocumentData | undefined }, what: string, unchanged: boolean) {
  if (!snap.exists) throw failed(`${what} not found`);
  if (!unchanged && snap.data()!.status !== 'active') throw failed(`${what} is inactive`);
  return snap.data()!;
}
