const hour = 3_600_000;
const day = 24 * hour;
const offset = 5.5 * hour;

export type Order = {
  id: string;
  orderNo: string;
  status: string;
  createdAt?: number;
  changedAt?: number;
  shippedAt?: number;
  deliveredAt?: number;
  paymentMethod?: string;
  paymentStatus?: string;
  total: number;
};

export type Product = {id: string; name: string; stock: number; threshold: number};

export type Reminder = {
  id: string;
  type: string;
  title: string;
  body: string;
  scheduledAt: number;
  conditionKey: string;
  active: boolean;
  relatedOrderId?: string;
  productId?: string;
};

export type Settings = ReturnType<typeof parseSettings>;

export function parseSettings(data: Record<string, unknown> = {}) {
  function integer(key: string, fallback: number, min: number, max: number) {
    const value = data[key];
    return typeof value === 'number' && Number.isInteger(value) && value >= min && value <= max
      ? value : fallback;
  }
  return {
    enabled: data.enabled !== false,
    pendingHours: integer('pendingHours', 24, 1, 720),
    confirmedHours: integer('confirmedHours', 24, 1, 720),
    packedHours: integer('packedHours', 24, 1, 720),
    transitDays: integer('transitDays', 5, 1, 90),
    codDays: integer('codDays', 3, 1, 90),
    lowStock: data.lowStock !== false,
    dailyDigest: data.dailyDigest !== false,
    weeklyDigest: data.weeklyDigest !== false,
    digestHour: integer('digestHour', 8, 0, 23),
  };
}

function localMidnight(now: number) {
  const date = new Date(now + offset);
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()) - offset;
}

export function weekStart(now: number) {
  const midnight = localMidnight(now);
  return midnight - ((new Date(midnight + offset).getUTCDay() + 6) % 7) * day;
}

export function previousWeekStart(now: number) {
  return weekStart(now) - 7 * day;
}

function dateKey(midnight: number) {
  return new Date(midnight + offset).toISOString().slice(0, 10);
}

export function planReminders(
  now: number, settings: Settings, orders: Order[], products: Product[], weeklyOrders: Order[],
): Reminder[] {
  if (!settings.enabled) return [];
  const reminders: Reminder[] = [];
  const limits: Record<string, {hours: number; title: string}> = {
    pending: {hours: settings.pendingHours, title: 'Pending order needs review'},
    confirmed: {hours: settings.confirmedHours, title: 'Order waiting to be packed'},
    packed: {hours: settings.packedHours, title: 'Packed order waiting to ship'},
  };
  for (const order of orders) {
    const stage = limits[order.status];
    const entered = order.changedAt ?? order.createdAt;
    const since = stage ? entered
      : order.status === 'shipped' ? order.shippedAt ?? entered
      : order.status === 'delivered' && order.paymentMethod === 'cod' &&
        ['unpaid', 'partial'].includes(order.paymentStatus ?? '') ? order.deliveredAt : undefined;
    const type = stage ? 'stale-order' : order.status === 'shipped' ? 'transit' : 'cod';
    const due = since == null ? undefined : since +
      (stage ? stage.hours * hour : (type === 'transit' ? settings.transitDays : settings.codDays) * day);
    if (due == null || due > now) continue;
    const title = stage?.title ?? (type === 'transit' ? 'Parcel delivery follow-up' : 'COD settlement pending');
    reminders.push({
      id: type + '--' + order.id, type, title, body: order.orderNo + ' needs attention.',
      scheduledAt: due, conditionKey: order.status + ':' + since, active: true,
      relatedOrderId: order.id,
    });
  }
  if (settings.lowStock) {
    for (const product of products) {
      if (product.stock > product.threshold) continue;
      reminders.push({
        id: 'stock--' + product.id, type: 'low-stock', title: product.stock === 0 ? 'Out of stock' : 'Low stock',
        body: product.name + ' · ' + product.stock + ' remaining.',
        scheduledAt: now, conditionKey: product.stock === 0 ? 'out-of-stock' : 'low-stock', active: true, productId: product.id,
      });
    }
  }
  const midnight = localMidnight(now);
  const digestAt = midnight + settings.digestHour * hour;
  if (now >= digestAt && settings.dailyDigest) {
    const waiting = orders.filter((order) => ['confirmed', 'packed'].includes(order.status)).length;
    const pending = orders.filter((order) => order.status === 'pending').length;
    reminders.push({
      id: 'daily--' + dateKey(midnight), type: 'daily', title: 'Morning dispatch digest',
      body: waiting + ' orders to pack or ship. ' + pending + ' pending review.',
      scheduledAt: digestAt, conditionKey: dateKey(midnight), active: false,
    });
  }
  const monday = weekStart(now);
  const weeklyAt = monday + settings.digestHour * hour;
  if (now >= weeklyAt && settings.weeklyDigest) {
    const week = dateKey(monday);
    const delivered = weeklyOrders.filter((order) => order.status === 'delivered' &&
      order.deliveredAt != null && order.deliveredAt >= monday - 7 * day && order.deliveredAt < monday);
    const billed = delivered.reduce((sum, order) => sum + order.total, 0);
    reminders.push({
      id: 'weekly--' + week, type: 'weekly', title: 'Last week’s delivered orders',
      body: delivered.length + ' delivered · LKR ' + (billed / 100).toLocaleString('en-LK', {
        minimumFractionDigits: 2, maximumFractionDigits: 2,
      }) + ' billed.',
      scheduledAt: weeklyAt, conditionKey: week, active: false,
    });
  }
  return reminders;
}