/**
 * One-off migration: Library `memberType` moved from `student` / `teacher` to `STUDENT` / `EMPLOYEE`
 * (borrowing policies keep `all`). Rewrites that field on libraryMembers, libraryLoans, libraryFines,
 * libraryIncidents and libraryBorrowingPolicies. Not a Cloud Function: run it by hand.
 *
 *   npm run member-type:migrate -- --project <id> [--branch org/zone/branch] [--write]
 *
 * Without --write it only prints how many documents it would change. Against the emulator set
 * FIRESTORE_EMULATOR_HOST (e.g. 127.0.0.1:8080); otherwise it uses your Application Default Credentials
 * on the real project, so check --project twice. Safe to re-run: already-migrated documents are skipped.
 * Only `memberType` is written (no `lastWrite`). Run `npm run stats:recompute -- --write` afterwards:
 * the audit triggers see each rewrite as a change and their per-library student/teacher counts can drift.
 * A staff loan or member issued before this change has no `admissionNumber`; that is not backfilled.
 */
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const option = (name: string) => args[args.indexOf(`--${name}`) + 1];
const project = args.includes('--project') ? option('project') : undefined;
const only = args.includes('--branch') ? option('branch') : undefined;
const write = args.includes('--write');
if (!project) {
  console.error(
    'Usage: npm run member-type:migrate -- --project <id> [--branch org/zone/branch] [--write]',
  );
  process.exit(1);
}
initializeApp({ projectId: project });
const db = getFirestore();

const RENAMES: Record<string, string> = { student: 'STUDENT', teacher: 'EMPLOYEE' };
const COLLECTIONS = [
  'libraryMembers',
  'libraryLoans',
  'libraryFines',
  'libraryIncidents',
  'libraryBorrowingPolicies',
];

async function main() {
  const branches: string[] = [];
  const [orgId, zoneId, branchId] = only?.split('/') ?? [];
  const wantedPath = `orgs/${orgId}/zones/${zoneId}/branches/${branchId}`;
  for (const org of await db.collection('orgs').listDocuments())
    for (const zone of await org.collection('zones').listDocuments())
      for (const branch of await zone.collection('branches').listDocuments())
        if (!only || branch.path === wantedPath) branches.push(branch.path);
  if (!branches.length) throw new Error('No matching branch found.');

  const writer = db.bulkWriter();
  let changed = 0;
  for (const path of branches) {
    console.log(path);
    for (const collection of COLLECTIONS) {
      const snapshot = await db.collection(`${path}/${collection}`).get();
      let count = 0;
      for (const doc of snapshot.docs) {
        const renamed = RENAMES[doc.get('memberType') as string];
        if (!renamed) continue;
        count++;
        if (write) void writer.update(doc.ref, { memberType: renamed });
      }
      if (count) console.log(`  ${collection}: ${count}`);
      changed += count;
    }
  }
  await writer.close();
  console.log(
    write
      ? `Done: ${changed} document(s) rewritten. Now run npm run stats:recompute -- --project ${project} --write.`
      : `Dry run: ${changed} document(s) would change. Re-run with --write to apply.`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
