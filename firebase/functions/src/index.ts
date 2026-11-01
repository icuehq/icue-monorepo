import { initializeApp } from 'firebase-admin/app';
import './region';
import { masters } from './inventory/masters';
import { itemSearch } from './inventory/search';
import * as sessionFns from './session';
import { callable, queryCallable } from './shared/callable';

initializeApp();

// Grouped exports deploy as `<group>-<name>` (e.g. `session-sync`); callable names cannot contain dots.
export const session = { sync: sessionFns.sync };
export { onRolePermissionsChange } from './session';
export { syncItemSearch } from './inventory/search';
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
export const inv = { ...masterFns, seedDefaults: callable(masters.seedDefaults) };
