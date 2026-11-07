import { Pipelines } from '@google-cloud/firestore';
import {
  type DocumentData,
  type Firestore,
  getFirestore,
  Timestamp,
} from 'firebase-admin/firestore';
import { z } from 'zod';

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
  schoolId: string,
  documentId: string,
  after: DocumentData | undefined,
  changedAt: Timestamp = Timestamp.now(),
  db: Firestore = searchDb(),
): Promise<void> {
  const ref = db.doc(`schools/${schoolId}/${collection}/${documentId}`);
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
  schoolId: string,
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
  const path = `schools/${schoolId}/${collection}`;
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
