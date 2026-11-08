import { initializeApp } from 'firebase-admin/app';
import './region';
import { assets, maintenance } from './inventory/assets';
import { importRun } from './inventory/import';
import { masters } from './inventory/masters';
import { itemSearch } from './inventory/search';
import { verification } from './inventory/verification';
import { copies as libraryCopies } from './library/copies';
import { fines as libraryFines } from './library/fines';
import { incidents as libraryIncidents } from './library/incidents';
import { loans as libraryLoans } from './library/loans';
import { masters as libraryMasters } from './library/masters';
import { members as libraryMembers } from './library/members';
import { mockDataFill } from './library/mockData';
import { reservations as libraryReservations } from './library/reservations';
import { catalogueSearch } from './library/search';
import { sync } from './session';
import { type AnyCallableDef, callable, queryCallable, routes } from './shared/callable';

initializeApp();

export { syncItemSearch } from './inventory/search';
export { syncCatalogueSearch } from './library/search';
export { outboxSend } from './shared/outbox';
export { dailyInventory } from './inventory/daily';
export { holdExpiry } from './library/reservations';
export { dailyLibrary } from './library/daily';
export { auditLibraryCatalogue, auditLibraryCopies, auditLibraryMembers } from './library/audit';

// Inventory masters other than seedDefaults are written by the client or only through the importer.
const mutations: AnyCallableDef[] = [
  assets,
  maintenance,
  verification,
  { seedDefaults: masters.seedDefaults },
  libraryMasters,
  libraryCopies,
  libraryMembers,
  libraryLoans,
  libraryReservations,
  libraryFines,
  libraryIncidents,
]
  .flatMap((group) => Object.values(group) as AnyCallableDef[])
  // Counts are written by the client straight to the lines (rules-checked); the callable is the tests' stand-in.
  .filter((def) => def.name !== 'inventory.verification.count');

// Each callable deploys as its name with dots as dashes, e.g. `inventory.purchaseOrder.receive` → `inventory-purchaseOrder-receive`.
export const { session, inventory, library } = routes([
  ['session.sync', sync],
  ...mutations.map((def) => [def.name, callable(def)] as [string, unknown]),
  [itemSearch.name, queryCallable(itemSearch)],
  [catalogueSearch.name, queryCallable(catalogueSearch)],
  ['library.mockData.fill', mockDataFill],
  ['inventory.import.run', importRun],
]);
