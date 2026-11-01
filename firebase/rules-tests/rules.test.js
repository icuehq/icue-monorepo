import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';
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

  it('stores: school-wide reads for stock viewers and settings users', async () => {
    await assertSucceeds(getDoc(doc(db('u_3'), 'schools/12/invStores/s31')));
    await assertSucceeds(getDoc(doc(db('u_3'), 'schools/12/invStores/s32')));
    await assertFails(getDoc(doc(db('u_1'), 'schools/12/invStores/s31')));
    await assertFails(getDoc(doc(db('u_3', { ...staff, sid: 13 }), 'schools/12/invStores/s31')));
    await assertSucceeds(getDocs(collection(db('u_3'), 'schools/12/invStores')));
    await assertFails(setDoc(doc(db('u_3'), 'schools/12/invStores/s31'), { campusId: 31 }));
  });
});

describe('inventory stock', () => {
  const STOCK = ['invBalances', 'invMovements', 'invReceipts', 'invIssues', 'invReturns', 'invAdjustments', 'invUnavailable'];
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      const acc = (perms, cmp = [31]) => ({ perms, cmp, all: false });
      await setDoc(doc(fs, 'schools/12/userAccess/s_view'), acc(['inv.stock.view']));
      await setDoc(doc(fs, 'schools/12/userAccess/s_req'), acc(['inv.issue.request']));
      await setDoc(doc(fs, 'schools/12/userAccess/s_apr'), acc(['inv.issue.approve']));
      await setDoc(doc(fs, 'schools/12/userAccess/s_32'), acc(['inv.stock.view'], [32]));
      for (const c of STOCK) {
        await setDoc(doc(fs, `schools/12/${c}/a31`), { campusId: 31 });
        await setDoc(doc(fs, `schools/12/${c}/a32`), { campusId: 32 });
      }
      await setDoc(doc(fs, 'schools/12/invIssueRequests/r1'), { campusId: 31, createdBy: 's_req' });
      await setDoc(doc(fs, 'schools/12/invTransfers/t1'), { campusId: 31, toCampusId: 32 });
      await setDoc(doc(fs, 'schools/12/invItems/i'), { name: 'i' });
      await setDoc(doc(fs, 'schools/12/invStores/s31'), { campusId: 31 });
    }),
  );

  it('balances, ledger and documents: stock viewers on the campus only, never writable', async () => {
    for (const c of STOCK) {
      await assertSucceeds(getDoc(doc(db('s_view'), `schools/12/${c}/a31`)));
      await assertFails(getDoc(doc(db('s_view'), `schools/12/${c}/a32`)));
      await assertFails(getDoc(doc(db('s_req'), `schools/12/${c}/a31`)));
      await assertFails(getDoc(doc(db('s_view', { ...staff, sid: 13 }), `schools/12/${c}/a31`)));
      await assertFails(setDoc(doc(db('s_view'), `schools/12/${c}/a31`), { campusId: 31 }));
    }
    const list = (cmp) => getDocs(query(collection(db('s_view'), 'schools/12/invBalances'), where('campusId', 'in', cmp)));
    await assertSucceeds(list([31]));
    await assertFails(list([31, 32]));
  });

  it('issue requests: requester sees own, approvers see the campus', async () => {
    await assertSucceeds(getDoc(doc(db('s_req'), 'schools/12/invIssueRequests/r1')));
    await assertSucceeds(getDoc(doc(db('s_apr'), 'schools/12/invIssueRequests/r1')));
    await assertSucceeds(getDoc(doc(db('s_view'), 'schools/12/invIssueRequests/r1')));
    await assertFails(getDoc(doc(db('s_32'), 'schools/12/invIssueRequests/r1')));
    await assertFails(getDoc(doc(db('u_2'), 'schools/12/invIssueRequests/r1')));
    await assertSucceeds(getDocs(query(collection(db('s_req'), 'schools/12/invIssueRequests'), where('createdBy', '==', 's_req'))));
    await assertFails(setDoc(doc(db('s_req'), 'schools/12/invIssueRequests/r1'), { status: 'approved' }));
  });

  it('transfers: visible to both campuses', async () => {
    await assertSucceeds(getDoc(doc(db('s_view'), 'schools/12/invTransfers/t1')));
    await assertSucceeds(getDoc(doc(db('s_32'), 'schools/12/invTransfers/t1')));
    await assertSucceeds(getDocs(query(collection(db('s_32'), 'schools/12/invTransfers'), where('toCampusId', 'in', [32]))));
    await assertFails(getDoc(doc(db('s_req'), 'schools/12/invTransfers/t1')));
  });

  it('requesters can browse items and stores to build a request', async () => {
    await assertSucceeds(getDoc(doc(db('s_req'), 'schools/12/invItems/i')));
    await assertSucceeds(getDoc(doc(db('s_req'), 'schools/12/invStores/s31')));
    await assertFails(getDoc(doc(db('s_32'), 'schools/12/invItems/i')));
  });
});

