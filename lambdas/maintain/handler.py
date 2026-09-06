from shared.logging_utils import get_logger

from compaction import compact, expire_snapshots
from init_catalog import run as run_init_catalog

logger = get_logger(__name__)

ACTIONS = {
    "init_catalog": lambda event: run_init_catalog(),
    "compact": lambda event: compact(),
    "expire_snapshots": lambda event: expire_snapshots(event.get("older_than_days", 30)),
}


def lambda_handler(event, context):
    action = event.get("action")
    if action not in ACTIONS:
        raise ValueError(f"unknown action {action!r}, expected one of {list(ACTIONS)}")

    logger.info("running maintain action=%s", action)
    result = ACTIONS[action](event)
    return {"action": action, "result": result}
