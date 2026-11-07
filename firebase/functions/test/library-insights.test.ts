import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { runDailyLibrary } from '../src/library/daily';
import { loans } from '../src/library/loans';
import { masters } from '../src/library/masters';
import { members } from '../src/library/members';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { dayTimestamp } from '../src/shared/dates';
import { seedLibrary, seedLibraryCategory, person } from './fixtures';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
let requestSequence = 0;
const auth = (uid = '1') => ({ uid, token: { schoolId: 12, personType: 'staff' } });

const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(definition, auth(uid), {
    requestId: `req-${String(++requestSequence).padStart(6, '0')}`,
    ...data,
  });
const outbox = async (): Promise<{ id: string; [field: string]: any }[]> =>
  (await db().collection(`schools/${SCHOOL_ID}/outbox`).get()).docs.map((outboxDocument) => ({
    id: outboxDocument.id,
    ...outboxDocument.data(),
  }));
const day = (offset: number) =>
  new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

describe('library notifications', () => {
  let mainLibrary: string, title: string;

  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set({
        permissions: [
          'library.settings',
          'library.catalogue',
          'library.circulation.operate',
        ],
        campusIds: [31],
        hasAllCampuses: false,
      });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/none`)
      .set({ permissions: ['library.catalogue'], campusIds: [31], hasAllCampuses: false });
    const category = (await seedLibraryCategory({ name: 'General' })).id;
    title = (
      await run(masters.catalogueUpsert, {
        title: 'Wings of Fire',
        authors: ['Kalam'],
        categoryId: category,
      })
    ).id;
    mainLibrary = (await seedLibrary({ name: 'Main', campusId: 31 })).id;
    await run(copies.acquisitionCreate, {
      catalogueId: title,
      libraryId: mainLibrary,
      quantity: 1,
    });
    await run(members.policyUpsert, {
      libraryId: mainLibrary,
      memberType: 'student',
      name: 'Primary',
      maxBooks: 2,
      loanDays: 7,
      maxRenewals: 1,
      fineType: 'per_day',
      fineAmount: 2,
      canReserve: true,
    });
  });

  it("issue and return tell the member (the student's parents); an overdue return also reports the fine", async () => {
    const issued = await run(loans.loanIssue, { person: person('student_501'), copyId: 'ACC-000001' });
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

  it('daily job: due soon and overdue, no membership notices; reruns post nothing new', async () => {
    const first = await run(loans.loanIssue, { person: person('student_501'), copyId: 'ACC-000001' }); // due in 7 days
    await runDailyLibrary(SCHOOL_ID);
    let ids = (await outbox()).map((outboxEvent) => outboxEvent.id);
    expect(ids).not.toContain(`library-due-soon__${first.id}`);
    expect(ids.some((id) => id.startsWith('library-member-expiring'))).toBe(false);
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
});
