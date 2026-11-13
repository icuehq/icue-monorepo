import { type DocumentData, FieldValue, getFirestore } from 'firebase-admin/firestore';
import type { Change } from '../shared/audit';
import { CopyStatus, LoanStatus } from '../shared/contracts';
import { timestampDay, todayIST } from '../shared/dates';
import { bump, type Counts, increments } from '../shared/statsCounts';

/**
 * Library analytics summary, kept only by the audit triggers (`audit.ts`); only `scripts/recompute-stats.ts`, run by hand, recounts it.
 *  - `libraryStats/overall`: current-state figures (LibraryStatsTotals) for the branch, and per library under `libraries`.
 *  - `libraryStats/day_yyyy-MM-dd`: that India-time day's flows (LibraryDailyTotals), same shape.
 * Overdue needs no job: active loans are counted by due date (`dueOn`) and the reader adds up the days before today.
 * Books and borrowers per library are distinct counts, tracked on the catalogue (`holdings.{libraryId}`: copies there)
 * and the member (`libraryIds`: libraries borrowed from).
 *
 * ponytail: triggers are at-least-once and not retried, so a rare redelivered event counts twice and a failed one
 * is lost; key each event (a marker per event ID) if the figures must be exact. Every write also bumps one document
 * (~1 write/s sustained), so a bulk copy import may fail a few; split per library if that becomes visible.
 */
/** Copy statuses with their own figure; under_maintenance and withdrawn share `outOfCirculation`. */
const COPY_STATUSES: string[] = [
  CopyStatus.available,
  CopyStatus.issued,
  CopyStatus.lost,
  CopyStatus.damaged,
];
const OPEN_FINE = ['outstanding', 'partially_paid'];

/** Signed amounts to add, for the branch and for each library they belong to. */
class Tally {
  branch: Counts = {};
  libraries: Record<string, Counts> = {};

  /** Adds [amount] to the branch and, when given, to the library. */
  add(key: string, amount: number, libraryId?: string) {
    bump(this.branch, key, amount);
    if (libraryId) this.addLibrary(key, amount, libraryId);
  }

  /** Adds [amount] to one library only (figures whose branch total is counted elsewhere). */
  addLibrary(key: string, amount: number, libraryId: string) {
    bump((this.libraries[libraryId] ??= {}), key, amount);
  }

  get empty() {
    return [this.branch, ...Object.values(this.libraries)].every((counts) =>
      Object.values(counts).every((amount) => !amount),
    );
  }

  /** A merge-able document of `increment`s. Never an empty map: a merge writes it as a value and wipes the field. */
  toIncrements() {
    const libraries = Object.entries(this.libraries)
      .map(([id, counts]) => [id, increments(counts)] as const)
      .filter(([, fields]) => Object.keys(fields).length);
    return {
      ...increments(this.branch),
      ...(libraries.length && { libraries: Object.fromEntries(libraries) }),
    };
  }
}

