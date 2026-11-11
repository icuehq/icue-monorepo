import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';
import { applyItemChange, itemSearch } from '../src/inventory/search';
import { runQuery } from '../src/shared/callable';
import { matchesAll, searchDb } from '../src/shared/searchMirror';
import { clearFirestore, db } from './setup';

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
const staff = (uid = '1', branchId: number | string = 427) => ({
  uid,
  token: { orgId: 8, zoneId: 147, branchId, personType: 'staff' },
});
const search = (
  data: Record<string, unknown>,
  auth: Parameters<typeof runQuery>[1] | null = staff(),
) => runQuery(itemSearch, auth ?? undefined, data) as ReturnType<typeof itemSearch.handler>;

describe('item search mirror', () => {
  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`${BRANCH}/userAccess/1`)
      .set({ permissions: ['inventory.items.view'] });
    await db()
      .doc(`${BRANCH}/userAccess/2`)
      .set({ permissions: ['inventory.stock.view'] });
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

  it('matches whole words of name or code, all terms required', () => {
    expect(matchesAll(['blue', 'pen'], item('Blue Pen', 'PEN-01'), ['name', 'code'])).toBe(true);
    expect(matchesAll(['blu'], item('Blue Pen', 'PEN-01'), ['name', 'code'])).toBe(false);
    expect(matchesAll(['01'], item('Blue Pen', 'PEN-01'), ['name', 'code'])).toBe(true);
  });

  describe('callable', () => {
    beforeEach(async () => {
      await applyItemChange(BRANCH, 'i1', item('Blue Pen', 'PEN-01'), timestampAt(1));
      await applyItemChange(BRANCH, 'i2', item('Blue Marker', 'MRK-01', 'c2'), timestampAt(1));
      await applyItemChange(BRANCH, 'i3', item('Black Pen', 'PEN-02'), timestampAt(1));
      await applyItemChange('orgs/8/zones/147/branches/428', 'x1', item('Blue Other School', 'OS-1'), timestampAt(1));
    });

    it('finds items by word, only in the caller’s branch, without internal fields', async () => {
      const result = await search({ q: 'Blue' });
      expect(result.items.map((i) => i.id)).toEqual(['i2', 'i1']); // sorted by name
      expect(result.items[0]).not.toHaveProperty('srcUpdatedAt');
      expect(result.items[0]).toMatchObject({ code: 'MRK-01', categoryId: 'c2' });
    });

    it('combines text with a category filter and pages with hasMore', async () => {
      expect((await search({ q: 'blue', categoryId: 'c1' })).items.map((i) => i.id)).toEqual([
        'i1',
      ]);
      const firstPage = await search({ q: 'pen', limit: 1 });
      expect(firstPage).toMatchObject({ hasMore: true, items: [{ id: 'i3' }] });
      const secondPage = await search({ q: 'pen', limit: 1, offset: 1 });
      expect(secondPage).toMatchObject({ hasMore: false, items: [{ id: 'i1' }] });
    });

    it('treats punctuation as separators, not search operators', async () => {
      expect((await search({ q: '"pen" -black *' })).items.map((i) => i.id)).toEqual(['i3']); // "-black" is the word black, not an exclusion
      await expect(search({ q: '- * "' })).rejects.toMatchObject({ code: 'invalid-argument' });
    });

    it('requires auth, a synced session and inv.items.view; rejects parents', async () => {
      await expect(search({ q: 'pen' }, null)).rejects.toMatchObject({ code: 'unauthenticated' });
      await expect(
        search({ q: 'pen' }, { uid: 'parent-1', token: { orgId: 8, zoneId: 147, branchId: 427, personType: 'parent' } }),
      ).rejects.toMatchObject({ code: 'permission-denied' });
      await expect(search({ q: 'pen' }, staff('9'))).rejects.toMatchObject({
        code: 'failed-precondition',
      });
      await expect(search({ q: 'pen' }, staff('2'))).rejects.toMatchObject({
        code: 'permission-denied',
      });
    });
  });
});
