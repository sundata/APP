from email.header import decode_header
from email import message_from_string


def contact(name, email, *, priority=False):
    return {
        "name": name,
        "relationship": "友人",
        "email": email,
        "is_priority": priority,
    }


def decoded_header(value):
    parts = []
    for part, charset in decode_header(value):
        if isinstance(part, bytes):
            parts.append(part.decode(charset or "ascii"))
        else:
            parts.append(part)
    return "".join(parts)


def test_make_from_header_round_trips_rfc2047(main_module):
    value = main_module.make_from_header("みまもりApp", "sender@example.com")

    assert value.startswith("=?utf-8?")
    assert value.endswith(" <sender@example.com>")
    assert decoded_header(value.rsplit(" <", 1)[0]) == "みまもりApp"


def test_send_alert_emails_returns_false_without_credentials(main_module, smtp, monkeypatch):
    monkeypatch.setattr(main_module, "GMAIL_USER", "")
    monkeypatch.setattr(main_module, "GMAIL_PASSWORD", "")

    assert main_module.send_alert_emails("太郎", "2026-01-01T00:00:00+00:00", 24, []) is False
    assert smtp.connections == []


def test_send_alert_emails_formats_jst_and_orders_contacts(
    main_module, smtp, monkeypatch
):
    monkeypatch.setattr(main_module, "GMAIL_USER", "sender@example.com")
    monkeypatch.setattr(main_module, "GMAIL_PASSWORD", "app-password")
    contacts = [
        contact("通常", "regular@example.com"),
        contact("空欄", "", priority=True),
        {"name": "欠落", "is_priority": True},
        contact("優先", "priority@example.com", priority=True),
    ]

    assert main_module.send_alert_emails(
        "太郎", "2026-01-01T00:00:00+00:00", 72, contacts
    ) is True

    assert [recipient for _, recipient, _ in smtp.sent_messages] == [
        "priority@example.com",
        "regular@example.com",
    ]
    for _, _, raw_message in smtp.sent_messages:
        message = message_from_string(raw_message)
        body = message.get_payload(0).get_payload(decode=True).decode("utf-8")
        assert "2026年01月01日 09:00 (JST)" in body
        assert "太郎" in body
        assert "72時間" in body


def test_send_alert_emails_falls_back_for_unparseable_date(
    main_module, smtp, monkeypatch
):
    monkeypatch.setattr(main_module, "GMAIL_USER", "sender@example.com")
    monkeypatch.setattr(main_module, "GMAIL_PASSWORD", "app-password")

    assert main_module.send_alert_emails(
        "太郎", "not-a-date", 24, [contact("花子", "hanako@example.com")]
    ) is True

    message = message_from_string(smtp.sent_messages[0][2])
    body = message.get_payload(0).get_payload(decode=True).decode("utf-8")
    assert "最後のチェックイン：not-a-date" in body


def test_send_alert_emails_returns_false_when_smtp_raises(
    main_module, smtp, monkeypatch
):
    monkeypatch.setattr(main_module, "GMAIL_USER", "sender@example.com")
    monkeypatch.setattr(main_module, "GMAIL_PASSWORD", "app-password")
    smtp.raise_on_login = RuntimeError("login failed")

    assert main_module.send_alert_emails(
        "太郎", "2026-01-01T00:00:00+00:00", 24, [contact("花子", "hanako@example.com")]
    ) is False
