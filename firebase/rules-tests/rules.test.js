import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { addDoc, collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';
import { getBytes, ref, uploadString } from 'firebase/storage';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

let env;
const staff = { schoolId: 12, personType: 'staff', personErpId: 884 };
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
  await env.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await setDoc(doc(firestore, 'schools/12/userAccess/1'), { permissions: ['inventory.items.view'], campusIds: [31], hasAllCampuses: false });
    await setDoc(doc(firestore, 'schools/12/userAccess/2'), { permissions: [], campusIds: [31], hasAllCampuses: false });
    await setDoc(doc(firestore, 'schools/12/config/rolePermissions'), { roles: {} });
    await setDoc(doc(firestore, 'schools/12/notifications/e__1'), { uid: '1', title: 't' });
    await setDoc(doc(firestore, 'schools/12/notifications/e__2'), { uid: '2', title: 't' });
    for (const collectionName of ['auditLogs', 'requests', 'uniqueKeys', 'outbox', 'counters']) {
      await setDoc(doc(firestore, `schools/12/${collectionName}/x`), { a: 1 });
    }
    await setDoc(doc(firestore, 'devices/2/tokens/t'), { token: 't' });
    await uploadString(ref(context.storage(), 'schools/12/inv/inventoryItems/i1/a.png'), 'x');
  });
});

describe('school data', () => {
  it('userAccess: own only, same school only, never writable', async () => {
    await assertSucceeds(getDoc(doc(db('1'), 'schools/12/userAccess/1')));
    await assertFails(getDoc(doc(db('1'), 'schools/12/userAccess/2')));
    await assertFails(getDoc(doc(db('1', { ...staff, schoolId: 13 }), 'schools/12/userAccess/1')));
    await assertFails(getDoc(doc(anon(), 'schools/12/userAccess/1')));
    await assertFails(setDoc(doc(db('1'), 'schools/12/userAccess/1'), { permissions: ['inventory.settings'] }));
  });

  it('config: readable in own school only', async () => {
    await assertSucceeds(getDoc(doc(db('2'), 'schools/12/config/rolePermissions')));
    await assertFails(getDoc(doc(db('2', { ...staff, schoolId: 13 }), 'schools/12/config/rolePermissions')));
    await assertFails(setDoc(doc(db('1'), 'schools/12/config/rolePermissions'), { roles: {} }));
  });

  it('notifications: own only, list must filter by uid', async () => {
    const firestore = db('1');
    await assertSucceeds(getDoc(doc(firestore, 'schools/12/notifications/e__1')));
    await assertFails(getDoc(doc(firestore, 'schools/12/notifications/e__2')));
    await assertSucceeds(getDocs(query(collection(firestore, 'schools/12/notifications'), where('uid', '==', '1'))));
    await assertFails(getDocs(collection(firestore, 'schools/12/notifications')));
  });

  it('internal collections: no client read or write', async () => {
    for (const collectionName of ['auditLogs', 'requests', 'uniqueKeys', 'outbox']) {
      await assertFails(getDoc(doc(db('1'), `schools/12/${collectionName}/x`)));
      await assertFails(setDoc(doc(db('1'), `schools/12/${collectionName}/y`), { a: 1 }));
    }
  });

  it('counters: any user holding a permission may bump them, nobody else', async () => {
    await assertSucceeds(setDoc(doc(db('1'), 'schools/12/counters/PR_2026-27'), { next: 1 }));
    await assertSucceeds(getDoc(doc(db('1'), 'schools/12/counters/PR_2026-27')));
    await assertFails(setDoc(doc(db('2'), 'schools/12/counters/PR_2026-27'), { next: 9 }));
    await assertFails(setDoc(doc(db('1', { ...staff, schoolId: 13 }), 'schools/12/counters/PR_2026-27'), { next: 9 }));
  });

  it('module collections: no client writes, no reads without a rule', async () => {
    await assertFails(setDoc(doc(db('1'), 'schools/12/inventoryBalances/b1'), { campusId: 31 }));
    await assertFails(getDoc(doc(db('1'), 'schools/12/inventoryBalances/b1')));
  });
});

