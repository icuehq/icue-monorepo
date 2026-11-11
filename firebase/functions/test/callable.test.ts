import { beforeEach, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { claimUniqueKey, financialYearOf, nextNumber } from '../src/shared/keys';
import { enqueue } from '../src/shared/outbox';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
const FINANCIAL_YEAR = financialYearOf(new Date());

const def: CallableDef<
  z.ZodObject<{ code: z.ZodString; fail: z.ZodOptional<z.ZodBoolean> }>,
  { number: string; id: string }
> = {
  name: 'test.create',
  permission: 'inventory.items.manage',
  input: z.object({ code: z.string().min(1), fail: z.boolean().optional() }),
  handler: async (context, input) => {
    const ref = context.doc(`inventoryItems/${input.code}`);
    await claimUniqueKey(context, 'item', input.code, ref.path);
    const documentNumber = await nextNumber(context, 'PR');
    await enqueue(context, 'created__1', {
      to: { permission: 'inventory.items.view' },
      category: 'test',
      title: 't',
      body: 'b',
    });
    context.set(ref, { code: input.code, number: documentNumber });
    context.audit({ action: 'test.create', documentPath: ref.path, after: { code: input.code } });
    if (input.fail) throw new Error('boom');
    return { number: documentNumber, id: ref.id };
  },
};

const staff = (uid = '1') => ({ uid, token: { orgId: 8, zoneId: 147, branchId: 427, personType: 'staff' } });
const call = (
  data: Record<string, unknown>,
  auth: Parameters<typeof runCallable>[1] | null = staff(),
) =>
  runCallable(def, auth ?? undefined, {
    requestId: 'req-00001',
    code: 'PEN',
    ...data,
  });
const count = async (collection: string) =>
  (await db().collection(`${BRANCH}/${collection}`).get()).size;

async function grant(uid: string, access: Record<string, unknown>) {
  await db()
    .doc(`${BRANCH}/userAccess/${uid}`)
    .set({
      permissions: ['inventory.items.manage'],
      ...access,
    });
}

describe('runCallable', () => {
  beforeEach(async () => {
    await clearFirestore();
    await grant('1', {});
  });

  it('rejects unauthenticated, parents, unsynced users, missing permission', async () => {
    await expect(call({}, null)).rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(
      call({}, { uid: 'parent-1', token: { orgId: 8, zoneId: 147, branchId: 427, personType: 'parent' } }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(call({}, staff('2'))).rejects.toMatchObject({ code: 'failed-precondition' });
    await grant('3', { permissions: ['inventory.items.view'] });
    await expect(call({}, staff('3'))).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('works only in the branch of the token', async () => {
    const otherBranch = { uid: '1', token: { orgId: 8, zoneId: 147, branchId: 428, personType: 'staff' } };
    await expect(call({}, otherBranch)).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(
      call({}, { uid: '1', token: { orgId: 8, personType: 'staff' } }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('validates requestId and input', async () => {
    await expect(call({ requestId: undefined })).rejects.toMatchObject({
      code: 'invalid-argument',
    });
    await expect(call({ code: '' })).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('writes record, counter, unique key, outbox, audit and request in one transaction', async () => {
    const result = await call({});
    expect(result).toEqual({ number: `PR/${FINANCIAL_YEAR}/000001`, id: 'PEN' });
    expect((await db().doc(`${BRANCH}/inventoryItems/PEN`).get()).data()).toMatchObject({
      number: result.number,
    });
    expect(
      (await db().doc(`${BRANCH}/counters/PR_${FINANCIAL_YEAR}`).get()).get('next'),
    ).toBe(1);
    expect(
      (await db().doc(`${BRANCH}/uniqueKeys/item_pen`).get()).get('documentPath'),
    ).toBe(`${BRANCH}/inventoryItems/PEN`);
    expect(
      (await db().doc(`${BRANCH}/outbox/created__1`).get()).get('status'),
    ).toBe('pending');
    expect(await count('auditLogs')).toBe(1);
    expect((await db().doc(`${BRANCH}/requests/req-00001`).get()).data()).toMatchObject({
      uid: '1',
      fn: 'test.create',
      result,
    });
  });

  it('replays a repeated requestId without writing again', async () => {
    const first = await call({});
    expect(await call({ code: 'OTHER' })).toEqual(first);
    expect(await count('auditLogs')).toBe(1);
    expect(
      (await db().doc(`${BRANCH}/counters/PR_${FINANCIAL_YEAR}`).get()).get('next'),
    ).toBe(1);
  });

  it('rejects a requestId reused by another user', async () => {
    await call({});
    await grant('5', {});
    await expect(call({}, staff('5'))).rejects.toMatchObject({ code: 'already-exists' });
  });

  it('rejects duplicate codes case-insensitively and writes nothing', async () => {
    await call({});
    await expect(call({ requestId: 'req-00002', code: 'pen' })).rejects.toMatchObject({
      code: 'already-exists',
    });
    expect(
      (await db().doc(`${BRANCH}/counters/PR_${FINANCIAL_YEAR}`).get()).get('next'),
    ).toBe(1);
    expect(await count('auditLogs')).toBe(1);
  });

  it('writes nothing when the handler fails', async () => {
    await expect(call({ fail: true })).rejects.toMatchObject({ code: 'internal' });
    for (const collection of [
      'inventoryItems',
      'counters',
      'uniqueKeys',
      'outbox',
      'auditLogs',
      'requests',
    ])
      expect(await count(collection)).toBe(0);
  });

  it('numbers sequentially and skips an existing outbox key without failing', async () => {
    await call({});
    const second = await call({ requestId: 'req-00002', code: 'BOOK' });
    expect(second.number).toBe(`PR/${FINANCIAL_YEAR}/000002`);
    expect(await count('outbox')).toBe(1);
  });
});
