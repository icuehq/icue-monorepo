import { initializeApp } from 'firebase-admin/app';
import './region';
import { masters } from './inventory/masters';
import { orders } from './inventory/orders';
import { procurement } from './inventory/procurement';
import { invoices, receiving } from './inventory/receiving';
import { stock } from './inventory/stock-ops';
import { itemSearch } from './inventory/search';
import { masters as libMasters } from './library/masters';
import { catalogueSearch } from './library/search';
import * as sessionFns from './session';
import { callable, queryCallable } from './shared/callable';

initializeApp();

// Grouped exports deploy as `<group>-<name>` (e.g. `session-sync`); callable names cannot contain dots.
export const session = { sync: sessionFns.sync };
export { onRolePermissionsChange } from './session';
export { syncItemSearch } from './inventory/search';
export { syncCatalogueSearch } from './library/search';
export { outboxSend } from './shared/outbox';

const masterFns = {
  category: { upsert: callable(masters.categoryUpsert), setStatus: callable(masters.categorySetStatus) },
  unit: { upsert: callable(masters.unitUpsert) },
  item: {
    upsert: callable(masters.itemUpsert),
    setStatus: callable(masters.itemSetStatus),
    search: queryCallable(itemSearch),
  },
  variant: { upsert: callable(masters.variantUpsert) },
  store: { upsert: callable(masters.storeUpsert), setStatus: callable(masters.storeSetStatus) },
};
const stockFns = {
  receipt: { confirm: callable(stock.receiptConfirm) },
  issueRequest: { submit: callable(stock.issueRequestSubmit), decide: callable(stock.issueRequestDecide) },
  issue: { create: callable(stock.issueCreate), acknowledge: callable(stock.issueAcknowledge) },
  return: { create: callable(stock.returnCreate) },
  transfer: {
    request: callable(stock.transferRequest),
    dispatch: callable(stock.transferDispatch),
    receive: callable(stock.transferReceive),
  },
  adjustment: { create: callable(stock.adjustmentCreate) },
  unavailable: { report: callable(stock.unavailableReport), resolve: callable(stock.unavailableResolve) },
};
const procurementFns = {
  vendor: { upsert: callable(procurement.vendorUpsert), setStatus: callable(procurement.vendorSetStatus) },
  pr: {
    save: callable(procurement.prSave),
    submit: callable(procurement.prSubmit),
    decide: callable(procurement.prDecide),
    cancel: callable(procurement.prCancel),
  },
  quotation: { save: callable(orders.quotationSave), select: callable(orders.quotationSelect) },
  po: {
    save: callable(orders.poSave),
    issue: callable(orders.poIssue),
    revise: callable(orders.poRevise),
    acknowledge: callable(orders.poAcknowledge),
    cancel: callable(orders.poCancel),
    close: callable(orders.poClose),
    receive: callable(receiving.poReceive),
  },
  invoice: {
    save: callable(invoices.invoiceSave),
    setPayment: callable(invoices.invoiceSetPayment),
    cancel: callable(invoices.invoiceCancel),
  },
};
export const inv = { ...masterFns, ...stockFns, ...procurementFns, seedDefaults: callable(masters.seedDefaults) };

export const lib = {
  library: { upsert: callable(libMasters.libraryUpsert), setStatus: callable(libMasters.librarySetStatus) },
  category: { upsert: callable(libMasters.categoryUpsert), setStatus: callable(libMasters.categorySetStatus) },
  catalogue: {
    upsert: callable(libMasters.catalogueUpsert),
    setStatus: callable(libMasters.catalogueSetStatus),
    search: queryCallable(catalogueSearch),
  },
  seedDefaults: callable(libMasters.seedDefaults),
};
