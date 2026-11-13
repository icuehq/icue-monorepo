/**
 * Manual repair for analytics drift: recounts `inventoryStats/overall`, `libraryStats/overall` and
 * `libraryStats/day_*` (plus the catalogue `holdings` and member `libraryIds` they depend on) from the data.
 * It reuses the triggers' own counting (`figures`, `deltas`), so a recount and a live write always agree.
 * Not a Cloud Function: run it by hand.
 *
 *   npm run stats:recompute -- --project <id> [--branch org/zone/branch] [--write]
 *
 * Without --write it only prints what differs. Against the emulator set FIRESTORE_EMULATOR_HOST
 * (e.g. 127.0.0.1:8080); otherwise it uses your Application Default Credentials on the real project.
 * Run it while nobody is writing: a write landing mid-run is counted by its trigger on top of the recount.
 *
 * ponytail: reads whole collections into memory, fine for one school branch; page the reads if one outgrows that.
 * Fine payments carry no date, so `finesCollected` lands on the day the fine was last updated.
 */
import { initializeApp } from 'firebase-admin/app';
import { type DocumentData, getFirestore, type Timestamp } from 'firebase-admin/firestore';
import { figures } from '../src/inventory/stats';
import { deltas } from '../src/library/stats';
import { timestampDay } from '../src/shared/dates';
import { bump, type Counts } from '../src/shared/statsCounts';

const args = process.argv.slice(2);
const option = (name: string) => args[args.indexOf(`--${name}`) + 1];
const project = args.includes('--project') ? option('project') : undefined;
const only = args.includes('--branch') ? option('branch') : undefined;
const write = args.includes('--write');
if (!project) {
  console.error(
    'Usage: npm run stats:recompute -- --project <id> [--branch org/zone/branch] [--write]',
  );
  process.exit(1);
}
initializeApp({ projectId: project });
const db = getFirestore();

/** `{'dueOn.2026-11-20': 1, copies: 3}` → `{dueOn: {'2026-11-20': 1}, copies: 3}`, zeros dropped. */
function nest(counts: Counts) {
  const out: Record<string, unknown> = {};
  for (const [key, amount] of Object.entries(counts)) {
    const rounded = Math.round(amount * 1e6) / 1e6;
    if (!rounded) continue;
    const [field, inner] = key.split('.');
    if (inner === undefined) out[field] = rounded;
    else ((out[field] ??= {}) as Record<string, number>)[inner] = rounded;
  }
  return out;
}

/** A summary document: branch figures, with per-group figures (stores / libraries) under [groupKey]. */
function summary(branch: Counts, groups: Record<string, Counts>, groupKey: string) {
  const grouped = Object.entries(groups)
    .map(([id, counts]) => [id, nest(counts)] as const)
    .filter(([, fields]) => Object.keys(fields).length);
  return { ...nest(branch), ...(grouped.length && { [groupKey]: Object.fromEntries(grouped) }) };
}

function merge(into: Counts, from: Counts) {
  for (const [key, amount] of Object.entries(from)) bump(into, key, amount);
}

const flatten = (value: unknown, prefix = ''): Record<string, unknown> =>
  value && typeof value === 'object' && !Array.isArray(value) && !('toMillis' in value)
    ? Object.entries(value).reduce(
        (all, [key, inner]) => ({ ...all, ...flatten(inner, prefix ? `${prefix}.${key}` : key) }),
        {},
      )
    : { [prefix]: value };

const day = (stamp?: Timestamp | null) => (stamp ? timestampDay(stamp) : undefined);

async function load(path: string, collection: string) {
  const snapshot = await db.collection(`${path}/${collection}`).get();
  return snapshot.docs.map((doc) => ({ id: doc.id, ref: doc.ref, data: doc.data() }));
}

/** Plans one document write; counted, and applied only with --write. */
const writer = db.bulkWriter();
let changes = 0;
function plan(
  label: string,
  current: DocumentData | undefined,
  wanted: DocumentData,
  apply: () => void,
) {
  const before = flatten(current ?? {});
  const after = flatten(wanted);
  const keys = [...new Set([...Object.keys(before), ...Object.keys(after)])];
  const differing = keys.filter((key) => (before[key] ?? 0) !== (after[key] ?? 0));
  if (!differing.length) return;
  changes++;
  console.log(`  ${label}`);
  for (const key of differing.slice(0, 8))
    console.log(
      `    ${key}: ${JSON.stringify(before[key] ?? null)} -> ${JSON.stringify(after[key] ?? null)}`,
    );
  if (differing.length > 8) console.log(`    … and ${differing.length - 8} more`);
  if (write) apply();
}

async function inventory(path: string) {
  const branch: Counts = {};
  const stores: Record<string, Counts> = {};
  for (const collection of [
    'inventoryItems',
    'inventoryBalances',
    'inventoryPurchaseRequests',
    'inventoryIssueRequests',
    'inventoryPurchaseOrders',
    'inventoryAssets',
  ])
    for (const { data } of await load(path, collection)) {
      const state = figures(collection, data, 1);
      merge(branch, state.branch);
      if (state.store) merge((stores[state.store.id] ??= {}), state.store.counts);
    }
  const ref = db.doc(`${path}/inventoryStats/overall`);
  const wanted = summary(branch, stores, 'stores');
  plan(
    'inventoryStats/overall',
    (await ref.get()).data(),
    wanted,
    () => void writer.set(ref, wanted),
  );
}

