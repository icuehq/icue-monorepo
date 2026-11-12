import {
  AggregateField,
  type DocumentData,
  FieldValue,
  getFirestore,
  type Query,
} from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { z } from 'zod';
import type { QueryDef } from '../shared/callable';
import { dayTimestamp, todayIST } from '../shared/dates';
import { schoolCollection } from '../shared/firestore';
import { forEachBranch } from '../shared/scheduled';
import type { Change } from './notices';

/**
 * Library analytics summary. The dashboard reads two documents instead of counting every collection:
 *  - `libraryStats/overall`: current-state figures (LibraryStatsTotals) for the branch, and per library under `libraries`.
 *  - `libraryStats/day_yyyy-MM-dd`: that India-time day's flows (LibraryDailyTotals), same shape.
 * A month is the sum of its day documents (one range query on the document ID), so no monthly document exists.
 *
 * The audit trigger of each collection calls [recordStats] with the write's before/after, which adds the difference
 * with `increment`. A redelivered trigger would count twice and a loan turning overdue is no write at all, so the
 * nightly [rebuildStats] recounts the overall document from the data and corrects both.
 * ponytail: every copy write bumps one hot document (~1 write/s sustained), so a 200-copy import may lose a few
 * increments until the nightly rebuild; shard the document if imports must be exact at once.
 */
type Counts = Record<string, number>;

/** Copy statuses the dashboard shows; other statuses only count towards `copies`. */
const COPY_STATUSES = ['available', 'issued', 'lost', 'damaged'];
const OPEN_FINE = ['outstanding', 'partially_paid'];

/** Signed amounts to add, for the branch and for each library they belong to. */
class Tally {
  branch: Counts = {};
  libraries: Record<string, Counts> = {};

  /** Adds [amount] to the branch and, when given, to the library. */
  add(key: string, amount: number, libraryId?: string) {
    if (!amount) return;
    this.branch[key] = (this.branch[key] ?? 0) + amount;
    if (!libraryId) return;
    const library = (this.libraries[libraryId] ??= {});
    library[key] = (library[key] ?? 0) + amount;
  }

  get empty() {
    return Object.keys(this.branch).length === 0;
  }

  /** A merge-able document of `increment`s. */
  toIncrements() {
    const increments = (counts: Counts) =>
      Object.fromEntries(Object.entries(counts).map(([key, n]) => [key, FieldValue.increment(n)]));
    return {
      ...increments(this.branch),
      libraries: Object.fromEntries(
        Object.entries(this.libraries).map(([id, counts]) => [id, increments(counts)]),
      ),
    };
  }
}

const isOverdue = (loan: DocumentData | undefined, today: string) =>
  loan?.status === 'active' && loan.dueDate.toMillis() < dayTimestamp(today).toMillis();

/** What each collection's write adds to the overall figures and to today's flows. */
function deltas(collection: string, { before, after }: Change, today: string) {
  const overall = new Tally();
  const daily = new Tally();
  /** `sign` = +1 for the state a write left behind, -1 for the one it replaced. */
  const state = (data: DocumentData | undefined, sign: number) => {
    if (!data) return;
    switch (collection) {
      case 'libraryCopies':
        overall.add('copies', sign, data.libraryId);
        if (COPY_STATUSES.includes(data.status)) overall.add(data.status, sign, data.libraryId);
        break;
      case 'libraryLoans':
        if (data.status === 'active') overall.add('activeLoans', sign, data.libraryId);
        if (isOverdue(data, today)) overall.add('overdue', sign, data.libraryId);
        break;
      case 'libraryFines':
        if (OPEN_FINE.includes(data.status))
          overall.add('outstandingFines', sign * (data.outstanding ?? 0), data.libraryId);
        break;
      case 'libraryMembers':
        overall.add(data.memberType === 'teacher' ? 'teachers' : 'students', sign);
        break;
      case 'libraryCatalogue':
        overall.add('titles', sign);
        break;
    }
  };
  state(after, 1);
  state(before, -1);

  if (collection === 'libraryLoans' && after) {
    const library = after.libraryId;
    if (!before) daily.add('loansIssued', 1, library);
    else if (before.status === 'active' && after.status === 'returned')
      daily.add('loansReturned', 1, library);
    else if (before.status === 'active' && after.status === 'lost')
      daily.add('loansLost', 1, library);
    if (before && (after.renewals?.length ?? 0) > (before.renewals?.length ?? 0))
      daily.add('loansRenewed', 1, library);
  } else if (collection === 'libraryFines' && after) {
    if (!before) daily.add('finesRaised', after.amount ?? 0, after.libraryId);
    daily.add('finesCollected', (after.paid ?? 0) - (before?.paid ?? 0), after.libraryId);
  } else if (collection === 'libraryIncidents' && after && !before) {
    daily.add('incidents', 1, after.libraryId);
  }
  return { overall, daily };
}

