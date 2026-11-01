import '../region';
import { getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { forEachSchool } from '../shared/scheduled';
import { schoolCollection } from '../shared/firestore';
import { post } from '../shared/outbox';
import { memberTo } from './notify';
import { todayIST, addDays } from '../shared/dates';

/** Daily library job (architecture §5.2): the FRS 11.17 date-driven notifications. Posting an existing key is a no-op, so reruns are safe. */

const DUE_SOON_DAYS = 2;
const MEMBERSHIP_DAYS = 7;

export async function runDailyLibrary(schoolId: string, today = todayIST()): Promise<void> {
  const db = getFirestore();
  const collection = (name: string) => schoolCollection(schoolId, name);

  const soon = await collection('libraryLoans').where('status', '==', 'active').where('dueDate', '>=', today).where('dueDate', '<=', addDays(today, DUE_SOON_DAYS)).get();
  for (const snapshot of soon.docs) {
    const loan = snapshot.data();
    await post(db, schoolId, `library-due-soon__${snapshot.id}`, {
      to: memberTo(loan.memberType, loan.personErpId), category: 'library.loan', title: 'Book due soon',
      body: `${loan.accessionNumber} is due on ${loan.dueDate}.`, data: { loanId: snapshot.id },
    });
  }

  const overdue = await collection('libraryLoans').where('status', '==', 'active').where('dueDate', '<', today).get();
  for (const snapshot of overdue.docs) {
    const loan = snapshot.data();
    await post(db, schoolId, `library-overdue__${snapshot.id}__${today}`, {
      to: memberTo(loan.memberType, loan.personErpId), category: 'library.loan', title: 'Book overdue',
      body: `${loan.accessionNumber} was due on ${loan.dueDate}. Please return it.`, data: { loanId: snapshot.id },
    });
  }

  const ending = await collection('libraryMembers').where('status', '==', 'active').where('end', '>=', today).where('end', '<=', addDays(today, MEMBERSHIP_DAYS)).get();
  for (const snapshot of ending.docs) {
    const member = snapshot.data();
    await post(db, schoolId, `library-member-expiring__${snapshot.id}__${member.end}`, {
      to: memberTo(member.memberType, member.personErpId), category: 'library.member', title: 'Library membership ending',
      body: `The membership ends on ${member.end}.`, data: { memberId: snapshot.id },
    });
  }

  const holds = await collection('libraryReservations').where('status', '==', 'ready').where('holdUntil', '>=', today).where('holdUntil', '<=', addDays(today, 1)).get();
  for (const snapshot of holds.docs) {
    const reservation = snapshot.data();
    await post(db, schoolId, `library-reservation-expiring__${snapshot.id}`, {
      to: memberTo(reservation.memberType, reservation.personErpId), category: 'library.reservation', title: 'Reserved book hold ending',
      body: `${reservation.title}: collect it by ${reservation.holdUntil}.`, data: { reservationId: snapshot.id },
    });
  }
}

/** 07:00 IST, every school. */
export const dailyLibrary = onSchedule({ schedule: '0 7 * * *', timeZone: 'Asia/Kolkata' }, async () => {
  await forEachSchool(runDailyLibrary);
});