describe('inventory masters', () => {
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await setDoc(doc(firestore, 'schools/12/userAccess/3'), { permissions: ['inventory.settings'], campusIds: [31], hasAllCampuses: false });
      for (const collectionName of ['inventoryCategories', 'inventoryUnits', 'inventoryItems']) await setDoc(doc(firestore, `schools/12/${collectionName}/a`), { name: 'a' });
      await setDoc(doc(firestore, 'schools/12/inventoryItems/a/variants/v'), { sku: 'v' });
      await setDoc(doc(firestore, 'schools/12/inventoryStores/s31'), { campusId: 31 });
      await setDoc(doc(firestore, 'schools/12/inventoryStores/s32'), { campusId: 32 });
    }),
  );

  it('categories, units, items, variants: readable with inv.items.view, never writable', async () => {
    for (const documentPath of ['inventoryCategories/a', 'inventoryUnits/a', 'inventoryItems/a', 'inventoryItems/a/variants/v']) {
      await assertSucceeds(getDoc(doc(db('1'), `schools/12/${documentPath}`)));
      await assertFails(getDoc(doc(db('2'), `schools/12/${documentPath}`)));
      await assertFails(getDoc(doc(db('1', { ...staff, schoolId: 13 }), `schools/12/${documentPath}`)));
      await assertFails(setDoc(doc(db('1'), `schools/12/${documentPath}`), { name: 'x' }));
    }
  });

  it('masters: plain client CRUD for the managing permission only, in own school', async () => {
    await env.withSecurityRulesDisabled((context) =>
      Promise.all([
        setDoc(doc(context.firestore(), 'schools/12/userAccess/m1'), { permissions: ['inventory.items.manage'], campusIds: [31] }),
        setDoc(doc(context.firestore(), 'schools/12/userAccess/m2'), { permissions: [], campusIds: [31] }),
        setDoc(doc(context.firestore(), 'schools/12/userAccess/m3'), { permissions: [], campusIds: [31] }),
      ]),
    );
    const cases = [
      ['3', 'inventoryCategories/tools'],
      ['3', 'inventoryUnits/box'],
      ['3', 'inventoryStores/main'],
      ['m1', 'inventoryItems/pen'],
      ['m1', 'inventoryItems/pen/variants/pen-red'],
      ['m2', 'libraries/main'],
      ['m3', 'libraryCategories/fiction'],
    ];
    for (const [uid, documentPath] of cases) {
      const path = `schools/12/${documentPath}`;
      await assertSucceeds(setDoc(doc(db(uid), path), { code: 'x', name: 'x' }));
      await assertSucceeds(updateDoc(doc(db(uid), path), { status: 'inactive' }));
      // Inventory masters need the permission; Library ones need any non-parent staff.
      const outsider = documentPath.startsWith('library') ? db('p', { schoolId: 12, personType: 'parent' }) : db('1');
      await assertFails(updateDoc(doc(outsider, path), { name: 'y' }));
      await assertFails(setDoc(doc(db(uid, { ...staff, schoolId: 13 }), path), { name: 'z' }));
      await assertSucceeds(deleteDoc(doc(db(uid), path)));
    }
    await assertFails(setDoc(doc(db('m1'), 'schools/12/inventoryUnits/box'), { name: 'x' }));
  });

  it('library categories: only two levels', async () => {
    await env.withSecurityRulesDisabled((context) =>
      setDoc(doc(context.firestore(), 'schools/12/userAccess/m3'), { permissions: [], campusIds: [31] }),
    );
    await assertSucceeds(setDoc(doc(db('m3'), 'schools/12/libraryCategories/top'), { name: 'Science', parentId: null }));
    await assertSucceeds(setDoc(doc(db('m3'), 'schools/12/libraryCategories/sub'), { name: 'Physics', parentId: 'top' }));
    await assertFails(setDoc(doc(db('m3'), 'schools/12/libraryCategories/deep'), { name: 'Optics', parentId: 'sub' }));
  });

  it('stores: school-wide reads for stock viewers and settings users', async () => {
    await assertSucceeds(getDoc(doc(db('3'), 'schools/12/inventoryStores/s31')));
    await assertSucceeds(getDoc(doc(db('3'), 'schools/12/inventoryStores/s32')));
    await assertFails(getDoc(doc(db('1'), 'schools/12/inventoryStores/s31')));
    await assertFails(getDoc(doc(db('3', { ...staff, schoolId: 13 }), 'schools/12/inventoryStores/s31')));
    await assertSucceeds(getDocs(collection(db('3'), 'schools/12/inventoryStores')));
    await assertFails(setDoc(doc(db('1'), 'schools/12/inventoryStores/s31'), { campusId: 31 }));
  });
});

