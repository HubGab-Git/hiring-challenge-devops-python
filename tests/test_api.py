import os

import psycopg2
import pytest
from fastapi.testclient import TestClient

from app import db
from app.main import app


DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/inventory"
)


def _db_available() -> bool:
    try:
        conn = psycopg2.connect(DATABASE_URL)
        conn.close()
        return True
    except Exception:
        return False


@pytest.fixture(scope="session")
def client():
    if not _db_available():
        pytest.skip("PostgreSQL is not available for tests")
    return TestClient(app)


@pytest.fixture(autouse=True)
def clean_db():
    if not _db_available():
        return
    db.init_db()
    conn = psycopg2.connect(DATABASE_URL)
    try:
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE servers RESTART IDENTITY")
        conn.commit()
    finally:
        conn.close()


def test_crud_flow(client):
    payload = {"hostname": "srv-1", "ip_address": "10.0.0.1", "state": "active"}
    resp = client.post("/servers", json=payload)
    assert resp.status_code == 201
    data = resp.json()
    assert data["id"] == 1

    resp = client.get("/servers")
    assert resp.status_code == 200
    assert len(resp.json()) == 1

    resp = client.get("/servers/1")
    assert resp.status_code == 200
    assert resp.json()["hostname"] == "srv-1"

    update = {"hostname": "srv-1b", "ip_address": "10.0.0.2", "state": "offline"}
    resp = client.put("/servers/1", json=update)
    assert resp.status_code == 200
    assert resp.json()["hostname"] == "srv-1b"

    resp = client.delete("/servers/1")
    assert resp.status_code == 204

    resp = client.get("/servers/1")
    assert resp.status_code == 404


def test_unique_hostname_validation(client):
    payload = {"hostname": "srv-unique", "ip_address": "10.0.0.10", "state": "active"}
    resp = client.post("/servers", json=payload)
    assert resp.status_code == 201

    resp = client.post(
        "/servers",
        json={"hostname": "srv-unique", "ip_address": "10.0.0.11", "state": "offline"},
    )
    assert resp.status_code == 400
    assert resp.json()["detail"] == "hostname must be unique"


def test_ip_validation(client):
    resp = client.post(
        "/servers",
        json={"hostname": "srv-ip", "ip_address": "not-an-ip", "state": "active"},
    )
    assert resp.status_code == 422


def test_state_validation(client):
    resp = client.post(
        "/servers",
        json={"hostname": "srv-state", "ip_address": "10.0.0.12", "state": "broken"},
    )
    assert resp.status_code == 422


def test_all_states_supported(client):
    states = ["active", "offline", "retired"]
    for idx, state in enumerate(states, start=1):
        payload = {
            "hostname": f"srv-state-{state}",
            "ip_address": f"10.0.1.{idx}",
            "state": state,
        }
        resp = client.post("/servers", json=payload)
        assert resp.status_code == 201
        assert resp.json()["state"] == state
