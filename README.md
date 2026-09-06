# serverless-ducklake

![DuckLake on AWS](docs/ducklakeonaws.png)

A cost-optimized DuckLake (DuckDB table format) data lakehouse on AWS: Lambda + Step
Functions for ingest/transform/maintenance, S3 for storage, RDS Postgres for the DuckLake
catalog, API Gateway for programmatic queries, and Apache Superset on Fargate for BI —
designed to run at close to $0 when idle. See [`docs/architecture.md`](docs/architecture.md)
for the full design and the reasoning behind each cost/networking decision.

## Prerequisites

- AWS account + credentials configured (`aws sts get-caller-identity` should work)
- Terraform >= 1.5
- Docker (with buildx — needed for `--platform linux/arm64` builds; default in current Docker Desktop/OrbStack)
- [`uv`](https://docs.astral.sh/uv/) — runs `scripts/query_cli.py` and the data generator with no manual venv/pip step; also what both Dockerfiles use to install Python dependencies

## Repository layout

```
bootstrap/      One-time remote Terraform state setup (S3 + DynamoDB)
terraform/      Main infrastructure (VPC, S3, RDS, ECR, Lambda, Step Functions, API GW, Superset)
lambdas/        Ingest / Transform / Maintain / Query Lambda source + shared DuckDB session code
superset/       Custom Superset image (DuckDB + ducklake extension, auto-attach config)
sql/            DDL, staging transforms, and maintenance SQL run by the Transform/Maintain Lambdas
data/           Mock e-commerce seed CSVs + the generator that produced them
scripts/        Deploy/build/init/query helper scripts
docs/           Architecture writeup
```

## Tools & technologies

**Infrastructure**
- [Terraform](https://www.terraform.io/) >= 1.5 — `hashicorp/aws` ~> 6.0, `hashicorp/random` ~> 3.6, `hashicorp/time` ~> 0.12 (the last one only to work around an IAM eventual-consistency race, see `docs/architecture.md`)
- AWS: VPC (no NAT Gateway), S3, RDS for PostgreSQL 17, Lambda (container images, arm64/Graviton), ECR, Step Functions (Standard), EventBridge, API Gateway (HTTP API), ECS on Fargate (arm64) + Application Load Balancer, IAM, CloudWatch Logs, Application Auto Scaling, SSM/ECS Exec

**Data & query engine**
- [DuckDB](https://duckdb.org/) 1.5.5 with the `ducklake`, `postgres`, `httpfs`, and `aws` extensions — baked into the image at build time, not installed at runtime
- [DuckLake](https://ducklake.select/) — the table format itself (Postgres-backed catalog, Parquet data files in S3)

**BI**
- [Apache Superset](https://superset.apache.org/) 6.1.0 (`-py312` image variant), connected to DuckDB via [`duckdb-engine`](https://github.com/Mause/duckdb_engine) (SQLAlchemy dialect), served by gunicorn

**Language & packaging**
- Python 3.12 (Superset) / 3.13 (Lambda) — dependencies installed with [`uv`](https://docs.astral.sh/uv/) everywhere (Dockerfiles and local scripts), not `pip`
- Docker + Buildx, building explicitly for `linux/arm64` with provenance/SBOM attestation disabled (Lambda rejects the multi-manifest image BuildKit produces by default)
- [Faker](https://faker.readthedocs.io/) — generates the mock e-commerce seed data

**Local tooling**
- AWS CLI, `make`, bash scripts (`scripts/`)

## Deploying (first time)

Follow this order — each step should be sanity-checked before moving to the next (see
`docs/architecture.md` for what to check at each one).

```bash
# 1. Bootstrap remote state (once)
make bootstrap
# copy the printed bucket/table names into terraform/backend.tf

# 2. Core infra: networking, storage, catalog DB
cd terraform && terraform init
terraform apply -target=module.networking -target=module.storage -target=module.catalog_db
cd ..

# 3. Build + push the maintain image, deploy Lambdas, bootstrap the catalog
make build-maintain
cd terraform && terraform apply -target=module.ecr -target=module.lambda_functions && cd ..
make init-catalog

# 4. Build + push transform and ingest, then run the pipeline manually
make build-transform build-ingest
make seed             # uploads data/seed/*.csv to the raw bucket's source-drop/
cd terraform && terraform apply && cd ..   # wires up Step Functions + EventBridge + API GW
make run-pipeline

# 5. Query the result
make query SQL="SELECT * FROM mart_order_summary LIMIT 10"

# 6. Superset — build/push its image, then apply last
./scripts/build_and_push_image.sh superset
cd terraform && terraform apply && cd ..
terraform -chdir=terraform output superset_alb_dns_name
terraform -chdir=terraform output -raw superset_admin_password
```

Copy `.env.example` to `.env` and fill in the `terraform output` values if you want the
scripts to pick them up without re-running `terraform output` each time.

## Everyday use

```bash
make run-pipeline                                        # trigger Ingest -> Transform manually
make query SQL="SELECT count(*) FROM orders"
./scripts/db_tunnel.sh                                    # psql into the private RDS via ECS Exec
```

The pipeline also runs automatically on the schedules in `terraform/variables.tf`
(`pipeline_schedule_cron`, `maintain_schedule_cron`), and Superset scales itself down
outside business hours (`superset_scale_up_cron` / `superset_scale_down_cron`).

## Regenerating mock data

```bash
make generate-data   # uv run data/generator/generate_mock_data.py (Faker, seeded — deterministic)
```

## Superset dataset connection

Add the DuckLake catalog in the UI once: **Settings → Database Connections → + Database →
DuckDB**, URI `duckdb:///:memory:`. It comes up already attached to the curated tables
(`customers`, `products`, `orders`, `order_items`, `mart_order_summary` under the
`ducklake_catalog` database in SQL Lab's schema browser) — see **Superset de-risking** in
`docs/architecture.md` for how that auto-attach mechanism works and how it was verified.

## License

[MIT](LICENSE)
