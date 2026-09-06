"""Runs DDL (idempotent create-if-missing) then per-table staging inserts, then rebuilds
the example mart — against the DuckLake catalog attached by shared.duckdb_session.
"""

import glob
import os

from shared.duckdb_session import get_connection
from shared.logging_utils import get_logger
from shared.s3_paths import RAW_BUCKET, SOURCE_TABLES

logger = get_logger(__name__)

SQL_DIR = os.path.join(os.path.dirname(__file__), "sql")
DDL_DIR = os.path.join(SQL_DIR, "ddl")
TRANSFORM_DIR = os.path.join(SQL_DIR, "transform")


def _run_sql_file(con, path: str, **format_kwargs):
    with open(path) as f:
        sql = f.read()
    if format_kwargs:
        sql = sql.format(**format_kwargs)
    con.execute(sql)


def run_ddl(con):
    for path in sorted(glob.glob(os.path.join(DDL_DIR, "*.sql"))):
        logger.info("running ddl %s", os.path.basename(path))
        _run_sql_file(con, path)


def run_staging(con) -> dict:
    counts = {}
    for table in SOURCE_TABLES:
        stg_path = os.path.join(TRANSFORM_DIR, f"stg_{table}.sql")
        raw_uri = f"s3://{RAW_BUCKET}/raw/{table}/*/*.csv"

        before = con.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
        logger.info("staging table=%s from %s", table, raw_uri)
        _run_sql_file(con, stg_path, raw_uri=raw_uri)
        after = con.execute(f"SELECT count(*) FROM {table}").fetchone()[0]

        counts[table] = {"before": before, "after": after, "inserted": after - before}
    return counts


def run_marts(con):
    mart_path = os.path.join(TRANSFORM_DIR, "mart_order_summary.sql")
    logger.info("rebuilding mart_order_summary")
    _run_sql_file(con, mart_path)


def run_all() -> dict:
    con = get_connection()
    try:
        run_ddl(con)
        counts = run_staging(con)
        run_marts(con)
        return counts
    finally:
        con.close()
