import { onCall } from 'firebase-functions/v2/https';
import { importRows, toList, toNumber, toText, type ImportType } from '../shared/importRows';
import { copies } from './copies';
import { cleanIsbn } from './isbn';
import { masters } from './masters';

const types: Record<string, ImportType> = {
  catalogue: {
    callable: masters.catalogueUpsert,
    mapRow: async (row, lookup) => ({
      title: row.title,
      authors: toList(row.authors),
      categoryId: await lookup('libraryCategory', row.category, 'Category'),
      isbn10: toText(row.isbn10),
      isbn13: toText(row.isbn13),
      publisher: toText(row.publisher),
      edition: toText(row.edition),
      year: toNumber(row.year),
      language: toText(row.language),
      pages: toNumber(row.pages),
      classificationNumber: toText(row.classificationNumber),
      keywords: toList(row.keywords),
    }),
  },
  copies: {
    callable: copies.acquisitionCreate,
    // Existing accession numbers cannot be kept: numbers come from one school-wide counter.
    mapRow: async (row, lookup) => ({
      type: 'opening',
      catalogueId: await lookup('libraryTitle', `isbn:${cleanIsbn(row.isbn13 ?? '')}`, 'Title'),
      libraryId: await lookup('library', row.library, 'Library'),
      quantity: toNumber(row.quantity) ?? 1,
      price: toNumber(row.price),
      shelf: toText(row.shelf),
      condition: toText(row.condition)?.toLowerCase() ?? 'good',
      date: toText(row.date),
    }),
  },
};

export const runLibraryImport = (auth: Parameters<typeof importRows>[0], data: unknown) =>
  importRows(auth, data, types);

export const importRun = onCall((request) => runLibraryImport(request.auth, request.data));
