import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';
import { applyItemChange, itemSearch, matchesAll, searchDb } from '../src/inventory/search';
import { runQuery } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
const mirror = (sid = SID) => searchDb().collection(`schools/${sid}/invItems`);
const at = (ms: number) => Timestamp.fromMillis(ms);
const item = (name: string, code: string, categoryId = 'c1') => ({ name, code, categoryId, status: 'active', stockUnit: 'pcs', tracking: 'qty', extra: 'x' });
const staff = (uid = 'u_1', sid: number | string = 12) => ({ uid, token: { sid, pt: 'staff' } });
const search = (data: Record<string, unknown>, auth: Parameters<typeof runQuery>[1] | null = staff()) =>
  runQuery(itemSearch, auth ?? undefined, data) as ReturnType<typeof itemSearch.handler>;

describe('item search mirror', () => {
  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SID}/userAccess/u_1`).set({ perms: ['inv.items.view'], cmp: [], all: true });
    await db().doc(`schools/${SID}/userAccess/u_2`).set({ perms: ['inv.stock.view'], cmp: [], all: true });
  });

  it('mirrors only the projection, updates it, and deletes it', async () => {
    await applyItemChange(SID, 'i1', item('Blue Pen', 'PEN-01'), at(1));
    expect((await mirror().doc('i1').get()).data()).toEqual({
      name: 'Blue Pen', code: 'PEN-01', categoryId: 'c1', status: 'active', stockUnit: 'pcs', tracking: 'qty', srcUpdatedAt: at(1),
    });
    await applyItemChange(SID, 'i1', item('Blue Pen XL', 'PEN-01'), at(2));
    expect((await mirror().doc('i1').get()).data()?.name).toBe('Blue Pen XL');
    await applyItemChange(SID, 'i1', undefined);
    expect((await mirror().doc('i1').get()).exists).toBe(false);
  });

  it('ignores an older delivery', async () => {
    await applyItemChange(SID, 'i1', item('New name', 'A'), at(5));
    await applyItemChange(SID, 'i1', item('Old name', 'A'), at(3));
    expect((await mirror().doc('i1').get()).data()?.name).toBe('New name');
  });

  it('matches whole words of name or code, all terms required', () => {
    expect(matchesAll(['blue', 'pen'], item('Blue Pen', 'PEN-01'))).toBe(true);
    expect(matchesAll(['blu'], item('Blue Pen', 'PEN-01'))).toBe(false);
    expect(matchesAll(['01'], item('Blue Pen', 'PEN-01'))).toBe(true);
  });

  describe('callable', () => {
    beforeEach(async () => {
      await applyItemChange(SID, 'i1', item('Blue Pen', 'PEN-01'), at(1));
      await applyItemChange(SID, 'i2', item('Blue Marker', 'MRK-01', 'c2'), at(1));
      await applyItemChange(SID, 'i3', item('Black Pen', 'PEN-02'), at(1));
      await applyItemChange('99', 'x1', item('Blue Other School', 'OS-1'), at(1));
    });

    it('finds items by word, only in the caller’s school, without internal fields', async () => {
      const res = await search({ q: 'Blue' });
      expect(res.items.map((i) => i.id)).toEqual(['i2', 'i1']); // sorted by name
      expect(res.items[0]).not.toHaveProperty('srcUpdatedAt');
      expect(res.items[0]).toMatchObject({ code: 'MRK-01', categoryId: 'c2' });
    });

    it('combines text with a category filter and pages with hasMore', async () => {
      expect((await search({ q: 'blue', categoryId: 'c1' })).items.map((i) => i.id)).toEqual(['i1']);
      const p1 = await search({ q: 'pen', limit: 1 });
      expect(p1).toMatchObject({ hasMore: true, items: [{ id: 'i3' }] });
      const p2 = await search({ q: 'pen', limit: 1, offset: 1 });
      expect(p2).toMatchObject({ hasMore: false, items: [{ id: 'i1' }] });
    });

    it('treats punctuation as separators, not search operators', async () => {
      expect((await search({ q: '"pen" -black *' })).items.map((i) => i.id)).toEqual(['i3']); // "-black" is the word black, not an exclusion
      await expect(search({ q: '- * "' })).rejects.toMatchObject({ code: 'invalid-argument' });
    });

    it('requires auth, a synced session and inv.items.view; rejects parents', async () => {
      await expect(search({ q: 'pen' }, null)).rejects.toMatchObject({ code: 'unauthenticated' });
      await expect(search({ q: 'pen' }, { uid: 'p_1', token: { sid: 12, pt: 'parent' } })).rejects.toMatchObject({ code: 'permission-denied' });
      await expect(search({ q: 'pen' }, staff('u_9'))).rejects.toMatchObject({ code: 'failed-precondition' });
      await expect(search({ q: 'pen' }, staff('u_2'))).rejects.toMatchObject({ code: 'permission-denied' });
    });
  });
});
