const assert = require('node:assert/strict');
const {test} = require('node:test');
const {parseSettings, planReminders, previousWeekStart, weekStart} = require('../lib/reminder_plan');

const hour = 3600000;
const day = 24 * hour;
const now = Date.parse('2026-11-23T02:30:00Z');

test('daily and weekly summaries follow the Sri Lanka calendar', () => {
  const rules = parseSettings();
  assert.equal(planReminders(now - 1, rules, [], [], []).length, 0);
  assert.equal(new Date(weekStart(now)).toISOString(), '2026-11-22T18:30:00.000Z');
  const delivered = {id: 'last-week', orderNo: 'JB-1', status: 'delivered',
    total: 125000, deliveredAt: previousWeekStart(now) + day};
  const candidates = planReminders(now, rules,
    [{id: 'packed', orderNo: 'JB-2', status: 'packed', total: 0}], [], [delivered]);
  assert.deepEqual(candidates.map((item) => item.id), ['daily--2026-11-23', 'weekly--2026-11-23']);
  assert.match(candidates[0].body, /^1 orders to pack or ship/);
  assert.match(candidates[1].body, /1 delivered.*1,250\.00/);
});

test('thresholds use the latest status entry, shipment, or COD delivery', () => {
  const rules = parseSettings({dailyDigest: false, weeklyDigest: false});
  const base = {orderNo: 'JB-1', total: 0, createdAt: now - 20 * day};
  const orders = [
    {...base, id: 'freshly-packed', status: 'packed', changedAt: now - hour},
    {...base, id: 'old-pending', status: 'pending', changedAt: now - 24 * hour},
    {...base, id: 'parcel', status: 'shipped', shippedAt: now - 5 * day},
    {...base, id: 'cod', status: 'delivered', deliveredAt: now - 4 * day, paymentMethod: 'cod', paymentStatus: 'partial'},
    {...base, id: 'paid', status: 'delivered', deliveredAt: now - 4 * day, paymentMethod: 'cod', paymentStatus: 'paid'},
  ];
  assert.deepEqual(planReminders(now, rules, orders, [], []).map((item) => item.id),
    ['stale-order--old-pending', 'transit--parcel', 'cod--cod']);
});

test('stock reminders follow product thresholds and their severity changes at zero', () => {
  const rules = parseSettings({dailyDigest: false, weeklyDigest: false});
  const products = [{id: 'one', name: 'Ring', stock: 0, threshold: 2},
    {id: 'two', name: 'Chain', stock: 2, threshold: 2}, {id: 'three', name: 'Bracelet', stock: 3, threshold: 2}];
  const planned = planReminders(now, rules, [], products, []);
  assert.deepEqual(planned.map((item) => item.conditionKey), ['out-of-stock', 'low-stock']);
  assert.equal(planReminders(now, {...rules, lowStock: false}, [], products, []).length, 0);
  assert.equal(parseSettings({pendingHours: -1, digestHour: 50}).pendingHours, 24);
  assert.deepEqual(planReminders(now, parseSettings({enabled: false}), [], products, []), []);
});