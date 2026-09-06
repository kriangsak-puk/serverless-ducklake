"""Builds a DuckDB connection ATTACHed to the DuckLake catalog.

Three distinct settings matter here and must not be conflated:
  - extension_directory: where DuckDB LOADs the ducklake/postgres/httpfs/aws extensions
    from. Must point at the path baked into the image at build time (see
    lambdas/base/Dockerfile.base) — NOT left to default to `home_directory`, since if that
    were pointed at /tmp DuckDB would look for extensions under /tmp/.duckdb/... and find
    nothing (autoload is disabled below, so that's a hard failure, not a re-download).
  - temp_directory: DuckDB's own spill-to-disk directory for large queries. Lambda's only
    writable filesystem is /tmp, sized by the function's configured ephemeral storage.
  - autoinstall/autoload: both disabled, so a cold start never tries to reach
    extensions.duckdb.org — there is no internet egress from the private VPC subnets these
    functions (other than Ingest) run in.
"""

import os

import duckdb

from .db_config import load_db_config

EXTENSION_DIR = os.environ.get("DUCKDB_EXTENSION_DIR", "/opt/duckdb_extensions")
TMP_DIR = "/tmp/duckdb_tmp"


def get_connection(catalog_alias: str = "ducklake_catalog") -> duckdb.DuckDBPyConnection:
    os.makedirs(TMP_DIR, exist_ok=True)

    con = duckdb.connect(
        config={
            "extension_directory": EXTENSION_DIR,
            "temp_directory": TMP_DIR,
            "autoinstall_known_extensions": "false",
            "autoload_known_extensions": "false",
        }
    )

    con.execute("LOAD httpfs")
    con.execute("LOAD aws")
    con.execute("LOAD postgres")
    con.execute("LOAD ducklake")

    region = os.environ.get("AWS_REGION", "us-east-1")
    con.execute(
        f"""
        CREATE OR REPLACE SECRET s3_secret (
            TYPE S3,
            PROVIDER CREDENTIAL_CHAIN,
            REGION '{region}'
        )
        """
    )

    db = load_db_config()
    curated_bucket = os.environ["CURATED_BUCKET"]
    attach_target = f"ducklake:postgres:{db.postgres_dsn}"
    con.execute(
        f"ATTACH '{attach_target}' AS {catalog_alias} "
        f"(DATA_PATH 's3://{curated_bucket}/ducklake/')"
    )
    con.execute(f"USE {catalog_alias}")

    return con
