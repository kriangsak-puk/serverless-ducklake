# DuckLake Cost-Efficient Data Platform on AWS

A lightweight, low-cost data lakehouse built on **DuckLake** (DuckDB's table format), using
AWS S3, RDS, Lambda, Step Functions, ECR, and ECS Fargate. Designed for small-to-medium
data platforms where a full-time data warehouse cluster is overkill.

This adapts an earlier hand-sketched design (originally worked out on a Miro board) to
what's actually implemented in this repo — see **Deviations from the original design**
below for the handful of places implementation reality changed the plan.

---

## 1. Data sources

- App databases (OLTP) — represented here by a mock e-commerce schema (customers,
  products, orders, order_items) in `data/seed/`.
- SaaS APIs / events, files / CSVs / logs — the same `Ingest` Lambda interface
  (`lambdas/ingest/sources/base_source.py`) is meant to support these; only the
  e-commerce CSV source is implemented today.

Pulled by the ingestion layer on demand or on a schedule — nothing runs continuously.

---

## 2. Orchestration — AWS Step Functions (**Standard**)

A Step Functions **Standard** workflow coordinates the pipeline:

1. Invokes **Ingest**
2. Invokes **Transform**
3. **Maintain** runs on its own separate EventBridge schedule, invoked directly (not
   through Step Functions)

See [deviation #1](#deviations-from-the-original-design) for why this is Standard, not
Express as originally sketched.

---

## 3. Serverless compute — Lambda functions (container images)

| Function | Job | VPC? |
|---|---|---|
| **Ingest** | Pulls from sources, lands raw files in S3 | No |
| **Transform** | Runs DuckDB + `ducklake` extension; writes Parquet to the S3 curated zone; updates the catalog in RDS | Yes |
| **Maintain** | Scheduled housekeeping — compacts small files, expires old snapshots, bootstraps the catalog | Yes |
| **Query** | Runs read-only ad-hoc SQL via DuckDB + `ducklake`, invoked through API Gateway | Yes |

All 4 are deployed as container images (`package_type = Image`) from ECR, sharing a common
base image (`lambdas/base/Dockerfile.base`) that bakes in the `duckdb`, `postgres`,
`httpfs`, and `aws` DuckDB extensions **at build time** — see
[deviation #3](#deviations-from-the-original-design) for why runtime extension installation
doesn't work here.

Practical limits: 15 min max runtime, 10 GB memory, 10 GB `/tmp` ephemeral storage.
Heavier/longer scans beyond this would need a Fargate-based fallback — out of scope for v1.

---

## 4. Storage

- **S3 — Raw Zone**: landing bucket for unprocessed data, partitioned `raw/<table>/dt=<date>/`.
  Lifecycle rules tier it to IA → Glacier → Deep Archive over time.
- **S3 — Curated Zone**: the actual DuckLake table data, stored as Parquet under
  `ducklake/`. No lifecycle transitions (it's live data) and versioning is off — see
  [deviation #4](#deviations-from-the-original-design) for the tradeoff.
- **RDS Postgres — Catalog**: DuckLake table/schema metadata and snapshots, plus a second
  database on the same instance for Superset's own metastore. See
  [deviation #2](#deviations-from-the-original-design) for why this is a small fixed
  instance, not Aurora Serverless v2.

---

## 5. Query & consumption layer

### a) Programmatic access — API Gateway → Lambda Query

`POST /query` with `{"sql": "SELECT ..."}`. Read-only enforced by
`lambdas/query/query_guard.py` (SELECT/WITH only, single statement, keyword blocklist) —
this is a basic guard, not a full SQL parser.

### b) Business users — Apache Superset on Fargate

Superset (`superset/`) embeds DuckDB via `duckdb-engine`. Because DuckDB's `ATTACH` is
per-connection, not persisted in a database file, `superset/superset_config.py` registers
a SQLAlchemy `Pool` "connect" hook that re-runs the `ATTACH ... TYPE ducklake` + `USE`
sequence on every fresh DuckDB connection Superset opens — so any "DuckDB" database
connection added through the Superset UI (`duckdb:///:memory:`) comes up already attached
to the curated tables. This mechanism (and the image's full boot sequence — `db upgrade`,
`fab create-admin`, `init`, and the `/health` endpoint) has been verified locally against a
real Postgres — see [Superset de-risking](#superset-de-risking). What's *not* yet verified
is the same flow against the real deployed AWS resources (real RDS in a VPC, real S3 via
the credential-chain secret) — spot-check that once after the `superset` module is first
applied. Superset's own metastore (dashboards/users/charts) reuses the same RDS instance in
a separate database.

---

## 6. Fargate scale-to-zero for Superset

Superset keeps no state in the container itself (all metadata lives in RDS), so it's safe
to stop and start freely:

1. ECS service on Fargate Spot, `desiredCount: 1`, 0.5 vCPU / 1 GB.
2. Application Auto Scaling scheduled actions: scale to 1 at business-hours start, 0 at
   end (cron expressions are tfvars — `superset_scale_up_cron` / `superset_scale_down_cron`).
3. A small ALB in front, health check on `/health` — this is the one piece that does
   **not** scale to zero (see [deviation #5](#deviations-from-the-original-design)).

---

## Deviations from the original design

The original sketch got most of this right, but six things changed between design and
implementation:

1. **Step Functions: Standard, not Express.** Express workflows cap execution at 5
   minutes; Transform is speced for up to 15. This is a hard limit, not a preference — at
   this run volume (a handful of executions/day), Standard's cost is negligible either way.

2. **RDS: `db.t4g.micro` single-AZ Postgres, not Aurora Serverless v2.** ASv2's
   auto-pause/resume latency would hit Query Lambda's p99 whenever the catalog DB has been
   idle. A small fixed instance avoids that. One-line tfvar (`db_instance_class`) to
   change if usage grows enough to justify autoscaling storage/compute.

3. **Not all 4 Lambdas sit in a VPC.** Only Transform, Maintain, and Query touch RDS.
   Ingest stays **outside the VPC** entirely — free S3/internet access, no NAT Gateway
   needed just for it. The other three run in private subnets with an S3 gateway endpoint
   (free) for S3 and a security-group rule for RDS — still no NAT Gateway anywhere.

4. **Superset's Fargate task runs in a public subnet**, not private. ECS Fargate pulls
   images over the task's own ENI (unlike Lambda, which uses the Lambda service's own
   infrastructure to pull images) — a private-subnet task would need ~3 paid interface VPC
   endpoints (ECR api/dkr + logs), costing about as much as the NAT Gateway this design
   avoids. A public subnet + a security group that only accepts inbound from the ALB gets
   free image-pull egress via the Internet Gateway while still reaching RDS over the VPC.

5. **The ALB does not scale to zero.** It's a fixed hourly cost regardless of whether
   Superset's task is running — only the Fargate task's own compute cost is what "scale to
   zero" actually saves.

6. **Lambda and Fargate run on arm64 (Graviton), not x86_64.** Cheaper, and also the
   architecture Docker on Apple Silicon produces by default — `architectures = ["arm64"]`
   on the Lambda functions and `runtime_platform.cpu_architecture = "ARM64"` on the
   Superset task definition must match whatever `scripts/build_and_push_image.sh` builds
   (it pins `--platform linux/arm64` explicitly for exactly this reason — an x86_64-built
   image deployed here would fail at invoke/start time with an exec format error, not at
   `terraform apply` time).

---

## Versions

Pinned versions as of when this repo was last checked against upstream — re-check
periodically, none of these are pinned out of necessity beyond what's noted:

| Component | Version | Notes |
|---|---|---|
| Terraform AWS provider | `~> 6.0` | v5→v6 upgrade guide reviewed; no breaking changes affect this repo's resources |
| Terraform random provider | `~> 3.6` | |
| Lambda base image | `public.ecr.aws/lambda/python:3.13` | |
| duckdb (Lambda + Superset) | `1.5.5` | must be recent enough to have the `ducklake` extension published — 1.1.3 predates it (404s at build time); kept identical across Lambda and Superset images now that both run Python 3.12+ |
| Superset | `apache/superset:6.1.0-py312` | the `-py312` variant matters — it's what lets duckdb match the Lambda images; older `-py39`-era tags cap duckdb at 1.4.5 |
| RDS Postgres | `17` (tfvar `db_engine_version`) | 18 is also available on RDS if you want newest-major; 17 is what's been verified locally |
| Python dependency installs | `uv`, not `pip` | both Dockerfiles and local scripts (`data/generator/`, `scripts/query_cli.py`) — local scripts use `uv run --script` with PEP 723 inline dependencies, no manual venv/pip step |

---

## Cost notes (verify against current AWS pricing for your region)

**Always-on:** RDS `db.t4g.micro` (24/7 — it's the catalog of record), the ALB.

**Usage-based, expected near-zero at this data volume:** Lambda invocations/duration, Step
Functions Standard state transitions, API Gateway requests, ECR storage.

**Avoided by design:** NAT Gateway; Secrets Manager / ECR interface VPC endpoints (off by
default via `enable_ecr_interface_endpoints` / `enable_secretsmanager_endpoint` — flip on
only if something empirically needs them, at ~$7.30/mo per endpoint per AZ).

---

## DuckDB extension loading (why this needs baking, not runtime install)

Transform/Maintain/Query run in private VPC subnets with no NAT Gateway — no general
internet egress. A runtime `INSTALL ducklake` (which reaches `extensions.duckdb.org`)
would hang and fail. Instead, `lambdas/base/Dockerfile.base` runs the `INSTALL` commands
at **build time** into a fixed `extension_directory`, and
`lambdas/shared/duckdb_session.py` points DuckDB's `extension_directory` config at that
same baked path at runtime with `autoinstall_known_extensions` / `autoload_known_extensions`
both disabled — so a cold start never tries to phone home. `home_directory` is intentionally
NOT used for this (it would look for extensions under `$HOME/.duckdb/...`, not the baked
path).

RDS credentials reach Lambda as plain (not console-"encrypted-helper") environment
variables — the Lambda service decrypts these before invocation with no network call from
inside the function, which is what makes this compatible with a no-NAT private subnet.

S3 access from DuckDB uses `CREATE SECRET (TYPE S3, PROVIDER CREDENTIAL_CHAIN)`, which
picks up the Lambda execution role's credentials automatically — no explicit access keys
anywhere.

---

## Superset de-risking

Verified end-to-end, including against real deployed AWS resources (RDS in the actual
VPC, S3 via the credential-chain secret, live ALB) — SQL Lab's schema browser shows
`ducklake_catalog.main` with all 5 curated tables, and queries against them return real
data.

Getting there took two real bugs, both instructive enough to call out:

1. **The connect hook used `dbapi_connection.cursor()` to run `ATTACH`/`USE`.** DuckDB's
   Python cursors are independent sub-sessions — catalog/schema state set on a cursor
   (`USE ducklake_catalog`) never propagates back to the parent connection. Fixed by
   executing directly on `dbapi_connection`, matching the pattern already used in
   `lambdas/shared/duckdb_session.py`.
2. **The connection-type filter was an exact string match (`== "duckdb"`) on the DBAPI
   connection's module name.** `duckdb-engine` wraps the raw `duckdb.DuckDBPyConnection`
   in its own `duckdb_engine.ConnectionWrapper` — module name `duckdb_engine`, not
   `duckdb`. The exact match silently rejected every real connection Superset ever opened,
   so the hook was a no-op the whole time; an initial isolated test with plain
   `duckdb-engine` (no Superset) happened to "pass" only because it wrote and read back
   from the same reused, un-attached connection — a false positive from insufficient test
   isolation. Fixed with `.startswith("duckdb")`, which catches both module names, and
   confirmed via `sqlalchemy.inspect(engine).get_schema_names()` — the exact call
   Superset's UI makes — actually listing `ducklake_catalog.main`.

If you ever touch `superset/superset_config.py` again, re-verify with `inspect()`
directly (not just "the app didn't crash") — this class of bug fails silently.

Original local-Postgres verification (still valid, boot sequence unaffected by the fix
above):

- The image builds cleanly and `superset db upgrade`, `superset fab create-admin`, and
  `superset init` all complete successfully against a real Postgres metastore.
- The full `entrypoint.sh` boot sequence works — `gunicorn` comes up and `/health` returns
  `200`, matching the ALB's health check config.

To reproduce the connection-level check locally against a temporary Postgres:

```bash
docker build --platform linux/arm64 -f superset/Dockerfile -t ducklake-superset:local .
docker run --rm -p 8088:8088 \
  -e SUPERSET_DB_HOST=... -e SUPERSET_DB_PORT=5432 -e SUPERSET_DB_NAME=superset_meta \
  -e SUPERSET_DB_USER=... -e SUPERSET_DB_PASSWORD=... \
  -e DUCKLAKE_DB_HOST=... -e DUCKLAKE_DB_PORT=5432 -e DUCKLAKE_DB_NAME=ducklake_catalog \
  -e DUCKLAKE_DB_USER=... -e DUCKLAKE_DB_PASSWORD=... \
  -e CURATED_BUCKET=... -e AWS_REGION=us-east-1 \
  ducklake-superset:local
```

(Needs network access to the real RDS instance — e.g. temporarily via `scripts/db_tunnel.sh`'s
approach or a temporarily-public dev endpoint — plus real AWS credentials for the S3
credential chain.) Log into `http://localhost:8088` (`admin` / the generated
`superset_admin_password` terraform output), add a "DuckDB" database with URI
`duckdb:///:memory:`, and confirm `SELECT * FROM customers LIMIT 10` returns rows in SQL Lab.

---

## DuckLake catalog bootstrap

`lambdas/maintain/init_catalog.py`'s `init_catalog` action (idempotent):

1. Opens a DuckDB connection and `ATTACH`es the catalog — the `ducklake` extension
   auto-creates its own metadata tables in Postgres on first attach.
2. Creates the Superset metastore database (`superset_db_name` tfvar) on the same RDS
   instance if it doesn't already exist — done via a direct `psycopg2` connection since
   `CREATE DATABASE` isn't expressible mid-session in the attached DuckDB catalog.

Run once via `scripts/init_catalog.sh` after `catalog_db` + `lambda_functions` (at least
`maintain`) are deployed, before the first Transform run — see the build order in the root
README.
