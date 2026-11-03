import { beforeEach, describe, expect, it } from 'vitest';
import { cleanIsbn, isIsbn10, isIsbn13, toIsbn13 } from '../src/library/isbn';
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

describe('isbn', () => {
  it('validates check digits and converts ISBN-10 to ISBN-13', () => {
    expect(isIsbn10('080442957X')).toBe(true);
    expect(isIsbn10('0804429571')).toBe(false);
    expect(isIsbn13('9780306406157')).toBe(true);
    expect(isIsbn13('9780306406158')).toBe(false);
    expect(toIsbn13('0306406152')).toBe('9780306406157');
    expect(cleanIsbn('978-0-306 40615-7')).toBe('9780306406157');
  });
});

describe('library masters', () => {
  let category: string;
  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set({
        permissions: ['library.settings', 'library.catalogue.manage', 'library.catalogue.view'],
        campusIds: [31],
        hasAllCampuses: false,
      });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/2`)
      .set({ permissions: ['library.catalogue.view'], campusIds: [31], hasAllCampuses: false });
    await run(masters.seedDefaults, {});
    category = (await seedLibraryCategory({ code: 'GEN', name: 'General' })).id;
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

  it('catalogue: creates, derives the ISBN-13 identity, rejects duplicates', async () => {
    const { id } = await book({ isbn10: '0-306-40615-2' });
    expect(await get(`libraryCatalogue/${id}`)).toMatchObject({
      status: 'active',
      isbn10: '0306406152',
      isbn13: null,
      identityKey: 'isbn:9780306406157',
      coverPath: null,
    });
    // same book given by its ISBN-13 is the same title
    await expect(book({ title: 'Other title', isbn13: '978-0-306-40615-7' })).rejects.toMatchObject(
      { code: 'already-exists' },
    );
  });

  it('catalogue: ISBN must be valid and consistent', async () => {
    await expect(book({ isbn13: '9780306406158' })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    await expect(book({ isbn10: '0306406152', isbn13: '9780306406164' })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('catalogue: books without ISBN dedupe on title, author, edition, publisher, year', async () => {
    await book({ edition: '2nd', year: 2001 });
    await expect(
      book({ title: 'wings  of fire!', edition: '2nd', year: 2001 }),
    ).rejects.toMatchObject({ code: 'already-exists' });
    await expect(book({ edition: '3rd', year: 2001 })).resolves.toHaveProperty('id');
  });

  it('catalogue: editing moves the identity key; inactive category rejected for new use', async () => {
    const { id } = await book({ isbn13: '9780306406157' });
    await book({ id, isbn13: undefined, edition: '2nd' }); // dropped ISBN → falls back to bibliographic key
    expect(await get('uniqueKeys/libraryTitle_isbn%3A9780306406157')).toBeUndefined();
    await expect(book({ isbn13: '9780306406157' })).resolves.toHaveProperty('id'); // old key was released
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
    it('finds by title/author/publisher word and by ISBN; filters by category', async () => {
      const firstBook = await book({ isbn13: '9780306406157', publisher: 'Universities Press' });
      const secondBook = await book({
        title: 'Ignited Minds',
        authors: ['Abdul Kalam'],
        categoryId: (await seedLibraryCategory({ code: 'X', name: 'X' })).id,
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
      const byIsbn = await search({ q: '978-0-306-40615-7' });
      expect(byIsbn.items).toHaveLength(1);
      expect(byIsbn.items[0]).toMatchObject({ id: firstBook.id, title: 'Wings of Fire' });
      expect(byIsbn.items[0]).not.toHaveProperty('authorsText');
      await expect(search({ q: '- *' })).rejects.toMatchObject({ code: 'invalid-argument' });
    });
  });
});
