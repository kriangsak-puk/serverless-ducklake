"""Shared S3 prefix conventions for the raw and curated zones."""

import os

RAW_BUCKET = os.environ.get("RAW_BUCKET", "")
CURATED_BUCKET = os.environ.get("CURATED_BUCKET", "")

# Ingest copies from here into raw/<table>/dt=<date>/... — see scripts/upload_seed_to_raw.sh
SOURCE_DROP_PREFIX = "source-drop"

RAW_PREFIX = "raw"

SOURCE_TABLES = ["customers", "products", "orders", "order_items"]


def raw_table_prefix(table: str, dt: str) -> str:
    return f"{RAW_PREFIX}/{table}/dt={dt}/"


def raw_s3_uri(table: str, dt: str) -> str:
    return f"s3://{RAW_BUCKET}/{raw_table_prefix(table, dt)}"


def raw_glob_uri(table: str) -> str:
    """Matches every dt= partition for a table — used by Transform to read everything landed so far."""
    return f"s3://{RAW_BUCKET}/{RAW_PREFIX}/{table}/*/*.csv"


def source_drop_uri(table: str) -> str:
    return f"s3://{RAW_BUCKET}/{SOURCE_DROP_PREFIX}/{table}.csv"
