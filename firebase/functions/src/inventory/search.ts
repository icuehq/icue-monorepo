import { type DocumentData, type Firestore, type Timestamp } from 'firebase-admin/firestore';
import type { z } from 'zod';
import type { QueryDef } from '../shared/callable';
import { applyChange, searchInput, searchPage, syncTrigger } from '../shared/searchMirror';

/** Item search (architecture §10): `syncItemSearch` mirrors a small projection, `searchItems` queries it. */
const FIELDS = ['code', 'name', 'categoryId', 'status', 'stockUnit', 'tracking'] as const;

/** The list-row fields mirrored into the search database. */
export const projectItem = (data: DocumentData) =>
  Object.fromEntries(FIELDS.map((field) => [field, data[field] ?? null]));

export const applyItemChange = (
  branchPath: string,
  itemId: string,
  after: DocumentData | undefined,
  changedAt?: Timestamp,
  db?: Firestore,
) => applyChange('inventoryItems', projectItem, branchPath, itemId, after, changedAt, db);

export const syncItemSearch = syncTrigger('inventoryItems', projectItem);

export const searchItems = (
  branchPath: string,
  query: z.infer<typeof searchInput>,
  db?: Firestore,
) =>
  searchPage(
    branchPath,
    'inventoryItems',
    query,
    { textFields: ['name', 'code'], sortField: 'name' },
    projectItem,
    db,
  );

export const itemSearch: QueryDef<typeof searchInput, Awaited<ReturnType<typeof searchItems>>> = {
  name: 'inventory.item.search',
  permission: 'inventory.items.view',
  input: searchInput,
  handler: searchItems,
};
