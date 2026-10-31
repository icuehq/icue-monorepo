import './region';
import { FieldValue, Firestore, getFirestore } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import type { Claims } from './shared/callable';
import { resolvePerms, type RolePermissions } from './shared/permissions';

const nums = (v: unknown): number[] => (Array.isArray(v) ? v.map(Number).filter(Number.isFinite) : []);

/** Writes `userAccess/{uid}` from the custom-token claims (architecture §3.2). */
export async function syncSession(db: Firestore, uid: string, token: Claims) {
  if (token.sid == null) throw new HttpsError('permission-denied', 'No school');
  const sid = String(token.sid);
  const config = (await db.doc(`schools/${sid}/config/rolePermissions`).get()).data() as RolePermissions | undefined;
  const rol = nums(token.rol);
  const pt = typeof token.pt === 'string' ? token.pt : null;
  const access = {
    perms: pt === 'parent' ? [] : resolvePerms(config, rol),
    cmp: nums(token.cmp),
    all: token.all === true,
    rol,
    pt,
    eid: token.eid == null ? null : Number(token.eid),
    wards: nums(token.wards),
  };
  await db.doc(`schools/${sid}/userAccess/${uid}`).set({ ...access, updatedAt: FieldValue.serverTimestamp() });
  return { perms: access.perms, cmp: access.cmp, all: access.all };
}

/** Recomputes `perms` of every user in [sid] from their stored role IDs. */
export async function recomputeSchool(db: Firestore, sid: string): Promise<number> {
  const config = (await db.doc(`schools/${sid}/config/rolePermissions`).get()).data() as RolePermissions | undefined;
  const writer = db.bulkWriter();
  let changed = 0;
  for (const d of (await db.collection(`schools/${sid}/userAccess`).get()).docs) {
    const a = d.data();
    const perms = a.pt === 'parent' ? [] : resolvePerms(config, a.rol ?? []);
    if (JSON.stringify(perms) === JSON.stringify(a.perms)) continue;
    void writer.update(d.ref, { perms, updatedAt: FieldValue.serverTimestamp() });
    changed++;
  }
  await writer.close();
  return changed;
}

export const sync = onCall((req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required');
  return syncSession(getFirestore(), req.auth.uid, req.auth.token as Claims);
});

export const onRolePermissionsChange = onDocumentWritten('schools/{sid}/config/rolePermissions', async (event) => {
  await recomputeSchool(getFirestore(), event.params.sid);
});
