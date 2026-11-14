import { beforeEach, describe, expect, it } from 'vitest';
import { assets as a } from '../src/inventory/assets';
import { masters } from '../src/inventory/masters';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { seedStore } from './fixtures';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
let requestSequence = 0;

const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(
    definition,
    { uid, token: { orgId: 8, zoneId: 147, branchId: 427, personType: 'staff' } },
    { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data },
  );
const code = (promise: Promise<unknown>) =>
  promise.then(
    () => 'ok',
    (error) => error.code,
  );

describe('RFID', () => {
  let store: string;

  beforeEach(async () => {
    await clearFirestore();
    const access = { personErpId: 5 };
    await db().doc(`${BRANCH}/userAccess/1`).set(access);
    await db().doc(`${BRANCH}/userAccess/none`).set(access);
    store = (await seedStore({ name: 'Main' })).id;
    await db().collection(`${BRANCH}/inventoryUnits`).add({ storeId: store, name: 'pcs' });
    await run(masters.seedDefaults, {});
  });

  it('assigns a unique RFID tag, moves and clears it', async () => {
    const category = (
      await run(masters.categoryUpsert, { storeId: store, name: 'C', suggestedTracking: 'quantity' })
    ).id;
    const item = (
      await run(masters.itemUpsert, {
        storeId: store,
        name: 'L',
        categoryId: category,
        stockUnit: 'pcs',
        tracking: 'asset',
      })
    ).id;
    const [firstAsset, secondAsset] = [
      (await run(a.register, { itemId: item, storeId: store })).id,
      (await run(a.register, { itemId: item, storeId: store })).id,
    ];
    await run(a.setRfid, { id: firstAsset, rfidTag: 'E200AA' });
    expect(await code(run(a.setRfid, { id: secondAsset, rfidTag: 'e200aa' }))).toBe(
      'already-exists',
    );
    await run(a.setRfid, { id: firstAsset, rfidTag: 'E200BB' });
    await run(a.setRfid, { id: secondAsset, rfidTag: 'E200AA' }); // old tag was released
    await run(a.setRfid, { id: secondAsset, rfidTag: null });
    expect(
      (await db().doc(`${BRANCH}/inventoryAssets/${secondAsset}`).get()).data()!.rfidTag,
    ).toBeNull();
  });
});