async function library(path: string) {
  const [copies, loans, fines, members, catalogue, incidents] = await Promise.all(
    [
      'libraryCopies',
      'libraryLoans',
      'libraryFines',
      'libraryMembers',
      'libraryCatalogue',
      'libraryIncidents',
    ].map((collection) => load(path, collection)),
  );
  const branch: Counts = {};
  const libraries: Record<string, Counts> = {};
  const addAll = (collection: string, docs: typeof copies) => {
    for (const { data } of docs) {
      const { overall } = deltas(collection, {
        branchPath: path,
        docId: '',
        before: undefined,
        after: data,
      });
      merge(branch, overall.branch);
      for (const [id, counts] of Object.entries(overall.libraries))
        merge((libraries[id] ??= {}), counts);
    }
  };
  addAll('libraryCopies', copies);
  addAll('libraryLoans', loans);
  addAll('libraryFines', fines);
  addAll('libraryMembers', members);
  addAll('libraryCatalogue', catalogue);

  // Copies per title per library (catalogue `holdings`) and libraries each member borrowed from (`libraryIds`).
  const holdings: Record<string, Counts> = {};
  for (const { data } of copies) bump((holdings[data.catalogueId] ??= {}), data.libraryId, 1);
  const borrowed: Record<string, Set<string>> = {};
  for (const { data } of loans)
    (borrowed[String(data.personErpId)] ??= new Set()).add(data.libraryId);

  for (const perLibrary of Object.values(holdings))
    for (const [libraryId, count] of Object.entries(perLibrary))
      if (count > 0) bump((libraries[libraryId] ??= {}), 'titles', 1);
  for (const { id, data } of members)
    for (const libraryId of borrowed[id] ?? [])
      bump(
        (libraries[libraryId] ??= {}),
        data.memberType === 'teacher' ? 'teachers' : 'students',
        1,
      );

  const overallRef = db.doc(`${path}/libraryStats/overall`);
  const overall = summary(branch, libraries, 'libraries');
  plan(
    'libraryStats/overall',
    (await overallRef.get()).data(),
    overall,
    () => void writer.set(overallRef, overall),
  );

  for (const { id, ref, data } of catalogue) {
    const wanted = Object.fromEntries(
      Object.entries(holdings[id] ?? {}).filter(([, count]) => count > 0),
    );
    plan(
      `libraryCatalogue/${id} holdings`,
      { holdings: data.holdings ?? {} },
      { holdings: wanted },
      () => void writer.update(ref, { holdings: wanted }),
    );
  }
  for (const { id, ref, data } of members) {
    const wanted = [...(borrowed[id] ?? [])].sort();
    plan(
      `libraryMembers/${id} libraryIds`,
      { libraryIds: [...(data.libraryIds ?? [])].sort().join() },
      { libraryIds: wanted.join() },
      () => void writer.update(ref, { libraryIds: wanted }),
    );
  }

  // Daily flows, each on the day it happened.
  const days: Record<string, { branch: Counts; libraries: Record<string, Counts> }> = {};
  const flow = (when: string | undefined, key: string, amount: number, libraryId: string) => {
    if (!when || !amount) return;
    const entry = (days[when] ??= { branch: {}, libraries: {} });
    bump(entry.branch, key, amount);
    bump((entry.libraries[libraryId] ??= {}), key, amount);
  };
  for (const { data } of loans) {
    flow(day(data.issuedDate), 'loansIssued', 1, data.libraryId);
    if (data.status === 'returned')
      flow(day(data.returnedDate), 'loansReturned', 1, data.libraryId);
    for (const renewal of data.renewals ?? [])
      flow(day(renewal.renewedDate), 'loansRenewed', 1, data.libraryId);
  }
  for (const { data } of fines) {
    flow(day(data.createdAt), 'finesRaised', data.amount ?? 0, data.libraryId);
    flow(day(data.updatedAt), 'finesCollected', data.paid ?? 0, data.libraryId);
  }
  for (const { data } of incidents)
    flow(
      day(data.reportedDate ?? data.createdAt),
      data.type === 'lost' ? 'booksLost' : 'booksDamaged',
      1,
      data.libraryId,
    );

  const existing = await load(path, 'libraryStats');
  for (const { id, ref, data } of existing)
    if (id.startsWith('day_') && !days[id.slice(4)])
      plan(`libraryStats/${id} (no activity)`, data, {}, () => void writer.delete(ref));
  for (const [when, { branch: dayBranch, libraries: dayLibraries }] of Object.entries(days)) {
    const ref = db.doc(`${path}/libraryStats/day_${when}`);
    const wanted = summary(dayBranch, dayLibraries, 'libraries');
    plan(
      `libraryStats/day_${when}`,
      existing.find((doc) => doc.id === `day_${when}`)?.data,
      wanted,
      () => void writer.set(ref, wanted),
    );
  }
}

async function main() {
  const branches: string[] = [];
  const [orgId, zoneId, branchId] = only?.split('/') ?? [];
  const wantedPath = `orgs/${orgId}/zones/${zoneId}/branches/${branchId}`;
  for (const org of await db.collection('orgs').listDocuments())
    for (const zone of await org.collection('zones').listDocuments())
      for (const branch of await zone.collection('branches').listDocuments())
        if (!only || branch.path === wantedPath) branches.push(branch.path);
  if (!branches.length) throw new Error('No matching branch found.');

  for (const path of branches) {
    console.log(path);
    await inventory(path);
    await library(path);
  }
  await writer.close();
  console.log(
    write
      ? `Done: ${changes} document(s) rewritten.`
      : `Dry run: ${changes} document(s) differ. Re-run with --write to apply.`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
