import { beforeAll, describe, expect, it } from 'vitest';
import { fillMockData } from '../src/library/mockData';
import { clearFirestore, db } from './setup';

const SCHOOL = 'schools/12';
const all = async (collection: string) =>
  (await db().collection(`${SCHOOL}/${collection}`).get()).docs.map((d) => ({
    id: d.id,
    ...d.data(),
  }));

describe('library mock data', () => {
  beforeAll(async () => {
    await clearFirestore();
    await fillMockData(db(), '12', 'tester', 31);
    await fillMockData(db(), '12', 'tester', 31); // repeatable: same documents again
  });

  it('is repeatable and keeps copies, loans and members consistent', async () => {
    const copies = await all('libraryCopies');
    const loans = await all('libraryLoans');
    const members = await all('libraryMembers');
    const active = loans.filter((loan: any) => loan.status === 'active');
    // every copy that is out has exactly one active loan pointing back at it
    for (const copy of copies.filter((c: any) => c.status === 'issued'))
      expect(active.filter((l: any) => l.barcode === copy.id)).toHaveLength(1);
    expect(copies.filter((c: any) => c.activeLoanId)).toHaveLength(active.length);
    for (const member of members)
      expect((member as any).activeLoans).toBe(
        active.filter((l: any) => l.personErpId === (member as any).personErpId).length,
      );
    // every state the screens show exists
    const seen = (rows: any[], field: string) => new Set(rows.map((row) => row[field]));
    expect(seen(loans, 'status')).toEqual(new Set(['active', 'returned', 'lost']));
    expect(seen(await all('libraryFines'), 'status')).toEqual(
      new Set(['outstanding', 'partially_paid', 'paid', 'waived']),
    );
    expect(seen(await all('libraryReservations'), 'status')).toEqual(
      new Set(['waiting', 'ready', 'fulfilled', 'cancelled', 'expired']),
    );
    expect(seen(await all('libraryIncidents'), 'status')).toEqual(new Set(['open', 'resolved']));
    expect(seen(copies, 'status')).toEqual(
      new Set([
        'available',
        'issued',
        'reserved',
        'damaged',
        'lost',
        'under_maintenance',
        'withdrawn',
      ]),
    );
    // a fine's balance always adds up
    for (const fine of (await all('libraryFines')) as any[])
      expect(fine.amount - fine.paid - fine.waived).toBeCloseTo(fine.outstanding);
  });
});
