"""Minimal read-only guard for SQL submitted to the public /query endpoint.

Not a full SQL parser — good enough to block obvious writes/DDL from an API surface that
otherwise hands arbitrary SQL to DuckDB. If this needs to get more permissive later,
prefer a real SQL parser (e.g. sqlglot) over extending this regex-based check.
"""

import re

FORBIDDEN_KEYWORDS = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|ATTACH|DETACH|COPY|CALL|PRAGMA|EXPORT|IMPORT|GRANT|REVOKE)\b",
    re.IGNORECASE,
)


class QueryNotAllowed(Exception):
    pass


def assert_read_only(sql: str) -> None:
    stripped = sql.strip().rstrip(";")

    if ";" in stripped:
        raise QueryNotAllowed("multiple statements are not allowed")

    if not stripped:
        raise QueryNotAllowed("empty query")

    first_word = stripped.split(None, 1)[0].upper()
    if first_word not in ("SELECT", "WITH"):
        raise QueryNotAllowed("only SELECT/WITH queries are allowed")

    if FORBIDDEN_KEYWORDS.search(stripped):
        raise QueryNotAllowed("query contains a disallowed keyword")
