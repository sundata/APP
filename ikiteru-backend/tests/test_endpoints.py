from datetime import datetime, timedelta, timezone
from email import message_from_string


def iso_now():
    return datetime.now(timezone.utc).isoformat()


def iso_from_now(hours):
    return (datetime.now(timezone.utc) + timedelta(hours=hours)).isoformat()


def contact(name, email, *, priority=False, relationship="友人"):
    return {
        "name": name,
        "relationship": relationship,
        "email": email,
        "phone": "",
        "is_priority": priority,
    }


def settings_payload(**overrides):
    payload = {
        "user_name": "太郎",
        "user_email": "taro@example.com",
        "interval_hours": 48,
        "contacts": [contact("花子", "hanako@example.com", priority=True)],
        "notify_email": True,
        "notify_sms": False,
    }
    payload.update(overrides)
    return payload


def test_root_health(client):
    response = client.get("/")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "みまもり API"}


def test_checkin_new_device_uses_defaults_and_persists_state(client, db):
    response = client.post("/users/new-device/checkin")

    assert response.status_code == 200
    body = response.json()
    stored = db.collection("users").document("new-device").get().to_dict()
    assert body["ok"] is True
    assert body["interval_hours"] == 24
    assert stored["interval_hours"] == 24
    assert stored["last_checkin"] == body["last_checkin"]
    assert stored["deadline"] == body["deadline"]
    assert stored["alert_sent"] is False
    assert datetime.fromisoformat(stored["deadline"]) - datetime.fromisoformat(
        stored["last_checkin"]
    ) == timedelta(hours=24)


def test_checkin_existing_device_reuses_interval_and_resets_alert(user_factory, client, db):
    user_factory(
        "existing",
        interval_hours=72,
        alert_sent=True,
        user_name="太郎",
    )

    response = client.post("/users/existing/checkin")

    assert response.status_code == 200
    body = response.json()
    stored = db.collection("users").document("existing").get().to_dict()
    assert body["interval_hours"] == 72
    assert stored["alert_sent"] is False
    assert datetime.fromisoformat(body["deadline"]) - datetime.fromisoformat(
        body["last_checkin"]
    ) == timedelta(hours=72)


def test_settings_persists_models_and_recomputes_existing_deadline(user_factory, client, db):
    last_checkin = (datetime.now(timezone.utc) - timedelta(hours=5)).isoformat()
    user_factory("configured", last_checkin=last_checkin, deadline=iso_from_now(3))

    response = client.put(
        "/users/configured/settings",
        json=settings_payload(interval_hours=72),
    )

    assert response.status_code == 200
    stored = db.collection("users").document("configured").get().to_dict()
    assert stored["user_name"] == "太郎"
    assert stored["user_email"] == "taro@example.com"
    assert stored["interval_hours"] == 72
    assert stored["notify_email"] is True
    assert stored["notify_sms"] is False
    assert stored["contacts"] == [contact("花子", "hanako@example.com", priority=True)]
    assert isinstance(stored["contacts"][0], dict)
    assert datetime.fromisoformat(stored["deadline"]) == datetime.fromisoformat(
        last_checkin
    ) + timedelta(hours=72)


def test_settings_without_checkin_does_not_add_deadline(client, db):
    response = client.put("/users/unstarted/settings", json=settings_payload())

    assert response.status_code == 200
    stored = db.collection("users").document("unstarted").get().to_dict()
    assert "deadline" not in stored


def test_settings_validation_errors_return_422(client):
    missing_required = {
        "user_email": "taro@example.com",
        "contacts": [],
    }
    bad_type = settings_payload(interval_hours="not-an-integer")

    assert client.put("/users/invalid/settings", json=missing_required).status_code == 422
    assert client.put("/users/invalid/settings", json=bad_type).status_code == 422


def test_status_unknown_device_returns_404(client):
    response = client.get("/users/missing/status")

    assert response.status_code == 404


def test_status_future_deadline_reports_remaining_time_and_defaults(user_factory, client):
    user_factory("future", deadline=iso_from_now(2))

    response = client.get("/users/future/status")

    assert response.status_code == 200
    body = response.json()
    assert body["device_id"] == "future"
    assert body["remaining_sec"] > 0
    assert body["is_overdue"] is False
    assert body["user_name"] == ""
    assert body["interval_hours"] == 24
    assert body["alert_sent"] is False


