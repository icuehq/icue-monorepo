import '../region';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { z } from 'zod';
import { runCallable, type CallableDef, type Claims } from '../shared/callable';
import { copies } from './copies';
import { cleanIsbn } from './isbn';
import { masters } from './masters';
import { members } from './members';

/**
 * CSV import (FRS 11 import): the app parses the file and sends rows; each row goes through the same callable as a
 * single-record save (own transaction, its rules and permission). Row `n` always uses the request ID `<importId>-<n>`,
 * so replaying a request is safe. Same design as `inv-import-run`.
 * ponytail: no staged preview / history / xlsx / overwrite; existing titles and members are rejected, not updated.
 */
const MAX_ROWS = 200;
const num = (v: string | undefined) => (v?.trim() ? Number(v) : undefined);
const str = (v: string | undefined) => v?.trim() || undefined;
const list = (v: string | undefined) => (v ?? '').split(';').map((x) => x.trim()).filter(Boolean);

type Row = Record<string, string>;
type Lookup = (kind: string, value: string) => Promise<string>;
type Type = { def: CallableDef<any, any>; map: (r: Row, id: Lookup) => Promise<Record<string, unknown>> }; // eslint-disable-line @typescript-eslint/no-explicit-any

const types: Record<string, Type> = {
  catalogue: {
    def: masters.catalogueUpsert,
    map: async (r, id) => ({
      title: r.title, authors: list(r.authors), categoryId: await id('libCategory', r.categoryCode),
      isbn10: str(r.isbn10), isbn13: str(r.isbn13), publisher: str(r.publisher), edition: str(r.edition), year: num(r.year),
      language: str(r.language), pages: num(r.pages), classNo: str(r.classNo), keywords: list(r.keywords),
    }),
  },
  copies: {
    def: copies.acquisitionCreate,
    // Existing accession numbers cannot be kept: numbers come from one school-wide counter.
    map: async (r, id) => ({
      type: 'opening', catalogueId: await id('libTitle', `isbn:${cleanIsbn(r.isbn13 ?? '')}`), libraryId: await id('libLibrary', r.libraryCode),
      qty: num(r.qty) ?? 1, price: num(r.price), shelf: str(r.shelf), condition: str(r.condition)?.toLowerCase() ?? 'good', date: str(r.date),
    }),
  },
  members: {
    def: members.memberUpsert,
    map: async (r, id) => ({
      memberType: r.memberType?.trim().toLowerCase(), erpId: num(r.erpId), classId: num(r.classId), memberCategory: r.memberCategory,
      libraryIds: await Promise.all(list(r.libraryCodes).map((c) => id('libLibrary', c))), start: r.start, end: str(r.end),
    }),
  },
};
async function lookup(sid: string, kind: string, value: string): Promise<string> {
  const key = await getFirestore().doc(`schools/${sid}/uniqueKeys/${kind}_${encodeURIComponent((value ?? '').trim().toLowerCase())}`).get();
  if (!key.exists) throw new HttpsError('failed-precondition', `${kind.replace(/^lib/, '')} "${value}" not found`);
  return String(key.data()!.ref).split('/').pop()!;
}

const input = z.object({
  importId: z.string().regex(/^[A-Za-z0-9_]{6,40}$/),
  type: z.enum(['catalogue', 'copies', 'members']),
  rows: z.array(z.record(z.string(), z.string().max(500))).min(1).max(MAX_ROWS),
});

export async function runLibraryImport(auth: { uid: string; token: Claims } | undefined, data: unknown) {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required');
  const parsed = input.safeParse(data);
  if (!parsed.success) throw new HttpsError('invalid-argument', z.prettifyError(parsed.error));
  const { importId, type, rows } = parsed.data;
  const sid = String(auth.token.sid);
  const results: Array<{ row: number; ok: boolean; error?: string }> = [];
  for (const [n, row] of rows.entries()) {
    try {
      const data = await types[type].map(row, (kind, value) => lookup(sid, kind, value));
      await runCallable(types[type].def, auth, { requestId: `${importId}-${n}`, ...data });
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
  runLibraryImport(req.auth ? { uid: req.auth.uid, token: req.auth.token as Claims } : undefined, req.data),
);
