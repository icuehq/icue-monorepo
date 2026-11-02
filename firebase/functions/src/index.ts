import { initializeApp } from 'firebase-admin/app';
import './region';
import { assets, maintenance } from './inventory/assets';
import { importRun } from './inventory/import';
import { masters } from './inventory/masters';
import { orders } from './inventory/orders';
import { receiving } from './inventory/receiving';
import { itemSearch } from './inventory/search';
import { stock } from './inventory/stock-operations';
import { verification } from './inventory/verification';
import { copies as libraryCopies } from './library/copies';
import { fines as libraryFines } from './library/fines';
import { importRun as libraryImportRun } from './library/import';
import { incidents as libraryIncidents } from './library/incidents';
import { loans as libraryLoans } from './library/loans';
import { masters as libraryMasters } from './library/masters';
import { members as libraryMembers } from './library/members';
import { reservations as libraryReservations } from './library/reservations';
import { catalogueSearch } from './library/search';
import { transfers as libraryTransfers } from './library/transfers';
import { verification as libraryVerification } from './library/verification';
import * as sessionFns from './session';
import { callable, queryCallable } from './shared/callable';

initializeApp();

// Grouped exports deploy as `<group>-<name>` (e.g. `session-sync`); callable names cannot contain dots.
export const session = { sync: sessionFns.sync };
export { syncItemSearch } from './inventory/search';
export { syncCatalogueSearch } from './library/search';
export { outboxSend } from './shared/outbox';
export { dailyInventory } from './inventory/daily';
export { holdExpiry } from './library/reservations';
export { dailyLibrary } from './library/daily';

const masterFns = {
  item: { search: queryCallable(itemSearch) },
};
const stockFns = {
  receipt: { confirm: callable(stock.receiptConfirm) },
  issueRequest: {
    submit: callable(stock.issueRequestSubmit),
    decide: callable(stock.issueRequestDecide),
  },
  issue: { create: callable(stock.issueCreate), acknowledge: callable(stock.issueAcknowledge) },
  return: { create: callable(stock.returnCreate) },
  transfer: {
    request: callable(stock.transferRequest),
    dispatch: callable(stock.transferDispatch),
    receive: callable(stock.transferReceive),
  },
  adjustment: { create: callable(stock.adjustmentCreate) },
  unavailable: {
    report: callable(stock.unavailableReport),
    resolve: callable(stock.unavailableResolve),
  },
};
const procurementFns = {
  purchaseOrder: {
    save: callable(orders.purchaseOrderSave),
    issue: callable(orders.purchaseOrderIssue),
    revise: callable(orders.purchaseOrderRevise),
    acknowledge: callable(orders.purchaseOrderAcknowledge),
    cancel: callable(orders.purchaseOrderCancel),
    close: callable(orders.purchaseOrderClose),
    receive: callable(receiving.purchaseOrderReceive),
  },
};
const assetFns = {
  asset: {
    register: callable(assets.register),
    assign: callable(assets.assign),
    transfer: callable(assets.transfer),
    return: callable(assets.return),
    setCondition: callable(assets.setCondition),
    setRfid: callable(assets.setRfid),
    retire: callable(assets.retire),
  },
  maintenance: { save: callable(maintenance.save), setStatus: callable(maintenance.setStatus) },
};
const verificationFns = {
  verification: {
    create: callable(verification.create),
    count: callable(verification.count),
    submit: callable(verification.submit),
    decide: callable(verification.decide),
  },
};
export const inventory = {
  ...masterFns,
  ...stockFns,
  ...procurementFns,
  ...assetFns,
  ...verificationFns,
  seedDefaults: callable(masters.seedDefaults),
  import: { run: importRun },
};

export const library = {
  catalogue: {
    upsert: callable(libraryMasters.catalogueUpsert),
    setStatus: callable(libraryMasters.catalogueSetStatus),
    search: queryCallable(catalogueSearch),
  },
  seedDefaults: callable(libraryMasters.seedDefaults),
  import: { run: libraryImportRun },
  acquisition: { create: callable(libraryCopies.acquisitionCreate) },
  copy: {
    update: callable(libraryCopies.copyUpdate),
    move: callable(libraryCopies.copyMove),
    setStatus: callable(libraryCopies.copySetStatus),
  },
  policy: {
    upsert: callable(libraryMembers.policyUpsert),
    setStatus: callable(libraryMembers.policySetStatus),
  },
  member: {
    upsert: callable(libraryMembers.memberUpsert),
    setStatus: callable(libraryMembers.memberSetStatus),
  },
  loan: {
    issue: callable(libraryLoans.loanIssue),
    return: callable(libraryLoans.loanReturn),
    renew: callable(libraryLoans.loanRenew),
    markLost: callable(libraryLoans.loanMarkLost),
  },
  reservation: {
    create: callable(libraryReservations.reservationCreate),
    cancel: callable(libraryReservations.reservationCancel),
  },
  fine: {
    waive: callable(libraryFines.fineWaive),
    setPayment: callable(libraryFines.fineSetPayment),
  },
  incident: {
    report: callable(libraryIncidents.incidentReport),
    resolve: callable(libraryIncidents.resolve),
  },
  transfer: {
    request: callable(libraryTransfers.transferRequest),
    approve: callable(libraryTransfers.transferApprove),
    dispatch: callable(libraryTransfers.transferDispatch),
    receive: callable(libraryTransfers.transferReceive),
  },
  verification: {
    create: callable(libraryVerification.verificationCreate),
    scan: callable(libraryVerification.verificationScan),
    submit: callable(libraryVerification.verificationSubmit),
    approve: callable(libraryVerification.verificationApprove),
  },
};