describe('inventory stock', () => {
  const STOCK = ['inventoryBalances', 'inventoryMovements', 'inventoryReceipts', 'inventoryIssues', 'inventoryReturns', 'inventoryAdjustments', 'inventoryUnavailableStock'];
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      const access = (permissions, campusIds = [31]) => ({ permissions, campusIds, hasAllCampuses: false });
      await setDoc(doc(firestore, 'schools/12/userAccess/view'), access(['inventory.stock.view']));
      await setDoc(doc(firestore, 'schools/12/userAccess/op'), access(['inventory.stock.operate']));
      await setDoc(doc(firestore, 'schools/12/userAccess/req'), access(['inventory.issue.request']));
      await setDoc(doc(firestore, 'schools/12/userAccess/apr'), access(['inventory.issue.approve']));
      await setDoc(doc(firestore, 'schools/12/userAccess/32'), access(['inventory.stock.view'], [32]));
      for (const collectionName of STOCK) {
        await setDoc(doc(firestore, `schools/12/${collectionName}/a31`), { campusId: 31 });
        await setDoc(doc(firestore, `schools/12/${collectionName}/a32`), { campusId: 32 });
      }
      await setDoc(doc(firestore, 'schools/12/inventoryIssueRequests/r1'), { campusId: 31, createdBy: 'req', status: 'pending' });
      await setDoc(doc(firestore, 'schools/12/inventoryItems/i'), { name: 'i' });
      await setDoc(doc(firestore, 'schools/12/inventoryStores/s31'), { campusId: 31 });
    }),
  );

  it('balances, ledger and documents: stock viewers on the campus only, never writable', async () => {
    for (const collectionName of STOCK) {
      await assertSucceeds(getDoc(doc(db('view'), `schools/12/${collectionName}/a31`)));
      await assertFails(getDoc(doc(db('view'), `schools/12/${collectionName}/a32`)));
      await assertFails(getDoc(doc(db('req'), `schools/12/${collectionName}/a31`)));
      await assertFails(getDoc(doc(db('view', { ...staff, schoolId: 13 }), `schools/12/${collectionName}/a31`)));
      await assertFails(setDoc(doc(db('view'), `schools/12/${collectionName}/a31`), { campusId: 31 }));
    }
    const list = (campusIds) => getDocs(query(collection(db('view'), 'schools/12/inventoryBalances'), where('campusId', 'in', campusIds)));
    await assertSucceeds(list([31]));
    await assertFails(list([31, 32]));
  });

  it('receive stock: operators write receipts, ledger rows and balances on their campus only', async () => {
    const write = (user, path, data) => setDoc(doc(db(user), `schools/12/${path}`), data);
    for (const collectionName of ['inventoryReceipts', 'inventoryMovements']) {
      await assertSucceeds(write('op', `${collectionName}/n1`, { campusId: 31, createdBy: 'op' }));
      await assertFails(write('op', `${collectionName}/n2`, { campusId: 32, createdBy: 'op' }));
      await assertFails(write('op', `${collectionName}/n3`, { campusId: 31, createdBy: 'someone' }));
      await assertFails(write('view', `${collectionName}/n4`, { campusId: 31, createdBy: 'view' }));
      await assertFails(write('op', `${collectionName}/a31`, { campusId: 31, createdBy: 'op' }));
    }
    await assertSucceeds(write('op', 'inventoryBalances/a31', { campusId: 31 }));
    await assertFails(write('op', 'inventoryBalances/a32', { campusId: 32 }));
    await assertFails(write('view', 'inventoryBalances/a31', { campusId: 31 }));
    await assertSucceeds(write('op', 'inventoryIssues/n1', { campusId: 31, createdBy: 'op' }));
    await assertFails(write('op', 'inventoryIssues/n2', { campusId: 32, createdBy: 'op' }));
    await assertFails(write('view', 'inventoryIssues/n3', { campusId: 31, createdBy: 'view' }));
  });

  it('acknowledge issue: operators on the campus fill the empty acknowledgement once', async () => {
    const acknowledge = (user, data, path = 'inventoryIssues/a31') => updateDoc(doc(db(user), `schools/12/${path}`), data);
    const receipt = { acknowledgement: { performedBy: 'op' }, updatedAt: 1 };
    await assertFails(acknowledge('view', receipt));
    await assertFails(acknowledge('op', receipt, 'inventoryIssues/a32'));
    await assertFails(acknowledge('op', { ...receipt, campusId: 32 }));
    await assertFails(acknowledge('op', { ...receipt, acknowledgement: { performedBy: 'someone' } }));
    await assertSucceeds(acknowledge('op', receipt));
    await assertFails(acknowledge('op', { ...receipt, updatedAt: 2 }));
  });

  it('returns: operators write returns and register entries, and only move the issue\'s returned quantities', async () => {
    const write = (user, path, data) => setDoc(doc(db(user), `schools/12/${path}`), data);
    for (const collectionName of ['inventoryReturns', 'inventoryAdjustments', 'inventoryUnavailableStock']) {
      await assertSucceeds(write('op', `${collectionName}/n1`, { campusId: 31, createdBy: 'op' }));
      await assertFails(write('op', `${collectionName}/n2`, { campusId: 32, createdBy: 'op' }));
      await assertFails(write('view', `${collectionName}/n3`, { campusId: 31, createdBy: 'view' }));
    }
    const update = (user, data) => updateDoc(doc(db(user), 'schools/12/inventoryIssues/a31'), data);
    await assertFails(update('view', { lineItems: [], updatedAt: 1 }));
    await assertFails(update('op', { lineItems: [], updatedAt: 1, campusId: 32 }));
    await assertSucceeds(update('op', { lineItems: [], updatedAt: 1 }));
  });

  it('resolve unavailable stock: operators on the campus close open entries, resolution fields only', async () => {
    await env.withSecurityRulesDisabled((context) =>
      setDoc(doc(context.firestore(), 'schools/12/inventoryUnavailableStock/u1'), { campusId: 31, status: 'open' }),
    );
    const resolve = (user, data, path = 'inventoryUnavailableStock/u1') => updateDoc(doc(db(user), `schools/12/${path}`), data);
    const resolution = { status: 'resolved', resolution: 'dispose', resolutionNote: null, resolvedAt: 1, resolvedBy: 'op', updatedAt: 1 };
    await assertFails(resolve('view', resolution));
    await assertFails(resolve('op', { ...resolution, campusId: 32 }));
    await assertFails(resolve('op', { ...resolution, quantity: 0 }));
    await assertSucceeds(resolve('op', resolution));
    await assertFails(resolve('op', resolution));
  });

  it('issue stock: operators move an approved request to issued, nothing else', async () => {
    const issue = (user, data) => updateDoc(doc(db(user), 'schools/12/inventoryIssueRequests/r1'), data);
    await env.withSecurityRulesDisabled((context) =>
      updateDoc(doc(context.firestore(), 'schools/12/inventoryIssueRequests/r1'), { status: 'approved' }),
    );
    const issued = { status: 'issued', lineItems: [], updatedAt: 1 };
    await assertFails(issue('view', issued));
    await assertFails(issue('op', { ...issued, createdBy: 'op' }));
    await assertFails(issue('op', { ...issued, status: 'approved' }));
    await assertSucceeds(issue('op', issued));
    await assertFails(issue('op', { ...issued, status: 'partially_issued' }));
  });

  it('issue request submit: requesters create pending requests on their campus, as themselves', async () => {
    const submit = (user, data) => setDoc(doc(db(user), 'schools/12/inventoryIssueRequests/n1'), data);
    await assertSucceeds(submit('req', { campusId: 31, createdBy: 'req', status: 'pending' }));
    await assertFails(submit('req', { campusId: 32, createdBy: 'req', status: 'pending' }));
    await assertFails(submit('req', { campusId: 31, createdBy: 'other', status: 'pending' }));
    await assertFails(submit('req', { campusId: 31, createdBy: 'req', status: 'approved' }));
    await assertFails(submit('view', { campusId: 31, createdBy: 'view', status: 'pending' }));
    await assertFails(setDoc(doc(db('req'), 'schools/12/inventoryIssueRequests/r1'), { campusId: 31, createdBy: 'req', status: 'pending' }));
  });

  it('issue request decide: approvers on the campus decide pending requests, decision fields only', async () => {
    const decide = (user, data, path = 'schools/12/inventoryIssueRequests/r1') => updateDoc(doc(db(user), path), data);
    const decision = { status: 'approved', approval: { performedBy: 'apr' }, updatedAt: 1 };
    await assertFails(decide('req', decision));
    await assertFails(decide('apr', { ...decision, approval: { performedBy: 'someone' } }));
    await assertFails(decide('apr', { ...decision, createdBy: 'apr' }));
    await assertFails(decide('apr', { ...decision, status: 'issued' }));
    await assertSucceeds(decide('apr', decision));
    await assertFails(decide('apr', { ...decision, status: 'rejected' }));
  });

  it('issue requests: requester sees own, approvers see the campus', async () => {
    await assertSucceeds(getDoc(doc(db('req'), 'schools/12/inventoryIssueRequests/r1')));
    await assertSucceeds(getDoc(doc(db('apr'), 'schools/12/inventoryIssueRequests/r1')));
    await assertSucceeds(getDoc(doc(db('view'), 'schools/12/inventoryIssueRequests/r1')));
    await assertFails(getDoc(doc(db('32'), 'schools/12/inventoryIssueRequests/r1')));
    await assertFails(getDoc(doc(db('2'), 'schools/12/inventoryIssueRequests/r1')));
    await assertSucceeds(getDocs(query(collection(db('req'), 'schools/12/inventoryIssueRequests'), where('createdBy', '==', 'req'))));
    await assertFails(setDoc(doc(db('req'), 'schools/12/inventoryIssueRequests/r1'), { status: 'approved' }));
  });

  it('requesters can browse items and stores to build a request', async () => {
    await assertSucceeds(getDoc(doc(db('req'), 'schools/12/inventoryItems/i')));
    await assertSucceeds(getDoc(doc(db('req'), 'schools/12/inventoryStores/s31')));
    await assertFails(getDoc(doc(db('32'), 'schools/12/inventoryItems/i')));
  });
});

