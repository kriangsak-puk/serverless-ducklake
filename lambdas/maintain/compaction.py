import os

from shared.duckdb_session import get_connection
from shared.logging_utils import get_logger
from shared.s3_paths import SOURCE_TABLES

logger = get_logger(__name__)

# Dockerfile COPYs sql/ to sit alongside this file (${LAMBDA_TASK_ROOT}/sql/).
SQL_DIR = os.path.join(os.path.dirname(__file__), "sql", "maintain")

TABLES = SOURCE_TABLES + ["mart_order_summary"]


def compact() -> dict:
    con = get_connection()
    results = {}
    try:
        template = open(os.path.join(SQL_DIR, "compact_tables.sql")).read()
        for table in TABLES:
            logger.info("compacting %s", table)
            con.execute(template.format(table=table))
            results[table] = "compacted"
    finally:
        con.close()
    return results


def expire_snapshots(older_than_days: int = 30) -> dict:
    con = get_connection()
    try:
        template = open(os.path.join(SQL_DIR, "expire_snapshots.sql")).read()
        older_than_expr = f"now() - INTERVAL '{older_than_days} days'"
        logger.info("expiring snapshots older than %d days", older_than_days)
        con.execute(template.format(older_than=older_than_expr))
        return {"status": "ok", "older_than_days": older_than_days}
    finally:
        con.close()
