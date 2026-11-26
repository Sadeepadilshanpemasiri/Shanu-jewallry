import assert from 'node:assert/strict';

const project = 'demo-jewellery-manager';
const root = 'projects/' + project + '/databases/(default)/documents';
const database = 'http://127.0.0.1:8080/v1/' + root;
const auth = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local', {
  method: 'POST', headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({email: 'owner@jewellery.test', password: 'JewelleryDemo123', returnSecureToken: true}),
});
assert.ok(auth.ok, 'Seed the local owner before running this check.');
const owner = await auth.json();
const headers = {Authorization: 'Bearer ' + owner.idToken, 'Content-Type': 'application/json'};
const token = 'waybill-test-' + Date.now();
const first = token + '-first';
const second = token + '-second';
const text = (stringValue) => ({stringValue});
const update = (collection, id, fields) => ({update: {name: root + '/' + collection + '/' + id, fields}});
const commit = (writes) => fetch(database + ':commit', {
  method: 'POST', headers, body: JSON.stringify({writes}),
});
const created = await commit([first, second].map((id) => update('orders', id, {status: text('packed')})));
assert.equal(created.status, 200, await created.text());
const waybillId = (courier) => encodeURIComponent(courier.toLowerCase() + '/' + token.toUpperCase());
const shipOrder = (order, courier) => update('orders', order, {
  status: text('shipped'), courier: text(courier), trackingId: text(token), waybillKey: text(waybillId(courier)),
});
const reserve = (order, courier) => ({
  ...update('waybills', waybillId(courier), {
    orderId: text(order), courierKey: text(courier.toLowerCase()), trackingNormalized: text(token.toUpperCase()),
  }),
  updateTransforms: [{fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME'}],
});

assert.equal((await commit([shipOrder(first, 'Courier One')])).status, 403);
assert.equal((await commit([reserve(first, 'Courier One')])).status, 403);
const competing = await Promise.all([first, second].map(async (id) => {
  const response = await commit([shipOrder(id, 'Courier One'), reserve(id, 'Courier One')]);
  return [id, response.status];
}));
assert.deepEqual(competing.map(([, result]) => result).sort(), [200, 403]);
const [winner] = competing.find(([, result]) => result === 200);
const [loser] = competing.find(([, result]) => result === 403);
const reserved = await (await fetch(database + '/waybills/' + encodeURIComponent(waybillId('Courier One')), {headers})).json();
assert.equal(reserved.fields.orderId.stringValue, winner);
const untouched = await (await fetch(database + '/orders/' + loser, {headers})).json();
assert.equal(untouched.fields.status.stringValue, 'packed');
const crossCourier = await commit([shipOrder(loser, 'Courier Two'), reserve(loser, 'Courier Two')]);
assert.equal(crossCourier.status, 200, await crossCourier.text());
console.log('PASS: shipping and waybill claims commit together, concurrent reuse is rejected, and tracking is courier-scoped.');