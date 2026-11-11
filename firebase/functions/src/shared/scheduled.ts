import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';

/**
 * Runs a scheduled [job] once for every branch (`orgs/{orgId}/zones/{zoneId}/branches/{branchId}`).
 * One failing branch is logged and does not stop the others; the run then fails so it shows as failed.
 */
export async function forEachBranch(job: (branchPath: string) => Promise<void>): Promise<void> {
  let failed = 0;
  for (const branch of (await getFirestore().collectionGroup('branches').select().get()).docs) {
    try {
      await job(branch.ref.path);
    } catch (error) {
      failed++;
      logger.error('scheduled job failed for branch', error, { branch: branch.ref.path });
    }
  }
  if (failed) throw new Error(`${failed} branch job(s) failed`);
}