/** What each collection's write adds to the overall figures and to today's flows. */
export function deltas(collection: string, { before, after }: Change) {
  const overall = new Tally();
  const daily = new Tally();
  /** `sign` = +1 for the state a write left behind, -1 for the one it replaced. */
  const state = (data: DocumentData | undefined, sign: number) => {
    if (!data) return;
    switch (collection) {
      case 'libraryCopies':
        overall.add('copies', sign, data.libraryId);
        // Every status lands in one figure, so the figures always add up to `copies`.
        overall.add(
          COPY_STATUSES.includes(data.status) ? data.status : 'outOfCirculation',
          sign,
          data.libraryId,
        );
        break;
      case 'libraryLoans':
        if (data.status !== LoanStatus.active) break;
        overall.add('activeLoans', sign, data.libraryId);
        overall.add(`dueOn.${timestampDay(data.dueDate)}`, sign, data.libraryId);
        break;
      case 'libraryFines':
        if (OPEN_FINE.includes(data.status))
          overall.add('outstandingFines', sign * (data.outstanding ?? 0), data.libraryId);
        break;
      case 'libraryMembers':
        overall.add(data.memberType === 'EMPLOYEE' ? 'teachers' : 'students', sign);
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
    else if (before.status === LoanStatus.active && after.status === LoanStatus.returned)
      daily.add('loansReturned', 1, library);
    if (before && (after.renewals?.length ?? 0) > (before.renewals?.length ?? 0))
      daily.add('loansRenewed', 1, library);
  } else if (collection === 'libraryFines' && after) {
    if (!before) daily.add('finesRaised', after.amount ?? 0, after.libraryId);
    daily.add('finesCollected', (after.paid ?? 0) - (before?.paid ?? 0), after.libraryId);
  } else if (collection === 'libraryIncidents' && after && !before) {
    // A loan marked lost also records a lost incident, so this counts every lost book once.
    daily.add(after.type === 'lost' ? 'booksLost' : 'booksDamaged', 1, after.libraryId);
  }
  return { overall, daily };
}

/** Copies a copy write adds to or takes from each catalogue title in each library: `{catalogueId: {libraryId: n}}`. */
function holdingMoves({ before, after }: Change) {
  const moves: Record<string, Counts> = {};
  for (const [copy, sign] of [
    [after, 1],
    [before, -1],
  ] as const)
    if (copy) bump((moves[copy.catalogueId] ??= {}), copy.libraryId, sign);
  return Object.entries(moves)
    .map(
      ([id, libraries]) => [id, Object.entries(libraries).filter(([, amount]) => amount)] as const,
    )
    .filter(([, libraries]) => libraries.length);
}

/** Applies a write's effect on the analytics summary. Collections the summary ignores cost nothing. */
export async function recordStats(collection: string, change: Change): Promise<void> {
  const preview = deltas(collection, change);
  const moves = collection === 'libraryCopies' ? holdingMoves(change) : [];
  const loan = collection === 'libraryLoans' && !change.before ? change.after : undefined;
  if (preview.overall.empty && preview.daily.empty && !moves.length && !loan) return;

  const db = getFirestore();
  const stats = db.collection(`${change.branchPath}/libraryStats`);
  const titleRefs = moves.map(([id]) => db.doc(`${change.branchPath}/libraryCatalogue/${id}`));
  const memberRef = loan && db.doc(`${change.branchPath}/libraryMembers/${loan.personErpId}`);

  await db.runTransaction(async (transaction) => {
    const [member, ...titles] = await Promise.all([
      memberRef ? transaction.get(memberRef) : undefined,
      ...titleRefs.map((ref) => transaction.get(ref)),
    ]);
    // Fresh tallies on every attempt: a retried transaction must not add twice.
    const { overall, daily } = deltas(collection, change);

    titles.forEach((title, index) => {
      if (!title.exists) return;
      const holdings: Counts = title.data()?.holdings ?? {};
      const update: Counts = {};
      for (const [libraryId, amount] of moves[index][1]) {
        const held = holdings[libraryId] ?? 0;
        update[`holdings.${libraryId}`] = held + amount;
        if (held > 0 !== held + amount > 0)
          overall.addLibrary('titles', held + amount > 0 ? 1 : -1, libraryId);
      }
      transaction.update(title.ref, update);
    });

    const libraryIds: string[] = member?.data()?.libraryIds ?? [];
    if (member?.exists && loan && !libraryIds.includes(loan.libraryId)) {
      transaction.update(member.ref, { libraryIds: FieldValue.arrayUnion(loan.libraryId) });
      overall.addLibrary(
        member.data()?.memberType === 'EMPLOYEE' ? 'teachers' : 'students',
        1,
        loan.libraryId,
      );
    }

    if (!overall.empty)
      transaction.set(stats.doc('overall'), overall.toIncrements(), { merge: true });
    if (!daily.empty)
      transaction.set(stats.doc(`day_${todayIST()}`), daily.toIncrements(), { merge: true });
  });
}
