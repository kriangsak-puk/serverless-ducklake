# Build context is the repo root (see scripts/build_and_push_image.sh).
#
# Bakes the ducklake/postgres/httpfs/aws DuckDB extensions at build time (same reasoning
# as lambdas/base/Dockerfile.base): even though this task runs in a public subnet with
# internet egress, baking avoids a runtime dependency on extensions.duckdb.org being
# reachable/fast at container start.
#
# Build for linux/arm64 (see scripts/build_and_push_image.sh) — must match the
# `runtime_platform.cpu_architecture = "ARM64"` set on the ECS task definition in
# terraform/modules/superset/main.tf.
#
# apache/superset:6.1.0-py312 already manages its own venv (/app/.venv) with `uv` — there
# is no `pip` inside it, so we install with `uv pip install` targeting that venv's python,
# consistent with uv being used for Python dependency installs everywhere in this repo.
FROM apache/superset:6.1.0-py312

USER root

# postgresql-client: lets scripts/db_tunnel.sh run `psql` inside this task via ECS Exec.
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY superset/requirements.txt /app/requirements-ducklake.txt
RUN uv pip install --python /app/.venv/bin/python3 --no-cache -r /app/requirements-ducklake.txt

ENV DUCKDB_EXTENSION_DIR=/app/duckdb_extensions
RUN mkdir -p ${DUCKDB_EXTENSION_DIR} && \
    python3 -c "\
import duckdb; \
con = duckdb.connect(config={'extension_directory': '${DUCKDB_EXTENSION_DIR}'}); \
con.execute('INSTALL httpfs'); \
con.execute('INSTALL aws'); \
con.execute('INSTALL postgres'); \
con.execute('INSTALL ducklake'); \
"

COPY superset/superset_config.py /app/pythonpath/superset_config.py
COPY superset/entrypoint.sh /app/ducklake-entrypoint.sh
RUN chmod +x /app/ducklake-entrypoint.sh

ENV SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config.py

USER superset

EXPOSE 8088

ENTRYPOINT ["/app/ducklake-entrypoint.sh"]
