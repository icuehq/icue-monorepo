import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, query, setDoc, where } from 'firebase/firestore';
import { getBytes, ref, uploadString } from 'firebase/storage';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

let env;
const staff = { sid: 12, pt: 'staff', eid: 884 };
const db = (uid, claims = staff) => env.authenticatedContext(uid, claims).firestore();
const anon = () => env.unauthenticatedContext().firestore();

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-icue',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
    storage: { rules: readFileSync('../storage.rules', 'utf8') },
  });
});
afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    await setDoc(doc(fs, 'schools/12/userAccess/u_1'), { perms: ['inv.items.view'], cmp: [31], all: false });
    await setDoc(doc(fs, 'schools/12/userAccess/u_2'), { perms: [], cmp: [31], all: false });
    await setDoc(doc(fs, 'schools/12/config/rolePermissions'), { roles: {} });
    await setDoc(doc(fs, 'schools/12/notifications/e__u_1'), { uid: 'u_1', title: 't' });
    await setDoc(doc(fs, 'schools/12/notifications/e__u_2'), { uid: 'u_2', title: 't' });
    for (const c of ['auditLogs', 'requests', 'uniqueKeys', 'outbox', 'counters']) {
      await setDoc(doc(fs, `schools/12/${c}/x`), { a: 1 });
    }
    await setDoc(doc(fs, 'devices/u_2/tokens/t'), { token: 't' });
    await uploadString(ref(ctx.storage(), 'schools/12/inv/invItems/i1/a.png'), 'x');
  });
});

describe('school data', () => {
  it('userAccess: own only, same school only, never writable', async () => {
    await assertSucceeds(getDoc(doc(db('u_1'), 'schools/12/userAccess/u_1')));
    await assertFails(getDoc(doc(db('u_1'), 'schools/12/userAccess/u_2')));
    await assertFails(getDoc(doc(db('u_1', { ...staff, sid: 13 }), 'schools/12/userAccess/u_1')));
    await assertFails(getDoc(doc(anon(), 'schools/12/userAccess/u_1')));
    await assertFails(setDoc(doc(db('u_1'), 'schools/12/userAccess/u_1'), { perms: ['inv.settings'] }));
  });

  it('config: readable in own school only', async () => {
    await assertSucceeds(getDoc(doc(db('u_2'), 'schools/12/config/rolePermissions')));
    await assertFails(getDoc(doc(db('u_2', { ...staff, sid: 13 }), 'schools/12/config/rolePermissions')));
    await assertFails(setDoc(doc(db('u_1'), 'schools/12/config/rolePermissions'), { roles: {} }));
  });

  it('notifications: own only, list must filter by uid', async () => {
    const fs = db('u_1');
    await assertSucceeds(getDoc(doc(fs, 'schools/12/notifications/e__u_1')));
    await assertFails(getDoc(doc(fs, 'schools/12/notifications/e__u_2')));
    await assertSucceeds(getDocs(query(collection(fs, 'schools/12/notifications'), where('uid', '==', 'u_1'))));
    await assertFails(getDocs(collection(fs, 'schools/12/notifications')));
  });

  it('internal collections: no client read or write', async () => {
    for (const c of ['auditLogs', 'requests', 'uniqueKeys', 'outbox', 'counters']) {
      await assertFails(getDoc(doc(db('u_1'), `schools/12/${c}/x`)));
      await assertFails(setDoc(doc(db('u_1'), `schools/12/${c}/y`), { a: 1 }));
    }
  });

  it('module collections: no client writes, no reads without a rule', async () => {
    await assertFails(setDoc(doc(db('u_1'), 'schools/12/invBalances/b1'), { campusId: 31 }));
    await assertFails(getDoc(doc(db('u_1'), 'schools/12/invBalances/b1')));
  });
});

