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
/** The text index covers title, subtitle, authorsText, publisher and keywordsText (`firebase/scripts/create-search-index.sh`). */

const projectRow = (catalogueDocument: DocumentData) =>
  Object.fromEntries(ROW.map((field) => [field, catalogueDocument[field] ?? null]));

/** The list-row fields plus flat text copies of the array fields, which the text index needs. */
export const projectCatalogue = (catalogueDocument: DocumentData) => ({
  ...projectRow(catalogueDocument),
  authorsText: (catalogueDocument.authors ?? []).join(' '),
  keywordsText: (catalogueDocument.keywords ?? []).join(' '),
});

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
