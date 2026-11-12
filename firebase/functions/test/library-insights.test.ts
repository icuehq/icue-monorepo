import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';
import { runDailyLibrary } from '../src/library/daily';
import { noticeLoan } from '../src/library/notices';
import { dayTimestamp } from '../src/shared/dates';
import { seedLibraryCategory, seedLibraryTitle } from './fixtures';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
const outbox = async (): Promise<{ id: string; [field: string]: any }[]> =>
  (await db().collection(`${BRANCH}/outbox`).get()).docs.map((outboxDocument) => ({
    id: outboxDocument.id,
    ...outboxDocument.data(),
  }));
const day = (offset: number) =>
  new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);
const loan = (catalogueId: string, dueOffset: number, status = 'active') => ({
  memberType: 'student',
  personErpId: 501,
  barcode: 'ACC-000001',
  catalogueId,
  status,
  dueDate: dayTimestamp(day(dueOffset)),
  issuedDate: Timestamp.now(),
});

describe('library notifications', () => {
  let title: string;

  beforeEach(async () => {
    await clearFirestore();
    const category = (await seedLibraryCategory({ name: 'General' })).id;
    title = (await seedLibraryTitle({ title: 'Wings of Fire', authors: ['Kalam'], categoryId: category })).id;
  });

  it("issue and return tell the member (the student's parents)", async () => {
    const issued = loan(title, 7);
    await noticeLoan({ branchPath: BRANCH, docId: 'l1', after: issued });
    expect((await outbox()).find((event) => event.id === 'library-issued__l1')).toMatchObject({
      to: { wardStudentIds: [501] },
      title: 'Book issued',
    });
    await noticeLoan({
      branchPath: BRANCH,
      docId: 'l1',
      before: issued,
      after: { ...issued, status: 'returned', overdueDays: 3 },
    });
    expect((await outbox()).map((event) => event.id)).toContain('library-returned__l1');
  });

  it('daily job: due soon and overdue; reruns post nothing new', async () => {
    const loans = db().collection(`${BRANCH}/libraryLoans`);
    await loans.doc('l1').set(loan(title, 7));
    await runDailyLibrary(BRANCH);
    expect((await outbox()).map((event) => event.id)).not.toContain('library-due-soon__l1');
    await loans.doc('l1').update({ dueDate: dayTimestamp(day(1)) });
    await runDailyLibrary(BRANCH);
    expect((await outbox()).map((event) => event.id)).toContain('library-due-soon__l1');
    await loans.doc('l1').update({ dueDate: dayTimestamp(day(-1)) });
    await runDailyLibrary(BRANCH);
    const ids = (await outbox()).map((event) => event.id);
    expect(ids).toContain(`library-overdue__l1__${day(0)}`);
    await runDailyLibrary(BRANCH);
    expect((await outbox()).length).toBe(ids.length);
  });
});
