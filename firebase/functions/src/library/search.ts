import { type DocumentData, type Firestore, type Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { QueryDef } from '../shared/callable';
import { applyChange, searchInput, searchPage, syncTrigger } from '../shared/searchMirror';

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
  branchPath: string,
  catalogueId: string,
  after: DocumentData | undefined,
  changedAt?: Timestamp,
  db?: Firestore,
) => applyChange(COLL, projectCatalogue, branchPath, catalogueId, after, changedAt, db);

export const syncCatalogueSearch = syncTrigger(COLL, projectCatalogue);

export const searchCatalogue = (
  branchPath: string,
  query: z.infer<typeof catalogueSearchInput>,
  db?: Firestore,
) =>
  searchPage(
    branchPath,
    COLL,
    query,
    {
      textFields: TEXT,
      sortField: 'title',
      categoryIds: query.categoryIds,
      classId: query.classId,
    },
    projectRow,
    db,
  );

export const catalogueSearch: QueryDef<
  typeof catalogueSearchInput,
  Awaited<ReturnType<typeof searchCatalogue>>
> = {
  name: 'library.catalogue.search',
  input: catalogueSearchInput,
  handler: searchCatalogue,
};
