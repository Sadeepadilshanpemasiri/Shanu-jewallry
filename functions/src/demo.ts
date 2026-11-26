import {Firestore, Timestamp} from 'firebase-admin/firestore';

export async function seedDemo(db: Firestore) {
  if (!/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST ?? '')) {
    throw new Error('Demo data requires the local Firestore emulator.');
  }
  const now = Date.now();
  const ago = (hours: number) => Timestamp.fromMillis(now - hours * 3_600_000);
  const marker = db.doc('settings/local_demo');
  const phone = '+94770000001';
  const customer = {name: 'Demo Customer', phone, address: 'Demo address', city: 'Colombo'};
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(marker);
    const counter = await tx.get(db.doc('settings/order_sequence'));
    if (existing.exists) return;
    const sequence = counter.get('last') ?? 0;
    const sku = 'JWL-DEMO-001';
    const productId = 'local-demo-ring';
    tx.set(db.doc('products/' + productId), {
      name: 'Champagne Ring', sku, category: 'Rings', metalType: 'Gold plated',
      description: 'Local demo stock', images: [], variants: ['Size 7'], costPrice: 85000,
      sellingPrice: 195000, stockQty: 2, lowStockThreshold: 2, isActive: true,
      createdAt: ago(120), updatedAt: ago(44), lastMovementId: 'local-demo-sale',
    });
    tx.set(db.doc('inventory_skus/' + sku), {productId});
    tx.set(db.doc('stock_movements/local-demo-opening'), {productId, type: 'stockIn', qty: 3, balance: 3,
      reason: 'Demo opening stock', actorUid: 'local-demo', createdAt: ago(120)});
    tx.set(db.doc('stock_movements/local-demo-sale'), {productId, type: 'stockOut', qty: -1, balance: 2,
      orderId: 'local-demo-delivered', reason: 'Demo delivered order', actorUid: 'local-demo', createdAt: ago(44)});
    tx.set(db.doc('customers/' + phone), {
      ...customer, notes: '', watchlist: false, blacklist: false, restrictionReason: '',
      totalOrders: 3, deliveredCount: 1, cancelledCount: 1, cancelledAfterShipping: 0,
      returnedCount: 0, failedCount: 0, riskLevel: 'medium', createdAt: ago(120), updatedAt: ago(36),
    });
    const event = (status: string, hours: number, note = '') =>
      ({status, note, actorUid: 'local-demo', at: ago(hours)});
    const common = {
      customerId: phone, customer,
      items: [{productId, name: 'Champagne Ring', sku, qty: 1, price: 195000, cost: 85000, category: 'Rings'}],
      subtotal: 195000, deliveryCharge: 35000, discount: 0, total: 230000,
      paymentMethod: 'cod', advance: 0, stockTiming: 'confirmed', stockRestored: false,
      requiresAdvance: false, customerReview: 'none', blacklistOverride: false, source: 'WhatsApp',
      notes: 'Local demo order', paymentStatus: 'unpaid', stockDeducted: false,
    };
    const orders = [
      {status: 'delivered', paymentStatus: 'paid', stockDeducted: true,
        courier: 'Demo Courier', trackingId: 'DEMO-001', waybillKey: 'demo%20courier%2FDEMO-001',
        createdAt: ago(48), shippedAt: ago(36), deliveredAt: ago(12), statusChangedAt: ago(12),
        statusHistory: [event('pending', 48), event('confirmed', 44), event('packed', 42),
          event('shipped', 36), event('delivered', 12)]},
      {status: 'cancelled', createdAt: ago(96), cancelledAt: ago(80), statusChangedAt: ago(80),
        cancelReason: 'Demo cancellation before packing',
        statusHistory: [event('pending', 96), event('cancelled', 80, 'Demo cancellation before packing')]},
      {status: 'pending', createdAt: ago(36), statusChangedAt: ago(36), statusHistory: [event('pending', 36)]},
    ];
    orders.forEach((order, index) => tx.set(db.doc('orders/local-demo-' + order.status), {
      ...common, ...order, orderNo: 'JB-' + String(sequence + index + 1).padStart(6, '0'), updatedAt: order.statusChangedAt,
    }));
    tx.set(db.doc('waybills/demo%20courier%2FDEMO-001'), {
      orderId: 'local-demo-delivered', courierKey: 'demo courier',
      trackingNormalized: 'DEMO-001', createdAt: ago(36),
    });
    tx.set(db.doc('couriers/demo%20courier'), {name: 'Demo Courier', isActive: true, trackingTemplate: ''});
    tx.set(counter.ref, {last: sequence + orders.length});
    tx.set(marker, {createdAt: ago(0)});
  });
}