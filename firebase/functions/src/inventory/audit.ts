import { auditClientWrites } from '../shared/audit';
import { recordStats } from './stats';

const withStats = (collection: string) => (change: Parameters<typeof recordStats>[1]) =>
  recordStats(collection, change);

/** Audit log for the inventory records the client writes directly (`StockWrites`, `ProcurementWrites`). Code-keyed masters, balances and the ledger are not audited. */
export const auditInventoryIssueRequests = auditClientWrites(
  'inventoryIssueRequests',
  withStats('inventoryIssueRequests'),
);
export const auditInventoryIssues = auditClientWrites('inventoryIssues');
export const auditInventoryReturns = auditClientWrites('inventoryReturns');
export const auditInventoryReceipts = auditClientWrites('inventoryReceipts');
export const auditInventoryAdjustments = auditClientWrites('inventoryAdjustments');
export const auditInventoryUnavailable = auditClientWrites('inventoryUnavailableStock');
export const auditInventoryPurchaseRequests = auditClientWrites(
  'inventoryPurchaseRequests',
  withStats('inventoryPurchaseRequests'),
);
export const auditInventoryQuotations = auditClientWrites('inventoryQuotations');
export const auditInventoryPurchaseOrders = auditClientWrites(
  'inventoryPurchaseOrders',
  withStats('inventoryPurchaseOrders'),
);
export const auditInventoryInvoices = auditClientWrites('inventoryInvoices');
