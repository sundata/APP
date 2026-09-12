// Web Push subscription (T39): register SW, subscribe, POST endpoint+keys.
export async function subscribePush(token: string): Promise<boolean> {
  if (!("serviceWorker" in navigator) || !("PushManager" in window)) return false;
  try {
    const reg = await navigator.serviceWorker.register("/sw.js");
    const sub = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: process.env.NEXT_PUBLIC_VAPID_KEY,
    });
    const json = sub.toJSON();
    const r = await fetch(
      (process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000") +
        "/api/v1/notifications/devices",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          platform: "webpush",
          token: json.endpoint,
          keys: json.keys,
        }),
      }
    );
    return r.ok;
  } catch {
    return false;
  }
}
