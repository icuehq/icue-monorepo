import type { Auth } from 'firebase-admin/auth';
import { describe, expect, it } from 'vitest';
import { createSessionToken } from '../../src/session';

describe('createSessionToken', () => {
  const mockAuth = {
    createCustomToken: async (uid: string, claims?: Record<string, unknown>) =>
      `mock-token-${uid}-${JSON.stringify(claims)}`,
  } as unknown as Auth;

  it('mints token with custom claims', async () => {
    const result = await createSessionToken(
      {
        uid: '884',
        orgId: 8,
        zoneId: 147,
        branchId: 427,
        roleIds: [4],
        actionIds: [100, 101],
      },
      mockAuth,
    );
    expect(result.token).toContain('mock-token-884');
    expect(result.token).toContain('"orgId":8');
    expect(result.token).toContain('"zoneId":147');
    expect(result.token).toContain('"branchId":427');
    expect(result.token).toContain('"scope":"branch"');
  });

  it('rejects missing uid or branch', async () => {
    await expect(createSessionToken({}, mockAuth)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
    await expect(createSessionToken({ uid: '1' }, mockAuth)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
  });
});
