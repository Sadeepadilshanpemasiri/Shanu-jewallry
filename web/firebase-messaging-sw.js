/* Firebase Messaging registers this worker under its own push scope. */
self.addEventListener('notificationclick', (event) => {
  if (event.notification.tag !== 'shop-reminders') return;
  event.stopImmediatePropagation();
  event.notification.close();
  const destination = new URL('/notifications', self.location.origin).href;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    const existing = windows.find((window) => window.url === destination);
    if (existing) {
      await existing.focus();
      return;
    }
    await self.clients.openWindow(destination);
  })());
});

importScripts(
  'https://www.gstatic.com/firebasejs/13.1.0/firebase-app-compat.js',
  'https://www.gstatic.com/firebasejs/13.1.0/firebase-messaging-compat.js',
  '/firebase-messaging-config.js',
);
firebase.initializeApp(self.shopFirebaseWebConfig);
firebase.messaging();