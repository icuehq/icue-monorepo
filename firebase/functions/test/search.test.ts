import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';
import { applyItemChange } from '../src/inventory/search';
import { searchDb } from '../src/shared/searchMirror';
import { clearFirestore } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
const mirror = (branch = BRANCH) => searchDb().collection(`${branch}/inventoryItems`);
const timestampAt = (milliseconds: number) => Timestamp.fromMillis(milliseconds);
const item = (name: string, code: string, categoryId = 'c1') => ({
  name,
  code,
  categoryId,
  status: 'active',
  stockUnit: 'pcs',
  tracking: 'quantity',
  extra: 'x',
});
describe('item search mirror', () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  it('mirrors only the projection, updates it, and deletes it', async () => {
    await applyItemChange(BRANCH, 'i1', item('Blue Pen', 'PEN-01'), timestampAt(1));
    expect((await mirror().doc('i1').get()).data()).toEqual({
      name: 'Blue Pen',
      code: 'PEN-01',
      categoryId: 'c1',
      status: 'active',
      stockUnit: 'pcs',
      tracking: 'quantity',
      srcUpdatedAt: timestampAt(1),
    });
    await applyItemChange(BRANCH, 'i1', item('Blue Pen XL', 'PEN-01'), timestampAt(2));
    expect((await mirror().doc('i1').get()).data()?.name).toBe('Blue Pen XL');
    await applyItemChange(BRANCH, 'i1', undefined);
    expect((await mirror().doc('i1').get()).exists).toBe(false);
  });

  it('ignores an older delivery', async () => {
    await applyItemChange(BRANCH, 'i1', item('New name', 'A'), timestampAt(5));
    await applyItemChange(BRANCH, 'i1', item('Old name', 'A'), timestampAt(3));
    expect((await mirror().doc('i1').get()).data()?.name).toBe('New name');
  });
});
