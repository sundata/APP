"""
みまもり Backend — Cloud Run (FastAPI)
========================================
Endpoints:
  POST /users/{device_id}/checkin          チェックイン
  PUT  /users/{device_id}/settings         設定更新（間隔、連絡先など）
  GET  /users/{device_id}/status           ステータス確認
  POST /internal/check-overdue             Cloud Scheduler 呼び出し、期限切れチェック
"""

import hmac
import os
import smtplib
import logging
from datetime import datetime, timezone, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.header import Header as EmailHeader
from email.utils import formataddr
from typing import Optional

from fastapi import FastAPI, HTTPException, Header, Request
from pydantic import BaseModel, EmailStr, field_validator
import google.cloud.firestore as firestore

# ──────────────────────────────────────────────
# 初期化
# ──────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="みまもり API", version="1.0.0")
db  = firestore.Client()

# Gmail SMTP 設定（環境変数から読み込む）
GMAIL_USER     = os.environ.get("GMAIL_USER", "")
GMAIL_PASSWORD = os.environ.get("GMAIL_APP_PASSWORD", "")   # アプリパスワード
SCHEDULER_SECRET = os.environ.get("SCHEDULER_SECRET", "")
if not SCHEDULER_SECRET:
    logger.warning("SCHEDULER_SECRET が未設定です。/internal/* は常に 403 を返します。")


# ──────────────────────────────────────────────
# リクエストモデル
# ──────────────────────────────────────────────
class ContactModel(BaseModel):
    name:         str
    relationship: str
    email:        EmailStr
    phone:        Optional[str] = ""
    is_priority:  bool = False

    @field_validator("name", "relationship", "phone")
    @classmethod
    def _no_control_chars(cls, value: Optional[str]) -> Optional[str]:
        if value and any(c in value for c in "\r\n"):
            raise ValueError("改行を含む値は指定できません")
        return value

class UserSettings(BaseModel):
    user_name:       str
    user_email:      EmailStr
    interval_hours:  int = 24          # 24 / 48 / 72
    contacts:        list[ContactModel]
    notify_email:    bool = True
    notify_sms:      bool = False

class CheckinRequest(BaseModel):
    device_id: str


# ──────────────────────────────────────────────
# ヘルスチェック
# ──────────────────────────────────────────────
@app.get("/")
def root():
    return {"status": "ok", "service": "みまもり API"}


# ──────────────────────────────────────────────
# 1. チェックイン（報告）
# ──────────────────────────────────────────────
@app.post("/users/{device_id}/checkin")
def checkin(device_id: str):
    """
    iOS App がタップするたびに呼び出す。
    lastCheckIn を更新し、次の期限を再計算してDBに保存。
    """
    now = datetime.now(timezone.utc)
    ref = db.collection("users").document(device_id)
    doc = ref.get()

    if doc.exists:
        data = doc.to_dict()
        interval_hours = data.get("interval_hours", 24)
    else:
        interval_hours = 24

    deadline = now + timedelta(hours=interval_hours)

    ref.set({
        "last_checkin":    now.isoformat(),
        "deadline":        deadline.isoformat(),
        "interval_hours":  interval_hours,
        "alert_sent":      False,   # 期限切れ通知済みフラグをリセット
        "updated_at":      now.isoformat(),
    }, merge=True)

    logger.info(f"[checkin] device={device_id} deadline={deadline.isoformat()}")
    return {
        "ok":           True,
        "last_checkin": now.isoformat(),
        "deadline":     deadline.isoformat(),
        "interval_hours": interval_hours,
    }


# ──────────────────────────────────────────────
# 2. 設定更新（連絡先・間隔など）
# ──────────────────────────────────────────────
@app.put("/users/{device_id}/settings")
def update_settings(device_id: str, settings: UserSettings):
    """
    ユーザー設定・緊急連絡先をサーバーに保存。
    チェックイン済みなら deadline を再計算して更新。
    """
    now = datetime.now(timezone.utc)
    ref = db.collection("users").document(device_id)
    doc = ref.get()

    update_data = {
        "user_name":      settings.user_name,
        "user_email":     settings.user_email,
        "interval_hours": settings.interval_hours,
        "notify_email":   settings.notify_email,
        "notify_sms":     settings.notify_sms,
        "contacts":       [c.model_dump() for c in settings.contacts],
        "updated_at":     now.isoformat(),
    }

    # 既存のチェックイン時刻があれば deadline を再計算
    if doc.exists:
        data = doc.to_dict()
        if data.get("last_checkin"):
            last_dt = datetime.fromisoformat(data["last_checkin"])
            new_deadline = last_dt + timedelta(hours=settings.interval_hours)
            update_data["deadline"] = new_deadline.isoformat()

    ref.set(update_data, merge=True)
    logger.info(f"[settings] device={device_id} interval={settings.interval_hours}h contacts={len(settings.contacts)}")
    return {"ok": True}