describe('inventory masters', () => {
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      await setDoc(doc(fs, 'schools/12/userAccess/u_3'), { perms: ['inv.settings'], cmp: [31], all: false });
      for (const c of ['invCategories', 'invUnits', 'invItems']) await setDoc(doc(fs, `schools/12/${c}/a`), { name: 'a' });
      await setDoc(doc(fs, 'schools/12/invItems/a/variants/v'), { sku: 'v' });
      await setDoc(doc(fs, 'schools/12/invStores/s31'), { campusId: 31 });
      await setDoc(doc(fs, 'schools/12/invStores/s32'), { campusId: 32 });
    }),
  );

  it('categories, units, items, variants: readable with inv.items.view, never writable', async () => {
    for (const p of ['invCategories/a', 'invUnits/a', 'invItems/a', 'invItems/a/variants/v']) {
      await assertSucceeds(getDoc(doc(db('u_1'), `schools/12/${p}`)));
      await assertFails(getDoc(doc(db('u_2'), `schools/12/${p}`)));
      await assertFails(getDoc(doc(db('u_1', { ...staff, sid: 13 }), `schools/12/${p}`)));
      await assertFails(setDoc(doc(db('u_1'), `schools/12/${p}`), { name: 'x' }));
    }
  });

  it('stores: campus-scoped reads for stock viewers and settings users', async () => {
    await assertSucceeds(getDoc(doc(db('u_3'), 'schools/12/invStores/s31')));
    await assertFails(getDoc(doc(db('u_3'), 'schools/12/invStores/s32')));
    await assertFails(getDoc(doc(db('u_1'), 'schools/12/invStores/s31')));
    const list = (uid, cmp) => getDocs(query(collection(db(uid), 'schools/12/invStores'), where('campusId', 'in', cmp)));
    await assertSucceeds(list('u_3', [31]));
    await assertFails(list('u_3', [31, 32]));
    await assertFails(setDoc(doc(db('u_3'), 'schools/12/invStores/s31'), { campusId: 31 }));
  });
});

describe('devices', () => {
  const token = { token: 'abc', platform: 'android', app: 'icueadmin', updatedAt: new Date() };

  it('owner manages own tokens with the allowed shape', async () => {
    await assertSucceeds(setDoc(doc(db('u_1'), 'devices/u_1/tokens/h1'), token));
    await assertSucceeds(getDoc(doc(db('u_1'), 'devices/u_1/tokens/h1')));
    await assertSucceeds(deleteDoc(doc(db('u_1'), 'devices/u_1/tokens/h1')));
    await assertFails(setDoc(doc(db('u_1'), 'devices/u_1/tokens/h2'), { ...token, extra: 1 }));
    await assertFails(setDoc(doc(db('u_1'), 'devices/u_1/tokens/h3'), { ...token, token: 5 }));
  });

  it('nobody else touches them', async () => {
    await assertFails(getDoc(doc(db('u_1'), 'devices/u_2/tokens/t')));
    await assertFails(deleteDoc(doc(db('u_1'), 'devices/u_2/tokens/t')));
    await assertFails(setDoc(doc(db('u_1'), 'devices/u_2/tokens/h'), token));
    await assertFails(setDoc(doc(anon(), 'devices/u_1/tokens/h'), token));
  });

  it('device doc holds only mute', async () => {
    await assertSucceeds(setDoc(doc(db('u_1'), 'devices/u_1'), { mute: { 'inv.lowStock': true } }));
    await assertFails(setDoc(doc(db('u_1'), 'devices/u_1'), { mute: {}, perms: ['x'] }));
    await assertFails(setDoc(doc(db('u_1'), 'devices/u_2'), { mute: {} }));
  });
});

describe('storage', () => {
  const st = (uid, claims = staff) => env.authenticatedContext(uid, claims).storage();
  const path = 'schools/12/inv/invItems/i1/a.png';

  it('reads need same school and module view permission', async () => {
    await assertSucceeds(getBytes(ref(st('u_1'), path)));
    await assertFails(getBytes(ref(st('u_2'), path)));
    await assertFails(getBytes(ref(st('u_1', { ...staff, sid: 13 }), path)));
    await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), path)));
  });

  it('writes are denied until upload registration exists', async () => {
    await assertFails(uploadString(ref(st('u_1'), 'schools/12/inv/invItems/i1/b.png'), 'x'));
  });
});
