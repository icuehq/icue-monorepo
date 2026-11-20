import { auditClientWrites } from '../shared/audit';
import { noticeFine, noticeIncident, noticeLoan } from './notices';
import { recordStats } from './stats';

const withStats = (collection: string) => (change: Parameters<typeof recordStats>[1]) =>
  recordStats(collection, change);

export const auditLibraryCatalogue = auditClientWrites(
  'libraryCatalogue',
  withStats('libraryCatalogue'),
);
export const auditLibraryCopies = auditClientWrites('libraryCopies', withStats('libraryCopies'));
export const auditLibraryMembers = auditClientWrites('libraryMembers', withStats('libraryMembers'));
export const auditLibraryPolicies = auditClientWrites('libraryBorrowingPolicies');
export const auditLibraryLoans = auditClientWrites(
  'libraryLoans',
  noticeLoan,
  withStats('libraryLoans'),
);
export const auditLibraryFines = auditClientWrites(
  'libraryFines',
  noticeFine,
  withStats('libraryFines'),
);
export const auditLibraryIncidents = auditClientWrites(
  'libraryIncidents',
  noticeIncident,
  withStats('libraryIncidents'),
);
