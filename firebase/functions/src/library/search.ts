import { type DocumentData, type Firestore, type Timestamp } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import type { QueryDef } from '../shared/callable';
import { applyChange, searchDb, searchInput, searchMirror, words } from '../shared/searchMirror';

/** A parent category's search includes its subcategories, so the caller sends the expanded ids. */
const catalogueSearchInput = searchInput.omit({ categoryId: true }).extend({
  categoryIds: z.array(z.string().min(1).max(100)).max(30).optional(),
  classId: z.number().int().positive().optional(),
});

/** Catalogue search (FRS 11.4): same mirror pattern as inventory items (architecture §10). */
const COLL = 'libraryCatalogue';
const ROW = [
  'title',
  'subtitle',
  'authors',
  'publisher',
  'year',
  'language',
  'categoryId',
  'classIds',
  'status',
] as const;
/** Fields the text index covers (see `firebase/scripts/create-search-index.sh`). */
const TEXT = ['title', 'subtitle', 'authorsText', 'publisher', 'keywordsText'];

const projectRow = (catalogueDocument: DocumentData) =>
  Object.fromEntries(ROW.map((field) => [field, catalogueDocument[field] ?? null]));

/** The list-row fields plus flat text copies of the array fields, which the text index needs. */
export const projectCatalogue = (catalogueDocument: DocumentData) => ({
  ...projectRow(catalogueDocument),
  authorsText: (catalogueDocument.authors ?? []).join(' '),
  keywordsText: (catalogueDocument.keywords ?? []).join(' '),
});

export const applyCatalogueChange = (
  schoolId: string,
  catalogueId: string,
  after: DocumentData | undefined,
  changedAt?: Timestamp,
  db?: Firestore,
) => applyChange(COLL, projectCatalogue, schoolId, catalogueId, after, changedAt, db);

export const syncCatalogueSearch = onDocumentWritten(
  `schools/{schoolId}/${COLL}/{id}`,
  (snapshot) =>
    applyCatalogueChange(
      snapshot.params.schoolId,
      snapshot.params.id,
      snapshot.data?.after.data(),
      snapshot.data?.after.updateTime,
    ),
);

export async function searchCatalogue(
  schoolId: string,
  query: z.infer<typeof catalogueSearchInput>,
  db: Firestore = searchDb(),
) {
  // Punctuation is dropped so users cannot inject search-DSL operators (quotes, -, *, OR).
  const terms = words(query.q);
  if (!terms.length) throw new HttpsError('invalid-argument', 'Enter a word to search for');
  const rows = await searchMirror(
    schoolId,
    COLL,
    query,
    {
      terms,
      textFields: TEXT,
      sortField: 'title',
      categoryIds: query.categoryIds,
      classId: query.classId,
    },
    db,
  );
  return {
    items: rows.slice(0, query.limit).map((row) => ({ id: row.id, ...projectRow(row.data) })),
    hasMore: rows.length > query.limit,
  };
}

export const catalogueSearch: QueryDef<
  typeof catalogueSearchInput,
  Awaited<ReturnType<typeof searchCatalogue>>
> = {
  name: 'library.catalogue.search',
  permission: 'library.catalogue',
  input: catalogueSearchInput,
  handler: searchCatalogue,
};
