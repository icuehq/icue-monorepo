import {
  type DocumentData,
  type Firestore,
  getFirestore,
  type Timestamp,
} from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import type { z } from 'zod';
import type { QueryDef } from '../shared/callable';
import {
  applyChange,
  searchDb,
  searchInput,
  searchMirror,
  words,
  type SearchRow,
} from '../shared/searchMirror';
import { cleanIsbn, isIsbn10, isIsbn13, toIsbn13 } from './isbn';

/** Catalogue search (FRS 11.4): same mirror pattern as inventory items (architecture §10). */
const COLL = 'libraryCatalogue';
const ROW = [
  'title',
  'subtitle',
  'authors',
  'publisher',
  'isbn',
  'year',
  'language',
  'categoryId',
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

/** ISBN-13 of [q] when the whole query is a valid ISBN (hyphens allowed). */
const isbnOf = (query: string) => {
  const isbn = cleanIsbn(query);
  return isIsbn13(isbn) ? isbn : isIsbn10(isbn) ? toIsbn13(isbn) : null;
};

export async function searchCatalogue(
  schoolId: string,
  query: z.infer<typeof searchInput>,
  db: Firestore = searchDb(),
) {
  const path = `schools/${schoolId}/${COLL}`;
  const isbn = isbnOf(query.q);
  let rows: SearchRow[];
  if (isbn) {
    // Exact lookups are plain queries on the source of truth, not text search.
    const snapshot = await getFirestore()
      .collection(path)
      .where('identityKey', '==', `isbn:${isbn}`)
      .get();
    rows = snapshot.docs
      .filter((doc) => !query.categoryId || doc.data().categoryId === query.categoryId)
      .slice(query.offset, query.offset + query.limit + 1)
      .map((doc) => ({ id: doc.id, data: doc.data() }));
  } else {
    // Punctuation is dropped so users cannot inject search-DSL operators (quotes, -, *, OR).
    const terms = words(query.q);
    if (!terms.length)
      throw new HttpsError('invalid-argument', 'Enter a word or an ISBN to search for');
    rows = await searchMirror(
      schoolId,
      COLL,
      query,
      { terms, textFields: TEXT, sortField: 'title' },
      db,
    );
  }
  return {
    items: rows.slice(0, query.limit).map((row) => ({ id: row.id, ...projectRow(row.data) })),
    hasMore: rows.length > query.limit,
  };
}

export const catalogueSearch: QueryDef<
  typeof searchInput,
  Awaited<ReturnType<typeof searchCatalogue>>
> = {
  name: 'library.catalogue.search',
  permission: 'library.catalogue',
  input: searchInput,
  handler: searchCatalogue,
};
