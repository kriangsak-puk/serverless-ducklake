# Build context is the repo root (see scripts/build_and_push_image.sh) so this can COPY
# both lambdas/shared/ (via the base image) and its own lambdas/ingest/ source.
FROM ducklake-base:latest

COPY lambdas/ingest/requirements.txt ${LAMBDA_TASK_ROOT}/requirements.txt
RUN uv pip install --system --no-cache -r ${LAMBDA_TASK_ROOT}/requirements.txt

COPY lambdas/ingest/handler.py ${LAMBDA_TASK_ROOT}/handler.py
COPY lambdas/ingest/sources/ ${LAMBDA_TASK_ROOT}/sources/

CMD ["handler.lambda_handler"]