describe('library (staff gate)', () => {
  const parent = { schoolId: 12, personType: 'parent', wardStudentIds: [501] };
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await setDoc(doc(firestore, 'schools/12/userAccess/4'), { permissions: [], campusIds: [31], hasAllCampuses: false });
      await setDoc(doc(firestore, 'schools/12/userAccess/8'), { permissions: [], campusIds: [32], hasAllCampuses: false });
      await setDoc(doc(firestore, 'schools/12/userAccess/parent-1'), { permissions: [], campusIds: [], hasAllCampuses: false });
      for (const collectionName of ['libraries', 'libraryCategories', 'libraryCatalogue', 'libraryCopies', 'libraryBooks', 'libraryMembers', 'libraryBorrowingPolicies']) await setDoc(doc(firestore, `schools/12/${collectionName}/a`), { name: 'a' });
      for (const collectionName of ['libraryLoans', 'libraryFines', 'libraryIncidents']) await setDoc(doc(firestore, `schools/12/${collectionName}/a`), { campusId: 31, personErpId: 501 });
    }),
  );

  it('libraries, categories, catalogue, copies: any staff reads; only libraries and categories are client-writable', async () => {
    for (const documentPath of ['libraries/a', 'libraryCategories/a', 'libraryCatalogue/a', 'libraryCopies/a']) {
      await assertSucceeds(getDoc(doc(db('4'), `schools/12/${documentPath}`)));
      await assertFails(getDoc(doc(db('4', { ...staff, schoolId: 13 }), `schools/12/${documentPath}`)));
    }
    for (const documentPath of ['libraryCatalogue/a', 'libraryCopies/a'])
      await assertFails(setDoc(doc(db('4'), `schools/12/${documentPath}`), { name: 'x' }));
  });

  it('books, members and policies: staff read, never writable', async () => {
    for (const documentPath of ['libraryBooks/a', 'libraryMembers/a', 'libraryBorrowingPolicies/a']) {
      await assertSucceeds(getDoc(doc(db('4'), `schools/12/${documentPath}`)));
      await assertFails(getDoc(doc(db('4', { ...staff, schoolId: 13 }), `schools/12/${documentPath}`)));
      await assertFails(setDoc(doc(db('4'), `schools/12/${documentPath}`), { name: 'x' }));
    }
  });

  it('loans, fines, incidents: staff on the campus or the borrower read; nobody writes', async () => {
    for (const collectionName of ['libraryLoans', 'libraryFines', 'libraryIncidents']) {
      const path = `schools/12/${collectionName}/a`;
      await assertSucceeds(getDoc(doc(db('4'), path)));
      await assertFails(getDoc(doc(db('8'), path))); // other campus
      await assertFails(getDoc(doc(db('4', { ...staff, schoolId: 13 }), path)));
      await assertSucceeds(getDoc(doc(db('parent-1', parent), path)));
      await assertFails(getDoc(doc(db('parent-1', { ...parent, wardStudentIds: [999] }), path)));
      await assertFails(setDoc(doc(db('4'), path), { status: 'x' }));
    }
  });

  it('a parent browses the catalogue only, reads their ward\'s membership, and writes nothing', async () => {
    for (const documentPath of ['libraries/a', 'libraryCategories/a', 'libraryCatalogue/a'])
      await assertSucceeds(getDoc(doc(db('parent-1', parent), `schools/12/${documentPath}`)));
    for (const documentPath of ['libraryCopies/a', 'libraryBooks/a', 'libraryBorrowingPolicies/a', 'libraryMembers/a'])
      await assertFails(getDoc(doc(db('parent-1', parent), `schools/12/${documentPath}`)));
    await env.withSecurityRulesDisabled((context) => setDoc(doc(context.firestore(), 'schools/12/libraryMembers/501'), { personErpId: 501 }));
    await assertSucceeds(getDoc(doc(db('parent-1', parent), 'schools/12/libraryMembers/501')));
    await assertFails(getDoc(doc(db('parent-1', { ...parent, schoolId: 13 }), 'schools/12/libraryCatalogue/a')));
    await assertFails(setDoc(doc(db('parent-1', parent), 'schools/12/libraries/a'), { name: 'x' }));
  });
});