describe('library masters', () => {
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      await setDoc(doc(fs, 'schools/12/userAccess/u_4'), { perms: ['lib.catalogue.view'], cmp: [31], all: false });
      await setDoc(doc(fs, 'schools/12/userAccess/u_5'), { perms: ['lib.catalogue.manage'], cmp: [31], all: false });
      await setDoc(doc(fs, 'schools/12/libLoans/a'), { campusId: 31, personErpId: 501 });
      await setDoc(doc(fs, 'schools/12/userAccess/u_7'), { perms: ['lib.circulation.operate'], cmp: [31], all: false });
      await setDoc(doc(fs, 'schools/12/userAccess/u_6'), { perms: ['lib.members.view'], cmp: [31], all: false });
      for (const c of ['libLibraries', 'libCategories', 'libCatalogue', 'libCopies', 'libAcquisitions', 'libMembers', 'libPolicies']) await setDoc(doc(fs, `schools/12/${c}/a`), { name: 'a' });
    }),
  );

  it('libraries, categories, catalogue: readable with lib.catalogue.view, never writable', async () => {
    for (const p of ['libLibraries/a', 'libCategories/a', 'libCatalogue/a', 'libCopies/a']) {
      await assertSucceeds(getDoc(doc(db('u_4'), `schools/12/${p}`)));
      await assertFails(getDoc(doc(db('u_1'), `schools/12/${p}`))); // inv.items.view is not enough
      await assertFails(getDoc(doc(db('u_4', { ...staff, sid: 13 }), `schools/12/${p}`)));
      await assertFails(setDoc(doc(db('u_4'), `schools/12/${p}`), { name: 'x' }));
    }
  });

  it('acquisitions: librarians (lib.catalogue.manage) only, never writable', async () => {
    await assertSucceeds(getDoc(doc(db('u_5'), 'schools/12/libAcquisitions/a')));
    await assertFails(getDoc(doc(db('u_4'), 'schools/12/libAcquisitions/a')));
    await assertFails(setDoc(doc(db('u_5'), 'schools/12/libAcquisitions/a'), { qty: 1 }));
  });

  it('circulation staff on the campus or the borrower read; nobody writes', async () => {
    await assertSucceeds(getDoc(doc(db('u_7'), 'schools/12/libLoans/a')));
    await assertFails(getDoc(doc(db('u_6'), 'schools/12/libLoans/a')));
    await assertFails(getDoc(doc(db('u_7', { ...staff, sid: 13 }), 'schools/12/libLoans/a')));
    await assertFails(setDoc(doc(db('u_7'), 'schools/12/libLoans/a'), { status: 'returned' }));
  });

  it('reservations: circulation staff on the campus or the member read; nobody writes', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'schools/12/libReservations/a'), { campusId: 31, personErpId: 501 }));
    await assertSucceeds(getDoc(doc(db('u_7'), 'schools/12/libReservations/a')));
    await assertFails(getDoc(doc(db('u_6'), 'schools/12/libReservations/a')));
    await assertFails(setDoc(doc(db('u_7'), 'schools/12/libReservations/a'), { status: 'cancelled' }));
  });

  it('fines: circulation staff, fine waivers, or borrower read; nobody writes', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      await setDoc(doc(fs, 'schools/12/userAccess/u_w'), { perms: ['lib.fines.waive'], cmp: [31], all: false });
      await setDoc(doc(fs, 'schools/12/libFines/a'), { campusId: 31, personErpId: 501 });
    });
    await assertSucceeds(getDoc(doc(db('u_7'), 'schools/12/libFines/a')));
    await assertSucceeds(getDoc(doc(db('u_w'), 'schools/12/libFines/a')));
    await assertFails(getDoc(doc(db('u_6'), 'schools/12/libFines/a')));
    await assertFails(setDoc(doc(db('u_7'), 'schools/12/libFines/a'), { status: 'waived' }));
  });

  it('incidents: circulation staff or member read; nobody writes', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      await setDoc(doc(fs, 'schools/12/libIncidents/a'), { campusId: 31, personErpId: 501 });
    });
    await assertSucceeds(getDoc(doc(db('u_7'), 'schools/12/libIncidents/a')));
    await assertFails(getDoc(doc(db('u_6'), 'schools/12/libIncidents/a')));
    await assertFails(setDoc(doc(db('u_7'), 'schools/12/libIncidents/a'), { status: 'resolved' }));
  });

  it('transfers and verifications: librarians on the campus read; nobody writes', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      await setDoc(doc(fs, 'schools/12/libTransfers/a'), { campusId: 32, toCampusId: 31 });
      await setDoc(doc(fs, 'schools/12/libVerifications/a'), { campusId: 31 });
    });
    for (const p of ['libTransfers/a', 'libVerifications/a']) {
      await assertSucceeds(getDoc(doc(db('u_5'), `schools/12/${p}`)));
      await assertFails(getDoc(doc(db('u_7'), `schools/12/${p}`)));
      await assertFails(setDoc(doc(db('u_5'), `schools/12/${p}`), { status: 'received' }));
    }
  });

  it('members and policies: lib.members.view only, never writable', async () => {
    for (const p of ['libMembers/a', 'libPolicies/a']) {
      await assertSucceeds(getDoc(doc(db('u_6'), `schools/12/${p}`)));
      await assertFails(getDoc(doc(db('u_4'), `schools/12/${p}`)));
      await assertFails(getDoc(doc(db('u_6', { ...staff, sid: 13 }), `schools/12/${p}`)));
      await assertFails(setDoc(doc(db('u_6'), `schools/12/${p}`), { name: 'x' }));
    }
  });
});

