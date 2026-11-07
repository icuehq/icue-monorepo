import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/library/masters';
import { applyCatalogueChange, catalogueSearch } from '../src/library/search';
import { runCallable, runQuery, type CallableDef } from '../src/shared/callable';
import { seedLibraryCategory } from './fixtures';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
let requestSequence = 0;

const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(
    definition,
    { uid, token: { schoolId: 12, personType: 'staff' } },
    { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data },
  );
const get = async (path: string) => (await db().doc(`schools/${SCHOOL_ID}/${path}`).get()).data();
const count = async (collection: string) =>
  (await db().collection(`schools/${SCHOOL_ID}/${collection}`).get()).size;
const search = (data: Record<string, unknown>) =>
  runQuery(catalogueSearch, { uid: '1', token: { schoolId: 12, personType: 'staff' } }, data);

describe('library masters', () => {
  let category: string;
  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set({
        permissions: ['library.settings', 'library.catalogue'],
        campusIds: [31],
        hasAllCampuses: false,
      });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/2`)
      .set({ permissions: ['library.members.view'], campusIds: [31], hasAllCampuses: false });
    await run(masters.seedDefaults, {});
    category = (await seedLibraryCategory({ name: 'General' })).id;
  });

  const book = (extra: Record<string, unknown> = {}) =>
    run(masters.catalogueUpsert, {
      title: 'Wings of Fire',
      authors: ['A. P. J. Abdul Kalam'],
      categoryId: category,
      ...extra,
    });

  it('seeds the 14 default categories once', async () => {
    expect(await count('libraryCategories')).toBe(15);
    expect(await run(masters.seedDefaults, {})).toEqual({ categories: 0 });
  });

  it('requires permission', async () => {
    await expect(
      run(masters.catalogueUpsert, { title: 'X', authors: ['Y'], categoryId: category }, '2'),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('catalogue: creates and rejects duplicates', async () => {
    const { id } = await book();
    expect(await get(`libraryCatalogue/${id}`)).toMatchObject({
      status: 'active',
      coverPath: null,
    });
    await expect(book()).rejects.toMatchObject({ code: 'already-exists' });
  });

  it('catalogue: books dedupe on title, author, edition, publisher, year', async () => {
    await book({ edition: '2nd', year: 2001 });
    await expect(
      book({ title: 'wings  of fire!', edition: '2nd', year: 2001 }),
    ).rejects.toMatchObject({ code: 'already-exists' });
    await expect(book({ edition: '3rd', year: 2001 })).resolves.toHaveProperty('id');
  });

  it('catalogue: editing moves the identity key; inactive category rejected for new use', async () => {
    const { id } = await book();
    await book({ id, edition: '2nd' });
    await expect(book()).resolves.toHaveProperty('id'); // old key was released
    await db()
      .doc(`schools/${SCHOOL_ID}/libraryCategories/${category}`)
      .update({ status: 'inactive' });
    await expect(book({ title: 'Another' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(book({ id, edition: '3rd' })).resolves.toEqual({ id }); // existing title keeps its category
  });

  it('catalogue: needs an author; setStatus toggles', async () => {
    await expect(book({ authors: [] })).rejects.toMatchObject({ code: 'invalid-argument' });
    const { id } = await book();
    await run(masters.catalogueSetStatus, { id, status: 'inactive' });
    expect((await get(`libraryCatalogue/${id}`))?.status).toBe('inactive');
  });

  describe('search', () => {
    it('finds by title/author/publisher word; filters by category', async () => {
      const firstBook = await book({ publisher: 'Universities Press' });
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
        (await search({ q: 'kalam', categoryId: category })).items.map((item) => item.id),
      ).toEqual([firstBook.id]);
      await expect(search({ q: '- *' })).rejects.toMatchObject({ code: 'invalid-argument' });
    });
  });
});
