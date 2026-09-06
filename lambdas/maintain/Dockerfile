# Build context is the repo root (see scripts/build_and_push_image.sh).
FROM ducklake-base:latest

COPY lambdas/maintain/handler.py ${LAMBDA_TASK_ROOT}/handler.py
COPY lambdas/maintain/init_catalog.py ${LAMBDA_TASK_ROOT}/init_catalog.py
COPY lambdas/maintain/compaction.py ${LAMBDA_TASK_ROOT}/compaction.py
COPY sql/ ${LAMBDA_TASK_ROOT}/sql/

CMD ["handler.lambda_handler"]
