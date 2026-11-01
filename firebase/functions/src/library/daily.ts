import '../region';
import { getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { todayIST } from '../inventory/stock';
import { post } from '../shared/outbox';
import { memberTo } from './notify';

/** Daily library job (architecture §5.2): the FRS 11.17 date-driven notifications. Posting an existing key is a no-op, so reruns are safe. */

const DUE_SOON_DAYS = 2;
const MEMBERSHIP_DAYS = 7;
const addDays = (d: string, n: number) => new Date(Date.parse(`${d}T00:00:00Z`) + n * 86_400_000).toISOString().slice(0, 10);

export async function runDailyLibrary(sid: string, today = todayIST()): Promise<void> {
  const db = getFirestore();
  const coll = (p: string) => db.collection(`schools/${sid}/${p}`);

  const soon = await coll('libLoans').where('status', '==', 'active').where('dueOn', '>=', today).where('dueOn', '<=', addDays(today, DUE_SOON_DAYS)).get();
  for (const d of soon.docs) {
    const l = d.data();
    await post(db, sid, `lib-due-soon__${d.id}`, {
      to: memberTo(l.memberType, l.personErpId), category: 'lib.loan', title: 'Book due soon',
      body: `${l.accessionNo} is due on ${l.dueOn}.`, data: { loanId: d.id },
    });
  }

  const overdue = await coll('libLoans').where('status', '==', 'active').where('dueOn', '<', today).get();
  for (const d of overdue.docs) {
    const l = d.data();
    await post(db, sid, `lib-overdue__${d.id}__${today}`, {
      to: memberTo(l.memberType, l.personErpId), category: 'lib.loan', title: 'Book overdue',
      body: `${l.accessionNo} was due on ${l.dueOn}. Please return it.`, data: { loanId: d.id },
    });
  }

  const ending = await coll('libMembers').where('status', '==', 'active').where('end', '>=', today).where('end', '<=', addDays(today, MEMBERSHIP_DAYS)).get();
  for (const d of ending.docs) {
    const m = d.data();
    await post(db, sid, `lib-member-expiring__${d.id}__${m.end}`, {
      to: memberTo(m.memberType, m.erpId), category: 'lib.member', title: 'Library membership ending',
      body: `The membership ends on ${m.end}.`, data: { memberId: d.id },
    });
  }

  const holds = await coll('libReservations').where('status', '==', 'ready').where('holdUntil', '>=', today).where('holdUntil', '<=', addDays(today, 1)).get();
  for (const d of holds.docs) {
    const r = d.data();
    await post(db, sid, `lib-rsv-expiring__${d.id}`, {
      to: memberTo(r.memberType, r.personErpId), category: 'lib.reservation', title: 'Reserved book hold ending',
      body: `${r.title}: collect it by ${r.holdUntil}.`, data: { reservationId: d.id },
    });
  }
}

/** 07:00 IST, every school. */
export const dailyLibrary = onSchedule({ schedule: '0 7 * * *', timeZone: 'Asia/Kolkata' }, async () => {
  for (const school of await getFirestore().collection('schools').listDocuments()) await runDailyLibrary(school.id);
});