describe('library reports and parent view (Lib-8)', () => {
  const parent = { sid: 12, pt: 'parent', wards: [501] };
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      await setDoc(doc(fs, 'schools/12/userAccess/u_r'), { perms: ['lib.reports.view'], cmp: [31], all: false });
      await setDoc(doc(fs, 'schools/12/userAccess/p_1'), { perms: [], cmp: [], all: false });
      await setDoc(doc(fs, 'schools/12/libCatalogue/a'), { title: 'a' });
      await setDoc(doc(fs, 'schools/12/libCopies/a'), { campusId: 31 });
      await setDoc(doc(fs, 'schools/12/libMembers/student_501'), { erpId: 501 });
      await setDoc(doc(fs, 'schools/12/libMembers/student_502'), { erpId: 502 });
      for (const [c, d] of Object.entries({
        libLoans: { campusId: 31, personErpId: 501 },
        libReservations: { campusId: 31, personErpId: 501 },
        libFines: { campusId: 31, personErpId: 501 },
        libIncidents: { campusId: 31, personErpId: 501 },
        libAcquisitions: { campusId: 31 },
        libTransfers: { campusId: 31, toCampusId: 32 },
        libVerifications: { campusId: 31 },
      })) {
        await setDoc(doc(fs, `schools/12/${c}/r31`), d);
        await setDoc(doc(fs, `schools/12/${c}/r32`), { ...d, campusId: 32, toCampusId: 33 });
      }
    }),
  );

  it('report readers see every report collection on their campus only', async () => {
    for (const c of ['libLoans', 'libReservations', 'libFines', 'libIncidents', 'libAcquisitions', 'libTransfers', 'libVerifications']) {
      await assertSucceeds(getDoc(doc(db('u_r'), `schools/12/${c}/r31`)));
      await assertFails(getDoc(doc(db('u_r'), `schools/12/${c}/r32`)));
      await assertFails(setDoc(doc(db('u_r'), `schools/12/${c}/r31`), { x: 1 }));
    }
    await assertSucceeds(getDoc(doc(db('u_r'), 'schools/12/libMembers/student_501'))); // dashboard member counts
    await assertFails(getDoc(doc(db('u_4'), 'schools/12/libLoans/r31')));
  });

  it('a parent reads only their ward\'s records, browses the catalogue, and writes nothing', async () => {
    for (const c of ['libLoans', 'libReservations', 'libFines', 'libIncidents']) {
      await assertSucceeds(getDoc(doc(db('p_1', parent), `schools/12/${c}/r31`)));
      await assertFails(setDoc(doc(db('p_1', parent), `schools/12/${c}/r31`), { x: 1 }));
    }
    await assertFails(getDoc(doc(db('p_1', { ...parent, wards: [999] }), 'schools/12/libLoans/r31')));
    await assertSucceeds(getDoc(doc(db('p_1', parent), 'schools/12/libMembers/student_501')));
    await assertFails(getDoc(doc(db('p_1', parent), 'schools/12/libMembers/student_502')));
    await assertSucceeds(getDoc(doc(db('p_1', parent), 'schools/12/libCatalogue/a')));
    await assertFails(getDoc(doc(db('p_1', parent), 'schools/12/libCopies/a')));
    await assertFails(getDoc(doc(db('p_1', parent), 'schools/12/libTransfers/r31')));
    await assertFails(getDoc(doc(db('p_1', { ...parent, sid: 13 }), 'schools/12/libCatalogue/a')));
    await assertFails(getDoc(doc(db('u_4'), 'schools/12/libMembers/student_501')));
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

describe('procurement (Inv-3)', () => {
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      const acc = (perms, cmp = [31]) => ({ perms, cmp, all: false });
      await setDoc(doc(fs, 'schools/12/userAccess/p_req'), acc(['inv.pr.request']));
      await setDoc(doc(fs, 'schools/12/userAccess/p_apr'), acc(['inv.pr.approve']));
      await setDoc(doc(fs, 'schools/12/userAccess/p_proc'), acc(['inv.procure.operate']));
      await setDoc(doc(fs, 'schools/12/userAccess/p_ven'), acc(['inv.vendors.manage']));
      await setDoc(doc(fs, 'schools/12/userAccess/p_32'), acc(['inv.pr.approve'], [32]));
      await setDoc(doc(fs, 'schools/12/invPurchaseRequests/pr1'), { campusId: 31, createdBy: 'p_req' });
      await setDoc(doc(fs, 'schools/12/invVendors/v1'), { name: 'v' });
      await setDoc(doc(fs, 'schools/12/invItems/i'), { name: 'i' });
    }),
  );

  it('purchase requests: requester sees own, approvers and procurement the campus', async () => {
    const pr = (u) => getDoc(doc(db(u), 'schools/12/invPurchaseRequests/pr1'));
    await assertSucceeds(pr('p_req'));
    await assertSucceeds(pr('p_apr'));
    await assertSucceeds(pr('p_proc'));
    await assertFails(pr('p_32'));
    await assertFails(pr('p_ven'));
    await assertFails(getDoc(doc(db('p_apr', { ...staff, sid: 13 }), 'schools/12/invPurchaseRequests/pr1')));
    await assertSucceeds(getDocs(query(collection(db('p_req'), 'schools/12/invPurchaseRequests'), where('createdBy', '==', 'p_req'))));
    await assertFails(setDoc(doc(db('p_req'), 'schools/12/invPurchaseRequests/pr1'), { status: 'approved' }));
  });

  it('vendors: vendor managers and procurement only, never writable; requesters can browse items', async () => {
    await assertSucceeds(getDoc(doc(db('p_ven'), 'schools/12/invVendors/v1')));
    await assertSucceeds(getDoc(doc(db('p_proc'), 'schools/12/invVendors/v1')));
    await assertFails(getDoc(doc(db('p_req'), 'schools/12/invVendors/v1')));
    await assertFails(setDoc(doc(db('p_ven'), 'schools/12/invVendors/v1'), { name: 'x' }));
    await assertSucceeds(getDoc(doc(db('p_req'), 'schools/12/invItems/i')));
  });
});

