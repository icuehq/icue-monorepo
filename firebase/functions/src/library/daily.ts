import { getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { todayIST, addDays, dayTimestamp, timestampDay } from '../shared/dates';
import { schoolCollection } from '../shared/firestore';
import { post } from '../shared/outbox';
import { forEachSchool } from '../shared/scheduled';
import { memberTo } from './notify';

/** Daily library job (architecture §5.2): the FRS 11.17 date-driven notifications. Posting an existing key is a no-op, so reruns are safe. */

const DUE_SOON_DAYS = 2;

export async function runDailyLibrary(schoolId: string, today = todayIST()): Promise<void> {
  const db = getFirestore();
  const collection = (name: string) => schoolCollection(schoolId, name);

  const soon = await collection('libraryLoans')
    .where('status', '==', 'active')
    .where('dueDate', '>=', dayTimestamp(today))
    .where('dueDate', '<=', dayTimestamp(addDays(today, DUE_SOON_DAYS)))
    .get();
  for (const snapshot of soon.docs) {
    const loan = snapshot.data();
    await post(db, schoolId, `library-due-soon__${snapshot.id}`, {
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
    await post(db, schoolId, `library-overdue__${snapshot.id}__${today}`, {
      to: memberTo(loan.memberType, loan.personErpId),
      category: 'library.loan',
      title: 'Book overdue',
      body: `${loan.barcode} was due on ${timestampDay(loan.dueDate)}. Please return it.`,
      data: { loanId: snapshot.id },
    });
  }

  const holds = await collection('libraryReservations')
    .where('status', '==', 'ready')
    .where('holdUntil', '>=', dayTimestamp(today))
    .where('holdUntil', '<=', dayTimestamp(addDays(today, 1)))
    .get();
  for (const snapshot of holds.docs) {
    const reservation = snapshot.data();
    await post(db, schoolId, `library-reservation-expiring__${snapshot.id}`, {
      to: memberTo(reservation.memberType, reservation.personErpId),
      category: 'library.reservation',
      title: 'Reserved book hold ending',
      body: `${reservation.title}: collect it by ${timestampDay(reservation.holdUntil)}.`,
      data: { reservationId: snapshot.id },
    });
  }
}

/** 07:00 IST, every school. */
export const dailyLibrary = onSchedule(
  { schedule: '0 7 * * *', timeZone: 'Asia/Kolkata', timeoutSeconds: 540 },
  async () => {
    await forEachSchool(runDailyLibrary);
  },
);
