import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import { claimsBranchPath } from './branch';
import { runCallable, type AnyCallableDef, type Auth } from './callable';
import { invalidInput } from './errors';
import { uniqueKeyId } from './keys';
import { codeDocId } from './masters';

/**
 * CSV import (FRS 14): the app parses the file and sends rows; each row goes through the same callable as a
 * single-record save (own transaction, its rules and permission). Row `n` always uses the request ID
 * `<importId>-<n>`, so replaying a request is safe.
 * Known limit: no staged preview, import history, xlsx or overwrite; add `importWorker` chunks past MAX_ROWS.
 */
export const MAX_ROWS = 200;

export type ImportRow = Record<string, string>;
/** Finds the document ID behind a unique code (inventory category code…; libraries and library categories are found by name); throws when it does not exist. */
export type CodeLookup = (keyType: string, value: string, label: string) => Promise<string>;
export interface ImportType {
  callable: AnyCallableDef;
  mapRow: (row: ImportRow, lookup: CodeLookup) => Promise<Record<string, unknown>>;
}

export const toNumber = (value: string | undefined) => (value?.trim() ? Number(value) : undefined);
export const toText = (value: string | undefined) => value?.trim() || undefined;
/** `a; b; c` → `['a', 'b', 'c']`. */
export const toList = (value: string | undefined) =>
  (value ?? '')
    .split(';')
    .map((part) => part.trim())
    .filter(Boolean);

/** Masters without a code, found by name. */
const NAME_COLLECTIONS: Record<string, string> = {
  library: 'libraries',
  libraryCategory: 'libraryCategories',
};

/** Masters whose document ID is their lowercased code (no `uniqueKeys` entry). */
const CODE_ID_COLLECTIONS: Record<string, string> = {
  inventoryCategory: 'inventoryCategories',
};

async function lookupByCode(
  branchPath: string,
  keyType: string,
  value: string,
  label: string,
): Promise<string> {
  const byName = NAME_COLLECTIONS[keyType];
  if (byName) {
    // These masters have no code: match the name, ignoring case.
    const wanted = (value ?? '').trim().toLowerCase();
    const documents = await getFirestore().collection(`${branchPath}/${byName}`).get();
    const match = documents.docs.find(
      (document) => String(document.data().name).trim().toLowerCase() === wanted,
    );
    if (!wanted || !match) {
      throw new HttpsError('failed-precondition', `${label} "${value}" not found`);
    }
    return match.id;
  }
  const collection = CODE_ID_COLLECTIONS[keyType];
  if (collection) {
    const docId = codeDocId(value ?? '');
    if (
      !docId ||
      !(await getFirestore().doc(`${branchPath}/${collection}/${docId}`).get()).exists
    ) {
      throw new HttpsError('failed-precondition', `${label} "${value}" not found`);
    }
    return docId;
  }
  const key = await getFirestore()
    .doc(`${branchPath}/uniqueKeys/${uniqueKeyId(keyType, value ?? '')}`)
    .get();
  if (!key.exists) throw new HttpsError('failed-precondition', `${label} "${value}" not found`);
  return String(key.data()!.documentPath).split('/').pop()!;
}

export async function importRows(auth: Auth, data: unknown, types: Record<string, ImportType>) {
  if (!auth) throw new HttpsError('unauthenticated', 'Please sign in to continue.');
  const input = z.object({
    importId: z.string().regex(/^[A-Za-z0-9_]{6,40}$/),
    type: z.enum(Object.keys(types) as [string, ...string[]]),
    rows: z
      .array(z.record(z.string(), z.string().max(500)))
      .min(1)
      .max(MAX_ROWS),
  });
  const parsed = input.safeParse(data);
  if (!parsed.success) throw invalidInput(parsed.error);
  const { importId, type, rows } = parsed.data;
  const branchPath = claimsBranchPath(auth.token);
  const lookup: CodeLookup = (keyType, value, label) =>
    lookupByCode(branchPath, keyType, value, label);
  const results: { row: number; ok: boolean; error?: string }[] = [];
  for (const [index, row] of rows.entries()) {
    try {
      const fields = await types[type].mapRow(row, lookup);
      await runCallable(types[type].callable, auth, {
        requestId: `${importId}-${index}`,
        ...fields,
      });
      results.push({ row: index, ok: true });
    } catch (error) {
      // Permission and sign-in failures stop the whole file; row problems are reported per row.
      if (
        error instanceof HttpsError &&
        ['permission-denied', 'unauthenticated'].includes(error.code)
      )
        throw error;
      results.push({
        row: index,
        ok: false,
        error: error instanceof HttpsError ? error.message : 'Invalid row',
      });
    }
  }
  return { results, created: results.filter((result) => result.ok).length };
}
