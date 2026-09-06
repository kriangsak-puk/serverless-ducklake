"""Ingest Lambda — runs OUTSIDE the VPC (see docs/architecture.md): it only needs S3 and,
eventually, internet egress for real SaaS API sources, neither of which needs a NAT
Gateway when the function has no VPC config at all.
"""

from datetime import date, datetime, timezone

from shared.logging_utils import get_logger

from sources.ecommerce_db import EcommerceDbSource

logger = get_logger(__name__)


def lambda_handler(event, context):
    dt = event.get("dt") or date.today().isoformat()
    source = EcommerceDbSource()

    results = {}
    for table in source.tables():
        bytes_landed = source.fetch(table, dt)
        results[table] = bytes_landed
        logger.info("landed table=%s dt=%s bytes=%d", table, dt, bytes_landed)

    return {
        "dt": dt,
        "tables_landed": results,
        "ran_at": datetime.now(timezone.utc).isoformat(),
    }
