import './region';
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import type { TokenClaims } from './shared/callable';
import { resolvePerms, type RolePermissions } from './shared/permissions';
import { serverTimestamp } from './shared/firestore';

const numbers = (value: unknown): number[] => (Array.isArray(value) ? value.map(Number).filter(Number.isFinite) : []);

/** Writes `userAccess/{uid}` from the custom-token claims (architecture §3.2). */
export async function syncSession(db: Firestore, uid: string, token: TokenClaims) {
  if (token.schoolId == null) throw new HttpsError('permission-denied', 'No school');
  const schoolId = String(token.schoolId);
  const config = (await db.doc(`schools/${schoolId}/config/rolePermissions`).get()).data() as RolePermissions | undefined;
  const roleIds = numbers(token.roleIds);
  const personType = typeof token.personType === 'string' ? token.personType : null;
  const access = {
    permissions: personType === 'parent' ? [] : resolvePerms(config, roleIds),
    campusIds: numbers(token.campusIds),
    hasAllCampuses: token.hasAllCampuses === true,
    roleIds,
    personType,
    personErpId: token.personErpId == null ? null : Number(token.personErpId),
    wardStudentIds: numbers(token.wardStudentIds),
  };
  await db.doc(`schools/${schoolId}/userAccess/${uid}`).set({ ...access, updatedAt: serverTimestamp() });
  return { permissions: access.permissions, campusIds: access.campusIds, hasAllCampuses: access.hasAllCampuses };
}

/** Recomputes `permissions` of every user in [schoolId] from their stored role IDs. */
export async function recomputeSchool(db: Firestore, schoolId: string): Promise<number> {
  const config = (await db.doc(`schools/${schoolId}/config/rolePermissions`).get()).data() as RolePermissions | undefined;
  const writer = db.bulkWriter();
  let changed = 0;
  for (const snapshot of (await db.collection(`schools/${schoolId}/userAccess`).get()).docs) {
    const userAccess = snapshot.data();
    const permissions = userAccess.personType === 'parent' ? [] : resolvePerms(config, userAccess.roleIds ?? []);
    if (JSON.stringify(permissions) === JSON.stringify(userAccess.permissions)) continue;
    void writer.update(snapshot.ref, { permissions, updatedAt: serverTimestamp() });
    changed++;
  }
  await writer.close();
  return changed;
}

export const sync = onCall((request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
  return syncSession(getFirestore(), request.auth.uid, request.auth.token as TokenClaims);
});

export const onRolePermissionsChange = onDocumentWritten('schools/{schoolId}/config/rolePermissions', async (event) => {
  await recomputeSchool(getFirestore(), event.params.schoolId);
});
