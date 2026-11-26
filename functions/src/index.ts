import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {logger} from 'firebase-functions';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {runReminders} from './reminders';

initializeApp();

export const shopReminders = onSchedule({
  schedule: 'every 15 minutes',
  timeZone: 'Asia/Colombo',
  maxInstances: 1,
  concurrency: 1,
  timeoutSeconds: 480,
}, async () => {
  const db = getFirestore();
  if (!await runReminders(db)) return;
  const owner = (await db.doc('access/owner').get()).get('uid');
  if (typeof owner !== 'string' || !owner) return;
  const pending = await db.collection('notifications').where('pushPending', '==', true).limit(200).get();
  if (pending.empty) return;
  const open = pending.docs.filter((doc) => doc.get('state') === 'open' && doc.get('isRead') !== true);
  const devices = await db.collection('push_devices').where('uid', '==', owner).get();
  const tokens = [...new Set(devices.docs.map((doc) => doc.get('token'))
    .filter((token): token is string => typeof token === 'string' && token.length > 0))];
  if (open.length && tokens.length === 0) return;

  let retry = false;
  const invalid = new Set<string>();
  if (open.length) {
    for (let offset = 0; offset < tokens.length; offset += 500) {
      const chunk = tokens.slice(offset, offset + 500);
      const result = await getMessaging().sendEachForMulticast({
        tokens: chunk,
        notification: {
          title: 'Jewellery Business Manager',
          body: open.length === 1 ? 'A shop reminder is ready.' : open.length + ' shop reminders are ready.',
        },
        data: {kind: 'shop-reminders'},
        webpush: {notification: {tag: 'shop-reminders', icon: '/icons/icon-192.png'}},
      });
      result.responses.forEach((response, index) => {
        if (response.success) return;
        const code = response.error?.code;
        if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
          invalid.add(chunk[index]);
        } else {
          retry = true;
          logger.warn('Browser notification was deferred', {code});
        }
      });
    }
  }
  for (const device of devices.docs.filter((doc) => invalid.has(doc.get('token')))) {
    await db.runTransaction(async (transaction) => {
      const fresh = await transaction.get(device.ref);
      if (fresh.exists && fresh.get('token') === device.get('token')) transaction.delete(device.ref);
    });
  }
  if (!retry) {
    const batch = db.batch();
    for (const doc of pending.docs) batch.update(doc.ref, {pushPending: false});
    await batch.commit();
  }
});