import { HttpsError } from 'firebase-functions/v2/https';
import type { CallableContext } from './callable';
import { serverTimestamp } from './firestore';

const IST_OFFSET_MS = 330 * 60 * 1000;

/** Indian financial year (Apr–Mar) of [date] in IST, e.g. `2026-27`. */
export function financialYearOf(date: Date): string {
  const ist = new Date(date.getTime() + IST_OFFSET_MS);
  const start = ist.getUTCMonth() >= 3 ? ist.getUTCFullYear() : ist.getUTCFullYear() - 1;
  return `${start}-${String((start + 1) % 100).padStart(2, '0')}`;
}

/**
 * Next sequential number `TYPE/2026-27/000123` from `counters/{TYPE_fy}`.
 * Known limit: one number per type per transaction (a second call reads the same
 * counter); add a `count` parameter when bulk numbering (accessions) needs it.
 */
export async function nextNumber(
  context: CallableContext,
  type: string,
  date = new Date(),
): Promise<string> {
  const financialYear = financialYearOf(date);
  const ref = context.doc(`counters/${type}_${financialYear}`);
  const snapshot = await context.transaction.get(ref);
  const next = ((snapshot.data()?.next as number | undefined) ?? 0) + 1;
  context.set(ref, { next, updatedAt: serverTimestamp() });
  return `${type}/${financialYear}/${String(next).padStart(6, '0')}`;
}

export const uniqueKeyRef = (context: CallableContext, keyType: string, value: string) =>
  context.doc(`uniqueKeys/${keyType}_${encodeURIComponent(value.trim().toLowerCase())}`);

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
