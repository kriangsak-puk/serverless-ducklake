#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Thin CLI: POST a SQL string to the deployed API Gateway /query endpoint and print
results as a table. Reads API_GATEWAY_URL from the environment, or pass --url.

Stdlib only, but run via `uv run` for consistency with the rest of this repo's Python
tooling (see data/generator/generate_mock_data.py).

Usage:
    uv run scripts/query_cli.py "SELECT * FROM mart_order_summary LIMIT 10"
"""

import argparse
import json
import os
import sys
import urllib.request


def run_query(url: str, sql: str) -> dict:
    req = urllib.request.Request(
        url=url.rstrip("/") + "/query",
        data=json.dumps({"sql": sql}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def print_table(columns: list[str], rows: list[list]) -> None:
    widths = [len(c) for c in columns]
    for row in rows:
        for i, val in enumerate(row):
            widths[i] = max(widths[i], len(str(val)))

    def fmt_row(values):
        return "  ".join(str(v).ljust(widths[i]) for i, v in enumerate(values))

    print(fmt_row(columns))
    print("  ".join("-" * w for w in widths))
    for row in rows:
        print(fmt_row(row))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("sql")
    parser.add_argument("--url", default=os.environ.get("API_GATEWAY_URL"))
    args = parser.parse_args()

    if not args.url:
        print("error: set API_GATEWAY_URL or pass --url", file=sys.stderr)
        sys.exit(1)

    result = run_query(args.url, args.sql)
    if "error" in result:
        print(f"error: {result['error']}", file=sys.stderr)
        sys.exit(1)

    print_table(result["columns"], result["rows"])
    print(f"\n({result['row_count']} rows)")
