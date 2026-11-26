const assert = require('node:assert/strict');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {runReminders} = require('../lib/reminders');

const project = 'demo-jewellery-manager';
const firestore = process.env.FIRESTORE_EMULATOR_HOST;
const auth = process.env.FIREBASE_AUTH_EMULATOR_HOST;
if (firestore !== '127.0.0.1:8080' || auth !== '127.0.0.1:9099') {
  throw new Error('Run with the local Auth and Firestore emulators.');
}
initializeApp({projectId: project});
const db = getFirestore();
const root = 'projects/' + project + '/databases/(default)/documents';
const rest = 'http://' + firestore + '/v1/' + root;
const authUrl = 'http://' + auth + '/identitytoolkit.googleapis.com/v1/accounts:';
const hour = 3_600_000;
const day = 24 * hour;
const now = Date.now();
const text = (stringValue) => ({stringValue});
const boolean = (booleanValue) => ({booleanValue});
const timestamp = (value) => ({timestampValue: new Date(value).toISOString()});
const nil = {nullValue: null};

async function login(method, email, password) {
  const response = await fetch(authUrl + method + '?key=local', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email, password, returnSecureToken: true}),
  });
  assert.ok(response.ok, await response.clone().text());
  return response.json();
}

const headers = (token) => ({Authorization: 'Bearer ' + token, 'Content-Type': 'application/json'});
function patch(path, token, fields) {
  const params = new URLSearchParams();
  for (const key of Object.keys(fields)) params.append('updateMask.fieldPaths', key);
  return fetch(rest + '/' + path + '?' + params, {
    method: 'PATCH', headers: headers(token), body: JSON.stringify({fields}),
  });
}

async function main() {
  const owner = await login('signInWithPassword', 'owner@jewellery.test', 'JewelleryDemo123');
  const stranger = await login('signUp', 'notice-test-' + now + '@jewellery.test', 'SecureTest123!');
  await db.doc('settings/reminders').set({digestHour: 0});
  await Promise.all([
    db.doc('orders/notice-pending').set({status: 'pending', orderNo: 'JB-NT1',
      statusChangedAt: Timestamp.fromMillis(now - 25 * hour)}),
    db.doc('orders/notice-transit').set({status: 'shipped', orderNo: 'JB-NT2',
      shippedAt: Timestamp.fromMillis(now - 6 * day)}),
    db.doc('orders/notice-cod').set({status: 'delivered', orderNo: 'JB-NT3',
      paymentMethod: 'cod', paymentStatus: 'partial', deliveredAt: Timestamp.fromMillis(now - 4 * day)}),
    db.doc('products/notice-ring').set({name: 'Ring', isActive: true, stockQty: 1, lowStockThreshold: 2}),
  ]);
  await runReminders(db, now);
  const pending = 'notifications/stale-order--notice-pending';
  const stock = 'notifications/stock--notice-ring';
  assert.equal((await db.doc(pending).get()).get('state'), 'open');
  assert.equal((await db.doc('notifications/transit--notice-transit').get()).get('type'), 'transit');
  assert.equal((await db.doc('notifications/cod--notice-cod').get()).get('type'), 'cod');
  assert.equal((await db.doc(stock).get()).get('state'), 'open');

  const count = (await db.collection('notifications').get()).size;
  await runReminders(db, now + 15 * 60_000);
  assert.equal((await db.collection('notifications').get()).size, count);
  assert.equal((await db.doc(pending).get()).get('createdAt').toMillis(), now);

  assert.equal((await fetch(rest + '/' + pending, {headers: headers(stranger.idToken)})).status, 403);
  assert.equal((await patch(pending, owner.idToken, {title: text('Fake notice')})).status, 403);
  assert.equal((await patch('notifications/fake', owner.idToken, {isRead: boolean(true)})).status, 403);
  const snoozed = await patch(pending, owner.idToken, {
    state: text('snoozed'), isRead: boolean(true), snoozedUntil: timestamp(now + hour),
  });
  assert.equal(snoozed.status, 200, await snoozed.text());
  const done = await patch(stock, owner.idToken, {
    state: text('done'), isRead: boolean(true), snoozedUntil: nil,
  });
  assert.equal(done.status, 200, await done.text());

  await runReminders(db, now + 30 * 60_000);
  assert.equal((await db.doc(pending).get()).get('state'), 'snoozed');
  await runReminders(db, now + 2 * hour);
  assert.equal((await db.doc(pending).get()).get('state'), 'open');
  assert.equal((await db.doc(pending).get()).get('isRead'), false);
  assert.equal((await db.doc(stock).get()).get('state'), 'done');

  await db.doc('orders/notice-pending').update({status: 'cancelled'});
  await db.doc('orders/notice-cod').update({paymentStatus: 'paid'});
  await db.doc('products/notice-ring').update({stockQty: 5});
  await runReminders(db, now + 3 * hour);
  assert.equal((await db.doc(pending).get()).get('state'), 'resolved');
  assert.equal((await db.doc('notifications/cod--notice-cod').get()).get('state'), 'resolved');
  assert.equal((await db.doc(stock).get()).get('state'), 'resolved');

  await db.doc('products/notice-ring').update({stockQty: 0});
  await runReminders(db, now + 4 * hour);
  assert.equal((await db.doc(stock).get()).get('title'), 'Out of stock');
  assert.equal((await db.doc(stock).get()).get('state'), 'open');

  const deviceId = 'a'.repeat(32);
  const register = (uid, token) => fetch(rest + ':commit', {
    method: 'POST', headers: headers(token),
    body: JSON.stringify({writes: [{
      update: {name: root + '/push_devices/' + deviceId, fields: {uid: text(uid), token: text('synthetic-token')}},
      updateTransforms: [{fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME'}],
    }]}),
  });
  assert.equal((await register(stranger.localId, stranger.idToken)).status, 403);
  assert.equal((await register(stranger.localId, owner.idToken)).status, 403);
  const allowed = await register(owner.localId, owner.idToken);
  assert.equal(allowed.status, 200, await allowed.text());
  assert.equal((await fetch(rest + '/push_devices/' + deviceId, {headers: headers(stranger.idToken)})).status, 403);
  assert.equal((await fetch(rest + '/push_devices/' + deviceId, {method: 'DELETE', headers: headers(owner.idToken)})).status, 200);

  console.log('PASS: reminders deduplicate, snooze and reopen, resolve on recovery, and protect notice contents and browser tokens.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});