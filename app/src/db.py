"""
Database abstraction layer.

The AWS deployment uses PostgreSQL by setting DATABASE_URL. A DynamoDB backend
is kept for experiments, but the worker and dashboard currently expect the
PostgreSQL schema.

Backend selection:
  - PostgreSQL (RDS): set DATABASE_URL (e.g. postgresql://user:pass@host:5432/dbname)
  - DynamoDB:         set TABLE_NAME

If both are set, DATABASE_URL takes precedence.
"""

import os

_backend = None
_redis = None

CACHE_TTL = 3600  # 1 hour


def _get_redis():
    global _redis
    if _redis is not None:
        return _redis
    redis_url = os.environ.get("REDIS_URL")
    if not redis_url:
        return None
    import redis

    kwargs = {"decode_responses": True}
    if redis_url.startswith("rediss://"):
        kwargs["ssl_cert_reqs"] = "required"
    _redis = redis.from_url(redis_url, **kwargs)
    return _redis


def _get_backend():
    global _backend
    if _backend is not None:
        return _backend

    if os.environ.get("DATABASE_URL"):
        _backend = _init_postgres()
    elif os.environ.get("TABLE_NAME"):
        _backend = _init_dynamodb()
    else:
        raise RuntimeError("Set TABLE_NAME (DynamoDB) or DATABASE_URL (PostgreSQL)")

    return _backend


# -- DynamoDB backend --

def _init_dynamodb():
    import boto3
    table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

    def put(short_id: str, url: str):
        table.put_item(Item={"id": short_id, "url": url, "clicks": 0})

    def get(short_id: str):
        resp = table.get_item(Key={"id": short_id})
        return resp.get("Item")

    def incr(short_id: str):
        table.update_item(
            Key={"id": short_id},
            UpdateExpression="SET clicks = if_not_exists(clicks, :zero) + :one",
            ExpressionAttributeValues={":one": 1, ":zero": 0},
        )

    return {"put": put, "get": get, "incr": incr, "type": "dynamodb"}


# -- PostgreSQL backend --

def _init_postgres():
    import psycopg2
    from psycopg2.extras import RealDictCursor

    conn = psycopg2.connect(os.environ["DATABASE_URL"])
    conn.autocommit = True

    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS urls (
                id     TEXT PRIMARY KEY,
                url    TEXT NOT NULL,
                clicks INTEGER NOT NULL DEFAULT 0,
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)

    def put(short_id: str, url: str):
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO urls (id, url) VALUES (%s, %s) ON CONFLICT (id) DO UPDATE SET url = %s",
                (short_id, url, url),
            )

    def get(short_id: str):
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT id, url, clicks FROM urls WHERE id = %s", (short_id,))
            return cur.fetchone()

    def incr(short_id: str):
        with conn.cursor() as cur:
            cur.execute("UPDATE urls SET clicks = clicks + 1 WHERE id = %s", (short_id,))

    return {"put": put, "get": get, "incr": incr, "type": "postgres"}


def put_mapping(short_id: str, url: str):
    _get_backend()["put"](short_id, url)
    r = _get_redis()
    if r:
        r.setex(f"url:{short_id}", CACHE_TTL, url)


def get_mapping(short_id: str):
    r = _get_redis()
    if r:
        cached = r.get(f"url:{short_id}")
        if cached:
            return {"id": short_id, "url": cached, "clicks": 0}
    return _get_backend()["get"](short_id)


def get_mapping_with_stats(short_id: str):
    """Fetch the full record from DB, bypassing Redis cache for accurate click counts."""
    return _get_backend()["get"](short_id)


def increment_clicks(short_id: str):
    _get_backend()["incr"](short_id)


def get_backend_type() -> str:
    return _get_backend()["type"]
