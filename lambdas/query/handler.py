import json

from shared.duckdb_session import get_connection
from shared.logging_utils import get_logger

from query_guard import QueryNotAllowed, assert_read_only

logger = get_logger(__name__)

MAX_ROWS = 1000


def _response(status: int, body: dict):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, default=str),
    }


def lambda_handler(event, context):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "body must be valid JSON"})

    sql = payload.get("sql")
    if not sql:
        return _response(400, {"error": "missing 'sql' field"})

    try:
        assert_read_only(sql)
    except QueryNotAllowed as e:
        return _response(400, {"error": str(e)})

    con = get_connection()
    try:
        result = con.execute(sql)
        columns = [d[0] for d in result.description]
        rows = result.fetchmany(MAX_ROWS)
        return _response(200, {"columns": columns, "rows": rows, "row_count": len(rows)})
    except Exception as e:
        logger.exception("query failed")
        return _response(400, {"error": str(e)})
    finally:
        con.close()
