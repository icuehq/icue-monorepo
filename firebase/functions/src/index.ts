import { initializeApp } from 'firebase-admin/app';
import './region';
import { assets, maintenance } from './inventory/assets';
import { importRun } from './inventory/import';
import { masters } from './inventory/masters';
import { copies as libraryCopies } from './library/copies';
import { rebuild as statsRebuild } from './library/stats';
import { sync, token } from './session';
import { type AnyCallableDef, callable, queryCallable, routes } from './shared/callable';

initializeApp();

export { syncItemSearch } from './inventory/search';
export { syncCatalogueSearch, syncLoanSearch } from './library/search';
export { outboxSend } from './shared/outbox';
export { dailyInventory } from './inventory/daily';
export { dailyLibrary } from './library/daily';
export { statsNightly as libraryStatsNightly } from './library/stats';
export {
  auditLibraryCatalogue,
  auditLibraryCopies,
  auditLibraryFines,
  auditLibraryIncidents,
  auditLibraryLoans,
  auditLibraryMembers,
  auditLibraryPolicies,
} from './library/audit';

// Inventory masters other than seedDefaults are written by the client or only through the importer.
const mutations: AnyCallableDef[] = [
  assets,
  maintenance,
  { seedDefaults: masters.seedDefaults },
  libraryCopies,
].flatMap((group) => Object.values(group) as AnyCallableDef[]);

// Each callable deploys as its name with dots as dashes, e.g. `inventory.purchaseOrder.receive` → `inventory-purchaseOrder-receive`.
export const { session, inventory, library } = routes([
  ['session.sync', sync],
  ['session.token', token],
  ...mutations.map((def) => [def.name, callable(def)] as [string, unknown]),
  [statsRebuild.name, queryCallable(statsRebuild)],
  ['inventory.import.run', importRun],
]);
