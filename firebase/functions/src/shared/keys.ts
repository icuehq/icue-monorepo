import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import type { Ctx } from './callable';

const IST_OFFSET_MS = 330 * 60 * 1000;

/** Indian financial year (Apr–Mar) of [date] in IST, e.g. `2026-27`. */
export function fyOf(date: Date): string {
  const ist = new Date(date.getTime() + IST_OFFSET_MS);
  const start = ist.getUTCMonth() >= 3 ? ist.getUTCFullYear() : ist.getUTCFullYear() - 1;
  return `${start}-${String((start + 1) % 100).padStart(2, '0')}`;
}

/**
 * Next sequential number `TYPE/2026-27/000123` from `counters/{TYPE_fy}`.
 * ponytail: one number per type per transaction (a second call reads the same
 * counter); add a `count` parameter when bulk numbering (accessions) needs it.
 */
export async function nextNumber(ctx: Ctx, type: string, date = new Date()): Promise<string> {
  const fy = fyOf(date);
  const ref = ctx.doc(`counters/${type}_${fy}`);
  const snap = await ctx.tx.get(ref);
  const next = ((snap.data()?.next as number | undefined) ?? 0) + 1;
  ctx.set(ref, { next, updatedAt: FieldValue.serverTimestamp() });
  return `${type}/${fy}/${String(next).padStart(6, '0')}`;
}

/**
 * Claims `uniqueKeys/{kind_value}` for [refPath]. Codes are case-insensitive.
 * Throws `already-exists` when another record holds it; re-claiming your own is a no-op.
 */
export async function claimUniqueKey(ctx: Ctx, kind: string, value: string, refPath: string): Promise<void> {
  const norm = value.trim().toLowerCase();
  const ref = ctx.doc(`uniqueKeys/${kind}_${encodeURIComponent(norm)}`);
  const snap = await ctx.tx.get(ref);
  if (snap.exists && snap.data()!.ref !== refPath) {
    throw new HttpsError('already-exists', `${kind} "${value}" already exists`);
  }
  ctx.set(ref, { kind, value: norm, ref: refPath });
}
