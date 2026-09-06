"""One-time (idempotent) DuckLake catalog + Superset metastore bootstrap.

Run via `scripts/init_catalog.sh` right after `catalog_db` + `lambda_functions` (maintain)
are deployed, before the first Transform run. Safe to re-run.
"""

import os

import psycopg2
from psycopg2 import errors as pg_errors

from shared.db_config import load_db_config
from shared.duckdb_session import get_connection
from shared.logging_utils import get_logger

logger = get_logger(__name__)


def ensure_ducklake_catalog() -> None:
    """ATTACHing with TYPE ducklake auto-creates the catalog's own metadata tables in
    Postgres on first attach if they don't already exist — so simply attaching (which
    get_connection() does) is the idempotent bootstrap step for the catalog itself."""
    con = get_connection()
    try:
        snapshot_count = con.execute(
            "SELECT count(*) FROM ducklake_snapshots('ducklake_catalog')"
        ).fetchone()[0]
        logger.info("ducklake catalog attached ok, %d snapshot(s) so far", snapshot_count)
    finally:
        con.close()


def ensure_superset_database() -> None:
    """Creates the separate `superset_db_name` database on the same RDS instance, used
    for Superset's own metastore (dashboards/users/charts) — kept apart from the DuckLake
    catalog's own tables. Postgres has no `CREATE DATABASE IF NOT EXISTS`, so check first.
    """
    db = load_db_config()
    superset_db_name = os.environ.get("SUPERSET_DB_NAME", "superset_meta")

    conn = psycopg2.connect(
        host=db.host, port=db.port, dbname=db.name, user=db.user, password=db.password
    )
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (superset_db_name,))
            if cur.fetchone():
                logger.info("database %s already exists", superset_db_name)
                return
            try:
                cur.execute(f'CREATE DATABASE "{superset_db_name}"')
                logger.info("created database %s", superset_db_name)
            except pg_errors.DuplicateDatabase:
                logger.info("database %s created concurrently, skipping", superset_db_name)
    finally:
        conn.close()


def run() -> dict:
    ensure_ducklake_catalog()
    ensure_superset_database()
    return {"status": "ok"}
