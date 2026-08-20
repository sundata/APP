import copy
import sys
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient


class FakeDocumentSnapshot:
    def __init__(self, document_id, data):
        self.id = document_id
        self._data = copy.deepcopy(data) if data is not None else None

    @property
    def exists(self):
        return self._data is not None

    def to_dict(self):
        return copy.deepcopy(self._data)


class FakeDocumentReference:
    def __init__(self, collection, document_id):
        self._collection = collection
        self.id = document_id

    def get(self):
        return FakeDocumentSnapshot(self.id, self._collection._documents.get(self.id))

    def set(self, data, merge=False):
        if merge and self.id in self._collection._documents:
            self._collection._documents[self.id].update(copy.deepcopy(data))
        else:
            self._collection._documents[self.id] = copy.deepcopy(data)

    def update(self, data):
        if self.id not in self._collection._documents:
            raise KeyError(self.id)
        self._collection._documents[self.id].update(copy.deepcopy(data))


class FakeCollection:
    def __init__(self):
        self._documents = {}

    def document(self, document_id):
        return FakeDocumentReference(self, document_id)

    def stream(self):
        return [
            FakeDocumentSnapshot(document_id, data)
            for document_id, data in self._documents.items()
        ]


class FakeFirestore:
    def __init__(self):
        self._collections = {}

    def collection(self, name):
        return self._collections.setdefault(name, FakeCollection())


class FakeSMTPServer:
    def __init__(self, controller, host, port):
        self.controller = controller
        self.host = host
        self.port = port
        self.logins = []
        self.sent_messages = []

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def login(self, username, password):
        if self.controller.raise_on_login is not None:
            raise self.controller.raise_on_login
        self.logins.append((username, password))

    def sendmail(self, sender, recipient, message):
        if self.controller.raise_on_send is not None:
            raise self.controller.raise_on_send
        self.sent_messages.append((sender, recipient, message))


class FakeSMTPController:
    def __init__(self):
        self.connections = []
        self.raise_on_login = None
        self.raise_on_send = None

    def factory(self, host, port):
        server = FakeSMTPServer(self, host, port)
        self.connections.append(server)
        return server

    @property
    def sent_messages(self):
        return [
            message
            for connection in self.connections
            for message in connection.sent_messages
        ]


_import_db = FakeFirestore()
with patch("google.cloud.firestore.Client", return_value=_import_db):
    if "main" in sys.modules:
        imported_main = sys.modules["main"]
    else:
        import main as imported_main


@pytest.fixture(scope="session")
def main_module():
    return imported_main


@pytest.fixture
def db(main_module, monkeypatch):
    fake_db = FakeFirestore()
    monkeypatch.setattr(main_module, "db", fake_db)
    return fake_db


@pytest.fixture
def client(main_module, db):
    return TestClient(main_module.app)


@pytest.fixture
def smtp(main_module, monkeypatch):
    controller = FakeSMTPController()
    monkeypatch.setattr(main_module.smtplib, "SMTP_SSL", controller.factory)
    return controller


def store_user(db, device_id, **fields):
    db.collection("users").document(device_id).set(fields)


@pytest.fixture
def user_factory(db):
    return lambda device_id, **fields: store_user(db, device_id, **fields)
