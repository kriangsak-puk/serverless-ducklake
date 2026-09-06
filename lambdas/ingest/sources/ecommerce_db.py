"""Simulates pulling from the e-commerce OLTP source.

In this repo the "source" is a fixed set of seed CSVs pre-populated into S3 at
`s3://<raw-bucket>/source-drop/<table>.csv` by `scripts/upload_seed_to_raw.sh`. A real
connector (a live Postgres/MySQL app DB, a SaaS API) would implement the same
`BaseSource` interface and this class swaps out cleanly — Ingest's job is structurally the
same either way: land raw rows into `raw/<table>/dt=<date>/...` in S3.
"""

import boto3

from shared.s3_paths import RAW_BUCKET, SOURCE_TABLES, raw_table_prefix

from .base_source import BaseSource

s3 = boto3.client("s3")


class EcommerceDbSource(BaseSource):
    def tables(self) -> list[str]:
        return SOURCE_TABLES

    def fetch(self, table: str, dt: str) -> int:
        source_key = f"source-drop/{table}.csv"
        dest_key = f"{raw_table_prefix(table, dt)}{table}.csv"

        s3.copy_object(
            Bucket=RAW_BUCKET,
            CopySource={"Bucket": RAW_BUCKET, "Key": source_key},
            Key=dest_key,
        )

        head = s3.head_object(Bucket=RAW_BUCKET, Key=dest_key)
        return head["ContentLength"]
