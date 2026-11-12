import { type DocumentData, getFirestore } from 'firebase-admin/firestore';
import { timestampDay } from '../shared/dates';
import { post } from '../shared/outbox';
import { memberTo } from './notify';

/**
 * Notices for circulation, which the client writes directly (`LoanWrites`): the member (a student's
 * parents, or the teacher) hears of an issue, a return, a fine, a lost or damaged book. They run inside
 * the collection's audit trigger (`audit.ts`), so each write costs one invocation. Outbox keys are fixed
 * per event, so a redelivered trigger never sends a notice twice.
 */
export interface Change {
  branchPath: string;
  docId: string;
  before?: DocumentData;
  after?: DocumentData;
}

export async function noticeLoan({
  branchPath,
  docId,
  before,
  after: loan,
}: Change): Promise<void> {
  if (!loan) return;
  const to = memberTo(loan.memberType, loan.personErpId);
  if (!before) {
    const title = (
      await getFirestore().doc(`${branchPath}/libraryCatalogue/${loan.catalogueId}`).get()
    ).data()?.title;
    await post(getFirestore(), branchPath, `library-issued__${docId}`, {
      to,
      category: 'library.loan',
      title: 'Book issued',
      body: `${title ?? loan.barcode}: due back ${timestampDay(loan.dueDate)}.`,
      data: { loanId: docId },
    });
  } else if (before.status === 'active' && loan.status === 'returned') {
    await post(getFirestore(), branchPath, `library-returned__${docId}`, {
      to,
      category: 'library.loan',
      title: 'Book returned',
      body: `${loan.barcode} was returned${loan.overdueDays ? ` ${loan.overdueDays} day(s) late` : ''}.`,
      data: { loanId: docId },
    });
  }
}

/** New overdue and lost-book fines of a loan; fines from incident resolutions never notified. */
export async function noticeFine({
  branchPath,
  docId,
  before,
  after: fine,
}: Change): Promise<void> {
  if (before || !fine?.loanId || fine.incidentId) return;
  const body =
    fine.type === 'lost'
      ? `${fine.barcode}: replacement charge of ${fine.amount}.`
      : `${fine.barcode}: overdue fine of ${fine.amount} for ${fine.fineCalculation?.overdueDays} day(s).`;
  await post(getFirestore(), branchPath, `library-fine__${docId}`, {
    to: memberTo(fine.memberType, fine.personErpId),
    category: 'library.fine',
    title: 'Fine recorded',
    body,
    data: { fineId: docId },
  });
}

/** New lost or damaged books: the member held responsible (if any) is told. */
export async function noticeIncident({
  branchPath,
  docId,
  before,
  after: incident,
}: Change): Promise<void> {
  if (before || !incident?.personErpId) return;
  const lost = incident.type === 'lost';
  await post(getFirestore(), branchPath, `library-incident__${docId}`, {
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
}
