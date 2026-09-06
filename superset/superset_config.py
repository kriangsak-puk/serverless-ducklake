"""Superset config — reads connection info from env vars set by the ECS task definition
(terraform/modules/superset/main.tf).

Superset's own metastore (dashboards/users/charts) uses SUPERSET_DB_* below.

The DuckLake catalog is added as a second database connection through the Superset UI
(SQL Lab -> Databases -> + Database -> "DuckDB", URI `duckdb:///:memory:`). Getting a
usable connection there is the least-proven part of this whole design (see
docs/architecture.md) — DuckDB's ATTACH is per-session, not persisted in a .duckdb file,
so a fresh pooled connection from Superset would normally come up with nothing attached.
The SQLAlchemy Pool "connect" hook below runs the ATTACH on every new DuckDB DBAPI
connection Superset opens (filtered by driver module name, so it never touches the
Postgres metastore pool), so any DuckDB-backed connection added in the UI comes up
already ATTACHed and USEd against the curated tables. Verify this end-to-end (see
docs/architecture.md's Superset de-risking step) before depending on it for real
dashboards.
"""

import os

from sqlalchemy import event
from sqlalchemy.pool import Pool

DB_USER = os.environ["SUPERSET_DB_USER"]
DB_PASSWORD = os.environ["SUPERSET_DB_PASSWORD"]
DB_HOST = os.environ["SUPERSET_DB_HOST"]
DB_PORT = os.environ["SUPERSET_DB_PORT"]
DB_NAME = os.environ["SUPERSET_DB_NAME"]

SQLALCHEMY_DATABASE_URI = (
    f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "change-me-in-production")

FEATURE_FLAGS = {}

# --- Auto-ATTACH the DuckLake catalog on every new DuckDB connection ---

DUCKDB_EXTENSION_DIR = os.environ.get("DUCKDB_EXTENSION_DIR", "/app/duckdb_extensions")
DUCKLAKE_DB_HOST = os.environ.get("DUCKLAKE_DB_HOST")
DUCKLAKE_DB_PORT = os.environ.get("DUCKLAKE_DB_PORT")
DUCKLAKE_DB_NAME = os.environ.get("DUCKLAKE_DB_NAME")
DUCKLAKE_DB_USER = os.environ.get("DUCKLAKE_DB_USER")
DUCKLAKE_DB_PASSWORD = os.environ.get("DUCKLAKE_DB_PASSWORD")
CURATED_BUCKET = os.environ.get("CURATED_BUCKET")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")


def _attach_ducklake_on_duckdb_connect(dbapi_connection, connection_record):
    # Fires for every SQLAlchemy connection pool in the process (Superset's own metastore
    # pool included) — only act on DuckDB DBAPI connections.
    if type(dbapi_connection).__module__.split(".")[0] != "duckdb":
        return
    if not DUCKLAKE_DB_HOST:
        return  # not configured (e.g. local dev without the full env) — no-op

    cursor = dbapi_connection.cursor()
    cursor.execute(f"SET extension_directory='{DUCKDB_EXTENSION_DIR}'")
    cursor.execute("SET autoinstall_known_extensions=false")
    cursor.execute("SET autoload_known_extensions=false")
    cursor.execute("LOAD httpfs")
    cursor.execute("LOAD aws")
    cursor.execute("LOAD postgres")
    cursor.execute("LOAD ducklake")
    cursor.execute(
        f"CREATE OR REPLACE SECRET s3_secret (TYPE S3, PROVIDER CREDENTIAL_CHAIN, REGION '{AWS_REGION}')"
    )
    dsn = (
        f"dbname={DUCKLAKE_DB_NAME} host={DUCKLAKE_DB_HOST} port={DUCKLAKE_DB_PORT} "
        f"user={DUCKLAKE_DB_USER} password={DUCKLAKE_DB_PASSWORD}"
    )
    cursor.execute(
        f"ATTACH 'ducklake:postgres:{dsn}' AS ducklake_catalog "
        f"(DATA_PATH 's3://{CURATED_BUCKET}/ducklake/')"
    )
    cursor.execute("USE ducklake_catalog")
    cursor.close()


event.listen(Pool, "connect", _attach_ducklake_on_duckdb_connect)