describe('quotations and purchase orders (Inv-4)', () => {
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      const acc = (perms, cmp = [31]) => ({ perms, cmp, all: false });
      await setDoc(doc(fs, 'schools/12/userAccess/p_proc'), acc(['inv.procure.operate']));
      await setDoc(doc(fs, 'schools/12/userAccess/p_far'), acc(['inv.procure.operate'], [99]));
      await setDoc(doc(fs, 'schools/12/userAccess/p_apr'), acc(['inv.pr.approve']));
      await setDoc(doc(fs, 'schools/12/invQuotations/q1'), { campusId: 31, prId: 'pr1' });
      await setDoc(doc(fs, 'schools/12/invPurchaseOrders/po1'), { campusId: 31, deliveryCampusId: 31 });
      await setDoc(doc(fs, 'schools/12/invPurchaseOrders/po1/revisions/r1'), { reason: 'x' });
      await setDoc(doc(fs, 'schools/12/userAccess/p_store'), acc(['inv.stock.operate']));
      await setDoc(doc(fs, 'schools/12/userAccess/p_store_far'), acc(['inv.stock.operate'], [99]));
      await setDoc(doc(fs, 'schools/12/invInvoices/i1'), { campusId: 31, poId: 'po1' });
    }),
  );

  it('procurement on the campus reads; others and writes are denied', async () => {
    for (const path of ['invQuotations/q1', 'invPurchaseOrders/po1', 'invPurchaseOrders/po1/revisions/r1']) {
      await assertSucceeds(getDoc(doc(db('p_proc'), `schools/12/${path}`)));
      await assertFails(getDoc(doc(db('p_apr'), `schools/12/${path}`)));
    }
    await assertFails(getDoc(doc(db('p_far'), 'schools/12/invQuotations/q1')));
    await assertFails(getDoc(doc(db('p_far'), 'schools/12/invPurchaseOrders/po1')));
    await assertFails(setDoc(doc(db('p_proc'), 'schools/12/invPurchaseOrders/po1'), { status: 'issued' }));
  });

  it('invoices follow procurement; receiving staff read orders due at their campus only', async () => {
    await assertSucceeds(getDoc(doc(db('p_proc'), 'schools/12/invInvoices/i1')));
    await assertFails(getDoc(doc(db('p_far'), 'schools/12/invInvoices/i1')));
    await assertFails(getDoc(doc(db('p_store'), 'schools/12/invInvoices/i1')));
    await assertFails(setDoc(doc(db('p_proc'), 'schools/12/invInvoices/i1'), { paymentStatus: 'paid' }));
    await assertSucceeds(getDoc(doc(db('p_store'), 'schools/12/invPurchaseOrders/po1')));
    await assertFails(getDoc(doc(db('p_store_far'), 'schools/12/invPurchaseOrders/po1')));
    await assertFails(getDoc(doc(db('p_store'), 'schools/12/invQuotations/q1')));
  });
});