# ──────────────────────────────────────────────
# 3. ステータス確認
# ──────────────────────────────────────────────
@app.get("/users/{device_id}/status")
def get_status(device_id: str):
    ref = db.collection("users").document(device_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="ユーザーが見つかりません")

    data = doc.to_dict()
    now  = datetime.now(timezone.utc)

    deadline_str = data.get("deadline")
    if deadline_str:
        deadline = datetime.fromisoformat(deadline_str)
        remaining_sec = max(0, int((deadline - now).total_seconds()))
        is_overdue    = deadline < now
    else:
        remaining_sec = 0
        is_overdue    = True

    return {
        "device_id":      device_id,
        "user_name":      data.get("user_name", ""),
        "last_checkin":   data.get("last_checkin"),
        "deadline":       deadline_str,
        "remaining_sec":  remaining_sec,
        "is_overdue":     is_overdue,
        "interval_hours": data.get("interval_hours", 24),
        "alert_sent":     data.get("alert_sent", False),
    }


# ──────────────────────────────────────────────
# 4. テストアラートメール送信
# ──────────────────────────────────────────────
@app.post("/users/{device_id}/test-alert")
def send_test_alert(device_id: str):
    """
    iOS App の「テストメールを送る」ボタンから呼び出される。
    デバイスが未登録の場合は自動でチェックインしてからテストメールを送信する。
    """
    ref = db.collection("users").document(device_id)
    doc = ref.get()

    # 未登録デバイスは自動でチェックイン（upsert）
    if not doc.exists:
        now = datetime.now(timezone.utc)
        ref.set({
            "last_checkin":   now.isoformat(),
            "deadline":       (now + timedelta(hours=24)).isoformat(),
            "interval_hours": 24,
            "alert_sent":     False,
            "updated_at":     now.isoformat(),
        }, merge=True)
        doc = ref.get()

    if not doc.exists:
        raise HTTPException(status_code=500, detail="デバイス登録に失敗しました")

    data      = doc.to_dict()
    contacts  = data.get("contacts", [])
    user_name = data.get("user_name", "ユーザー")

    if not contacts:
        raise HTTPException(status_code=400, detail="緊急連絡先が登録されていません")

    if not GMAIL_USER or not GMAIL_PASSWORD:
        raise HTTPException(status_code=500, detail="メール設定が未完了です")

    subject = f"【テスト】{user_name}さんの安否通知テスト — みまもり"
    body_template = """\
{name} 様

「みまもり」アプリより、通知テストのご連絡です。

{user_name} さんがテストメールの送信を行いました。
実際に緊急が発生した際は、{user_name} さんが一定期間チェックインを行わなかった場合に
自動でこのようなメールが届きます。

このメールが届いていれば、安否通知機能は正常に動作しています。

─────────────────────────
みまもり — 毎日のチェックインで安否をお届けするアプリ
このメールはテスト送信です。返信は不要です。
─────────────────────────
"""

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(GMAIL_USER, GMAIL_PASSWORD)
            sorted_contacts = sorted(contacts, key=lambda c: not c.get("is_priority", False))
            for contact in sorted_contacts:
                to_email = _safe_email(contact.get("email", ""))
                if not to_email:
                    continue
                body = body_template.format(
                    name      = contact.get("name", "緊急連絡先"),
                    user_name = user_name,
                )
                msg = MIMEMultipart("alternative")
                msg["Subject"] = EmailHeader(subject, "utf-8").encode()
                msg["From"]    = make_from_header("みまもりApp", GMAIL_USER)
                msg["To"]      = to_email
                msg.attach(MIMEText(body, "plain", "utf-8"))
                server.sendmail(GMAIL_USER, to_email, msg.as_string())
                logger.info(f"[test-alert] Sent to {to_email}")
        return {"ok": True, "sent_to": len(contacts)}
    except Exception as e:
        logger.error(f"[test-alert] SMTP error: {e}")
        raise HTTPException(status_code=500, detail="メール送信に失敗しました")


