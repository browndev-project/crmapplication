importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCEkVF6LEQG43n4jcLveonJ9Hcb2Fsgs8c',
  appId: '1:992421986323:web:d9fb53054f0e55a42effe6',
  messagingSenderId: '992421986323',
  projectId: 'browndevs',
});

const messaging = firebase.messaging();

function formatPayload(data) {
  let title = data.title || 'New Notification';
  let body = data.body || '';
  let imageUrl = data.imageUrl || data.mediaUrl || null;

  const type = (data.type || '').toLowerCase();

  if (type === 'whatsapp_message') {
    title = data.title || 'New WhatsApp Message';
    body = data.body || '';
    if (!body || body.includes('business.facebook.com')) {
      body = '📷 Photo';
    }
  }

  if (!body && data.alert) {
    body = data.alert;
  }

  return { title, body, imageUrl };
}

messaging.onBackgroundMessage(function(payload) {
  const data = payload.data || {};
  const { title, body, imageUrl } = formatPayload(data);

  const options = {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/favicon.png',
    data: { click_action: 'FLUTTER_NOTIFICATION_CLICK', ...data },
  };

  if (imageUrl) {
    options.image = imageUrl;
  }

  return self.registration.showNotification(title, options);
});

self.addEventListener('push', function(event) {
  let data = {};
  try {
    data = event.data.json();
  } catch (e) {
    console.error('Error parsing push data:', e);
  }

  const payload = data.data || data.notification || {};
  const { title, body, imageUrl } = formatPayload(payload);

  const options = {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/favicon.png',
    data: { click_action: 'FLUTTER_NOTIFICATION_CLICK', ...payload },
  };

  if (imageUrl) {
    options.image = imageUrl;
  }

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const urlToOpen = new URL('/', self.location.origin).href;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (const client of clientList) {
        if (client.url === urlToOpen && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});