describe('assets and maintenance (Inv-6)', () => {
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      const acc = (perms, cmp = [31]) => ({ perms, cmp, all: false });
      await setDoc(doc(fs, 'schools/12/userAccess/p_view'), acc(['inv.assets.view']));
      await setDoc(doc(fs, 'schools/12/userAccess/p_far'), acc(['inv.assets.view'], [99]));
      await setDoc(doc(fs, 'schools/12/userAccess/p_none'), acc(['inv.stock.view']));
      await setDoc(doc(fs, 'schools/12/invAssets/a1'), { campusId: 31, status: 'available' });
      await setDoc(doc(fs, 'schools/12/invAssets/a1/history/h1'), { campusId: 31, type: 'registered' });
      await setDoc(doc(fs, 'schools/12/invMaintenance/m1'), { campusId: 31, assetId: 'a1' });
      await setDoc(doc(fs, 'schools/12/invAssetAssignments/g1'), { campusId: 31, assetId: 'a1', personErpId: 884 });
    }),
  );

  it('asset viewers on the campus read; others and every write are denied', async () => {
    for (const path of ['invAssets/a1', 'invAssets/a1/history/h1', 'invMaintenance/m1']) {
      await assertSucceeds(getDoc(doc(db('p_view'), `schools/12/${path}`)));
      await assertFails(getDoc(doc(db('p_far'), `schools/12/${path}`)));
    }
    await assertSucceeds(getDoc(doc(db('p_view'), 'schools/12/invAssetAssignments/g1')));
    await assertFails(getDoc(doc(db('p_far', { sid: 12, pt: 'staff', eid: 1 }), 'schools/12/invAssetAssignments/g1')));
    await assertFails(getDoc(doc(db('p_none'), 'schools/12/invAssets/a1')));
    await assertFails(setDoc(doc(db('p_view'), 'schools/12/invAssets/a1'), { status: 'lost' }));
    await assertFails(setDoc(doc(db('p_view'), 'schools/12/invMaintenance/m1'), { cost: 0 }));
  });

  it('a custodian reads their own assignment only', async () => {
    await assertSucceeds(getDoc(doc(db('p_none'), 'schools/12/invAssetAssignments/g1'))); // eid 884
    await assertFails(getDoc(doc(db('p_none', { sid: 12, pt: 'staff', eid: 1 }), 'schools/12/invAssetAssignments/g1')));
    await assertFails(getDoc(doc(db('p_none'), 'schools/12/invAssets/a1')));
  });
});

