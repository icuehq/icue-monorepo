import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';
import { rebuildStats, recordStats } from '../src/library/stats';
import { dayTimestamp, todayIST } from '../src/shared/dates';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
const today = todayIST();
const read = async (name: string) =>
  (await db().doc(`${BRANCH}/libraryStats/${name}`).get()).data();
const loan = (over: Record<string, unknown> = {}) => ({
  libraryId: 'main',
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

describe('library analytics summary', () => {
  beforeEach(clearFirestore);

  it('issue, renew and return move the overall and the daily figures', async () => {
    await recordStats('libraryLoans', change(undefined, loan()));
    await recordStats('libraryLoans', change(loan(), loan({ renewals: [{}] })));
    await recordStats(
      'libraryLoans',
      change(loan({ renewals: [{}] }), loan({ status: 'returned', renewals: [{}] })),
    );
    expect(await read('overall')).toMatchObject({
      activeLoans: 0,
      libraries: { main: { activeLoans: 0 } },
    });
    expect(await read(`day_${today}`)).toMatchObject({
      loansIssued: 1,
      loansRenewed: 1,
      loansReturned: 1,
      libraries: { main: { loansIssued: 1 } },
    });
  });

  it('a returned overdue loan leaves the overdue figure; fines track what is still owed', async () => {
    const late = loan({ dueDate: dayTimestamp('2000-01-01') });
    await recordStats('libraryLoans', change(undefined, late));
    expect((await read('overall'))?.overdue).toBe(1);
    await recordStats('libraryLoans', change(late, { ...late, status: 'returned' }));
    expect((await read('overall'))?.overdue).toBe(0);

    const fine = { libraryId: 'main', status: 'outstanding', amount: 50, outstanding: 50, paid: 0 };
    await recordStats('libraryFines', change(undefined, fine));
    await recordStats(
      'libraryFines',
      change(fine, { ...fine, status: 'partially_paid', outstanding: 30, paid: 20 }),
    );
    expect((await read('overall'))?.outstandingFines).toBe(30);
    expect(await read(`day_${today}`)).toMatchObject({ finesRaised: 50, finesCollected: 20 });
  });

  it('rebuild recounts from the data and fixes drift', async () => {
    const branch = db().doc(BRANCH);
    await branch.collection('libraries').doc('main').set({ name: 'Main' });
    await branch.collection('libraryCatalogue').doc('t1').set({ title: 'A' });
    await branch.collection('libraryMembers').doc('student_1').set({ memberType: 'student' });
    await branch
      .collection('libraryCopies')
      .doc('c1')
      .set({ libraryId: 'main', status: 'available' });
    await branch.collection('libraryCopies').doc('c2').set({ libraryId: 'main', status: 'issued' });
    await branch
      .collection('libraryLoans')
      .doc('l1')
      .set(loan({ dueDate: Timestamp.fromMillis(0) }));
    await branch
      .collection('libraryFines')
      .doc('f1')
      .set({ libraryId: 'main', status: 'outstanding', outstanding: 40 });
    await db().doc(`${BRANCH}/libraryStats/overall`).set({ copies: 99 });
    await rebuildStats(BRANCH);
    expect(await read('overall')).toMatchObject({
      copies: 2,
      available: 1,
      issued: 1,
      activeLoans: 1,
      overdue: 1,
      outstandingFines: 40,
      titles: 1,
      students: 1,
      teachers: 0,
      libraries: { main: { copies: 2, overdue: 1 } },
    });
  });
});
