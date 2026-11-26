import {Firestore, Timestamp} from 'firebase-admin/firestore';
import {type Order, parseSettings, planReminders, previousWeekStart, type Reminder, weekStart} from './reminder_plan';

function millis(value: unknown): number | undefined {
  return value instanceof Timestamp ? value.toMillis() : undefined;
}

function asOrder(id: string, data: FirebaseFirestore.DocumentData): Order {
  const previous = Array.isArray(data.statusHistory)
    ? [...data.statusHistory].reverse().find((record) => record?.status === data.status)
    : undefined;
  return {
    id,
    orderNo: typeof data.orderNo === 'string' ? data.orderNo : id,
    status: data.status,
    createdAt: millis(data.createdAt),
    changedAt: millis(data.statusChangedAt) ?? millis(previous?.at),
    shippedAt: millis(data.shippedAt),
    deliveredAt: millis(data.deliveredAt),
    paymentMethod: data.paymentMethod,
    paymentStatus: data.paymentStatus,
    total: Number.isSafeInteger(data.total) ? data.total : 0,
  };
}

async function upsert(db: Firestore, reminder: Reminder, now: Timestamp) {
  const reference = db.collection('notifications').doc(reminder.id);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const current = snapshot.data();
    if (current && (millis(current.evaluatedAt) ?? 0) > now.toMillis()) return;

    const existingEvent = current?.conditionKey === reminder.conditionKey &&
      (!reminder.active || current.active === true);
    const wake = existingEvent && current.state === 'snoozed' &&
      (millis(current.snoozedUntil) ?? Infinity) <= now.toMillis();
    if (existingEvent && !wake) {
      if (reminder.active && (current.title !== reminder.title || current.body !== reminder.body)) {
        transaction.update(reference, {title: reminder.title, body: reminder.body, evaluatedAt: now});
      }
      return;
    }
    transaction.set(reference, {
      type: reminder.type,
      title: reminder.title,
      body: reminder.body,
      relatedOrderId: reminder.relatedOrderId ?? null,
      productId: reminder.productId ?? null,
      scheduledAt: Timestamp.fromMillis(reminder.scheduledAt),
      createdAt: now,
      evaluatedAt: now,
      conditionKey: reminder.conditionKey,
      active: reminder.active,
      state: 'open',
      isRead: false,
      snoozedUntil: null,
      pushPending: true,
    });
  });
}

export async function runReminders(db: Firestore, evaluatedAt = Date.now()) {
  const now = Timestamp.fromMillis(evaluatedAt);
  const settings = parseSettings((await db.doc('settings/reminders').get()).data());
  const orders = db.collection('orders');
  const unclosed = db.collection('notifications').where('active', '==', true);
  const [work, cod, stock, history, active, snoozedDigests] = await Promise.all([
    settings.enabled ? orders.where('status', 'in', ['pending', 'confirmed', 'packed', 'shipped']).get() : null,
    settings.enabled ? orders.where('status', '==', 'delivered').where('paymentMethod', '==', 'cod')
      .where('paymentStatus', 'in', ['unpaid', 'partial']).get() : null,
    settings.enabled && settings.lowStock ? db.collection('products').where('isActive', '==', true).get() : null,
    settings.enabled && settings.weeklyDigest ? orders
      .where('deliveredAt', '>=', Timestamp.fromMillis(previousWeekStart(evaluatedAt)))
      .where('deliveredAt', '<', Timestamp.fromMillis(weekStart(evaluatedAt))).get() : null,
    unclosed.get(),
    settings.enabled ? db.collection('notifications').where('state', '==', 'snoozed').get() : null,
  ]);
  const target = planReminders(
    evaluatedAt, settings,
    [...(work?.docs ?? []), ...(cod?.docs ?? [])].map((doc) => asOrder(doc.id, doc.data())),
    (stock?.docs ?? []).flatMap((doc) => {
      const data = doc.data();
      return Number.isSafeInteger(data.stockQty) && Number.isSafeInteger(data.lowStockThreshold)
        ? [{id: doc.id, name: String(data.name ?? doc.id), stock: data.stockQty, threshold: data.lowStockThreshold}]
        : [];
    }),
    (history?.docs ?? []).map((doc) => asOrder(doc.id, doc.data())),
  );
  const desired = new Set(target.map((reminder) => reminder.id));
  for (const reminder of target) {
    await upsert(db, reminder, now);
  }
  for (const doc of active.docs) {
    if (desired.has(doc.id)) continue;
    await db.runTransaction(async (transaction) => {
      const data = (await transaction.get(doc.ref)).data();
      if (!data?.active || (millis(data.evaluatedAt) ?? 0) > evaluatedAt) return;
      transaction.update(doc.ref, {
        active: false, state: 'resolved', isRead: true,
        snoozedUntil: null, pushPending: false, evaluatedAt: now,
      });
    });
  }
  // Old digests stay in the inbox and can be snoozed past the day they were created.
  for (const doc of snoozedDigests?.docs ?? []) {
    const data = doc.data();
    if (data.active || desired.has(doc.id) || (millis(data.snoozedUntil) ?? Infinity) > evaluatedAt) continue;
    if ((data.type === 'daily' && !settings.dailyDigest) || (data.type === 'weekly' && !settings.weeklyDigest)) continue;
    await upsert(db, {
      id: doc.id, type: data.type, title: data.title, body: data.body,
      scheduledAt: millis(data.scheduledAt) ?? evaluatedAt, conditionKey: data.conditionKey, active: false,
    }, now);
  }
  return settings.enabled;
}