import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';
import {
  applyCatalogueChange,
  applyLoanChange,
  catalogueSearch,
  loanSearch,
} from '../src/library/search';
import { runQuery } from '../src/shared/callable';
import { seedLibraryCategory, seedLibraryTitle } from './fixtures';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';

const get = async (path: string) => (await db().doc(`${BRANCH}/${path}`).get()).data();
const search = (data: Record<string, unknown>) =>
  runQuery(
    catalogueSearch,
    { uid: '1', token: { orgId: 8, zoneId: 147, branchId: 427, personType: 'staff' } },
    data,
  );

describe('library masters', () => {
  let category: string;
  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`${BRANCH}/userAccess/1`).set({
      permissions: [],
    });
    category = (await seedLibraryCategory({ name: 'General' })).id;
  });

  const book = (extra: Record<string, unknown> = {}) =>
    seedLibraryTitle({
      title: 'Wings of Fire',
      authors: ['A. P. J. Abdul Kalam'],
      categoryId: category,
      ...extra,
    });

  describe('search', () => {
    it('finds by title/author/publisher word; filters by category', async () => {
      const firstBook = await book({ publisher: 'Universities Press', classIds: [8] });
      const secondBook = await book({
        title: 'Ignited Minds',
        authors: ['Abdul Kalam'],
        categoryId: (await seedLibraryCategory({ name: 'X' })).id,
      });
      for (const catalogueBook of [firstBook, secondBook])
        await applyCatalogueChange(
          BRANCH,
          catalogueBook.id,
          await get(`libraryCatalogue/${catalogueBook.id}`),
        );
      expect((await search({ q: 'kalam' })).items.map((item) => item.id).sort()).toEqual(
        [firstBook.id, secondBook.id].sort(),
      );
      expect((await search({ q: 'universities' })).items.map((item) => item.id)).toEqual([
        firstBook.id,
      ]);
      expect(
        (await search({ q: 'kalam', categoryIds: [category] })).items.map((item) => item.id),
      ).toEqual([firstBook.id]);
      expect((await search({ q: 'kalam', classId: 8 })).items.map((item) => item.id)).toEqual([
        firstBook.id,
      ]);
      expect(
        (await search({ q: 'kalam', status: 'active' })).items.map((item) => item.id).sort(),
      ).toEqual([firstBook.id, secondBook.id].sort());
      expect((await search({ q: 'kalam', status: 'inactive' })).items).toEqual([]);
      await expect(search({ q: '- *' })).rejects.toMatchObject({ code: 'invalid-argument' });
    });
  });

  describe('loan search', () => {
    it('finds active loans by book title, member name or admission number, earliest due first', async () => {
      const loan = (
        bookTitle: string,
        memberName: string,
        admissionNumber: string | null,
        due: number,
        status = 'active',
      ) => ({
        bookTitle,
        memberName,
        admissionNumber,
        status,
        dueDate: Timestamp.fromMillis(due),
        barcode: 'ACC1',
        number: 'LIS1',
      });
      await applyLoanChange(BRANCH, 'late', loan('Wings of Fire', 'Ravi Kumar', 'ADM/24/7', 2_000));
      await applyLoanChange(BRANCH, 'early', loan('Ignited Minds', 'Asha Rao', null, 1_000));
      await applyLoanChange(
        BRANCH,
        'returned',
        loan('Wings of Fire', 'Asha Rao', null, 500, 'returned'),
      );
      const ids = async (q: string) =>
        (
          await runQuery(
            loanSearch,
            { uid: '1', token: { orgId: 8, zoneId: 147, branchId: 427, personType: 'staff' } },
            { q },
          )
        ).items.map((item) => item.id);
      expect(await ids('wings')).toEqual(['late']);
      expect(await ids('asha')).toEqual(['early']);
      expect(await ids('ADM/24/7')).toEqual(['late']);
      expect(await ids('LIS1')).toEqual([]);
    });
  });
});
