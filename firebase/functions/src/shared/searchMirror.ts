import {
  type DocumentData,
  type Firestore,
  getFirestore,
  Timestamp,
} from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { BRANCH_TRIGGER, branchPathOf } from './branch';

/**
 * Text search lives in a second, Enterprise-edition database (`search`): `(default)` stays the source of
 * truth, a trigger mirrors a small projection into it, and web clients query the mirror directly with
 * Firestore Pipelines (architecture §10). Inventory items and the library catalogue share this.
 */
export const SEARCH_DB = 'search';
export const searchDb = () => getFirestore(SEARCH_DB);

/** Mirrors one document change; a delivery older than what is stored is ignored. */
export async function applyChange(
  collection: string,
  project: (data: DocumentData) => DocumentData,
  branchPath: string,
  documentId: string,
  after: DocumentData | undefined,
  changedAt: Timestamp = Timestamp.now(),
  db: Firestore = searchDb(),
): Promise<void> {
  const ref = db.doc(`${branchPath}/${collection}/${documentId}`);
  if (!after) {
    await ref.delete();
    return;
  }
  await db.runTransaction(async (transaction) => {
    const current = (await transaction.get(ref)).data()?.srcUpdatedAt as Timestamp | undefined;
    if (current && current.toMillis() > changedAt.toMillis()) return;
    transaction.set(ref, { ...project(after), srcUpdatedAt: changedAt });
  });
}

/** Whether a write leaves the mirrored projection unchanged (so the search database need not be touched). */
export const sameProjection = (
  project: (data: DocumentData) => DocumentData,
  before: DocumentData | undefined,
  after: DocumentData | undefined,
) => !!before && !!after && JSON.stringify(project(before)) === JSON.stringify(project(after));

/** Trigger that mirrors writes of `${BRANCH_TRIGGER}/<collection>/{id}` that change the projection. */
export const syncTrigger = (collection: string, project: (data: DocumentData) => DocumentData) =>
  onDocumentWritten(`${BRANCH_TRIGGER}/${collection}/{id}`, async (event) => {
    const after = event.data?.after.data();
    if (sameProjection(project, event.data?.before.data(), after)) return;
    await applyChange(
      collection,
      project,
      branchPathOf(event.params),
      event.params.id,
      after,
      event.data?.after.updateTime,
    );
  });
