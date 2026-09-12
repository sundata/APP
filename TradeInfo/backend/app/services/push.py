"""Push senders per platform (T37 FCM/APNs, T39 webpush).

- FcmSender: HTTP v1 API; caller injects get_access_token (prod: Cloud Run
  metadata server / service-account OAuth).
- ApnsSender: http/2 APNs endpoint; needs a JWT es256 provider — injectable.
- WebPushSender: VAPID-signed POST to the subscription endpoint. VAPID signing
  needs ES256 — injectable sign_jwt callable; pywebpush wires at deploy.

All raise PushError on transport failure so fanout can record it.
"""

from typing import Any, Callable, Optional

import httpx

FCM_SEND_URL = "https://fcm.googleapis.com/v1/projects/{project}/messages:send"
APNS_URL = "https://api.push.apple.com/3/device/{token}"


class PushError(Exception):
    pass


class FcmSender:
    def __init__(
        self,
        project_id: str,
        get_access_token: Callable[[], str],
        client: Optional[httpx.Client] = None,
    ) -> None:
        self.project_id = project_id
        self._token = get_access_token
        self._client = client or httpx.Client(timeout=10.0)

    def send(self, token: str, title: str, body: str, data: dict[str, Any]) -> None:
        payload = {
            "message": {
                "token": token,
                "notification": {"title": title, "body": body},
                "data": {k: str(v) for k, v in data.items()},
            }
        }
        r = self._client.post(
            FCM_SEND_URL.format(project=self.project_id),
            json=payload,
            headers={"authorization": f"Bearer {self._token()}"},
        )
        if r.status_code != 200:
            raise PushError(f"fcm {r.status_code}: {r.text[:200]}")


class ApnsSender:
    def __init__(
        self,
        get_jwt: Callable[[], str],
        bundle_id: str,
        sandbox: bool = True,
        client: Optional[httpx.Client] = None,
    ) -> None:
        self._jwt = get_jwt
        self.bundle_id = bundle_id
        self._client = client or httpx.Client(timeout=10.0, http2=True)
        self._host = (
            "https://api.sandbox.push.apple.com" if sandbox else "https://api.push.apple.com"
        )

    def send(self, token: str, title: str, body: str, data: dict[str, Any]) -> None:
        payload = {"aps": {"alert": {"title": title, "body": body}}, **data}
        r = self._client.post(
            f"{self._host}/3/device/{token}",
            json=payload,
            headers={
                "authorization": f"bearer {self._jwt()}",
                "apns-topic": self.bundle_id,
                "apns-push-type": "alert",
            },
        )
        if r.status_code != 200:
            raise PushError(f"apns {r.status_code}: {r.text[:200]}")


class WebPushSender:
    def __init__(
        self,
        sign_vapid_jwt: Callable[[str], str],  # (endpoint_origin) -> JWT
        vapid_subject: str,
        client: Optional[httpx.Client] = None,
    ) -> None:
        self._sign = sign_vapid_jwt
        self.subject = vapid_subject
        self._client = client or httpx.Client(timeout=10.0)

    def send(
        self, endpoint: str, title: str, body: str, data: dict[str, Any]
    ) -> None:
        # payload encryption (aes128gcm) is done by pywebpush at deploy; here
        # we send the request with the VAPID signature — deploy wiring wraps
        # this to attach the encrypted body.
        origin = endpoint.split("/2/")[0].split("/push")[0]
        r = self._client.post(
            endpoint,
            json={"title": title, "body": body, "data": data},
            headers={
                "authorization": f"vapid t={self._sign(origin)},k={self.subject}",
                "content-type": "application/json",
            },
        )
        if r.status_code not in (200, 201, 202):
            raise PushError(f"webpush {r.status_code}: {r.text[:200]}")