describe('library client writes (no callable)', () => {
  const stamp = (action, uid = '4') => ({ by: uid, action, at: serverTimestamp() });
  const title = { title: 'Wings of Fire', authors: ['Kalam'], categoryId: 'cat', identityKey: 'bib:x', status: 'active', createdBy: '4' };
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await setDoc(doc(firestore, 'schools/12/userAccess/4'), { permissions: [], campusIds: [31], hasAllCampuses: false });
      await setDoc(doc(firestore, 'schools/12/libraryCategories/cat'), { name: 'General' });
      await setDoc(doc(firestore, 'schools/12/libraries/main'), { campusId: 31, status: 'active' });
      await setDoc(doc(firestore, 'schools/12/libraries/junior'), { campusId: 32, status: 'active' });
      await setDoc(doc(firestore, 'schools/12/libraries/other'), { campusId: 31, status: 'inactive' });
      await setDoc(doc(firestore, 'schools/12/libraryCatalogue/t1'), { ...title, createdBy: '9' });
      await setDoc(doc(firestore, 'schools/12/libraryCopies/c1'), { campusId: 31, libraryId: 'main', status: 'available', condition: 'good', shelf: null, remarks: null });
      await setDoc(doc(firestore, 'schools/12/libraryCopies/c2'), { campusId: 31, libraryId: 'main', status: 'issued', condition: 'good', shelf: null, remarks: null });
      await setDoc(doc(firestore, 'schools/12/libraryMembers/501'), { campusIds: [31], blocked: false });
      await setDoc(doc(firestore, 'schools/12/libraryMembers/502'), { campusIds: [31, 32], blocked: false });
    }),
  );
  const parent = { schoolId: 12, personType: 'parent' };

  it('titles: staff create / edit / deactivate, always stamped; and parents fail', async () => {
    const created = { ...title, lastWrite: stamp('libraryCatalogue.create') };
    await assertSucceeds(setDoc(doc(db('4'), 'schools/12/libraryCatalogue/t2'), created));
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryCatalogue/t3'), { ...title })); // no stamp
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryCatalogue/t3'), { ...created, lastWrite: stamp('libraryCatalogue.create', 'someone-else') }));
    await assertFails(setDoc(doc(db('p', parent), 'schools/12/libraryCatalogue/t3'), created));
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryCatalogue/t1'), { title: 'New', identityKey: 'bib:y', lastWrite: stamp('libraryCatalogue.update') }));
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryCatalogue/t1'), { status: 'inactive', lastWrite: stamp('libraryCatalogue.status') }));
  });

  it('title keys: create-only (never overwritten), readable and deletable, library keys only', async () => {
    const key = { keyType: 'libraryTitle', value: 'bib:x', documentPath: 'libraryCatalogue/t1' };
    await assertSucceeds(setDoc(doc(db('4'), 'schools/12/uniqueKeys/libraryTitle_bib%3Ax'), key));
    await assertSucceeds(getDoc(doc(db('4'), 'schools/12/uniqueKeys/libraryTitle_bib%3Ax')));
    await assertFails(setDoc(doc(db('4'), 'schools/12/uniqueKeys/libraryTitle_bib%3Ax'), { ...key, documentPath: 'libraryCatalogue/t9' }));
    await assertSucceeds(deleteDoc(doc(db('4'), 'schools/12/uniqueKeys/libraryTitle_bib%3Ax')));
    await assertFails(setDoc(doc(db('4'), 'schools/12/uniqueKeys/inventoryItem_x'), { keyType: 'inventoryItem' }));
    await assertFails(setDoc(doc(db('p', parent), 'schools/12/uniqueKeys/libraryTitle_z'), key));
  });

  it('copies: edit; move only an available copy to another active library on an allowed campus', async () => {
    const edit = { condition: 'fair', shelf: 'A-3', remarks: null, lastWrite: stamp('libraryCopy.update') };
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryCopies/c1'), edit));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryCopies/c1'), { condition: 'fair', shelf: null, remarks: null })); // unstamped
    await assertFails(updateDoc(doc(db('p', parent), 'schools/12/libraryCopies/c1'), edit));
    const move = (libraryId, campusId) => ({ libraryId, campusId, shelf: 'J-1', lastWrite: stamp('libraryCopy.move') });
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryCopies/c1'), move('junior', 32))); // campus 32 not allowed
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryCopies/c1'), move('other', 31))); // inactive library
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryCopies/c2'), move('other', 31))); // not available
    await env.withSecurityRulesDisabled((context) => setDoc(doc(context.firestore(), 'schools/12/libraries/second'), { campusId: 31, status: 'active' }));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryCopies/c1'), move('second', 99))); // campus must come from the library
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryCopies/c1'), move('second', 31)));
  });

  it('policies: stamped create on an active library of an allowed campus; library, person type and campus fixed', async () => {
    await env.withSecurityRulesDisabled((context) => setDoc(doc(context.firestore(), 'schools/12/libraryBorrowingPolicies/p1'), { libraryId: 'main', campusId: 31, memberType: 'student', status: 'active' }));
    const policy = (libraryId, campusId, action = 'libraryPolicy.create', by = '4') => ({ libraryId, campusId, memberType: 'student', status: 'active', createdBy: by, lastWrite: stamp(action) });
    await assertSucceeds(setDoc(doc(db('4'), 'schools/12/libraryBorrowingPolicies/p2'), policy('main', 31)));
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryBorrowingPolicies/p3'), { ...policy('main', 31), lastWrite: null })); // unstamped
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryBorrowingPolicies/p3'), policy('junior', 32))); // campus 32 not allowed
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryBorrowingPolicies/p3'), policy('other', 31))); // inactive library
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryBorrowingPolicies/p3'), policy('main', 32))); // campus must come from the library
    await assertFails(setDoc(doc(db('p', parent), 'schools/12/libraryBorrowingPolicies/p3'), policy('main', 31, 'libraryPolicy.create', 'p')));
    const edit = (extra) => ({ libraryId: 'main', campusId: 31, memberType: 'student', maxBooks: 3, lastWrite: stamp('libraryPolicy.update'), ...extra });
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryBorrowingPolicies/p1'), edit({})));
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryBorrowingPolicies/p1'), { status: 'inactive', lastWrite: stamp('libraryPolicy.status') }));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryBorrowingPolicies/p1'), edit({ memberType: 'teacher' })));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryBorrowingPolicies/p1'), edit({ libraryId: 'other' })));
  });

  it('circulation: stamped loans, narrow copy / member edits, library counters, fines and incidents on the campus', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await setDoc(doc(firestore, 'schools/12/libraryLoans/l1'), { campusId: 31, status: 'active' });
      await setDoc(doc(firestore, 'schools/12/libraryLoans/l2'), { campusId: 31, status: 'returned' });
    });
    const loan = { campusId: 31, status: 'active', issuedBy: '4', lastWrite: stamp('libraryLoan.issue') };
    await assertSucceeds(setDoc(doc(db('4'), 'schools/12/libraryLoans/l3'), loan));
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryLoans/l4'), { ...loan, lastWrite: null }));
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryLoans/l4'), { ...loan, campusId: 32 }));
    await assertFails(setDoc(doc(db('p', parent), 'schools/12/libraryLoans/l4'), loan));
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryLoans/l1'), { status: 'returned', lastWrite: stamp('libraryLoan.return') }));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryLoans/l2'), { status: 'active', lastWrite: stamp('libraryLoan.renew') })); // not active
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryLoans/l3'), { status: 'active', lastWrite: stamp('libraryLoan.issue') })); // wrong action
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryCopies/c1'), { status: 'issued', activeLoanId: 'l3' }));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryCopies/c1'), { status: 'in_transit' }));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryCopies/c1'), { status: 'lost', libraryId: 'junior' }));
    const member = { memberType: 'student', personErpId: 777, campusIds: [31], activeLoans: 1, blocked: false, createdBy: '4' };
    await assertSucceeds(setDoc(doc(db('4'), 'schools/12/libraryMembers/777'), member));
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryMembers/778'), { ...member, blocked: true }));
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryMembers/778'), { ...member, campusIds: [32] }));
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryMembers/501'), { activeLoans: 2, name: 'A' }));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryMembers/501'), { memberType: 'teacher' }));
    await assertSucceeds(setDoc(doc(db('4'), 'schools/12/counters/LIS_2026-27'), { next: 1 }));
    await assertFails(setDoc(doc(db('4'), 'schools/12/counters/PO_2026-27'), { next: 1 }));
    await assertFails(setDoc(doc(db('p', parent), 'schools/12/counters/LIS_2026-27'), { next: 1 }));
    const fine = { campusId: 31, status: 'outstanding', createdBy: '4' };
    await assertSucceeds(setDoc(doc(db('4'), 'schools/12/libraryFines/l1__overdue'), fine));
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryFines/x'), { ...fine, campusId: 32 }));
    await assertFails(setDoc(doc(db('4'), 'schools/12/libraryFines/x'), { ...fine, status: 'paid' }));
    const settle = (extra, action = 'libraryFine.waive') => ({ waived: 5, outstanding: 5, status: 'partially_paid', lastWrite: stamp(action), ...extra });
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryFines/l1__overdue'), settle({})));
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryFines/l1__overdue'), settle({ paid: 5 }, 'libraryFine.setPayment')));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryFines/l1__overdue'), settle({}, 'libraryFine.other')));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryFines/l1__overdue'), settle({ amount: 1 }))); // amount is fixed
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryFines/l1__overdue'), { waived: 5 })); // unstamped
    await assertFails(updateDoc(doc(db('p', parent), 'schools/12/libraryFines/l1__overdue'), settle({})));
    await assertSucceeds(addDoc(collection(db('4'), 'schools/12/libraryIncidents'), { campusId: 31, status: 'open', createdBy: '4' }));
    await assertFails(addDoc(collection(db('4'), 'schools/12/libraryIncidents'), { campusId: 32, status: 'open', createdBy: '4' }));
    await env.withSecurityRulesDisabled((context) => setDoc(doc(context.firestore(), 'schools/12/libraryIncidents/i1'), { campusId: 31, status: 'open' }));
    const resolve = (extra) => ({ status: 'resolved', resolution: 'repaired', charge: 0, lastWrite: stamp('libraryIncident.resolve'), ...extra });
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryIncidents/i1'), resolve({})));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryIncidents/i1'), resolve({}))); // no longer open
    await env.withSecurityRulesDisabled((context) => setDoc(doc(context.firestore(), 'schools/12/libraryIncidents/i2'), { campusId: 31, status: 'open', barcode: 'c1' }));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryIncidents/i2'), resolve({ barcode: 'c9' }))); // identity is fixed
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryIncidents/i2'), resolve({ lastWrite: null })));
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryCopies/c1'), { status: 'withdrawn' }));
  });

  it('members: manual block and unblock, every campus of the member must be the caller\'s', async () => {
    const block = { blocked: true, blockedBy: 'manual', blockReason: 'Misconduct', lastWrite: stamp('libraryMember.block') };
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryMembers/501'), block));
    await assertSucceeds(updateDoc(doc(db('4'), 'schools/12/libraryMembers/501'), { blocked: false, blockedBy: null, blockReason: null, lastWrite: stamp('libraryMember.block') }));
    await assertFails(updateDoc(doc(db('4'), 'schools/12/libraryMembers/502'), block)); // member also on campus 32
    await assertFails(updateDoc(doc(db('p', parent), 'schools/12/libraryMembers/501'), block));
  });
});

