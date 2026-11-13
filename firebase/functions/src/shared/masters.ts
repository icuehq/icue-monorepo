import { type DocumentData } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import type { CallableDef, CallableContext } from './callable';
import { serverTimestamp } from './firestore';
import { claimUniqueKey } from './keys';

/** Helpers shared by the inventory and library master-data callables. */

export const defineCallable = <S extends z.ZodType, R>(definition: CallableDef<S, R>) => definition;

export const id = z.string().min(1).max(100);
export const code = z.string().trim().min(1).max(30);
export const name = z.string().trim().min(1).max(120);
export const text = (max: number) => z.string().trim().max(max).nullish();
export const optionalText = text(500);
export const money = z.number().min(0).max(100_000_000);
export const status = z.enum(['active', 'inactive']);

export const failed = (message: string) => new HttpsError('failed-precondition', message);
export const missing = (what: string) => new HttpsError('not-found', `${what} not found`);

/** Document ID for masters keyed by their code (case-insensitive: `STA` and `sta` are one document). */
export const codeDocId = (value: string) => value.trim().toLowerCase();

/**
 * Creates (no `id`) or edits (`id`) a master document. Codes are immutable once
 * created (their `uniqueKeys` entry is never released). A `codeless` master
 * has no code at all (auto ID only).
 * `build` runs after the existing doc is loaded and returns the fields to write.
 */
export async function saveMaster(
  context: CallableContext,
  documentData: {
    coll: string;
    entityType: string;
    id?: string;
    code?: string;
    codeless?: boolean;
    build: (before: DocumentData | undefined, code: string | undefined) => Promise<Record<string, unknown>>;
  },
): Promise<{ id: string }> {
  const now = serverTimestamp();
  if (documentData.id) {
    const ref = context.doc(`${documentData.coll}/${documentData.id}`);
    const snapshot = await context.transaction.get(ref);
    if (!snapshot.exists) throw missing(documentData.entityType);
    const before = snapshot.data()!;
    if (documentData.code && documentData.code.toLowerCase() !== String(before.code).toLowerCase())
      throw failed('Code cannot be changed');
    const after = await documentData.build(before, before.code);
    context.update(ref, { ...after, updatedAt: now });
    context.audit({
      action: `${documentData.entityType}.update`,
      documentPath: ref.path,
      before,
      after,
    });
    return { id: ref.id };
  }
  if (!documentData.code && !documentData.codeless)
    throw new HttpsError('invalid-argument', 'Please enter a code.');
  const ref = context.newDoc(documentData.coll);
  if (documentData.code)
    await claimUniqueKey(context, documentData.entityType, documentData.code, ref.path);
  const after = await documentData.build(undefined, documentData.code);
  context.set(ref, {
    status: 'active',
    ...after,
    ...(documentData.code ? { code: documentData.code } : {}),
    createdAt: now,
    createdBy: context.uid,
    updatedAt: now,
  });
  context.audit({ action: `${documentData.entityType}.create`, documentPath: ref.path, after });
  return { id: ref.id };
}

/** Active, unless it is the value the record already holds (existing records keep deactivated masters). */
export function usable(
  snapshot: { exists: boolean; data(): DocumentData | undefined },
  what: string,
  unchanged: boolean,
) {
  if (!snapshot.exists) throw failed(`${what} not found`);
  if (!unchanged && snapshot.data()!.status !== 'active') throw failed(`${what} is inactive`);
  return snapshot.data()!;
}
