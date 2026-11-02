import { type DocumentData, type Firestore, type Timestamp } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import type { z } from 'zod';
import type { QueryDef } from '../shared/callable';
import { applyChange, searchDb, searchInput, searchMirror, words } from '../shared/searchMirror';

/** Item search (architecture §10): `syncItemSearch` mirrors a small projection, `searchItems` queries it. */
const FIELDS = ['code', 'name', 'categoryId', 'status', 'stockUnit', 'tracking'] as const;

/** The list-row fields mirrored into the search database. */
export const projectItem = (data: DocumentData) =>
  Object.fromEntries(FIELDS.map((field) => [field, data[field] ?? null]));

export const applyItemChange = (
  schoolId: string,
  itemId: string,
  after: DocumentData | undefined,
  changedAt?: Timestamp,
  db?: Firestore,
) => applyChange('inventoryItems', projectItem, schoolId, itemId, after, changedAt, db);

export const syncItemSearch = onDocumentWritten('schools/{schoolId}/inventoryItems/{id}', (event) =>
  applyItemChange(
    event.params.schoolId,
    event.params.id,
    event.data?.after.data(),
    event.data?.after.updateTime,
  ),
);

export async function searchItems(
  schoolId: string,
  query: z.infer<typeof searchInput>,
  db: Firestore = searchDb(),
) {
  // Punctuation is dropped so users cannot inject search-DSL operators (quotes, -, *, OR).
  const terms = words(query.q);
  if (!terms.length) throw new HttpsError('invalid-argument', 'Enter a word to search for');
  const rows = await searchMirror(
    schoolId,
    'inventoryItems',
    query,
    { terms, textFields: ['name', 'code'], sortField: 'name' },
    db,
  );
  return {
    items: rows.slice(0, query.limit).map((row) => ({ id: row.id, ...projectItem(row.data) })),
    hasMore: rows.length > query.limit,
  };
}

export const itemSearch: QueryDef<typeof searchInput, Awaited<ReturnType<typeof searchItems>>> = {
  name: 'inventory.item.search',
  permission: 'inventory.items.view',
  input: searchInput,
  handler: searchItems,
};
