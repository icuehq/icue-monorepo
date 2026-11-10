import { getAuth } from 'firebase-admin/auth';
import { type Firestore, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import type { TokenClaims } from './shared/callable';
import { serverTimestamp } from './shared/firestore';
import { permissionsFromActions } from './shared/permissions';

const numbers = (value: unknown): number[] =>
  Array.isArray(value) ? value.map(Number).filter(Number.isFinite) : [];

export async function createSessionToken(data: Record<string, unknown>, auth = getAuth()) {
  const uid = String(data.uid ?? data.personErpId ?? '');
  if (!uid) throw new HttpsError('invalid-argument', 'UID required');
  if (data.schoolId == null) throw new HttpsError('invalid-argument', 'schoolId required');
  const schoolId = Number(data.schoolId);

  const claims: Record<string, unknown> = {
    schoolId,
    campusIds: numbers(data.campusIds),
    hasAllCampuses: data.hasAllCampuses === true,
    roleIds: numbers(data.roleIds),
    actionIds: numbers(data.actionIds),
    personType: typeof data.personType === 'string' ? data.personType : 'staff',
    personErpId: Number(uid),
  };
  if (Array.isArray(data.wardStudentIds)) {
    claims.wardStudentIds = numbers(data.wardStudentIds);
  }

  const customToken = await auth.createCustomToken(uid, claims);
  return { token: customToken };
}

export const token = onCall((request) => {
  return createSessionToken((request.data ?? {}) as Record<string, unknown>);
});

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
