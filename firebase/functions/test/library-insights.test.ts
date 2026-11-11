import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { runDailyLibrary } from '../src/library/daily';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { dayTimestamp } from '../src/shared/dates';
import { loans } from './circulation';
import {
  seedLibrary,
  seedLibraryCategory,
  seedLibraryPolicy,
  seedLibraryTitle,
  person,
} from './fixtures';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
let requestSequence = 0;
const auth = (uid = '1') => ({ uid, token: { orgId: 8, zoneId: 147, branchId: 427, personType: 'staff' } });

const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(definition, auth(uid), {
    requestId: `req-${String(++requestSequence).padStart(6, '0')}`,
    ...data,
  });
const outbox = async (): Promise<{ id: string; [field: string]: any }[]> =>
  (await db().collection(`${BRANCH}/outbox`).get()).docs.map((outboxDocument) => ({
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
      .doc(`${BRANCH}/userAccess/1`)
      .set({
        permissions: [],
      });
    const category = (await seedLibraryCategory({ name: 'General' })).id;
    title = (
      await seedLibraryTitle({
        title: 'Wings of Fire',
        authors: ['Kalam'],
        categoryId: category,
      })
    ).id;
    mainLibrary = (await seedLibrary({ name: 'Main' })).id;
    await run(copies.createBook, {
      catalogueId: title,
      libraryId: mainLibrary,
      quantity: 1,
      barcodes: ['ACC-000001'],
    });
    await seedLibraryPolicy({
      libraryId: mainLibrary,
      memberType: 'student',
      name: 'Primary',
      maxBooks: 2,
      loanDays: 7,
      maxRenewals: 1,
      fineType: 'per_day',
      fineAmount: 2,
    });
  });

  it("issue and return tell the member (the student's parents); an overdue return also reports the fine", async () => {
    const issued = await run(loans.loanIssue, {
      person: person(501),
      barcode: 'ACC-000001',
    });
    expect(
      (await outbox()).find((outboxEvent) => outboxEvent.id === `library-issued__${issued.id}`),
    ).toMatchObject({ to: { wardStudentIds: [501] }, title: 'Book issued' });
    await db()
      .doc(`${BRANCH}/libraryLoans/${issued.id}`)
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
    });
  });

  it('daily job: due soon and overdue, no membership notices; reruns post nothing new', async () => {
    const first = await run(loans.loanIssue, {
      person: person(501),
      barcode: 'ACC-000001',
    }); // due in 7 days
    await runDailyLibrary(BRANCH);
    let ids = (await outbox()).map((outboxEvent) => outboxEvent.id);
    expect(ids).not.toContain(`library-due-soon__${first.id}`);
    expect(ids.some((id) => id.startsWith('library-member-expiring'))).toBe(false);
    await db()
      .doc(`${BRANCH}/libraryLoans/${first.id}`)
      .update({ dueDate: dayTimestamp(day(1)) });
    await runDailyLibrary(BRANCH);
    expect((await outbox()).map((outboxEvent) => outboxEvent.id)).toContain(
      `library-due-soon__${first.id}`,
    );
    await db()
      .doc(`${BRANCH}/libraryLoans/${first.id}`)
      .update({ dueDate: dayTimestamp(day(-1)) });
    await runDailyLibrary(BRANCH);
    ids = (await outbox()).map((outboxEvent) => outboxEvent.id);
    expect(ids).toContain(`library-overdue__${first.id}__${day(0)}`);
    const before = ids.length;
    await runDailyLibrary(BRANCH);
    expect((await outbox()).length).toBe(before);
  });
});
