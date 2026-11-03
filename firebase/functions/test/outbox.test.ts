import type { BatchResponse, TokenMessage } from 'firebase-admin/messaging';
import { beforeEach, describe, expect, it } from 'vitest';
import { deliver, resolveRecipients } from '../src/shared/outbox';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';

async function user(
  uid: string,
  access: Record<string, unknown>,
  tokens: string[] = [],
  mute?: Record<string, boolean>,
) {
  await db()
    .doc(`schools/${SCHOOL_ID}/userAccess/${uid}`)
    .set({
      permissions: [],
      campusIds: [],
      hasAllCampuses: false,
      personErpId: null,
      wardStudentIds: [],
      ...access,
    });
  if (mute) await db().doc(`devices/${uid}`).set({ mute });
  for (const token of tokens) await db().doc(`devices/${uid}/tokens/${token}`).set({ token });
}

function fakeSend(sent: TokenMessage[], dead = new Set<string>()) {
  return async (messages: TokenMessage[]): Promise<BatchResponse> => {
    sent.push(...messages);
    const responses = messages.map((outboxEvent) =>
      dead.has(outboxEvent.token)
        ? { success: false, error: { code: 'messaging/registration-token-not-registered' } }
        : { success: true, messageId: 'id' },
    ) as BatchResponse['responses'];
    return {
      responses,
      successCount: responses.filter((response) => response.success).length,
      failureCount: 0,
    };
  };
}

describe('outbox', () => {
  beforeEach(async () => {
    await clearFirestore();
    await user('1', { permissions: ['inventory.stock.operate'], campusIds: [31] }, ['t1']);
    await user('2', { permissions: ['inventory.stock.operate'], campusIds: [32] }, ['t2']);
    await user(
      '3',
      { permissions: ['inventory.stock.operate'], hasAllCampuses: true },
      ['t3', 'dead'],
      { 'inventory.lowStock': false },
    );
    await user('4', { personErpId: 884 }, ['t4'], { 'inventory.lowStock': true });
    await user('parent-1', { personType: 'parent', wardStudentIds: [5521] }, ['t5']);
  });

  it('resolves recipients by permission + campus, personErpId and wardStudentIds', async () => {
    const result = (to: object) => resolveRecipients(db(), SCHOOL_ID, to).then((ids) => ids.sort());
    expect(await result({ permission: 'inventory.stock.operate', campusId: 31 })).toEqual([
      '1',
      '3',
    ]);
    expect(await result({ permission: 'inventory.stock.operate' })).toEqual(['1', '2', '3']);
    expect(await result({ personErpIds: [884] })).toEqual(['4']);
    expect(await result({ wardStudentIds: [5521, 9] })).toEqual(['parent-1']);
    expect(await result({ uids: ['x'], personErpIds: [884] })).toEqual(['4', 'x']);
  });

  it('delivers once: inbox copy per recipient, push unless muted, dead tokens removed', async () => {
    const ref = db().doc(`schools/${SCHOOL_ID}/outbox/low__b1`);
    await ref.set({
      to: { permission: 'inventory.stock.operate', campusId: 31, personErpIds: [884] },
      category: 'inventory.lowStock',
      title: 'Low stock',
      body: 'Pens',
      status: 'pending',
      createdAt: new Date(),
    });
    const sent: TokenMessage[] = [];
    await deliver(db(), SCHOOL_ID, 'low__b1', fakeSend(sent, new Set(['dead'])));

    expect(sent.map((outboxEvent) => outboxEvent.token).sort()).toEqual(['dead', 't1', 't3']); // 4 muted
    expect((await db().collection(`schools/${SCHOOL_ID}/notifications`).get()).size).toBe(3);
    expect((await db().doc('devices/3/tokens/dead').get()).exists).toBe(false);
    expect((await ref.get()).data()).toMatchObject({ status: 'sent', recipients: 3, sent: 2 });

    // A retry after a crash skips recipients already handled.
    await ref.update({ status: 'pending' });
    const again: TokenMessage[] = [];
    await deliver(db(), SCHOOL_ID, 'low__b1', fakeSend(again));
    expect(again).toEqual([]);
  });

  it('never calls FCM when running in the emulator', async () => {
    process.env.FUNCTIONS_EMULATOR = 'true';
    try {
      const ref = db().doc(`schools/${SCHOOL_ID}/outbox/emu`);
      await ref.set({
        to: { uids: ['1'] },
        category: 'x',
        title: 't',
        body: 'b',
        status: 'pending',
        createdAt: new Date(),
      });
      await deliver(db(), SCHOOL_ID, 'emu'); // default sender; real FCM would throw without credentials
      expect((await ref.get()).get('status')).toBe('sent');
    } finally {
      delete process.env.FUNCTIONS_EMULATOR;
    }
  });

  it('expires stale events without sending', async () => {
    const ref = db().doc(`schools/${SCHOOL_ID}/outbox/old`);
    await ref.set({
      to: { uids: ['1'] },
      category: 'x',
      title: 't',
      body: 'b',
      status: 'pending',
      createdAt: new Date(Date.now() - 2 * 3600e3),
    });
    const sent: TokenMessage[] = [];
    await deliver(db(), SCHOOL_ID, 'old', fakeSend(sent));
    expect(sent).toEqual([]);
    expect((await ref.get()).get('status')).toBe('expired');
  });
});
