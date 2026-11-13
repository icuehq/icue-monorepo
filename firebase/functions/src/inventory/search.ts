import { type DocumentData, type Firestore, type Timestamp } from 'firebase-admin/firestore';
import { applyChange, syncTrigger } from '../shared/searchMirror';

/** Item search (architecture §10): `syncItemSearch` mirrors a small projection that web clients query. */
const FIELDS = ['name', 'categoryId', 'status', 'stockUnit', 'tracking'] as const;

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
