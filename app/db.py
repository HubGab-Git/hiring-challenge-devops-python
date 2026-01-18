import os
from contextlib import contextmanager

import psycopg2
from psycopg2.extras import RealDictCursor


def _database_url() -> str:
    return os.getenv(
        "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/inventory"
    )


@contextmanager
def get_conn():
    conn = psycopg2.connect(_database_url())
    try:
        yield conn
    finally:
        conn.close()


def init_db():
    ddl = """
    CREATE TABLE IF NOT EXISTS servers (
        id SERIAL PRIMARY KEY,
        hostname TEXT NOT NULL UNIQUE,
        ip_address TEXT NOT NULL,
        state TEXT NOT NULL
    )
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(ddl)
        conn.commit()


def fetch_all():
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT id, hostname, ip_address, state FROM servers ORDER BY id")
            return cur.fetchall()


def fetch_one(server_id: int):
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT id, hostname, ip_address, state FROM servers WHERE id = %s",
                (server_id,),
            )
            return cur.fetchone()


def insert_one(hostname: str, ip_address: str, state: str):
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                INSERT INTO servers (hostname, ip_address, state)
                VALUES (%s, %s, %s)
                RETURNING id, hostname, ip_address, state
                """,
                (hostname, ip_address, state),
            )
            row = cur.fetchone()
        conn.commit()
        return row


def update_one(server_id: int, hostname: str, ip_address: str, state: str):
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                UPDATE servers
                SET hostname = %s, ip_address = %s, state = %s
                WHERE id = %s
                RETURNING id, hostname, ip_address, state
                """,
                (hostname, ip_address, state, server_id),
            )
            row = cur.fetchone()
        conn.commit()
        return row


def delete_one(server_id: int):
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM servers WHERE id = %s", (server_id,))
            deleted = cur.rowcount
        conn.commit()
        return deleted
