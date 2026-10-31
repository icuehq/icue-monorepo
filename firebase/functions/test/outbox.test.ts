import type { BatchResponse, TokenMessage } from 'firebase-admin/messaging';
import { beforeEach, describe, expect, it } from 'vitest';
import { deliver, resolveRecipients } from '../src/shared/outbox';
import { clearFirestore, db } from './setup';

const SID = '12';

async function user(uid: string, access: Record<string, unknown>, tokens: string[] = [], mute?: Record<string, boolean>) {
  await db().doc(`schools/${SID}/userAccess/${uid}`).set({ perms: [], cmp: [], all: false, eid: null, wards: [], ...access });
  if (mute) await db().doc(`devices/${uid}`).set({ mute });
  for (const t of tokens) await db().doc(`devices/${uid}/tokens/${t}`).set({ token: t });
}

function fakeSend(sent: TokenMessage[], dead = new Set<string>()) {
  return async (m: TokenMessage[]): Promise<BatchResponse> => {
    sent.push(...m);
    const responses = m.map((x) =>
      dead.has(x.token)
        ? { success: false, error: { code: 'messaging/registration-token-not-registered' } }
        : { success: true, messageId: 'id' },
    ) as BatchResponse['responses'];
    return { responses, successCount: responses.filter((r) => r.success).length, failureCount: 0 };
  };
}

describe('outbox', () => {
  beforeEach(async () => {
    await clearFirestore();
    await user('u_1', { perms: ['inv.stock.operate'], cmp: [31] }, ['t1']);
    await user('u_2', { perms: ['inv.stock.operate'], cmp: [32] }, ['t2']);
    await user('u_3', { perms: ['inv.stock.operate'], all: true }, ['t3', 'dead'], { 'inv.lowStock': false });
    await user('u_4', { eid: 884 }, ['t4'], { 'inv.lowStock': true });
    await user('p_1', { pt: 'parent', wards: [5521] }, ['t5']);
  });

  it('resolves recipients by permission + campus, eid and wards', async () => {
    const r = (to: object) => resolveRecipients(db(), SID, to).then((x) => x.sort());
    expect(await r({ perm: 'inv.stock.operate', campusId: 31 })).toEqual(['u_1', 'u_3']);
    expect(await r({ perm: 'inv.stock.operate' })).toEqual(['u_1', 'u_2', 'u_3']);
    expect(await r({ eids: [884] })).toEqual(['u_4']);
    expect(await r({ wards: [5521, 9] })).toEqual(['p_1']);
    expect(await r({ uids: ['x'], eids: [884] })).toEqual(['u_4', 'x']);
  });

  it('delivers once: inbox copy per recipient, push unless muted, dead tokens removed', async () => {
    const ref = db().doc(`schools/${SID}/outbox/low__b1`);
    await ref.set({
      to: { perm: 'inv.stock.operate', campusId: 31, eids: [884] },
      category: 'inv.lowStock',
      title: 'Low stock',
      body: 'Pens',
      status: 'pending',
      createdAt: new Date(),
    });
    const sent: TokenMessage[] = [];
    await deliver(db(), SID, 'low__b1', fakeSend(sent, new Set(['dead'])));

    expect(sent.map((m) => m.token).sort()).toEqual(['dead', 't1', 't3']); // u_4 muted
    expect((await db().collection(`schools/${SID}/notifications`).get()).size).toBe(3);
    expect((await db().doc('devices/u_3/tokens/dead').get()).exists).toBe(false);
    expect((await ref.get()).data()).toMatchObject({ status: 'sent', recipients: 3, sent: 2 });

    // A retry after a crash skips recipients already handled.
    await ref.update({ status: 'pending' });
    const again: TokenMessage[] = [];
    await deliver(db(), SID, 'low__b1', fakeSend(again));
    expect(again).toEqual([]);
  });

  it('never calls FCM when running in the emulator', async () => {
    process.env.FUNCTIONS_EMULATOR = 'true';
    try {
      const ref = db().doc(`schools/${SID}/outbox/emu`);
      await ref.set({ to: { uids: ['u_1'] }, category: 'x', title: 't', body: 'b', status: 'pending', createdAt: new Date() });
      await deliver(db(), SID, 'emu'); // default sender; real FCM would throw without credentials
      expect((await ref.get()).get('status')).toBe('sent');
    } finally {
      delete process.env.FUNCTIONS_EMULATOR;
    }
  });

  it('expires stale events without sending', async () => {
    const ref = db().doc(`schools/${SID}/outbox/old`);
    await ref.set({ to: { uids: ['u_1'] }, category: 'x', title: 't', body: 'b', status: 'pending', createdAt: new Date(Date.now() - 2 * 3600e3) });
    const sent: TokenMessage[] = [];
    await deliver(db(), SID, 'old', fakeSend(sent));
    expect(sent).toEqual([]);
    expect((await ref.get()).get('status')).toBe('expired');
  });
});
