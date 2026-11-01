/**
 * Seeds `schools/{schoolId}/config/rolePermissions` from the FRS §12 default matrix.
 *
 *   npm run seed -- --project dev --school 12 --roles admin=4,principal=9,teacher=7
 *
 * Role names: see DEFAULT_ROLES. Uses Application Default Credentials, or the
 * emulator when FIRESTORE_EMULATOR_HOST is set. Refuses to overwrite unless --force.
 */
import { readFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { DEFAULT_ROLES } from '../src/shared/permissions';

const { values } = parseArgs({
  options: {
    project: { type: 'string' },
    school: { type: 'string' },
    roles: { type: 'string' },
    force: { type: 'boolean', default: false },
  },
});
if (!values.project || !values.school || !values.roles) {
  throw new Error('Usage: --project <alias|id> --school <schoolId> --roles name=roleId,...');
}
const aliases = JSON.parse(readFileSync(`${__dirname}/../../.firebaserc`, 'utf8')).projects as Record<string, string>;
const projectId = aliases[values.project] ?? values.project;

const roles: Record<string, string[]> = {};
for (const pair of values.roles.split(',')) {
  const [name, id] = pair.split('=').map((part) => part.trim());
  if (!DEFAULT_ROLES[name] || !id) throw new Error(`Unknown role "${name}" (known: ${Object.keys(DEFAULT_ROLES)})`);
  roles[id] = [...new Set([...(roles[id] ?? []), ...DEFAULT_ROLES[name]])].sort();
}

void (async () => {
  initializeApp({ projectId });
  const db = getFirestore();
  const ref = db.doc(`schools/${values.school}/config/rolePermissions`);
  const before = (await ref.get()).data();
  if (before && !values.force) throw new Error(`${ref.path} exists in ${projectId}; pass --force to overwrite`);
  const batch = db.batch();
  batch.set(ref, { roles, updatedAt: FieldValue.serverTimestamp() });
  batch.set(db.collection(`schools/${values.school}/auditLogs`).doc(), {
    actor: 'seed',
    action: 'config.rolePermissions.seed',
    ref: ref.path,
    before: before ?? null,
    after: { roles },
    reason: null,
    at: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.log(`Seeded ${ref.path} in ${projectId}`);
})();
