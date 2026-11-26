/**
 * One-off backfill on library catalogue titles of `libraryIds` (the libraries whose `holdings` count is above zero)
 * and of `copyCount` / `availableCopies`, counted from the title's copies.
 * The stats trigger keeps it from now on; titles written before it was fixed may be missing libraries or list
 * ones they no longer hold. Updating a title also re-mirrors it into the search database through its trigger.
 *
 *   npm run library-ids:backfill -- --project <id> [--branch org/zone/branch] [--write]
 *
 * Without --write it only prints how many titles it would change. Against the emulator set
 * FIRESTORE_EMULATOR_HOST; otherwise it uses your Application Default Credentials on the real project.
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
    'Usage: npm run library-ids:backfill -- --project <id> [--branch org/zone/branch] [--write]',
  );
  process.exit(1);
}
initializeApp({ projectId: project });
const db = getFirestore();

async function main() {
  const [orgId, zoneId, branchId] = only?.split('/') ?? [];
  const wantedPath = `orgs/${orgId}/zones/${zoneId}/branches/${branchId}`;
  let checked = 0;
  let changed = 0;
  for (const org of await db.collection('orgs').listDocuments())
    for (const zone of await org.collection('zones').listDocuments())
      for (const branch of await zone.collection('branches').listDocuments()) {
        if (only && branch.path !== wantedPath) continue;
        const titles = await branch.collection('libraryCatalogue').get();
        const counts: Record<string, { copies: number; available: number }> = {};
        for (const copy of (await branch.collection('libraryCopies').get()).docs) {
          const { catalogueId, status } = copy.data();
          const count = (counts[catalogueId] ??= { copies: 0, available: 0 });
          count.copies++;
          if (status === 'available') count.available++;
        }
        console.log(`${branch.path}: ${titles.size} titles`);
        for (const title of titles.docs) {
          checked++;
          const holdings: Record<string, number> = title.data().holdings ?? {};
          const wanted = Object.keys(holdings)
            .filter((libraryId) => holdings[libraryId] > 0)
            .sort();
          const current: string[] = [...(title.data().libraryIds ?? [])].sort();
          const { copies, available } = counts[title.id] ?? { copies: 0, available: 0 };
          if (
            wanted.join() === current.join() &&
            title.data().copyCount === copies &&
            title.data().availableCopies === available
          )
            continue;
          changed++;
          if (write)
            await title.ref.update({
              libraryIds: wanted,
              copyCount: copies,
              availableCopies: available,
            });
        }
      }
  console.log(`${write ? 'Updated' : 'Would update'} ${changed} of ${checked} titles.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
