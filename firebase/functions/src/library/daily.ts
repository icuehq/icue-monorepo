import { getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { todayIST, addDays, dayTimestamp, timestampDay } from '../shared/dates';
import { schoolCollection } from '../shared/firestore';
import { post } from '../shared/outbox';
import { forEachBranch } from '../shared/scheduled';
import { memberTo } from './notify';

/** Daily library job (architecture §5.2): the FRS 11.17 date-driven notifications. Posting an existing key is a no-op, so reruns are safe. */

const DUE_SOON_DAYS = 2;

export async function runDailyLibrary(branchPath: string, today = todayIST()): Promise<void> {
  const db = getFirestore();
  const collection = (name: string) => schoolCollection(branchPath, name);

  const soon = await collection('libraryLoans')
    .where('status', '==', 'active')
    .where('dueDate', '>=', dayTimestamp(today))
    .where('dueDate', '<=', dayTimestamp(addDays(today, DUE_SOON_DAYS)))
    .get();
  for (const snapshot of soon.docs) {
    const loan = snapshot.data();
    await post(db, branchPath, `library-due-soon__${snapshot.id}`, {
      to: memberTo(loan.memberType, loan.personErpId),
      category: 'library.loan',
      title: 'Book due soon',
      body: `${loan.barcode} is due on ${timestampDay(loan.dueDate)}.`,
      data: { loanId: snapshot.id },
    });
  }

  const overdue = await collection('libraryLoans')
    .where('status', '==', 'active')
    .where('dueDate', '<', dayTimestamp(today))
    .get();
  for (const snapshot of overdue.docs) {
    const loan = snapshot.data();
    await post(db, branchPath, `library-overdue__${snapshot.id}__${today}`, {
      to: memberTo(loan.memberType, loan.personErpId),
      category: 'library.loan',
      title: 'Book overdue',
      body: `${loan.barcode} was due on ${timestampDay(loan.dueDate)}. Please return it.`,
      data: { loanId: snapshot.id },
    });
  }
}

/** 07:00 IST, every school. */
export const dailyLibrary = onSchedule(
  { schedule: '0 7 * * *', timeZone: 'Asia/Kolkata', timeoutSeconds: 540 },
  async () => {
    await forEachBranch(runDailyLibrary);
  },
);
