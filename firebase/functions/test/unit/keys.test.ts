import { describe, expect, it } from 'vitest';
import { financialYearOf } from '../../src/shared/keys';

describe('financialYearOf', () => {
  it('April starts a new financial year', () => {
    expect(financialYearOf(new Date('2026-04-01T00:00:00+05:30'))).toBe('2026-27');
    expect(financialYearOf(new Date('2027-03-31T23:59:59+05:30'))).toBe('2026-27');
  });

  it('uses IST, not UTC, at the boundary', () => {
    // 31 Mar 2026 20:00 UTC = 1 Apr 2026 01:30 IST
    expect(financialYearOf(new Date('2026-03-31T20:00:00Z'))).toBe('2026-27');
  });

  it('pads the century rollover', () => {
    expect(financialYearOf(new Date('2099-06-01T00:00:00Z'))).toBe('2099-00');
  });
});
