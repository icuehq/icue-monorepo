import { HttpsError } from 'firebase-functions/v2/https';
import type { CallableContext } from './callable';
import { INDIA_OFFSET_MILLISECONDS } from './dates';
import { serverTimestamp } from './firestore';

/** Indian financial year (Apr–Mar) of [date] in IST, e.g. `2026-27`. */
export function financialYearOf(date: Date): string {
  const ist = new Date(date.getTime() + INDIA_OFFSET_MILLISECONDS);
  const start = ist.getUTCMonth() >= 3 ? ist.getUTCFullYear() : ist.getUTCFullYear() - 1;
  return `${start}-${String((start + 1) % 100).padStart(2, '0')}`;
}

/**
 * The next [count] running numbers (1, 2, …) of `counters/{key}`.
 * Known limit: one call per key per transaction (a second call reads the same counter).
 */
export async function nextSequence(
  context: CallableContext,
  key: string,
  count: number,
): Promise<number[]> {
  const ref = context.doc(`counters/${key}`);
  const snapshot = await context.transaction.get(ref);
  const first = ((snapshot.data()?.next as number | undefined) ?? 0) + 1;
  context.set(ref, { next: first + count - 1, updatedAt: serverTimestamp() });
  return Array.from({ length: count }, (_, offset) => first + offset);
}

/** The next [count] sequential numbers `TYPE/2026-27/000123` from `counters/{TYPE_fy}`. */
export async function nextNumbers(
  context: CallableContext,
  type: string,
  count: number,
  date = new Date(),
): Promise<string[]> {
  const financialYear = financialYearOf(date);
  const numbers = await nextSequence(context, `${type}_${financialYear}`, count);
  return numbers.map((number) => `${type}/${financialYear}/${String(number).padStart(6, '0')}`);
}

/** Next sequential number `TYPE/2026-27/000123`. */
export const nextNumber = async (context: CallableContext, type: string, date = new Date()) =>
  (await nextNumbers(context, type, 1, date))[0];

/** `uniqueKeys` document ID of [value]; codes are case-insensitive. */
export const uniqueKeyId = (keyType: string, value: string) =>
  `${keyType}_${encodeURIComponent(value.trim().toLowerCase())}`;

export const uniqueKeyRef = (context: CallableContext, keyType: string, value: string) =>
  context.doc(`uniqueKeys/${uniqueKeyId(keyType, value)}`);

/**
 * Claims `uniqueKeys/{keyType_value}` for [documentPath]. Codes are case-insensitive.
 * Throws `already-exists` when another record holds it; re-claiming your own is a no-op.
 */
export async function claimUniqueKey(
  context: CallableContext,
  keyType: string,
  value: string,
  documentPath: string,
): Promise<void> {
  const norm = value.trim().toLowerCase();
  const ref = uniqueKeyRef(context, keyType, value);
  const snapshot = await context.transaction.get(ref);
  if (snapshot.exists && snapshot.data()!.documentPath !== documentPath) {
    throw new HttpsError('already-exists', `${keyType} "${value}" already exists`);
  }
  context.set(ref, { keyType, value: norm, documentPath });
}
