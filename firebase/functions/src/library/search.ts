import { type DocumentData, type Firestore, type Timestamp } from 'firebase-admin/firestore';
import { applyChange, prefixText, syncTrigger } from '../shared/searchMirror';

export { prefixText };

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
  'libraryIds',
  'copyCount',
  'availableCopies',
  'status',
] as const;
/** The text index covers title, subtitle, authorsText, publisher, keywordsText and prefixText (`firebase/scripts/create-search-index.sh`). */

const projectRow = (catalogueDocument: DocumentData) =>
  Object.fromEntries(ROW.map((field) => [field, catalogueDocument[field] ?? null]));

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

const LOAN_ROW = [...LOAN_TEXT, 'libraryId', 'status', 'dueDate'];

/** The [row] fields of [document] plus `prefixText` of its [text] fields, so a half-typed word matches. */
const mirrorRow = (document: DocumentData, row: string[], text: string[]) => ({
  ...Object.fromEntries(row.map((field) => [field, document[field] ?? null])),
  prefixText: prefixText(...text.map((field) => document[field] ?? '')),
});

export const projectLoan = (loan: DocumentData) => mirrorRow(loan, LOAN_ROW, LOAN_TEXT);

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
const INCIDENT_ROW = [...LOAN_TEXT, 'libraryId', 'status', 'type', 'createdAt'];

export const projectIncident = (incident: DocumentData) =>
  mirrorRow(incident, INCIDENT_ROW, LOAN_TEXT);

export const syncIncidentSearch = syncTrigger(INCIDENTS, projectIncident);

/**
 * Members search mirror: whole words or typed prefixes of the member's name or admission number. `onLoan`
 * is flattened from `activeLoans` because the mirror filters only by equality.
 */
const MEMBERS = 'libraryMembers';

export const projectMember = (member: DocumentData) => ({
  name: member.name ?? null,
  admissionNumber: member.admissionNumber ?? null,
  personErpId: member.personErpId ?? null,
  memberType: member.memberType ?? null,
  libraryIds: member.libraryIds ?? [],
  blocked: member.blocked ?? false,
  onLoan: (member.activeLoans ?? 0) > 0,
  prefixText: prefixText(member.name ?? '', member.admissionNumber ?? ''),
});

export const syncLibraryMemberSearch = syncTrigger(MEMBERS, projectMember);

/** Fines search mirror: whole words or typed prefixes of the member name, admission number, book title or accession no. */
const FINES = 'libraryFines';
const FINE_TEXT = ['memberName', 'admissionNumber', 'bookTitle', 'barcode'];
const FINE_ROW = [...FINE_TEXT, 'libraryId', 'status', 'type', 'createdAt'];

export const projectFine = (fine: DocumentData) => mirrorRow(fine, FINE_ROW, FINE_TEXT);

export const syncFineSearch = syncTrigger(FINES, projectFine);
