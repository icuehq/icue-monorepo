import { beforeEach, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { claimUniqueKey, fyOf, nextNumber } from '../src/shared/keys';
import { enqueue } from '../src/shared/outbox';
import { clearFirestore, db } from './setup';

const SID = '12';
const FY = fyOf(new Date());

const def: CallableDef<z.ZodObject<{ campusId: z.ZodNumber; code: z.ZodString; fail: z.ZodOptional<z.ZodBoolean> }>, { no: string; id: string }> = {
  name: 'test.create',
  perm: 'inv.items.manage',
  input: z.object({ campusId: z.number(), code: z.string().min(1), fail: z.boolean().optional() }),
  handler: async (ctx, input) => {
    const ref = ctx.doc(`invItems/${input.code}`);
    await claimUniqueKey(ctx, 'item', input.code, ref.path);
    const no = await nextNumber(ctx, 'PR');
    await enqueue(ctx, `created__${ctx.sid}`, { to: { perm: 'inv.items.view' }, category: 'test', title: 't', body: 'b' });
    ctx.set(ref, { code: input.code, campusId: input.campusId, no });
    ctx.audit({ action: 'test.create', ref: ref.path, after: { code: input.code } });
    if (input.fail) throw new Error('boom');
    return { no, id: ref.id };
  },
};

const staff = (uid = 'u_1') => ({ uid, token: { sid: 12, pt: 'staff' } });
const call = (data: Record<string, unknown>, auth: Parameters<typeof runCallable>[1] | null = staff()) =>
  runCallable(def, auth ?? undefined, { requestId: 'req-00001', campusId: 31, code: 'PEN', ...data });
const count = async (coll: string) => (await db().collection(`schools/${SID}/${coll}`).get()).size;

async function grant(uid: string, access: Record<string, unknown>) {
  await db().doc(`schools/${SID}/userAccess/${uid}`).set({ perms: ['inv.items.manage'], cmp: [31], all: false, ...access });
}

describe('runCallable', () => {
  beforeEach(async () => {
    await clearFirestore();
    await grant('u_1', {});
  });

  it('rejects unauthenticated, parents, unsynced users, missing permission', async () => {
    await expect(call({}, null)).rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(call({}, { uid: 'p_1', token: { sid: 12, pt: 'parent' } })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(call({}, staff('u_2'))).rejects.toMatchObject({ code: 'failed-precondition' });
    await grant('u_3', { perms: ['inv.items.view'] });
    await expect(call({}, staff('u_3'))).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('enforces campus scope unless `all`', async () => {
    await expect(call({ campusId: 99 })).rejects.toMatchObject({ code: 'permission-denied' });
    await grant('u_4', { cmp: [], all: true });
    await expect(call({ campusId: 99 }, staff('u_4'))).resolves.toMatchObject({ id: 'PEN' });
  });

  it('validates requestId and input', async () => {
    await expect(call({ requestId: undefined })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(call({ code: '' })).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('writes record, counter, unique key, outbox, audit and request in one transaction', async () => {
    const res = await call({});
    expect(res).toEqual({ no: `PR/${FY}/000001`, id: 'PEN' });
    expect((await db().doc(`schools/${SID}/invItems/PEN`).get()).data()).toMatchObject({ no: res.no });
    expect((await db().doc(`schools/${SID}/counters/PR_${FY}`).get()).get('next')).toBe(1);
    expect((await db().doc(`schools/${SID}/uniqueKeys/item_pen`).get()).get('ref')).toBe(`schools/${SID}/invItems/PEN`);
    expect((await db().doc(`schools/${SID}/outbox/created__${SID}`).get()).get('status')).toBe('pending');
    expect(await count('auditLogs')).toBe(1);
    expect((await db().doc(`schools/${SID}/requests/req-00001`).get()).data()).toMatchObject({ uid: 'u_1', fn: 'test.create', result: res });
  });

  it('replays a repeated requestId without writing again', async () => {
    const first = await call({});
    expect(await call({ code: 'OTHER' })).toEqual(first);
    expect(await count('auditLogs')).toBe(1);
    expect((await db().doc(`schools/${SID}/counters/PR_${FY}`).get()).get('next')).toBe(1);
  });

  it('rejects a requestId reused by another user', async () => {
    await call({});
    await grant('u_5', {});
    await expect(call({}, staff('u_5'))).rejects.toMatchObject({ code: 'already-exists' });
  });

  it('rejects duplicate codes case-insensitively and writes nothing', async () => {
    await call({});
    await expect(call({ requestId: 'req-00002', code: 'pen' })).rejects.toMatchObject({ code: 'already-exists' });
    expect((await db().doc(`schools/${SID}/counters/PR_${FY}`).get()).get('next')).toBe(1);
    expect(await count('auditLogs')).toBe(1);
  });

  it('writes nothing when the handler fails', async () => {
    await expect(call({ fail: true })).rejects.toThrow('boom');
    for (const c of ['invItems', 'counters', 'uniqueKeys', 'outbox', 'auditLogs', 'requests']) expect(await count(c)).toBe(0);
  });

  it('numbers sequentially and skips an existing outbox key without failing', async () => {
    await call({});
    const second = await call({ requestId: 'req-00002', code: 'BOOK' });
    expect(second.no).toBe(`PR/${FY}/000002`);
    expect(await count('outbox')).toBe(1);
  });
});
