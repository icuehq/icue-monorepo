import { type DocumentData, type Firestore, type Timestamp } from 'firebase-admin/firestore';
import { applyChange, syncTrigger } from '../shared/searchMirror';

/** Catalogue search mirror (FRS 11.4): same pattern as inventory items (architecture §10). */
const COLL = 'libraryCatalogue';
const ROW = [
  'title',
  'subtitle',
  'authors',
  'publisher',
  'year',
  'language',
  'categoryId',
  'classIds',
  'status',
] as const;
/** The text index covers title, subtitle, authorsText, publisher, keywordsText and prefixText (`firebase/scripts/create-search-index.sh`). */

const projectRow = (catalogueDocument: DocumentData) =>
  Object.fromEntries(ROW.map((field) => [field, catalogueDocument[field] ?? null]));

const MIN_PREFIX = 3;

/**
 * Every prefix of at least [MIN_PREFIX] letters of each word, so a half-typed word matches: the text index
 * only matches whole words. 'Marigold' gives 'mar mari marig marigo marigol' (the full word is indexed already).
 */
export const prefixText = (...texts: string[]) =>
  [
    ...new Set(
      texts
        .join(' ')
        .toLowerCase()
        .split(/[^\p{L}\p{N}]+/u)
        .flatMap((word) =>
          Array.from({ length: Math.max(0, word.length - MIN_PREFIX) }, (_, index) =>
            word.slice(0, MIN_PREFIX + index),
          ),
        ),
    ),
  ].join(' ');

/** The list-row fields plus flat text copies of the array fields, which the text index needs. */
export const projectCatalogue = (catalogueDocument: DocumentData) => {
  const authorsText = (catalogueDocument.authors ?? []).join(' ');
  const keywordsText = (catalogueDocument.keywords ?? []).join(' ');
  return {
    ...projectRow(catalogueDocument),
    authorsText,
    keywordsText,
    prefixText: prefixText(
      catalogueDocument.title ?? '',
      catalogueDocument.subtitle ?? '',
      authorsText,
      catalogueDocument.publisher ?? '',
      keywordsText,
    ),
  };
};

export const applyCatalogueChange = (
  branchPath: string,
  catalogueId: string,
  after: DocumentData | undefined,
  changedAt?: Timestamp,
  db?: Firestore,
) => applyChange(COLL, projectCatalogue, branchPath, catalogueId, after, changedAt, db);

export const syncCatalogueSearch = syncTrigger(COLL, projectCatalogue);

/** Issue Books search mirror (loans): whole words of the book title, member name or admission number. */
const LOANS = 'libraryLoans';
const LOAN_TEXT = ['bookTitle', 'memberName', 'admissionNumber'];

const LOAN_ROW = [...LOAN_TEXT, 'status', 'dueDate'];

export const projectLoan = (loan: DocumentData) =>
  Object.fromEntries(LOAN_ROW.map((field) => [field, loan[field] ?? null]));

export const applyLoanChange = (
  branchPath: string,
  loanId: string,
  after: DocumentData | undefined,
  changedAt?: Timestamp,
  db?: Firestore,
) => applyChange(LOANS, projectLoan, branchPath, loanId, after, changedAt, db);

export const syncLoanSearch = syncTrigger(LOANS, projectLoan);

/** Lost & Damaged search mirror (incidents): whole words of the book title, member name or admission number. */
const INCIDENTS = 'libraryIncidents';
const INCIDENT_ROW = [...LOAN_TEXT, 'status', 'type', 'createdAt'];

export const projectIncident = (incident: DocumentData) =>
  Object.fromEntries(INCIDENT_ROW.map((field) => [field, incident[field] ?? null]));

export const syncIncidentSearch = syncTrigger(INCIDENTS, projectIncident);