describe('verification and reports (Inv-7)', () => {
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      const acc = (perms, cmp = [31]) => ({ perms, cmp, all: false });
      await setDoc(doc(fs, 'schools/12/userAccess/p_count'), acc(['inv.stock.view', 'inv.stock.operate']));
      await setDoc(doc(fs, 'schools/12/invVerifications/v2'), { campusId: 31, status: 'submitted' });
      await setDoc(doc(fs, 'schools/12/invVerifications/v2/lines/l1'), { campusId: 31, expected: 3 });
      await setDoc(doc(fs, 'schools/12/userAccess/p_stock'), acc(['inv.stock.view']));
      await setDoc(doc(fs, 'schools/12/userAccess/p_rep'), acc(['inv.reports.view']));
      await setDoc(doc(fs, 'schools/12/userAccess/p_far'), acc(['inv.stock.view', 'inv.reports.view'], [99]));
      await setDoc(doc(fs, 'schools/12/invVerifications/v1'), { campusId: 31, status: 'counting' });
      await setDoc(doc(fs, 'schools/12/invVerifications/v1/lines/l1'), { campusId: 31, expected: 3 });
      await setDoc(doc(fs, 'schools/12/invPurchaseOrders/po1'), { campusId: 31, deliveryCampusId: 31 });
      await setDoc(doc(fs, 'schools/12/invVendors/ven1'), { name: 'Acme' });
    }),
  );

  it('stock viewers on the campus read sessions and lines; stock viewers cannot count', async () => {
    for (const path of ['invVerifications/v1', 'invVerifications/v1/lines/l1']) {
      await assertSucceeds(getDoc(doc(db('p_stock'), `schools/12/${path}`)));
      await assertFails(getDoc(doc(db('p_far'), `schools/12/${path}`)));
    }
    await assertFails(updateDoc(doc(db('p_stock'), 'schools/12/invVerifications/v1/lines/l1'), { counted: 3, diff: 0, countedBy: 'p_stock' }));
  });

  it('operators count lines of a counting session (offline-queued writes), nothing else', async () => {
    const line = (uid, v = 'v1') => doc(db(uid), `schools/12/invVerifications/${v}/lines/l1`);
    const count = { counted: 5, diff: 2, reason: 'excess', countedBy: 'p_count' };
    await assertSucceeds(updateDoc(line('p_count'), count));
    await assertFails(updateDoc(line('p_count'), { ...count, diff: 1 })); // diff must match expected
    await assertFails(updateDoc(line('p_count'), { ...count, countedBy: 'p_stock' }));
    await assertFails(updateDoc(line('p_count'), { ...count, expected: 99 })); // snapshot is not editable
    await assertFails(updateDoc(line('p_count'), { ...count, reason: 'because' }));
    await assertFails(updateDoc(line('p_count', 'v2'), count)); // session no longer counting
    await assertFails(updateDoc(line('p_far'), count));
  });

  it('report viewers read the campus records of every report collection and the vendors', async () => {
    await assertSucceeds(getDoc(doc(db('p_rep'), 'schools/12/invPurchaseOrders/po1')));
    await assertSucceeds(getDoc(doc(db('p_rep'), 'schools/12/invVerifications/v1')));
    await assertSucceeds(getDoc(doc(db('p_rep'), 'schools/12/invVendors/ven1')));
    await assertFails(getDoc(doc(db('p_far'), 'schools/12/invPurchaseOrders/po1')));
    await assertFails(getDoc(doc(db('p_stock'), 'schools/12/invPurchaseOrders/po1')));
  });
});