def test_status_past_deadline_is_overdue_and_clamps_remaining(user_factory, client):
    user_factory("past", deadline=iso_from_now(-1), user_name="次郎", interval_hours=72)

    body = client.get("/users/past/status").json()

    assert body["remaining_sec"] == 0
    assert body["is_overdue"] is True
    assert body["user_name"] == "次郎"
    assert body["interval_hours"] == 72


def test_status_without_deadline_is_overdue(user_factory, client):
    user_factory("no-deadline", user_name="三郎", alert_sent=True)

    body = client.get("/users/no-deadline/status").json()

    assert body["deadline"] is None
    assert body["remaining_sec"] == 0
    assert body["is_overdue"] is True
    assert body["alert_sent"] is True


def test_test_alert_auto_upserts_then_rejects_empty_contacts(client, db):
    response = client.post("/users/unregistered/test-alert")

    assert response.status_code == 400
    stored = db.collection("users").document("unregistered").get().to_dict()
    assert stored["interval_hours"] == 24
    assert stored["alert_sent"] is False
    assert "last_checkin" in stored
    assert "deadline" in stored


def test_test_alert_rejects_empty_contacts(user_factory, client):
    user_factory("empty", contacts=[], user_name="太郎")

    response = client.post("/users/empty/test-alert")

    assert response.status_code == 400


def test_test_alert_requires_gmail_credentials(
    user_factory, client, main_module, monkeypatch
):
    user_factory("no-creds", contacts=[contact("花子", "hanako@example.com")])
    monkeypatch.setattr(main_module, "GMAIL_USER", "")
    monkeypatch.setattr(main_module, "GMAIL_PASSWORD", "")

    response = client.post("/users/no-creds/test-alert")

    assert response.status_code == 500
    assert response.json()["detail"] == "メール設定が未完了です"


def test_test_alert_sends_one_message_per_contact(user_factory, client, smtp, main_module, monkeypatch):
    monkeypatch.setattr(main_module, "GMAIL_USER", "sender@example.com")
    monkeypatch.setattr(main_module, "GMAIL_PASSWORD", "app-password")
    contacts = [
        contact("優先", "priority@example.com", priority=True),
        contact("通常", "regular@example.com"),
    ]
    user_factory("mail-test", contacts=contacts, user_name="太郎")

    response = client.post("/users/mail-test/test-alert")

    assert response.status_code == 200
    assert response.json() == {"ok": True, "sent_to": 2}
    assert len(smtp.connections) == 1
    server = smtp.connections[0]
    assert server.host == "smtp.gmail.com"
    assert server.port == 465
    assert server.logins == [("sender@example.com", "app-password")]
    assert [recipient for _, recipient, _ in server.sent_messages] == [
        "priority@example.com",
        "regular@example.com",
    ]
    for _, recipient, raw_message in server.sent_messages:
        message = message_from_string(raw_message)
        assert message["Subject"].startswith("=?utf-8?")
        assert message["From"].startswith("=?utf-8?")
        assert "太郎" in message.get_payload(0).get_payload(decode=True).decode("utf-8")
        assert recipient in message["To"]


def test_test_alert_skips_contacts_without_email(
    user_factory, client, smtp, main_module, monkeypatch
):
    monkeypatch.setattr(main_module, "GMAIL_USER", "sender@example.com")
    monkeypatch.setattr(main_module, "GMAIL_PASSWORD", "app-password")
    user_factory(
        "mail-skips-empty",
        contacts=[
            contact("優先", "priority@example.com", priority=True),
            contact("空欄", ""),
            {"name": "欠落", "relationship": "友人"},
            contact("通常", "regular@example.com"),
        ],
        user_name="太郎",
    )

    response = client.post("/users/mail-skips-empty/test-alert")

    assert response.status_code == 200
    assert response.json()["sent_to"] == 4
    assert [recipient for _, recipient, _ in smtp.sent_messages] == [
        "priority@example.com",
        "regular@example.com",
    ]


