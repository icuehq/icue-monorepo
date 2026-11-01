import '../region';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { z } from 'zod';
import { runCallable, type CallableDef, type Claims } from '../shared/callable';
import { masters } from './masters';
import { procurement } from './procurement';

/**
 * CSV import (FRS 14): the app parses the file and sends rows; each row goes through the same
 * callable as a single-record save (own transaction, all its rules and permission). Replaying a
 * request is safe: row `n` always uses the request ID `<importId>-<n>`.
 * ponytail: no staged preview / import history / xlsx / overwrite; add `importWorker` chunks when files exceed MAX_ROWS.
 */
const MAX_ROWS = 200;
const num = (v: string | undefined) => (v?.trim() ? Number(v) : undefined);
const str = (v: string | undefined) => v?.trim() || undefined;
const tracking = (v: string | undefined) => str(v)?.toLowerCase() ?? 'qty';

type Row = Record<string, string>;
type Type = { def: CallableDef<any, any>; map: (r: Row, categoryId: (code: string) => Promise<string>) => Promise<Record<string, unknown>> }; // eslint-disable-line @typescript-eslint/no-explicit-any

const types: Record<string, Type> = {
  categories: {
    def: masters.categoryUpsert,
    map: async (r, cat) => ({
      code: r.code, name: r.name, suggestedTracking: tracking(r.tracking),
      parentId: str(r.parentCode) ? await cat(r.parentCode) : undefined,
    }),
  },
  stores: {
    def: masters.storeUpsert,
    map: async (r) => ({ code: r.code, name: r.name, campusId: num(r.campusId), location: str(r.location) }),
  },
  items: {
    def: masters.itemUpsert,
    map: async (r, cat) => ({
      code: r.code, name: r.name, categoryId: await cat(r.categoryCode), stockUnit: str(r.stockUnit) ?? 'pcs',
      tracking: tracking(r.tracking), minLevel: num(r.minLevel), reorderLevel: num(r.reorderLevel), defaultPrice: num(r.defaultPrice),
    }),
  },
  vendors: {
    def: procurement.vendorUpsert,
    map: async (r) => ({ code: r.code, name: r.name, contactPerson: str(r.contactPerson), phone: str(r.phone), email: str(r.email), taxNo: str(r.taxNo) }),
  },
};

const input = z.object({
  importId: z.string().regex(/^[A-Za-z0-9_]{6,40}$/),
  type: z.enum(['categories', 'stores', 'items', 'vendors']),
  rows: z.array(z.record(z.string(), z.string().max(500))).min(1).max(MAX_ROWS),
});

export async function runImport(auth: { uid: string; token: Claims } | undefined, data: unknown) {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required');
  const parsed = input.safeParse(data);
  if (!parsed.success) throw new HttpsError('invalid-argument', z.prettifyError(parsed.error));
  const { importId, type, rows } = parsed.data;
  const t = types[type];
  const sid = String(auth.token.sid);
  const categoryId = async (code: string) => {
    const key = await getFirestore().doc(`schools/${sid}/uniqueKeys/invCategory_${encodeURIComponent((code ?? '').trim().toLowerCase())}`).get();
    if (!key.exists) throw new HttpsError('failed-precondition', `Category "${code}" not found`);
    return String(key.data()!.ref).split('/').pop()!;
  };
  const results: Array<{ row: number; ok: boolean; error?: string }> = [];
  for (const [n, row] of rows.entries()) {
    try {
      const data = await t.map(row, categoryId);
      await runCallable(t.def, auth, { requestId: `${importId}-${n}`, ...data });
      results.push({ row: n, ok: true });
    } catch (e) {
      // Permission and sign-in failures stop the whole file; row problems are reported per row.
      if (e instanceof HttpsError && ['permission-denied', 'unauthenticated'].includes(e.code)) throw e;
      results.push({ row: n, ok: false, error: e instanceof HttpsError ? e.message : 'Invalid row' });
    }
  }
  return { results, created: results.filter((r) => r.ok).length };
}

export const importRun = onCall((req) =>
  runImport(req.auth ? { uid: req.auth.uid, token: req.auth.token as Claims } : undefined, req.data),
);
