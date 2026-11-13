import { initializeApp } from 'firebase-admin/app';
import './region';
import { assets, maintenance } from './inventory/assets';
import { importRun } from './inventory/import';
import { masters } from './inventory/masters';
import { copies as libraryCopies } from './library/copies';
import { sync, token } from './session';
import { type AnyCallableDef, callable, routes } from './shared/callable';

initializeApp();

export {
  auditInventoryAdjustments,
  auditInventoryInvoices,
  auditInventoryIssueRequests,
  auditInventoryIssues,
  auditInventoryPurchaseOrders,
  auditInventoryPurchaseRequests,
  auditInventoryQuotations,
  auditInventoryReceipts,
  auditInventoryReturns,
  auditInventoryUnavailable,
} from './inventory/audit';
export { syncItemSearch } from './inventory/search';
export {
  statsInventoryAssets,
  statsInventoryBalances,
  statsInventoryItems,
} from './inventory/stats';
export { syncCatalogueSearch, syncIncidentSearch, syncLoanSearch } from './library/search';
export { outboxSend } from './shared/outbox';
export { dailyInventory } from './inventory/daily';
export { dailyLibrary } from './library/daily';
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
  ['inventory.import.run', importRun],
]);
