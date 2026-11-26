import assert from 'node:assert/strict';

const project = 'demo-jewellery-manager';
const auth = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const db = 'http://127.0.0.1:8080/v1/projects/' + project + '/databases/(default)/documents';
const email = 'owner@jewellery.test';
const password = 'JewelleryDemo123';

async function account(method, email, password) {
  const response = await fetch(auth + '/accounts:' + method + '?key=local', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email, password, returnSecureToken: true}),
  });
  return response.json();
}

const created = await account('signUp', email, password);
const owner = created.error?.message === 'EMAIL_EXISTS'
  ? await account('signInWithPassword', email, password) : created;
assert.ok(owner.localId, owner.error?.message ?? 'Could not seed local owner.');
const result = await fetch(db + '/access/owner', {
  method: 'PATCH',
  headers: {'Content-Type': 'application/json', Authorization: 'Bearer owner'},
  body: JSON.stringify({fields: {uid: {stringValue: owner.localId}}}),
});
assert.ok(result.ok, await result.text());

if (process.argv.includes('--verify')) {
  const stranger = await account('signUp', 'stranger-' + Date.now() + '@jewellery.test', password);
  assert.ok(stranger.idToken);
  const headers = (token) => ({Authorization: 'Bearer ' + token, 'Content-Type': 'application/json'});
  const document = db + '/test_records/one';
  const body = JSON.stringify({fields: {name: {stringValue: 'Owner only'}}});
  assert.equal((await fetch(db + '/access/owner', {headers: headers(owner.idToken)})).status, 200);
  assert.equal((await fetch(db + '/access/owner', {headers: headers(stranger.idToken)})).status, 403);
  assert.equal((await fetch(document, {method: 'PATCH', headers: headers(owner.idToken), body})).status, 200);
  assert.equal((await fetch(document, {headers: headers(stranger.idToken)})).status, 403);
  assert.equal((await fetch(document)).status, 403);
  assert.equal((await fetch(db + '/access/owner', {method: 'PATCH', headers: headers(owner.idToken), body})).status, 403);
  console.log('PASS: Firestore accepts the configured owner and denies other users and owner reassignment.');

  const root = 'projects/' + project + '/databases/(default)/documents';
  const product = '/products/test-ring';
  const movement = '/stock_movements/opening';
  const string = (stringValue) => ({stringValue});
  const int = (value) => ({integerValue: String(value)});
  const firestore = (path, fields) => ({name: root + path, fields});
  const audit = (path, quantity, balance, type) => ({
    update: firestore(path, {
      productId: string('test-ring'), qty: int(quantity), balance: int(balance),
      reason: string('Test audit entry'), type: string(type), actorUid: string(owner.localId),
    }),
    updateTransforms: [{fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME'}],
  });
  const commit = (writes) => fetch(db + ':commit', {
    method: 'POST', headers: headers(owner.idToken), body: JSON.stringify({writes}),
  });

  const created = await commit([
    {update: firestore(product, {stockQty: int(3), lastMovementId: string('opening')})},
    audit(movement, 3, 3, 'stockIn'),
  ]);
  assert.equal(created.status, 200, await created.text());
  assert.equal((await commit([{update: firestore(product, {stockQty: int(0)})}])).status, 403);
  assert.equal((await commit([
    {update: firestore(product, {stockQty: int(-1), lastMovementId: string('negative')})},
    audit('/stock_movements/negative', -4, -1, 'stockOut'),
  ])).status, 403);
  assert.equal((await commit([
    {update: firestore(product, {stockQty: int(3), lastMovementId: string('forged')})},
    audit('/stock_movements/forged', 1, 3, 'stockIn'),
  ])).status, 403);
  const changed = await commit([
    {update: firestore(product, {stockQty: int(1), lastMovementId: string('out')})},
    audit('/stock_movements/out', -2, 1, 'stockOut'),
  ]);
  assert.equal(changed.status, 200, await changed.text());
  assert.equal((await fetch(db + movement, {method: 'DELETE', headers: headers(owner.idToken)})).status, 403);
  assert.equal((await (await fetch(db + product, {headers: headers(owner.idToken)})).json()).fields.stockQty.integerValue, '1');
  console.log('PASS: stock and audit commit together, negative stock and forged movements are denied, audit records are immutable.');

  if (process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    const bucket = 'http://127.0.0.1:9199/v0/b/' + project + '.appspot.com/o';
    const photo = 'products/test-ring/emulator-photo';
    const bytes = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+R48kAAAAASUVORK5CYII=', 'base64');
    const boundary = 'inventory-test-boundary';
    const upload = (token, contentType) => fetch(bucket + '?name=' + encodeURIComponent(photo), {
      method: 'POST',
      headers: {
        Authorization: 'Firebase ' + token,
        'X-Goog-Upload-Protocol': 'multipart',
        'Content-Type': 'multipart/related; boundary=' + boundary,
      },
      body: Buffer.concat([
        Buffer.from('--' + boundary + '\r\nContent-Type: application/json; charset=utf-8\r\n\r\n' +
          JSON.stringify({name: photo, contentType}) + '\r\n--' + boundary + '\r\nContent-Type: ' + contentType + '\r\n\r\n'),
        bytes,
        Buffer.from('\r\n--' + boundary + '--'),
      ]),
    });
    assert.equal((await upload(stranger.idToken, 'image/png')).status, 403);
    assert.equal((await upload(owner.idToken, 'text/plain')).status, 403);
    const uploaded = await upload(owner.idToken, 'image/png');
    assert.equal(uploaded.status, 200, await uploaded.text());
    console.log('PASS: Storage accepts owner product images and denies non-owner and invalid file types.');
  }
}

console.log('Local owner login: ' + email + ' / ' + password);