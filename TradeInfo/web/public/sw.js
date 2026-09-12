// Web Push service worker (T39): receives push events, shows notification.
self.addEventListener("push", (event) => {
  const data = event.data ? event.data.json() : {};
  event.waitUntil(
    self.registration.showNotification(data.title || "SimpleMarket", {
      body: data.body || "",
      data: data.data || {},
      icon: "/icon.png",
    })
  );
});
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow("/watchlist"));
});