# ──────────────────────────────────────────────
# 4. 期限切れチェック（Cloud Scheduler から呼び出し）
# ──────────────────────────────────────────────
@app.post("/internal/check-overdue")
def check_overdue(x_scheduler_secret: Optional[str] = Header(None)):
    """
    Cloud Scheduler が5分ごとに呼び出す。
    期限切れかつ未通知のユーザーを全員チェックし、
    緊急連絡先にメールを送る。
    """
    # 簡易認証
    if not SCHEDULER_SECRET or not x_scheduler_secret or \
            not hmac.compare_digest(x_scheduler_secret, SCHEDULER_SECRET):
        raise HTTPException(status_code=403, detail="Forbidden")

    now      = datetime.now(timezone.utc)
    alerted  = []
    errors   = []

    users_ref = db.collection("users").stream()

    for doc in users_ref:
        data      = doc.to_dict()
        device_id = doc.id

        deadline_str = data.get("deadline")
        if not deadline_str:
            continue

        deadline   = datetime.fromisoformat(deadline_str)
        alert_sent = data.get("alert_sent", False)

        # 期限切れ かつ まだ通知していない
        if deadline < now and not alert_sent:
            contacts      = data.get("contacts", [])
            user_name     = data.get("user_name", "ユーザー")
            notify_email  = data.get("notify_email", True)
            last_checkin  = data.get("last_checkin", "不明")

            if notify_email and contacts:
                sent = send_alert_emails(
                    user_name    = user_name,
                    last_checkin = last_checkin,
                    interval_h   = data.get("interval_hours", 24),
                    contacts     = contacts,
                )
                if sent:
                    # 通知済みフラグを立てる
                    db.collection("users").document(device_id).update({
                        "alert_sent":  True,
                        "alerted_at":  now.isoformat(),
                    })
                    alerted.append(device_id)
                    logger.info(f"[alert] Sent for device={device_id}")
                else:
                    errors.append(device_id)
                    logger.error(f"[alert] Failed for device={device_id}")

    return {
        "checked_at": now.isoformat(),
        "alerted":    alerted,
        "errors":     errors,
    }


# ──────────────────────────────────────────────
# メール送信ユーティリティ
# ──────────────────────────────────────────────
def _safe_email(value: str) -> str:
    """ヘッダーインジェクションを防ぐため、制御文字を含む宛先は破棄する"""
    email_addr = (value or "").strip()
    if not email_addr or any(c in email_addr for c in "\r\n") or "@" not in email_addr:
        return ""
    return email_addr


def make_from_header(display_name: str, email_addr: str) -> str:
    """日本語表示名を RFC2047 エンコードして From ヘッダーを生成する"""
    h = EmailHeader()
    h.append(display_name, "utf-8")
    return f"{h.encode()} <{email_addr}>"


def send_alert_emails(user_name: str, last_checkin: str,
                      interval_h: int, contacts: list[dict]) -> bool:
    """Gmail SMTP で全緊急連絡先にメールを送る"""
    if not GMAIL_USER or not GMAIL_PASSWORD:
        logger.error("Gmail credentials not set")
        return False

    # 日時フォーマット
    try:
        dt  = datetime.fromisoformat(last_checkin)
        dt  = dt.astimezone(timezone(timedelta(hours=9)))  # JST
        last_str = dt.strftime("%Y年%m月%d日 %H:%M (JST)")
    except Exception:
        last_str = last_checkin

    subject = f"【安否確認】{user_name}さんの連絡が途絶えています — みまもり"
    body_template = """\
{name} 様

「みまもり」アプリより、大切なご連絡です。

{user_name} さんが {interval_h}時間以上チェックインを行っていません。

　最後のチェックイン：{last_str}

お手数ですが、{user_name} さんの安否をご確認いただけますでしょうか。

─────────────────────────
みまもり — 毎日のチェックインで安否をお届けするアプリ
このメールは自動送信です。返信は不要です。
─────────────────────────
"""

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(GMAIL_USER, GMAIL_PASSWORD)

            # 優先連絡先を先に、その後残りを送信
            sorted_contacts = sorted(contacts,
                                     key=lambda c: not c.get("is_priority", False))

            for contact in sorted_contacts:
                to_email = _safe_email(contact.get("email", ""))
                if not to_email:
                    continue

                body = body_template.format(
                    name       = contact.get("name", "緊急連絡先"),
                    user_name  = user_name,
                    interval_h = interval_h,
                    last_str   = last_str,
                )

                msg = MIMEMultipart("alternative")
                msg["Subject"] = EmailHeader(subject, "utf-8").encode()
                msg["From"]    = make_from_header("みまもりApp", GMAIL_USER)
                msg["To"]      = to_email
                msg.attach(MIMEText(body, "plain", "utf-8"))

                server.sendmail(GMAIL_USER, to_email, msg.as_string())
                logger.info(f"[mail] Sent to {to_email}")

        return True

    except Exception as e:
        logger.error(f"[mail] SMTP error: {e}")
        return False
