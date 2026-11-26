import assert from 'node:assert/strict';

const project = 'demo-jewellery-manager';
const root = 'projects/' + project + '/databases/(default)/documents';
const database = 'http://127.0.0.1:8080/v1/' + root;
const auth = await fetch(
  'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local',
  {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      email: 'owner@jewellery.test', password: 'JewelleryDemo123', returnSecureToken: true,
    }),
  },
);
assert.ok(auth.ok, 'Seed the local owner before running this check.');
const owner = await auth.json();
const headers = {Authorization: 'Bearer ' + owner.idToken, 'Content-Type': 'application/json'};
const prefix = 'batch-' + Date.now();
const text = (stringValue) => ({stringValue});
const number = (integerValue) => ({integerValue: String(integerValue)});
const update = (collection, id, fields) => ({update: {name: root + '/' + collection + '/' + id, fields}});
const stock = (id, previous, next, event) => {
  const delta = next - previous;
  const movementId = id + '-' + event;
  return [
    update('products', id, {stockQty: number(next), lastMovementId: text(movementId)}),
    {
      ...update('stock_movements', movementId, {
        productId: text(id), orderId: text(prefix), qty: number(delta), balance: number(next),
        reason: text('Order emulator test'), actorUid: text(owner.localId),
        type: text(delta > 0 ? 'returned' : 'stockOut'),
      }),
      updateTransforms: [{fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME'}],
    },
  ];
};
const commit = (writes) => fetch(database + ':commit', {
  method: 'POST', headers, body: JSON.stringify({writes}),
});
const ids = Array.from({length: 6}, (_, i) => prefix + '-' + i);
for (const id of ids) {
  const response = await commit(stock(id, 0, 2, 'opening'));
  assert.equal(response.status, 200, await response.text());
}

const orderChanges = (status) => [
  update('orders', prefix, {status: text(status)}),
  update('customers', prefix, {totalOrders: number(1)}),
];
const confirmed = await commit([
  ...orderChanges('confirmed'),
  update('settings', prefix, {last: number(1)}),
  ...ids.flatMap((id) => stock(id, 2, 0, 'deduct')),
]);
assert.equal(confirmed.status, 200, await confirmed.text());

const invalid = await commit([
  ...orderChanges('cancelled'),
  ...ids.flatMap((id, index) => stock(id, 0, index === 0 ? -1 : 2, 'invalid')),
]);
assert.equal(invalid.status, 403, await invalid.text());
const order = await (await fetch(database + '/orders/' + prefix, {headers})).json();
assert.equal(order.fields.status.stringValue, 'confirmed');

const cancelled = await commit([
  ...orderChanges('cancelled'),
  ...ids.flatMap((id) => stock(id, 0, 2, 'restore')),
]);
assert.equal(cancelled.status, 200, await cancelled.text());
for (const id of ids) {
  const product = await (await fetch(database + '/products/' + id, {headers})).json();
  assert.equal(product.fields.stockQty.integerValue, '2');
}
console.log('PASS: all six products and their audit entries commit atomically with the order and customer record.');