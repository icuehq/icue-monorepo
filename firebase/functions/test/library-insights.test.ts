import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { runDailyLibrary } from '../src/library/daily';
import { runLibraryImport } from '../src/library/import';
import { loans } from '../src/library/loans';
import { masters } from '../src/library/masters';
import { members } from '../src/library/members';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
let n = 0;
const auth = (uid = 'u_1') => ({ uid, token: { sid: 12, pt: 'staff' } });
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_1') =>
  runCallable(d, auth(uid), { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const imp = (type: string, rows: Record<string, string>[], uid = 'u_1', importId = 'imp_000001') =>
  runLibraryImport(auth(uid), { importId, type, rows });
const outbox = async () => (await db().collection(`schools/${SID}/outbox`).get()).docs.map((d) => ({ id: d.id, ...d.data() }));
const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

describe('library notifications and import', () => {
  let l1: string, title: string;

  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SID}/userAccess/u_1`).set({ perms: ['lib.settings', 'lib.catalogue.manage', 'lib.circulation.operate'], cmp: [31], all: false });
    await db().doc(`schools/${SID}/userAccess/u_none`).set({ perms: ['lib.catalogue.view'], cmp: [31], all: false });
    const cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General' })).id;
    title = (await run(masters.catalogueUpsert, { title: 'Wings of Fire', authors: ['Kalam'], categoryId: cat })).id;
    l1 = (await run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 31 })).id;
    await run(copies.acquisitionCreate, { type: 'donation', catalogueId: title, libraryId: l1, qty: 1 });
    await run(members.policyUpsert, { libraryId: l1, memberCategory: 'primary', name: 'Primary', maxBooks: 2, loanDays: 7, maxRenewals: 1, fineType: 'per_day', fineAmount: 2, canReserve: true });
    await run(members.memberUpsert, { memberType: 'student', erpId: 501, memberCategory: 'primary', libraryIds: [l1], start: '2020-01-01', end: day(3) });
  });

  it('issue and return tell the member (the student\'s parents); an overdue return also reports the fine', async () => {
    const issued = await run(loans.loanIssue, { memberId: 'student_501', copyId: 'ACC-000001' });
    expect((await outbox()).find((o) => o.id === `lib-issued__${issued.id}`)).toMatchObject({ to: { wards: [501] }, title: 'Book issued' });
    await db().doc(`schools/${SID}/libLoans/${issued.id}`).update({ dueOn: day(-3) });
    await run(loans.loanReturn, { id: issued.id, condition: 'damaged' });
    const ids = (await outbox()).map((o) => o.id);
    expect(ids).toEqual(expect.arrayContaining([`lib-returned__${issued.id}`, `lib-fine__${issued.id}__overdue`]));
    const incident = (await outbox()).find((o) => o.id.startsWith('lib-incident__'))!;
    expect(incident.to).toMatchObject({ wards: [501], perm: 'lib.circulation.operate', campusId: 31 });
  });

  it('daily job: due soon, overdue, membership ending; reruns post nothing new', async () => {
    const a = await run(loans.loanIssue, { memberId: 'student_501', copyId: 'ACC-000001' }); // due in 7 days
    await runDailyLibrary(SID);
    let ids = (await outbox()).map((o) => o.id);
    expect(ids).not.toContain(`lib-due-soon__${a.id}`);
    expect(ids).toContain(`lib-member-expiring__student_501__${day(3)}`);
    await db().doc(`schools/${SID}/libLoans/${a.id}`).update({ dueOn: day(1) });
    await runDailyLibrary(SID);
    expect((await outbox()).map((o) => o.id)).toContain(`lib-due-soon__${a.id}`);
    await db().doc(`schools/${SID}/libLoans/${a.id}`).update({ dueOn: day(-1) });
    await runDailyLibrary(SID);
    ids = (await outbox()).map((o) => o.id);
    expect(ids).toContain(`lib-overdue__${a.id}__${day(0)}`);
    const before = ids.length;
    await runDailyLibrary(SID);
    expect((await outbox()).length).toBe(before);
  });

  it('imports catalogue, copies and members through the single-record rules; bad rows and duplicates are reported', async () => {
    const books = await imp('catalogue', [
      { title: 'Malgudi Days', authors: 'R. K. Narayan', categoryCode: 'gen', isbn13: '9780143039648', year: '2006' },
      { title: 'Malgudi Days', authors: 'R. K. Narayan', categoryCode: 'gen', isbn13: '9780143039648' },
      { title: 'No category', authors: 'X', categoryCode: 'nope' },
    ]);
    expect(books.results.map((r) => r.ok)).toEqual([true, false, false]);
    expect(books.results[1].error).toMatch(/already exists/);
    expect((await imp('catalogue', [{ title: 'Malgudi Days', authors: 'R. K. Narayan', categoryCode: 'gen', isbn13: '9780143039648' }], 'u_1', 'imp_000009')).created).toBe(0); // new import ID: rejected as duplicate
    const cps = await imp('copies', [{ isbn13: '978-0-14-303964-8', libraryCode: 'L1', qty: '3', price: '250' }, { isbn13: '9780000000002', libraryCode: 'L1' }], 'u_1', 'imp_000002');
    expect(cps.results.map((r) => r.ok)).toEqual([true, false]);
    expect((await db().collection(`schools/${SID}/libCopies`).get()).size).toBe(4); // 1 from setup + 3 imported
    const mem = await imp('members', [{ memberType: 'student', erpId: '777', memberCategory: 'primary', libraryCodes: 'L1', start: '2025-04-01' }], 'u_1', 'imp_000003');
    expect(mem.created).toBe(1);
    expect((await db().doc(`schools/${SID}/libMembers/student_777`).get()).exists).toBe(true);
    await expect(imp('members', [{ memberType: 'student', erpId: '778', memberCategory: 'primary', libraryCodes: 'L1', start: '2025-04-01' }], 'u_none', 'imp_000004')).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
