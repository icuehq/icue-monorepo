import { beforeEach, describe, expect, it } from 'vitest';
import { cleanIsbn, isIsbn10, isIsbn13, toIsbn13 } from '../src/library/isbn';
import { masters } from '../src/library/masters';
import { applyCatalogueChange, catalogueSearch } from '../src/library/search';
import { runCallable, runQuery, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
let n = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_1') =>
  runCallable(d, { uid, token: { sid: 12, pt: 'staff' } }, { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SID}/${path}`).get()).data();
const count = async (coll: string) => (await db().collection(`schools/${SID}/${coll}`).get()).size;
const search = (data: Record<string, unknown>) => runQuery(catalogueSearch, { uid: 'u_1', token: { sid: 12, pt: 'staff' } }, data);

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
  let cat: string;
  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SID}/userAccess/u_1`).set({ perms: ['lib.settings', 'lib.catalogue.manage', 'lib.catalogue.view'], cmp: [31], all: false });
    await db().doc(`schools/${SID}/userAccess/u_2`).set({ perms: ['lib.catalogue.view'], cmp: [31], all: false });
    await run(masters.seedDefaults, {});
    cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General' })).id;
  });

  const book = (extra: Record<string, unknown> = {}) =>
    run(masters.catalogueUpsert, { title: 'Wings of Fire', authors: ['A. P. J. Abdul Kalam'], categoryId: cat, ...extra });

  it('seeds the 14 default categories once', async () => {
    expect(await count('libCategories')).toBe(15);
    expect(await run(masters.seedDefaults, {})).toEqual({ categories: 0 });
  });

  it('requires permission', async () => {
    await expect(run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 31 }, 'u_2')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(run(masters.catalogueUpsert, { title: 'X', authors: ['Y'], categoryId: cat }, 'u_2')).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('libraries: unique code, campus scope, campus fixed, staff de-duplicated', async () => {
    await expect(run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 99 })).rejects.toMatchObject({ code: 'permission-denied' });
    const { id } = await run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 31, staffIds: [5, 5, 6] });
    expect((await get(`libLibraries/${id}`))?.staffIds).toEqual([5, 6]);
    await expect(run(masters.libraryUpsert, { code: 'l1', name: 'Dup', campusId: 31 })).rejects.toMatchObject({ code: 'already-exists' });
    await db().doc(`schools/${SID}/userAccess/u_1`).update({ cmp: [31, 32] });
    await expect(run(masters.libraryUpsert, { id, name: 'Main', campusId: 32 })).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(masters.librarySetStatus, { id, status: 'inactive' });
    expect((await get(`libLibraries/${id}`))?.status).toBe('inactive');
  });

  it('categories: one level only, unique codes', async () => {
    const sub = await run(masters.categoryUpsert, { code: 'SUB', name: 'Sub', parentId: cat });
    await expect(run(masters.categoryUpsert, { code: 'SS', name: 'SubSub', parentId: sub.id })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(run(masters.categoryUpsert, { code: 'gen', name: 'Dup' })).rejects.toMatchObject({ code: 'already-exists' });
  });

  it('catalogue: creates, derives the ISBN-13 identity, rejects duplicates', async () => {
    const { id } = await book({ isbn10: '0-306-40615-2' });
    expect(await get(`libCatalogue/${id}`)).toMatchObject({ status: 'active', isbn10: '0306406152', isbn13: null, dupKey: 'isbn:9780306406157', coverPath: null });
    // same book given by its ISBN-13 is the same title
    await expect(book({ title: 'Other title', isbn13: '978-0-306-40615-7' })).rejects.toMatchObject({ code: 'already-exists' });
  });

  it('catalogue: ISBN must be valid and consistent', async () => {
    await expect(book({ isbn13: '9780306406158' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(book({ isbn10: '0306406152', isbn13: '9780306406164' })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('catalogue: books without ISBN dedupe on title, author, edition, publisher, year', async () => {
    await book({ edition: '2nd', year: 2001 });
    await expect(book({ title: 'wings  of fire!', edition: '2nd', year: 2001 })).rejects.toMatchObject({ code: 'already-exists' });
    await expect(book({ edition: '3rd', year: 2001 })).resolves.toHaveProperty('id');
  });

  it('catalogue: editing moves the identity key; inactive category rejected for new use', async () => {
    const { id } = await book({ isbn13: '9780306406157' });
    await book({ id, isbn13: undefined, edition: '2nd' }); // dropped ISBN → falls back to bibliographic key
    expect(await get('uniqueKeys/libTitle_isbn%3A9780306406157')).toBeUndefined();
    await expect(book({ isbn13: '9780306406157' })).resolves.toHaveProperty('id'); // old key was released
    await run(masters.categorySetStatus, { id: cat, status: 'inactive' });
    await expect(book({ title: 'Another' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(book({ id, edition: '3rd' })).resolves.toEqual({ id }); // existing title keeps its category
  });

  it('catalogue: needs an author; setStatus toggles', async () => {
    await expect(book({ authors: [] })).rejects.toMatchObject({ code: 'invalid-argument' });
    const { id } = await book();
    await run(masters.catalogueSetStatus, { id, status: 'inactive' });
    expect((await get(`libCatalogue/${id}`))?.status).toBe('inactive');
  });

  describe('search', () => {
    it('finds by title/author/publisher word and by ISBN; filters by category', async () => {
      const a = await book({ isbn13: '9780306406157', publisher: 'Universities Press' });
      const b = await book({ title: 'Ignited Minds', authors: ['Abdul Kalam'], categoryId: (await run(masters.categoryUpsert, { code: 'X', name: 'X' })).id });
      for (const r of [a, b]) await applyCatalogueChange(SID, r.id, await get(`libCatalogue/${r.id}`));
      expect((await search({ q: 'kalam' })).items.map((r) => r.id).sort()).toEqual([a.id, b.id].sort());
      expect((await search({ q: 'universities' })).items.map((r) => r.id)).toEqual([a.id]);
      expect((await search({ q: 'kalam', categoryId: cat })).items.map((r) => r.id)).toEqual([a.id]);
      const byIsbn = await search({ q: '978-0-306-40615-7' });
      expect(byIsbn.items).toHaveLength(1);
      expect(byIsbn.items[0]).toMatchObject({ id: a.id, title: 'Wings of Fire' });
      expect(byIsbn.items[0]).not.toHaveProperty('authorsText');
      await expect(search({ q: '- *' })).rejects.toMatchObject({ code: 'invalid-argument' });
    });
  });
});
