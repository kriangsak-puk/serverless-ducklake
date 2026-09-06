# DuckLake Cost-Efficient Data Platform on AWS

A lightweight, low-cost data lakehouse architecture built on **DuckLake** (DuckDB's table format), using AWS S3, RDS, Lambda, and Step Functions. Designed for small-to-medium data platforms where a full-time data warehouse cluster is overkill.

Miro board: https://miro.com/app/board/uXjVHq0P5Pk=/

---

## 1. Data Sources

- App databases (OLTP)
- SaaS APIs / events
- Files / CSVs / logs

These are pulled by the ingestion layer on demand or on a schedule — nothing here runs continuously.

---

## 2. Orchestration — AWS Step Functions (Express)

A Step Functions **Express** workflow (not Standard) coordinates the pipeline:

1. Invokes **Ingest**
2. Invokes **Transform**
3. Triggers **Maintain** on a schedule (e.g. daily, via EventBridge)

Express workflows are priced per request/duration — a fraction of a cent per run — and nothing runs when there's no pipeline execution in progress.

---

## 3. Serverless Compute — Lambda functions

| Function | Job |
|---|---|
| **Ingest** | Pulls from sources, lands raw files in S3 |
| **Transform** | Runs DuckDB + `ducklake` extension; writes Parquet to the S3 curated zone; updates the catalog in RDS |
| **Compact / Maintain** | Scheduled housekeeping — compacts small files, expires old snapshots (DuckLake needs this periodically to stay fast and cheap) |
| **Query** | Runs ad-hoc SQL via DuckDB + `ducklake` for programmatic consumers |

All Lambdas are pay-per-invocation with zero cost when idle.

**Practical limits to plan around:** 15 min max runtime, 10 GB memory, 10 GB `/tmp` ephemeral storage. Heavier/longer scans beyond this can fall back to a short-lived Fargate task running the same DuckDB + ducklake setup.

---

## 4. Storage

- **S3 — Raw Zone**: landing bucket for unprocessed data. Lifecycle rules tier this to Glacier / Deep Archive once it's no longer needed hot.
- **S3 — Curated Zone**: the actual DuckLake table data, stored as Parquet.
- **RDS Postgres — DuckLake Catalog**: table/schema metadata and snapshots. A small instance or Aurora Serverless v2 is sufficient — this holds metadata, not the bulk data.

---

## 5. Query & Consumption layer

Two distinct paths depending on the consumer:

### a) Programmatic access — API Gateway → Lambda Query
For notebooks and internal apps that need on-demand SQL access. Serverless end-to-end, pay per call, no idle cost.

### b) Business users — Apache Superset on Fargate
Superset embeds DuckDB directly via the `duckdb-engine` SQLAlchemy driver, `ATTACH`es the DuckLake catalog on connect, and queries S3 + RDS directly — **no Lambda hop needed**. Its own metastore (dashboards, users, charts) reuses the same RDS instance in a separate schema, avoiding a second database.

---

## 6. Fargate scale-to-zero for Superset

Superset is the one piece of this platform that isn't naturally serverless (it's a long-running web app), so scale-to-zero is what keeps it in line with the "lightweight, cost-effective" goal. Because Superset keeps no state in the container itself (all metadata lives in RDS), it's safe to stop and start freely.

### Recommended: scheduled scale-down (simple, minimal added complexity)

1. Run Superset as an **ECS service on Fargate**, `desiredCount: 1`, sized small (0.5 vCPU / 1 GB is usually enough for light BI traffic).
2. Register two **Application Auto Scaling scheduled actions** on the service:
   - Scale to `desiredCount: 1` at the start of business hours (e.g. 8am weekdays).
   - Scale to `desiredCount: 0` at end of day and all weekend.
3. Put a small **Application Load Balancer** in front (health check on Superset's `/health` endpoint) — this is the one always-on cost in this piece, but it's minor (fixed hourly charge + usage).
4. Use **Fargate Spot** for the task if a brief interruption/restart is acceptable — a meaningful discount over standard Fargate for an internal tool.

This covers the common case well: a small/medium team mostly uses BI during work hours, so you pay for compute roughly 40–50 hours/week instead of 168.

### Optional, more advanced: wake-on-request

If usage is unpredictable rather than business-hours-shaped, front the ALB with a lightweight Lambda that:

- Checks if the service is running
- Calls `UpdateService(desiredCount=1)` if not
- Serves a short "waking up, retry shortly" response while it starts

Cold start is roughly the time for a new Fargate task + Superset boot (typically under a minute). This gets closer to true on-demand scale-to-zero but adds a moving part — only worth it if business-hours scheduling doesn't fit your usage pattern.

---

## Why this is cost-efficient

- **Lambda**: pay-per-invocation, $0 idle cost
- **Step Functions Express**: sub-cent per execution
- **S3**: lifecycle rules move cold/raw data to Glacier automatically
- **RDS**: a single small instance / Aurora Serverless v2 doing double duty as both the DuckLake catalog and Superset's metastore — no big data-warehouse cluster
- **Fargate (Superset)**: the only long-running piece, and it scales to zero outside business hours

Nothing in this architecture runs continuously except, optionally on a schedule, the BI layer.