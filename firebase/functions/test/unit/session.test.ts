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
        schoolId: 12,
        campusIds: [31],
        roleIds: [4],
        actionIds: [100, 101],
      },
      mockAuth,
    );
    expect(result.token).toContain('mock-token-884');
    expect(result.token).toContain('"schoolId":12');
    expect(result.token).toContain('"campusIds":[31]');
  });

  it('rejects missing uid or schoolId', async () => {
    await expect(createSessionToken({}, mockAuth)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
    await expect(createSessionToken({ uid: '1' }, mockAuth)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
  });
});
