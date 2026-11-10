import { beforeEach, describe, expect, it } from 'vitest';
import { applyCatalogueChange, catalogueSearch } from '../src/library/search';
import { runQuery } from '../src/shared/callable';
import { seedLibraryCategory, seedLibraryTitle } from './fixtures';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';

const get = async (path: string) => (await db().doc(`schools/${SCHOOL_ID}/${path}`).get()).data();
const search = (data: Record<string, unknown>) =>
  runQuery(catalogueSearch, { uid: '1', token: { schoolId: 12, personType: 'staff' } }, data);

describe('library masters', () => {
  let category: string;
  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set({
        permissions: [],
        campusIds: [31],
        hasAllCampuses: false,
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
          SCHOOL_ID,
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
      await expect(search({ q: '- *' })).rejects.toMatchObject({ code: 'invalid-argument' });
    });
  });
});
