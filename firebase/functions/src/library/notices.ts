import { getFirestore } from 'firebase-admin/firestore';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { timestampDay } from '../shared/dates';
import { post } from '../shared/outbox';
import { memberTo } from './notify';

/**
 * Notices for circulation, which the client writes directly (`LoanWrites`): the member (a student's
 * parents, or the teacher) hears of an issue, a return, a fine, a lost or damaged book and a ready
 * reservation. Outbox keys are fixed per event, so a redelivered trigger, or a callable that already
 * queued the same notice, never sends it twice.
 */
const path = (collection: string) => `schools/{schoolId}/${collection}/{docId}`;

export const noticeLoans = onDocumentWritten(path('libraryLoans'), async (event) => {
  const before = event.data?.before.data();
  const loan = event.data?.after.data();
  const { schoolId, docId } = event.params;
  if (!loan) return;
  const to = memberTo(loan.memberType, loan.personErpId);
  if (!before) {
    const title = (
      await getFirestore().doc(`schools/${schoolId}/libraryCatalogue/${loan.catalogueId}`).get()
    ).data()?.title;
    await post(getFirestore(), schoolId, `library-issued__${docId}`, {
      to,
      category: 'library.loan',
      title: 'Book issued',
      body: `${title ?? loan.barcode}: due back ${timestampDay(loan.dueDate)}.`,
      data: { loanId: docId },
    });
  } else if (before.status === 'active' && loan.status === 'returned') {
    await post(getFirestore(), schoolId, `library-returned__${docId}`, {
      to,
      category: 'library.loan',
      title: 'Book returned',
      body: `${loan.barcode} was returned${loan.overdueDays ? ` ${loan.overdueDays} day(s) late` : ''}.`,
      data: { loanId: docId },
    });
  }
});

/** Overdue and lost-book fines of a loan; fines from incident resolutions never notified. */
export const noticeFines = onDocumentCreated(path('libraryFines'), async (event) => {
  const fine = event.data?.data();
  if (!fine?.loanId || fine.incidentId) return;
  const { schoolId, docId } = event.params;
  const body =
    fine.type === 'lost'
      ? `${fine.barcode}: replacement charge of ${fine.amount}.`
      : `${fine.barcode}: overdue fine of ${fine.amount} for ${fine.fineCalculation?.overdueDays} day(s).`;
  await post(getFirestore(), schoolId, `library-fine__${docId}`, {
    to: memberTo(fine.memberType, fine.personErpId),
    category: 'library.fine',
    title: 'Fine recorded',
    body,
    data: { fineId: docId },
  });
});

/** Lost or damaged books: the member held responsible (if any) is told. */
export const noticeIncidents = onDocumentCreated(path('libraryIncidents'), async (event) => {
  const incident = event.data?.data();
  if (!incident?.personErpId) return;
  const { schoolId, docId } = event.params;
  const lost = incident.type === 'lost';
  await post(getFirestore(), schoolId, `library-incident__${docId}`, {
    to: memberTo(incident.memberType, incident.personErpId),
    category: 'library.incident',
    title: lost ? 'Lost book recorded' : 'Damaged book recorded',
    body: incident.loanId
      ? lost
        ? `${incident.barcode} was marked lost.`
        : `${incident.barcode} was returned damaged.`
      : `${incident.barcode} was reported ${incident.type}.`,
    data: { incidentId: docId },
  });
});

/** A returned copy held for the next waiting member; holds made by callables queue the same key. */
export const noticeReservations = onDocumentWritten(path('libraryReservations'), async (event) => {
  const before = event.data?.before.data();
  const reservation = event.data?.after.data();
  if (!reservation || reservation.status !== 'ready' || before?.status === 'ready') return;
  const { schoolId, docId } = event.params;
  await post(getFirestore(), schoolId, `library-reservation-ready__${docId}`, {
    to: memberTo(reservation.memberType, reservation.personErpId),
    category: 'library.reservation',
    title: 'Reserved book is ready',
    body: `${reservation.title}: collect it by ${timestampDay(reservation.holdUntil)}.`,
    data: { reservationId: docId },
  });
});
