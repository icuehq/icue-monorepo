import { type Firestore, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import type { TokenClaims } from './shared/callable';
import { serverTimestamp } from './shared/firestore';
import { permissionsFromActions } from './shared/permissions';

const numbers = (value: unknown): number[] =>
  Array.isArray(value) ? value.map(Number).filter(Number.isFinite) : [];

/** Writes `userAccess/{uid}` from the custom-token claims (architecture §3.2); permissions come from `actionIds`. */
export async function syncSession(db: Firestore, uid: string, token: TokenClaims) {
  if (token.schoolId == null) throw new HttpsError('permission-denied', 'No school');
  const schoolId = String(token.schoolId);
  const roleIds = numbers(token.roleIds);
  const personType = typeof token.personType === 'string' ? token.personType : null;
  const access = {
    permissions: personType === 'parent' ? [] : permissionsFromActions(token.actionIds),
    campusIds: numbers(token.campusIds),
    hasAllCampuses: token.hasAllCampuses === true,
    roleIds,
    personType,
    personErpId: token.personErpId == null ? null : Number(token.personErpId),
    wardStudentIds: numbers(token.wardStudentIds),
  };
  await db
    .doc(`schools/${schoolId}/userAccess/${uid}`)
    .set({ ...access, updatedAt: serverTimestamp() });
  return {
    permissions: access.permissions,
    campusIds: access.campusIds,
    hasAllCampuses: access.hasAllCampuses,
  };
}

export const sync = onCall((request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
  return syncSession(getFirestore(), request.auth.uid, request.auth.token);
});
