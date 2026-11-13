import { beforeEach, describe, expect, it } from 'vitest';
import { recordStats } from '../src/library/stats';
import { dayTimestamp, todayIST } from '../src/shared/dates';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
const today = todayIST();
const read = async (name: string) =>
  (await db().doc(`${BRANCH}/libraryStats/${name}`).get()).data();
const loan = (over: Record<string, unknown> = {}) => ({
  libraryId: 'main',
  personErpId: 7,
  status: 'active',
  dueDate: dayTimestamp('2999-01-01'),
  renewals: [],
  ...over,
});
const change = (before?: object, after?: object) => ({
  branchPath: BRANCH,
  docId: 'x',
  before,
  after,
});
const record = (collection: string, before?: object, after?: object) =>
  recordStats(collection, change(before, after));

describe('library analytics summary', () => {
  beforeEach(clearFirestore);

  it('issue, renew and return move the overall and the daily figures', async () => {
    const renewed = loan({ renewals: [{}], dueDate: dayTimestamp('2999-02-01') });
    await record('libraryLoans', undefined, loan());
    await record('libraryLoans', loan(), renewed);
    expect((await read('overall'))?.libraries.main.dueOn).toEqual({
      '2999-01-01': 0,
      '2999-02-01': 1,
    });
    await record('libraryLoans', renewed, { ...renewed, status: 'returned' });
    expect(await read('overall')).toMatchObject({
      activeLoans: 0,
      dueOn: { '2999-02-01': 0 },
      libraries: { main: { activeLoans: 0 } },
    });
    expect(await read(`day_${today}`)).toMatchObject({
      loansIssued: 1,
      loansRenewed: 1,
      loansReturned: 1,
      libraries: { main: { loansIssued: 1 } },
    });
  });

  it('fines track what is still owed', async () => {
    const fine = { libraryId: 'main', status: 'outstanding', amount: 50, outstanding: 50, paid: 0 };
    await record('libraryFines', undefined, fine);
    await record('libraryFines', fine, {
      ...fine,
      status: 'partially_paid',
      outstanding: 30,
      paid: 20,
    });
    expect((await read('overall'))?.libraries.main.outstandingFines).toBe(30);
    expect(await read(`day_${today}`)).toMatchObject({ finesRaised: 50, finesCollected: 20 });
  });

  it('each day counts lost and damaged books apart', async () => {
    const incident = (type: string) => ({ type, libraryId: 'main' });
    await record('libraryIncidents', undefined, incident('lost'));
    await record('libraryIncidents', undefined, incident('damaged'));
    await record('libraryIncidents', undefined, incident('damaged'));
    expect(await read(`day_${today}`)).toMatchObject({
      booksLost: 1,
      booksDamaged: 2,
      libraries: { main: { booksLost: 1, booksDamaged: 2 } },
    });
  });

  it('every copy status lands in one figure that adds up to copies', async () => {
    for (const status of ['available', 'issued', 'withdrawn', 'under_maintenance'])
      await record('libraryCopies', undefined, { libraryId: 'main', catalogueId: 'c', status });
    expect(await read('overall')).toMatchObject({
      copies: 4,
      available: 1,
      issued: 1,
      outOfCirculation: 2,
    });
  });

  it('a library counts a title while it holds a copy of it', async () => {
    await db().doc(`${BRANCH}/libraryCatalogue/t1`).set({ title: 'A' });
    const copy = (libraryId: string) => ({ catalogueId: 't1', libraryId, status: 'available' });
    await record('libraryCopies', undefined, copy('main'));
    await record('libraryCopies', undefined, copy('main'));
    await record('libraryCopies', copy('main'), copy('annex'));
    expect((await read('overall'))?.libraries).toMatchObject({
      main: { titles: 1, copies: 1 },
      annex: { titles: 1, copies: 1 },
    });
    await record('libraryCopies', copy('main'), undefined);
    expect((await read('overall'))?.libraries.main.titles).toBe(0);
    expect((await db().doc(`${BRANCH}/libraryCatalogue/t1`).get()).data()?.holdings).toEqual({
      main: 0,
      annex: 1,
    });
  });

  it('a member counts as a borrower of each library once', async () => {
    await db().doc(`${BRANCH}/libraryMembers/7`).set({ memberType: 'student' });
    await record('libraryLoans', undefined, loan());
    await record('libraryLoans', undefined, loan());
    await record('libraryLoans', undefined, loan({ libraryId: 'annex' }));
    expect((await read('overall'))?.libraries).toMatchObject({
      main: { students: 1 },
      annex: { students: 1 },
    });
  });

  it('a branch-only write leaves every library figure alone', async () => {
    await record('libraryLoans', undefined, loan());
    await record('libraryCatalogue', undefined, { title: 'B' });
    await record('libraryMembers', undefined, { memberType: 'teacher' });
    expect(await read('overall')).toMatchObject({
      titles: 1,
      teachers: 1,
      libraries: { main: { activeLoans: 1 } },
    });
  });
});