/** Applies a write's effect on the analytics summary. Collections the summary ignores cost nothing. */
export async function recordStats(collection: string, change: Change): Promise<void> {
  const today = todayIST();
  const { overall, daily } = deltas(collection, change, today);
  if (overall.empty && daily.empty) return;
  const db = getFirestore();
  const batch = db.batch();
  if (!overall.empty)
    batch.set(db.doc(`${change.branchPath}/libraryStats/overall`), overall.toIncrements(), {
      merge: true,
    });
  if (!daily.empty)
    batch.set(db.doc(`${change.branchPath}/libraryStats/day_${today}`), daily.toIncrements(), {
      merge: true,
    });
  await batch.commit();
}

/** Counts of one library (or the whole branch) straight from the data. */
async function recount(branchPath: string, today: string, libraryId?: string) {
  const scoped = (name: string) => {
    const collection = schoolCollection(branchPath, name);
    return libraryId ? collection.where('libraryId', '==', libraryId) : collection;
  };
  const count = async (query: Query) => (await query.count().get()).data().count;
  const copies = scoped('libraryCopies');
  const active = scoped('libraryLoans').where('status', '==', 'active');
  const [total, activeLoans, overdue, fines, ...byStatus] = await Promise.all([
    count(copies),
    count(active),
    count(active.where('dueDate', '<', dayTimestamp(today))),
    scoped('libraryFines')
      .where('status', 'in', OPEN_FINE)
      .aggregate({ sum: AggregateField.sum('outstanding') })
      .get(),
    ...COPY_STATUSES.map((status) => count(copies.where('status', '==', status))),
  ]);
  const [available, issued, lost, damaged] = byStatus;
  return {
    copies: total,
    available,
    issued,
    lost,
    damaged,
    activeLoans,
    overdue,
    outstandingFines: fines.data().sum,
  };
}

/** Recounts the overall document of a branch from the data (the nightly job and the one-time backfill). */
export async function rebuildStats(branchPath: string, today = todayIST()): Promise<void> {
  const libraries = await schoolCollection(branchPath, 'libraries').select().get();
  const [branch, titles, students, teachers, ...perLibrary] = await Promise.all([
    recount(branchPath, today),
    schoolCollection(branchPath, 'libraryCatalogue').count().get(),
    schoolCollection(branchPath, 'libraryMembers')
      .where('memberType', '==', 'student')
      .count()
      .get(),
    schoolCollection(branchPath, 'libraryMembers')
      .where('memberType', '==', 'teacher')
      .count()
      .get(),
    ...libraries.docs.map((library) => recount(branchPath, today, library.id)),
  ]);
  await getFirestore()
    .doc(`${branchPath}/libraryStats/overall`)
    .set({
      ...branch,
      titles: titles.data().count,
      students: students.data().count,
      teachers: teachers.data().count,
      libraries: Object.fromEntries(
        libraries.docs.map((library, index) => [library.id, perLibrary[index]]),
      ),
    });
}

/** 00:10 IST, every school: recount, which also makes the new day's overdue loans show. */
export const statsNightly = onSchedule(
  { schedule: '10 0 * * *', timeZone: 'Asia/Kolkata', timeoutSeconds: 540 },
  async () => {
    await forEachBranch((branchPath) => rebuildStats(branchPath));
  },
);

/** Builds the summary on demand (first deploy, or after a restore). */
export const rebuild: QueryDef<z.ZodObject<Record<string, never>>, { ok: true }> = {
  name: 'library.stats.rebuild',
  input: z.object({}),
  handler: async (branchPath) => {
    await rebuildStats(branchPath);
    return { ok: true };
  },
};
