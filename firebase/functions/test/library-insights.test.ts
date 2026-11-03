import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { runDailyLibrary } from '../src/library/daily';
import { runLibraryImport } from '../src/library/import';
import { loans } from '../src/library/loans';
import { masters } from '../src/library/masters';
import { members } from '../src/library/members';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { dayTimestamp } from '../src/shared/dates';
import { seedLibrary, seedLibraryCategory } from './fixtures';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
let requestSequence = 0;
const auth = (uid = '1') => ({ uid, token: { schoolId: 12, personType: 'staff' } });

const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(definition, auth(uid), {
    requestId: `req-${String(++requestSequence).padStart(6, '0')}`,
    ...data,
  });
const imp = (type: string, rows: Record<string, string>[], uid = '1', importId = 'imp_000001') =>
  runLibraryImport(auth(uid), { importId, type, rows });
const outbox = async (): Promise<{ id: string; [field: string]: any }[]> =>
  (await db().collection(`schools/${SCHOOL_ID}/outbox`).get()).docs.map((outboxDocument) => ({
    id: outboxDocument.id,
    ...outboxDocument.data(),
  }));
const day = (offset: number) =>
  new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

describe('library notifications and import', () => {
  let mainLibrary: string, title: string;

  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set({
        permissions: [
          'library.settings',
          'library.catalogue.manage',
          'library.circulation.operate',
        ],
        campusIds: [31],
        hasAllCampuses: false,
      });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/none`)
      .set({ permissions: ['library.catalogue.view'], campusIds: [31], hasAllCampuses: false });
    const category = (await seedLibraryCategory({ code: 'GEN', name: 'General' })).id;
    title = (
      await run(masters.catalogueUpsert, {
        title: 'Wings of Fire',
        authors: ['Kalam'],
        categoryId: category,
      })
    ).id;
    mainLibrary = (await seedLibrary({ code: 'L1', name: 'Main', campusId: 31 })).id;
    await run(copies.acquisitionCreate, {
      type: 'donation',
      catalogueId: title,
      libraryId: mainLibrary,
      quantity: 1,
    });
    await run(members.policyUpsert, {
      libraryId: mainLibrary,
      memberCategory: 'primary',
      name: 'Primary',
      maxBooks: 2,
      loanDays: 7,
      maxRenewals: 1,
      fineType: 'per_day',
      fineAmount: 2,
      canReserve: true,
    });
    await run(members.memberUpsert, {
      memberType: 'student',
      personErpId: 501,
      memberCategory: 'primary',
      libraryIds: [mainLibrary],
      start: '2020-01-01',
      end: day(3),
    });
  });

  it("issue and return tell the member (the student's parents); an overdue return also reports the fine", async () => {
    const issued = await run(loans.loanIssue, { memberId: 'student_501', copyId: 'ACC-000001' });
    expect(
      (await outbox()).find((outboxEvent) => outboxEvent.id === `library-issued__${issued.id}`),
    ).toMatchObject({ to: { wardStudentIds: [501] }, title: 'Book issued' });
    await db()
      .doc(`schools/${SCHOOL_ID}/libraryLoans/${issued.id}`)
      .update({ dueDate: dayTimestamp(day(-3)) });
    await run(loans.loanReturn, { id: issued.id, condition: 'damaged' });
    const ids = (await outbox()).map((outboxEvent) => outboxEvent.id);
    expect(ids).toEqual(
      expect.arrayContaining([
        `library-returned__${issued.id}`,
        `library-fine__${issued.id}__overdue`,
      ]),
    );
    const incident = (await outbox()).find((outboxEvent) =>
      outboxEvent.id.startsWith('library-incident__'),
    )!;
    expect(incident.to).toMatchObject({
      wardStudentIds: [501],
      permission: 'library.circulation.operate',
      campusId: 31,
    });
  });

  it('daily job: due soon, overdue, membership ending; reruns post nothing new', async () => {
    const first = await run(loans.loanIssue, { memberId: 'student_501', copyId: 'ACC-000001' }); // due in 7 days
    await runDailyLibrary(SCHOOL_ID);
    let ids = (await outbox()).map((outboxEvent) => outboxEvent.id);
    expect(ids).not.toContain(`library-due-soon__${first.id}`);
    expect(ids).toContain(`library-member-expiring__student_501__${day(3)}`);
    await db()
      .doc(`schools/${SCHOOL_ID}/libraryLoans/${first.id}`)
      .update({ dueDate: dayTimestamp(day(1)) });
    await runDailyLibrary(SCHOOL_ID);
    expect((await outbox()).map((outboxEvent) => outboxEvent.id)).toContain(
      `library-due-soon__${first.id}`,
    );
    await db()
      .doc(`schools/${SCHOOL_ID}/libraryLoans/${first.id}`)
      .update({ dueDate: dayTimestamp(day(-1)) });
    await runDailyLibrary(SCHOOL_ID);
    ids = (await outbox()).map((outboxEvent) => outboxEvent.id);
    expect(ids).toContain(`library-overdue__${first.id}__${day(0)}`);
    const before = ids.length;
    await runDailyLibrary(SCHOOL_ID);
    expect((await outbox()).length).toBe(before);
  });

  it('imports catalogue, copies and members through the single-record rules; bad rows and duplicates are reported', async () => {
    const books = await imp('catalogue', [
      {
        title: 'Malgudi Days',
        authors: 'R. K. Narayan',
        categoryCode: 'gen',
        isbn13: '9780143039648',
        year: '2006',
      },
      {
        title: 'Malgudi Days',
        authors: 'R. K. Narayan',
        categoryCode: 'gen',
        isbn13: '9780143039648',
      },
      { title: 'No category', authors: 'X', categoryCode: 'nope' },
    ]);
    expect(books.results.map((result) => result.ok)).toEqual([true, false, false]);
    expect(books.results[1].error).toMatch(/already exists/);
    expect(
      (
        await imp(
          'catalogue',
          [
            {
              title: 'Malgudi Days',
              authors: 'R. K. Narayan',
              categoryCode: 'gen',
              isbn13: '9780143039648',
            },
          ],
          '1',
          'imp_000009',
        )
      ).created,
    ).toBe(0); // new import ID: rejected as duplicate
    const cps = await imp(
      'copies',
      [
        { isbn13: '978-0-14-303964-8', libraryCode: 'L1', quantity: '3', price: '250' },
        { isbn13: '9780000000002', libraryCode: 'L1' },
      ],
      '1',
      'imp_000002',
    );
    expect(cps.results.map((result) => result.ok)).toEqual([true, false]);
    expect((await db().collection(`schools/${SCHOOL_ID}/libraryCopies`).get()).size).toBe(4); // 1 from setup + 3 imported
    const member = await imp(
      'members',
      [
        {
          memberType: 'student',
          personErpId: '777',
          memberCategory: 'primary',
          libraryCodes: 'L1',
          start: '2025-04-01',
        },
      ],
      '1',
      'imp_000003',
    );
    expect(member.created).toBe(1);
    expect((await db().doc(`schools/${SCHOOL_ID}/libraryMembers/student_777`).get()).exists).toBe(
      true,
    );
    await expect(
      imp(
        'members',
        [
          {
            memberType: 'student',
            personErpId: '778',
            memberCategory: 'primary',
            libraryCodes: 'L1',
            start: '2025-04-01',
          },
        ],
        'none',
        'imp_000004',
      ),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
