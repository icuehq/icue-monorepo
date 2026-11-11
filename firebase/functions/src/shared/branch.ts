import { HttpsError } from 'firebase-functions/v2/https';

/** The org → zone → branch a document lives under; the branch is the tenant. */
export interface Branch {
  orgId: string;
  zoneId: string;
  branchId: string;
}

/** Firestore path of a branch: `orgs/{orgId}/zones/{zoneId}/branches/{branchId}`. */
export const branchPath = ({ orgId, zoneId, branchId }: Branch) =>
  `orgs/${orgId}/zones/${zoneId}/branches/${branchId}`;

/** Trigger path prefix; its `{orgId}/{zoneId}/{branchId}` params rebuild the path with [branchPathOf]. */
export const BRANCH_TRIGGER = 'orgs/{orgId}/zones/{zoneId}/branches/{branchId}';

export const branchPathOf = (params: Record<string, string>) =>
  branchPath(params as unknown as Branch);

/** The branch a verified token was issued for; callers must be signed in to one. */
export function claimsBranch(token: Record<string, unknown>): Branch {
  const { orgId, zoneId, branchId } = token;
  if (orgId == null || zoneId == null || branchId == null)
    throw new HttpsError(
      'permission-denied',
      'Your account is not linked to a branch. Please contact your administrator.',
    );
  return { orgId: String(orgId), zoneId: String(zoneId), branchId: String(branchId) };
}

export const claimsBranchPath = (token: Record<string, unknown>) => branchPath(claimsBranch(token));