def test_test_alert_smtp_failure_returns_500(user_factory, client, smtp, main_module, monkeypatch):
    monkeypatch.setattr(main_module, "GMAIL_USER", "sender@example.com")
    monkeypatch.setattr(main_module, "GMAIL_PASSWORD", "app-password")
    smtp.raise_on_send = RuntimeError("connection broke")
    user_factory("mail-failure", contacts=[contact("花子", "hanako@example.com")])

    response = client.post("/users/mail-failure/test-alert")

    assert response.status_code == 500
    assert "connection broke" in response.json()["detail"]


def test_check_overdue_requires_scheduler_secret(client, main_module, monkeypatch):
    monkeypatch.setattr(main_module, "SCHEDULER_SECRET", "expected")

    assert client.post("/internal/check-overdue").status_code == 403
    assert client.post(
        "/internal/check-overdue",
        headers={"X-Scheduler-Secret": "wrong"},
    ).status_code == 403


def test_check_overdue_alerts_only_eligible_users(
    user_factory, client, db, smtp, main_module, monkeypatch
):
    monkeypatch.setattr(main_module, "SCHEDULER_SECRET", "expected")
    monkeypatch.setattr(main_module, "GMAIL_USER", "sender@example.com")
    monkeypatch.setattr(main_module, "GMAIL_PASSWORD", "app-password")
    overdue = iso_from_now(-2)
    user_factory(
        "eligible",
        deadline=overdue,
        last_checkin=iso_now(),
        interval_hours=24,
        user_name="太郎",
        contacts=[contact("花子", "hanako@example.com")],
        notify_email=True,
        alert_sent=False,
    )
    user_factory(
        "already-alerted",
        deadline=overdue,
        contacts=[contact("花子", "already@example.com")],
        alert_sent=True,
    )
    user_factory(
        "future",
        deadline=iso_from_now(2),
        contacts=[contact("花子", "future@example.com")],
        alert_sent=False,
    )
    user_factory("no-deadline", contacts=[contact("花子", "none@example.com")])
    user_factory(
        "email-disabled",
        deadline=overdue,
        contacts=[contact("花子", "disabled@example.com")],
        notify_email=False,
        alert_sent=False,
    )
    user_factory("no-contacts", deadline=overdue, contacts=[], alert_sent=False)

    response = client.post(
        "/internal/check-overdue",
        headers={"X-Scheduler-Secret": "expected"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["alerted"] == ["eligible"]
    assert body["errors"] == []
    stored = db.collection("users").document("eligible").get().to_dict()
    assert stored["alert_sent"] is True
    assert "alerted_at" in stored
    assert len(smtp.sent_messages) == 1


def test_check_overdue_records_failure_without_setting_alert_flag(
    user_factory, client, db, main_module, monkeypatch
):
    monkeypatch.setattr(main_module, "SCHEDULER_SECRET", "expected")
    monkeypatch.setattr(main_module, "GMAIL_USER", "")
    monkeypatch.setattr(main_module, "GMAIL_PASSWORD", "")
    user_factory(
        "failed",
        deadline=iso_from_now(-1),
        contacts=[contact("花子", "hanako@example.com")],
        alert_sent=False,
    )

    response = client.post(
        "/internal/check-overdue",
        headers={"X-Scheduler-Secret": "expected"},
    )

    assert response.status_code == 200
    assert response.json()["alerted"] == []
    assert response.json()["errors"] == ["failed"]
    assert db.collection("users").document("failed").get().to_dict()["alert_sent"] is False


def test_check_overdue_records_smtp_failure_without_setting_alert_flag(
    user_factory, client, db, smtp, main_module, monkeypatch
):
    monkeypatch.setattr(main_module, "SCHEDULER_SECRET", "expected")
    monkeypatch.setattr(main_module, "GMAIL_USER", "sender@example.com")
    monkeypatch.setattr(main_module, "GMAIL_PASSWORD", "app-password")
    smtp.raise_on_send = RuntimeError("smtp unavailable")
    user_factory(
        "smtp-failed",
        deadline=iso_from_now(-1),
        contacts=[contact("花子", "hanako@example.com")],
        alert_sent=False,
    )

    response = client.post(
        "/internal/check-overdue",
        headers={"X-Scheduler-Secret": "expected"},
    )

    assert response.status_code == 200
    assert response.json()["errors"] == ["smtp-failed"]
    assert db.collection("users").document("smtp-failed").get().to_dict()["alert_sent"] is False