describe('devices', () => {
  const token = { token: 'abc', platform: 'android', app: 'icueadmin', updatedAt: new Date() };

  it('owner manages own tokens with the allowed shape', async () => {
    await assertSucceeds(setDoc(doc(db('1'), 'devices/1/tokens/h1'), token));
    await assertSucceeds(getDoc(doc(db('1'), 'devices/1/tokens/h1')));
    await assertSucceeds(deleteDoc(doc(db('1'), 'devices/1/tokens/h1')));
    await assertFails(setDoc(doc(db('1'), 'devices/1/tokens/h2'), { ...token, extra: 1 }));
    await assertFails(setDoc(doc(db('1'), 'devices/1/tokens/h3'), { ...token, token: 5 }));
  });

  it('nobody else touches them', async () => {
    await assertFails(getDoc(doc(db('1'), 'devices/2/tokens/t')));
    await assertFails(deleteDoc(doc(db('1'), 'devices/2/tokens/t')));
    await assertFails(setDoc(doc(db('1'), 'devices/2/tokens/h'), token));
    await assertFails(setDoc(doc(anon(), 'devices/1/tokens/h'), token));
  });

  it('device doc holds only mute', async () => {
    await assertSucceeds(setDoc(doc(db('1'), 'devices/1'), { mute: { 'inventory.lowStock': true } }));
    await assertFails(setDoc(doc(db('1'), 'devices/1'), { mute: {}, permissions: ['x'] }));
    await assertFails(setDoc(doc(db('1'), 'devices/2'), { mute: {} }));
  });
});

describe('storage', () => {
  const storageFor = (uid, claims = staff) => env.authenticatedContext(uid, claims).storage();
  const path = 'schools/12/inv/inventoryItems/i1/a.png';

  it('reads need same school and module view permission', async () => {
    await assertSucceeds(getBytes(ref(storageFor('1'), path)));
    await assertFails(getBytes(ref(storageFor('2'), path)));
    await assertFails(getBytes(ref(storageFor('1', { ...staff, schoolId: 13 }), path)));
    await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), path)));
  });

  it('writes are denied until upload registration exists', async () => {
    await assertFails(uploadString(ref(storageFor('1'), 'schools/12/inv/inventoryItems/i1/b.png'), 'x'));
  });
});

