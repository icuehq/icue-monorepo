import { type DocumentData, getFirestore } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { BRANCH_TRIGGER, branchPathOf } from '../shared/branch';
import { serverTimestamp } from '../shared/firestore';
import { type Change, noticeFine, noticeIncident, noticeLoan } from './notices';
import { recordStats } from './stats';

const IGNORED = ['lastWrite', 'updatedAt'];

/** Only the fields that differ between [before] and [after] (all of [after] for a create). */
function changedFields(before: DocumentData | undefined, after: DocumentData) {
  const keys = Object.keys(after).filter((key) => !IGNORED.includes(key));
  const differs = (key: string) => JSON.stringify(before?.[key]) !== JSON.stringify(after[key]);
  const changed = before ? keys.filter(differs) : keys;
  const pick = (source: DocumentData | undefined) =>
    source ? Object.fromEntries(changed.map((key) => [key, source[key] ?? null])) : null;
  return { before: pick(before), after: pick(after) };
}

/**
 * Audit log for client writes (no callable): every such write stamps `lastWrite` {by, action, reason, at}
 * (enforced by `firestore.rules`). A write that leaves the stamp alone (a callable's, say) is not logged here.
 * The event ID is the log's ID, so a redelivered event cannot log twice.
 * One trigger per collection also runs its member [notice] and updates the analytics summary (`stats.ts`), so a write is billed one invocation, not three.
 */
const auditClientWrites = (collection: string, notice?: (change: Change) => Promise<void>) =>
  onDocumentWritten(`${BRANCH_TRIGGER}/${collection}/{docId}`, async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const branchPath = branchPathOf(event.params);
    const { docId } = event.params;
    await Promise.all([
      audit(collection, event.id, branchPath, docId, before, after),
      notice?.({ branchPath, docId, before, after }),
      recordStats(collection, { branchPath, docId, before, after }),
    ]);
  });

async function audit(
  collection: string,
  eventId: string,
  branchPath: string,
  docId: string,
  before: DocumentData | undefined,
  after: DocumentData | undefined,
) {
  const mark = after?.lastWrite;
  if (!after || !mark || before?.lastWrite?.at?.isEqual(mark.at)) return;
  await getFirestore()
    .doc(`${branchPath}/auditLogs/${eventId}`)
    .set({
      actor: mark.by,
      action: mark.action,
      documentPath: `${collection}/${docId}`,
      ...changedFields(before, after),
      reason: mark.reason ?? null,
      performedAt: serverTimestamp(),
    });
}

export const auditLibraryCatalogue = auditClientWrites('libraryCatalogue');
export const auditLibraryCopies = auditClientWrites('libraryCopies');
export const auditLibraryMembers = auditClientWrites('libraryMembers');
export const auditLibraryPolicies = auditClientWrites('libraryBorrowingPolicies');
export const auditLibraryLoans = auditClientWrites('libraryLoans', noticeLoan);
export const auditLibraryFines = auditClientWrites('libraryFines', noticeFine);
export const auditLibraryIncidents = auditClientWrites('libraryIncidents', noticeIncident);
