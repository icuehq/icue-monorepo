import { Pipelines } from '@google-cloud/firestore';
import {
  type DocumentData,
  type Firestore,
  getFirestore,
  Timestamp,
} from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import { BRANCH_TRIGGER, branchPathOf } from './branch';

/**
 * Text search lives in a second, Enterprise-edition database (`search`) that only Functions touch:
 * `(default)` stays the source of truth, a trigger mirrors a small projection into it, and a query
 * callable searches the mirror (architecture §10). Inventory items and the library catalogue share this.
 */
export const SEARCH_DB = 'search';
export const searchDb = () => getFirestore(SEARCH_DB);

/** Mirrors one document change; a delivery older than what is stored is ignored. */
export async function applyChange(
  collection: string,
  project: (data: DocumentData) => DocumentData,
  branchPath: string,
  documentId: string,
  after: DocumentData | undefined,
  changedAt: Timestamp = Timestamp.now(),
  db: Firestore = searchDb(),
): Promise<void> {
  const ref = db.doc(`${branchPath}/${collection}/${documentId}`);
  if (!after) {
    await ref.delete();
    return;
  }
  await db.runTransaction(async (transaction) => {
    const current = (await transaction.get(ref)).data()?.srcUpdatedAt as Timestamp | undefined;
    if (current && current.toMillis() > changedAt.toMillis()) return;
    transaction.set(ref, { ...project(after), srcUpdatedAt: changedAt });
  });
}

export const words = (text: string) =>
  text
    .toLowerCase()
    .split(/[^\p{L}\p{N}]+/u)
    .filter(Boolean);

/** Emulator stand-in for text search: every query word equals a word of one of [fields]. */
export const matchesAll = (terms: string[], data: DocumentData, fields: string[]) => {
  const have = new Set(words(fields.map((field) => String(data[field] ?? '')).join(' ')));
  return terms.every((term) => have.has(term));
};

export const searchInput = z.object({
  q: z.string().max(100),
  categoryId: z.string().min(1).max(100).optional(),
  offset: z.number().int().min(0).max(5000).default(0),
  limit: z.number().int().min(1).max(50).default(25),
});

export interface SearchRow {
  id: string;
  data: DocumentData;
}

/**
 * One page of whole-word matches (plus one extra row so the caller can tell whether more exist), sorted by [sortField].
 * Known limit: the emulator has no text search (`document_matches`), so a whole-word scan of one school's mirror
 * stands in; the real path is covered by the dev spike, not by tests.
 */
export async function searchMirror(
  branchPath: string,
  collection: string,
  query: z.infer<typeof searchInput>,
  options: {
    terms: string[];
    textFields: string[];
    sortField: string;
    /** Keeps rows in any of these categories; defaults to the query's single `categoryId`. */
    categoryIds?: string[];
    /** Keeps rows whose `classIds` array holds this class (library catalogue). */
    classId?: number;
  },
  db: Firestore = searchDb(),
): Promise<SearchRow[]> {
  const path = `${branchPath}/${collection}`;
  const categoryIds = options.categoryIds ?? (query.categoryId ? [query.categoryId] : undefined);
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    const all = (await db.collection(path).get()).docs
      .filter(
        (doc) =>
          matchesAll(options.terms, doc.data(), options.textFields) &&
          (!categoryIds || categoryIds.includes(doc.data().categoryId)) &&
          (options.classId === undefined || (doc.data().classIds ?? []).includes(options.classId)),
      )
      .sort((left, right) =>
        String(left.data()[options.sortField]).localeCompare(
          String(right.data()[options.sortField]),
        ),
      );
    return all
      .slice(query.offset, query.offset + query.limit + 1)
      .map((doc) => ({ id: doc.id, data: doc.data() }));
  }
  const { documentMatches, field } = Pipelines;
  let pipeline = db
    .pipeline()
    .collection(path)
    .search({ query: documentMatches(options.terms.join(' ')) });
  if (categoryIds) pipeline = pipeline.where(field('categoryId').equalAny(categoryIds));
  if (options.classId !== undefined)
    pipeline = pipeline.where(field('classIds').arrayContains(options.classId));
  const result = await pipeline
    .sort(field(options.sortField).ascending())
    .offset(query.offset)
    .limit(query.limit + 1)
    .execute();
  return result.results.map((row) => ({ id: row.id!, data: row.data() }));
}

/** Validates the query, searches the mirror and returns one page of projected rows plus `hasMore`. */
export async function searchPage(
  branchPath: string,
  collection: string,
  query: z.infer<typeof searchInput>,
  options: Omit<Parameters<typeof searchMirror>[3], 'terms'>,
  project: (data: DocumentData) => DocumentData,
  db: Firestore = searchDb(),
) {
  // Punctuation is dropped so users cannot inject search-DSL operators (quotes, -, *, OR).
  const terms = words(query.q);
  if (!terms.length) throw new HttpsError('invalid-argument', 'Enter a word to search for.');
  const rows = await searchMirror(branchPath, collection, query, { ...options, terms }, db);
  return {
    items: rows.slice(0, query.limit).map((row) => ({ id: row.id, ...project(row.data) })),
    hasMore: rows.length > query.limit,
  };
}

/** Whether a write leaves the mirrored projection unchanged (so the search database need not be touched). */
export const sameProjection = (
  project: (data: DocumentData) => DocumentData,
  before: DocumentData | undefined,
  after: DocumentData | undefined,
) => !!before && !!after && JSON.stringify(project(before)) === JSON.stringify(project(after));

/** Trigger that mirrors writes of `${BRANCH_TRIGGER}/<collection>/{id}` that change the projection. */
export const syncTrigger = (collection: string, project: (data: DocumentData) => DocumentData) =>
  onDocumentWritten(`${BRANCH_TRIGGER}/${collection}/{id}`, async (event) => {
    const after = event.data?.after.data();
    if (sameProjection(project, event.data?.before.data(), after)) return;
    await applyChange(
      collection,
      project,
      branchPathOf(event.params),
      event.params.id,
      after,
      event.data?.after.updateTime,
    );
  });
