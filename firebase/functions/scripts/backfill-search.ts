/**
 * One-off backfill of the `search` database: copies the existing inventory items, library catalogue, loans
 * and incidents of every branch (or one) into the text-search mirror. The `sync*Search` triggers only mirror
 * documents written after they were deployed. Reuses the triggers' own projections and `applyChange`, so a
 * backfilled document equals a live-mirrored one, and a document edited mid-run is never overwritten by an
 * older copy (each mirror row carries the source document's update time). Not a Cloud Function: run it by hand.
 *
 *   npm run search:backfill -- --project <id> [--branch org/zone/branch] [--write]
 *
 * Without --write it only prints how many documents it would mirror. Against the emulator set
 * FIRESTORE_EMULATOR_HOST; otherwise it uses your Application Default Credentials on the real project.
 */
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { projectItem } from '../src/inventory/search';
import { projectCatalogue, projectIncident, projectLoan } from '../src/library/search';
import { applyChange } from '../src/shared/searchMirror';

const args = process.argv.slice(2);
const option = (name: string) => args[args.indexOf(`--${name}`) + 1];
const project = args.includes('--project') ? option('project') : undefined;
const only = args.includes('--branch') ? option('branch') : undefined;
const write = args.includes('--write');
if (!project) {
  console.error(
    'Usage: npm run search:backfill -- --project <id> [--branch org/zone/branch] [--write]',
  );
  process.exit(1);
}
initializeApp({ projectId: project });
const db = getFirestore();
const searchDb = getFirestore('search');

const MIRRORS = {
  inventoryItems: projectItem,
  libraryCatalogue: projectCatalogue,
  libraryLoans: projectLoan,
  libraryIncidents: projectIncident,
};

async function main() {
  const branches: string[] = [];
  const [orgId, zoneId, branchId] = only?.split('/') ?? [];
  const wantedPath = `orgs/${orgId}/zones/${zoneId}/branches/${branchId}`;
  for (const org of await db.collection('orgs').listDocuments())
    for (const zone of await org.collection('zones').listDocuments())
      for (const branch of await zone.collection('branches').listDocuments())
        if (!only || branch.path === wantedPath) branches.push(branch.path);
  if (!branches.length) throw new Error('No matching branch found.');

  let total = 0;
  for (const path of branches) {
    console.log(path);
    for (const [collection, projection] of Object.entries(MIRRORS)) {
      const snapshot = await db.collection(`${path}/${collection}`).get();
      console.log(`  ${collection}: ${snapshot.size}`);
      total += snapshot.size;
      if (write)
        for (const doc of snapshot.docs)
          await applyChange(
            collection,
            projection,
            path,
            doc.id,
            doc.data(),
            doc.updateTime,
            searchDb,
          );
    }
  }
  console.log(
    write
      ? `Done: ${total} document(s) mirrored.`
      : `Dry run: ${total} document(s) would be mirrored. Re-run with --write to apply.`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
