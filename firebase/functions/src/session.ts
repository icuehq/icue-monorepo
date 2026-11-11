import { getAuth } from 'firebase-admin/auth';
import { type Firestore, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { branchPath, claimsBranch } from './shared/branch';
import type { TokenClaims } from './shared/callable';
import { logged } from './shared/errors';
import { serverTimestamp } from './shared/firestore';
import { permissionsFromActions } from './shared/permissions';

const numbers = (value: unknown): number[] =>
  Array.isArray(value) ? value.map(Number).filter(Number.isFinite) : [];

const SCOPES = ['branch', 'zone', 'org'];

export async function createSessionToken(data: Record<string, unknown>, auth = getAuth()) {
  const uid = String(data.uid ?? data.personErpId ?? '');
  if (!uid)
    throw new HttpsError(
      'invalid-argument',
      'We could not identify this user. Please sign in again.',
    );
  for (const key of ['orgId', 'zoneId', 'branchId'])
    if (data[key] == null)
      throw new HttpsError(
        'invalid-argument',
        'Your account details are incomplete. Please contact your administrator.',
      );

  // A zone or corporate user is issued a token for one active branch of theirs (the switcher re-exchanges).
  const claims: Record<string, unknown> = {
    orgId: Number(data.orgId),
    zoneId: Number(data.zoneId),
    branchId: Number(data.branchId),
    scope: SCOPES.includes(String(data.scope)) ? data.scope : 'branch',
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

export const token = onCall((request) =>
  logged('session.token', {}, () =>
    createSessionToken((request.data ?? {}) as Record<string, unknown>),
  ),
);

/** Writes `<branch>/userAccess/{uid}` from the custom-token claims (architecture §3.2); permissions come from `actionIds`. */
export async function syncSession(db: Firestore, uid: string, token: TokenClaims) {
  const branch = branchPath(claimsBranch(token));
  const roleIds = numbers(token.roleIds);
  const personType = typeof token.personType === 'string' ? token.personType : null;
  const access = {
    permissions: personType === 'parent' ? [] : permissionsFromActions(token.actionIds),
    scope: typeof token.scope === 'string' ? token.scope : 'branch',
    roleIds,
    personType,
    personErpId: token.personErpId == null ? null : Number(token.personErpId),
    wardStudentIds: numbers(token.wardStudentIds),
  };
  await db.doc(`${branch}/userAccess/${uid}`).set({ ...access, updatedAt: serverTimestamp() });
  return { permissions: access.permissions, scope: access.scope };
}

export const sync = onCall((request) =>
  logged('session.sync', { uid: request.auth?.uid }, async () => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in to continue.');
    return syncSession(getFirestore(), request.auth.uid, request.auth.token);
  }),
);