describe('procurement (Inv-3)', () => {
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      const access = (permissions, campusIds = [31]) => ({ permissions, campusIds, hasAllCampuses: false });
      await setDoc(doc(firestore, 'schools/12/userAccess/parent-req'), access(['inventory.purchaseRequest.request']));
      await setDoc(doc(firestore, 'schools/12/userAccess/parent-apr'), access(['inventory.purchaseRequest.approve']));
      await setDoc(doc(firestore, 'schools/12/userAccess/proc'), access(['inventory.procure.operate']));
      await setDoc(doc(firestore, 'schools/12/userAccess/ven'), access(['inventory.vendors.manage']));
      await setDoc(doc(firestore, 'schools/12/userAccess/parent-32'), access(['inventory.purchaseRequest.approve'], [32]));
      await setDoc(doc(firestore, 'schools/12/inventoryPurchaseRequests/pr1'), { campusId: 31, createdBy: 'parent-req' });
      await setDoc(doc(firestore, 'schools/12/inventoryVendors/v1'), { name: 'v' });
      await setDoc(doc(firestore, 'schools/12/inventoryItems/i'), { name: 'i' });
    }),
  );

  it('purchase requests: requester sees own, approvers and procurement the campus', async () => {
    const readPurchaseRequest = (userId) => getDoc(doc(db(userId), 'schools/12/inventoryPurchaseRequests/pr1'));
    await assertSucceeds(readPurchaseRequest('parent-req'));
    await assertSucceeds(readPurchaseRequest('parent-apr'));
    await assertSucceeds(readPurchaseRequest('proc'));
    await assertFails(readPurchaseRequest('parent-32'));
    await assertFails(readPurchaseRequest('ven'));
    await assertFails(getDoc(doc(db('parent-apr', { ...staff, schoolId: 13 }), 'schools/12/inventoryPurchaseRequests/pr1')));
    await assertSucceeds(getDocs(query(collection(db('parent-req'), 'schools/12/inventoryPurchaseRequests'), where('createdBy', '==', 'parent-req'))));
    await assertSucceeds(setDoc(doc(db('parent-req'), 'schools/12/inventoryPurchaseRequests/pr1'), { status: 'approved' }));
    await assertFails(setDoc(doc(db('2'), 'schools/12/inventoryPurchaseRequests/pr1'), { status: 'approved' }));
  });

  it('vendors: vendor managers write, procurement reads; requesters can browse items', async () => {
    await assertSucceeds(getDoc(doc(db('ven'), 'schools/12/inventoryVendors/v1')));
    await assertSucceeds(getDoc(doc(db('proc'), 'schools/12/inventoryVendors/v1')));
    await assertFails(getDoc(doc(db('parent-req'), 'schools/12/inventoryVendors/v1')));
    await assertSucceeds(setDoc(doc(db('ven'), 'schools/12/inventoryVendors/v1'), { name: 'x' }));
    await assertFails(setDoc(doc(db('proc'), 'schools/12/inventoryVendors/v1'), { name: 'x' }));
    await assertSucceeds(getDoc(doc(db('parent-req'), 'schools/12/inventoryItems/i')));
  });
});

describe('quotations and purchase orders (Inv-4)', () => {
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      const access = (permissions, campusIds = [31]) => ({ permissions, campusIds, hasAllCampuses: false });
      await setDoc(doc(firestore, 'schools/12/userAccess/proc'), access(['inventory.procure.operate']));
      await setDoc(doc(firestore, 'schools/12/userAccess/far'), access(['inventory.procure.operate'], [99]));
      await setDoc(doc(firestore, 'schools/12/userAccess/parent-apr'), access(['inventory.purchaseRequest.approve']));
      await setDoc(doc(firestore, 'schools/12/inventoryQuotations/q1'), { campusId: 31, purchaseRequestId: 'pr1' });
      await setDoc(doc(firestore, 'schools/12/inventoryPurchaseOrders/po1'), { campusId: 31, deliveryCampusId: 31 });
      await setDoc(doc(firestore, 'schools/12/inventoryPurchaseOrders/po1/revisions/r1'), { reason: 'x' });
      await setDoc(doc(firestore, 'schools/12/userAccess/store'), access(['inventory.stock.operate']));
      await setDoc(doc(firestore, 'schools/12/userAccess/store_far'), access(['inventory.stock.operate'], [99]));
      await setDoc(doc(firestore, 'schools/12/inventoryInvoices/i1'), { campusId: 31, purchaseOrderId: 'po1' });
    }),
  );

  it('procurement on the campus reads; others and writes are denied', async () => {
    for (const path of ['inventoryQuotations/q1', 'inventoryPurchaseOrders/po1', 'inventoryPurchaseOrders/po1/revisions/r1']) {
      await assertSucceeds(getDoc(doc(db('proc'), `schools/12/${path}`)));
      await assertFails(getDoc(doc(db('parent-apr'), `schools/12/${path}`)));
    }
    await assertFails(getDoc(doc(db('far'), 'schools/12/inventoryQuotations/q1')));
    await assertFails(getDoc(doc(db('far'), 'schools/12/inventoryPurchaseOrders/po1')));
    await assertFails(setDoc(doc(db('proc'), 'schools/12/inventoryPurchaseOrders/po1'), { status: 'issued' }));
  });

  it('invoices follow procurement; receiving staff read orders due at their campus only', async () => {
    await assertSucceeds(getDoc(doc(db('proc'), 'schools/12/inventoryInvoices/i1')));
    await assertFails(getDoc(doc(db('far'), 'schools/12/inventoryInvoices/i1')));
    await assertFails(getDoc(doc(db('store'), 'schools/12/inventoryInvoices/i1')));
    await assertSucceeds(setDoc(doc(db('proc'), 'schools/12/inventoryInvoices/i1'), { paymentStatus: 'paid' }));
    await assertFails(setDoc(doc(db('2'), 'schools/12/inventoryInvoices/i1'), { paymentStatus: 'paid' }));
    await assertSucceeds(getDoc(doc(db('store'), 'schools/12/inventoryPurchaseOrders/po1')));
    await assertFails(getDoc(doc(db('store_far'), 'schools/12/inventoryPurchaseOrders/po1')));
    await assertFails(getDoc(doc(db('store'), 'schools/12/inventoryQuotations/q1')));
  });
});

