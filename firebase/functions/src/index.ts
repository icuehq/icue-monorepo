import { initializeApp } from 'firebase-admin/app';
import './region';
import * as sessionFns from './session';

initializeApp();

// Grouped exports deploy as `<group>-<name>` (e.g. `session-sync`); callable names cannot contain dots.
export const session = { sync: sessionFns.sync };
export { onRolePermissionsChange } from './session';
export { outboxSend } from './shared/outbox';
