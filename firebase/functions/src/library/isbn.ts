/** Strips hyphens/spaces and upper-cases (ISBN-10 may end in X). */
export const cleanIsbn = (s: string) => s.replace(/[\s-]/g, '').toUpperCase();

export function isIsbn10(s: string): boolean {
  if (!/^\d{9}[\dX]$/.test(s)) return false;
  const sum = [...s].reduce((a, c, i) => a + (c === 'X' ? 10 : Number(c)) * (10 - i), 0);
  return sum % 11 === 0;
}

export function isIsbn13(s: string): boolean {
  if (!/^\d{13}$/.test(s)) return false;
  const sum = [...s].reduce((a, c, i) => a + Number(c) * (i % 2 ? 3 : 1), 0);
  return sum % 10 === 0;
}

/** The ISBN-13 form of a valid ISBN-10 (978 prefix, recomputed check digit). */
export function toIsbn13(isbn10: string): string {
  const body = `978${isbn10.slice(0, 9)}`;
  const sum = [...body].reduce((a, c, i) => a + Number(c) * (i % 2 ? 3 : 1), 0);
  return body + String((10 - (sum % 10)) % 10);
}
