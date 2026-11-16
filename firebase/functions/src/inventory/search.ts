import {
  type DocumentData,
  type Firestore,
  getFirestore,
  type Timestamp,
} from 'firebase-admin/firestore';
import { onDocumentUpdated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { BRANCH_TRIGGER, branchPathOf } from '../shared/branch';
import { applyChange, prefixText, syncTrigger } from '../shared/searchMirror';

/** Item search (architecture §10): `syncItemSearch` mirrors a small projection that web clients query. */
const FIELDS = [
  'name',
  'storeId',
  'categoryId',
  'status',
  'stockUnit',
  'tracking',
  'createdAt',
] as const;

/** The list-row fields mirrored into the search database, plus `prefixText` so a half-typed word matches (the text index covers name and prefixText). */
export const projectItem = (data: DocumentData) => ({
  ...Object.fromEntries(FIELDS.map((field) => [field, data[field] ?? null])),
  prefixText: prefixText(data.name ?? ''),
});

export const applyItemChange = (
  branchPath: string,
  itemId: string,
  after: DocumentData | undefined,
  changedAt?: Timestamp,
  db?: Firestore,
) => applyChange('inventoryItems', projectItem, branchPath, itemId, after, changedAt, db);

export const syncItemSearch = syncTrigger('inventoryItems', projectItem);

/**
 * Stock balance search: a balance holds only `itemId`, so the mirror adds the item's name (`itemName`, plus
 * `prefixText`) and keeps just the identity and filter fields; the client reads the quantities from `(default)`.
 * The text index covers itemName and prefixText (`firebase/scripts/create-search-index.sh`).
 */
const BALANCE_FIELDS = [
  'storeId',
  'itemId',
  'variantId',
  'batchNumber',
  'isBelowReorderLevel',
] as const;

export const projectBalance = (data: DocumentData, itemName: string) => ({
  ...Object.fromEntries(BALANCE_FIELDS.map((field) => [field, data[field] ?? null])),
  itemName,
  prefixText: prefixText(itemName),
});

const itemNameOf = async (branchPath: string, itemId: string, db: Firestore = getFirestore()) =>
  ((await db.doc(`${branchPath}/inventoryItems/${itemId}`).get()).data()?.name as
    string | undefined) ?? '';

export const applyBalanceChange = async (
  branchPath: string,
  balanceId: string,
  after: DocumentData | undefined,
  changedAt?: Timestamp,
  db?: Firestore,
) => {
  const itemName = after ? await itemNameOf(branchPath, after.itemId) : '';
  return applyChange(
    'inventoryBalances',
    (data) => projectBalance(data, itemName),
    branchPath,
    balanceId,
    after,
    changedAt,
    db,
  );
};

export const syncBalanceSearch = onDocumentWritten(
  `${BRANCH_TRIGGER}/inventoryBalances/{id}`,
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const branch = branchPathOf(event.params);
    if (
      before &&
      after &&
      JSON.stringify(projectBalance(before, '')) === JSON.stringify(projectBalance(after, ''))
    )
      return;
    await applyBalanceChange(branch, event.params.id, after, event.data?.after.updateTime);
  },
);

/** A renamed item renames its balances in the search mirror. */
export const syncBalanceItemNames = onDocumentUpdated(
  `${BRANCH_TRIGGER}/inventoryItems/{id}`,
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.name === after.name) return;
    const branch = branchPathOf(event.params);
    const balances = await getFirestore()
      .collection(`${branch}/inventoryBalances`)
      .where('itemId', '==', event.params.id)
      .get();
    await Promise.all(
      balances.docs.map((balance) =>
        applyBalanceChange(branch, balance.id, balance.data(), event.data?.after.updateTime),
      ),
    );
  },
);
