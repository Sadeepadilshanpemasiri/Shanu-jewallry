import assert from 'node:assert/strict';

const project = 'demo-jewellery-manager';
if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080' ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099') {
  throw new Error('Run with the local Firebase emulators.');
}
const auth = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local', {
  method: 'POST', headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({email: 'owner@jewellery.test', password: 'JewelleryDemo123', returnSecureToken: true}),
});
assert.equal(auth.status, 200);
const owner = await auth.json();
const root = 'projects/' + project + '/databases/(default)/documents';
const database = 'http://127.0.0.1:8080/v1/' + root;
const headers = {Authorization: 'Bearer ' + owner.idToken, 'Content-Type': 'application/json'};
const id = 'archive-' + Date.now();
const text = (stringValue) => ({stringValue});
const boolean = (booleanValue) => ({booleanValue});
const product = (fields, mask) => ({
  update: {name: root + '/products/' + id, fields},
  ...(mask ? {updateMask: {fieldPaths: Object.keys(fields)}} : {}),
});
const commit = (writes) => fetch(database + ':commit', {
  method: 'POST', headers, body: JSON.stringify({writes}),
});
assert.equal((await commit([product({name: text('Test ring'), sku: text('TEST-RING'),
  stockQty: {integerValue: '0'}, isActive: boolean(true)})])).status, 200);

const change = (archived, action) => product({isActive: boolean(!archived), lastArchiveAction: text(action)}, true);
const audit = (archived, action) => ({
  update: {name: root + '/inventory_activity/' + action, fields: {
    productId: text(id), productName: text('Test ring'), actorUid: text(owner.localId), archived: boolean(archived),
  }},
  updateTransforms: [{fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME'}],
});
assert.equal((await commit([change(true, id + '-archive')])).status, 403);
assert.equal((await commit([audit(true, id + '-archive')])).status, 403);
for (const archived of [true, false]) {
  const action = id + (archived ? '-archive' : '-restore');
  const saved = await commit([change(archived, action), audit(archived, action)]);
  assert.equal(saved.status, 200, await saved.text());
  const current = await (await fetch(database + '/products/' + id, {headers})).json();
  assert.equal(current.fields.stockQty.integerValue, '0');
  assert.equal(current.fields.sku.stringValue, 'TEST-RING');
  assert.equal(current.fields.isActive.booleanValue, !archived);
  assert.equal((await fetch(database + '/inventory_activity/' + action, {method: 'DELETE', headers})).status, 403);
}
console.log('PASS: archive and restore preserve product stock and SKU and require an immutable activity entry.');