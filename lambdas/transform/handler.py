from datetime import datetime, timezone

from shared.logging_utils import get_logger

from transform_runner import run_all

logger = get_logger(__name__)


def lambda_handler(event, context):
    counts = run_all()
    logger.info("transform complete: %s", counts)
    return {
        "table_counts": counts,
        "ran_at": datetime.now(timezone.utc).isoformat(),
    }