describe('assets and maintenance (Inv-6)', () => {
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      const access = (permissions, campusIds = [31]) => ({ permissions, campusIds, hasAllCampuses: false });
      await setDoc(doc(firestore, 'schools/12/userAccess/parent-view'), access(['inventory.assets.view']));
      await setDoc(doc(firestore, 'schools/12/userAccess/far'), access(['inventory.assets.view'], [99]));
      await setDoc(doc(firestore, 'schools/12/userAccess/none'), access(['inventory.stock.view']));
      await setDoc(doc(firestore, 'schools/12/inventoryAssets/a1'), { campusId: 31, status: 'available' });
      await setDoc(doc(firestore, 'schools/12/inventoryAssets/a1/history/h1'), { campusId: 31, type: 'registered' });
      await setDoc(doc(firestore, 'schools/12/inventoryMaintenanceJobs/m1'), { campusId: 31, assetId: 'a1' });
      await setDoc(doc(firestore, 'schools/12/inventoryAssetAssignments/g1'), { campusId: 31, assetId: 'a1', personErpId: 884 });
    }),
  );

  it('asset viewers on the campus read; others and every write are denied', async () => {
    for (const path of ['inventoryAssets/a1', 'inventoryAssets/a1/history/h1', 'inventoryMaintenanceJobs/m1']) {
      await assertSucceeds(getDoc(doc(db('parent-view'), `schools/12/${path}`)));
      await assertFails(getDoc(doc(db('far'), `schools/12/${path}`)));
    }
    await assertSucceeds(getDoc(doc(db('parent-view'), 'schools/12/inventoryAssetAssignments/g1')));
    await assertFails(getDoc(doc(db('far', { schoolId: 12, personType: 'staff', personErpId: 1 }), 'schools/12/inventoryAssetAssignments/g1')));
    await assertFails(getDoc(doc(db('none'), 'schools/12/inventoryAssets/a1')));
    await assertFails(setDoc(doc(db('parent-view'), 'schools/12/inventoryAssets/a1'), { status: 'lost' }));
    await assertFails(setDoc(doc(db('parent-view'), 'schools/12/inventoryMaintenanceJobs/m1'), { cost: 0 }));
  });

  it('a custodian reads their own assignment only', async () => {
    await assertSucceeds(getDoc(doc(db('none'), 'schools/12/inventoryAssetAssignments/g1'))); // personErpId 884
    await assertFails(getDoc(doc(db('none', { schoolId: 12, personType: 'staff', personErpId: 1 }), 'schools/12/inventoryAssetAssignments/g1')));
    await assertFails(getDoc(doc(db('none'), 'schools/12/inventoryAssets/a1')));
  });
});

describe('verification and reports (Inv-7)', () => {
  beforeEach(() =>
    env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      const access = (permissions, campusIds = [31]) => ({ permissions, campusIds, hasAllCampuses: false });
      await setDoc(doc(firestore, 'schools/12/userAccess/count'), access(['inventory.stock.view', 'inventory.stock.operate']));
      await setDoc(doc(firestore, 'schools/12/inventoryVerifications/v2'), { campusId: 31, status: 'submitted' });
      await setDoc(doc(firestore, 'schools/12/inventoryVerifications/v2/lineItems/l1'), { campusId: 31, expected: 3 });
      await setDoc(doc(firestore, 'schools/12/userAccess/stock'), access(['inventory.stock.view']));
      await setDoc(doc(firestore, 'schools/12/userAccess/rep'), access(['inventory.reports.view']));
      await setDoc(doc(firestore, 'schools/12/userAccess/far'), access(['inventory.stock.view', 'inventory.reports.view'], [99]));
      await setDoc(doc(firestore, 'schools/12/inventoryVerifications/v1'), { campusId: 31, status: 'counting' });
      await setDoc(doc(firestore, 'schools/12/inventoryVerifications/v1/lineItems/l1'), { campusId: 31, expected: 3 });
      await setDoc(doc(firestore, 'schools/12/inventoryPurchaseOrders/po1'), { campusId: 31, deliveryCampusId: 31 });
      await setDoc(doc(firestore, 'schools/12/inventoryVendors/ven1'), { name: 'Acme' });
    }),
  );

  it('stock viewers on the campus read sessions and lines; stock viewers cannot count', async () => {
    for (const path of ['inventoryVerifications/v1', 'inventoryVerifications/v1/lineItems/l1']) {
      await assertSucceeds(getDoc(doc(db('stock'), `schools/12/${path}`)));
      await assertFails(getDoc(doc(db('far'), `schools/12/${path}`)));
    }
    await assertFails(updateDoc(doc(db('stock'), 'schools/12/inventoryVerifications/v1/lineItems/l1'), { counted: 3, difference: 0, countedBy: 'stock' }));
  });

  it('operators count lines of a counting session (offline-queued writes), nothing else', async () => {
    const line = (uid, v = 'v1') => doc(db(uid), `schools/12/inventoryVerifications/${v}/lineItems/l1`);
    const count = { counted: 5, difference: 2, reason: 'excess', countedBy: 'count' };
    await assertSucceeds(updateDoc(line('count'), count));
    await assertFails(updateDoc(line('count'), { ...count, difference: 1 })); // difference must match expected
    await assertFails(updateDoc(line('count'), { ...count, countedBy: 'stock' }));
    await assertFails(updateDoc(line('count'), { ...count, expected: 99 })); // snapshot is not editable
    await assertFails(updateDoc(line('count'), { ...count, reason: 'because' }));
    await assertFails(updateDoc(line('count', 'v2'), count)); // session no longer counting
    await assertFails(updateDoc(line('far'), count));
  });

  it('report viewers read the campus records of every report collection and the vendors', async () => {
    await assertSucceeds(getDoc(doc(db('rep'), 'schools/12/inventoryPurchaseOrders/po1')));
    await assertSucceeds(getDoc(doc(db('rep'), 'schools/12/inventoryVerifications/v1')));
    await assertSucceeds(getDoc(doc(db('rep'), 'schools/12/inventoryVendors/ven1')));
    await assertFails(getDoc(doc(db('far'), 'schools/12/inventoryPurchaseOrders/po1')));
    await assertFails(getDoc(doc(db('stock'), 'schools/12/inventoryPurchaseOrders/po1')));
  });
});
