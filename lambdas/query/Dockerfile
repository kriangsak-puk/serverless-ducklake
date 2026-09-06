# Build context is the repo root (see scripts/build_and_push_image.sh).
FROM ducklake-base:latest

COPY lambdas/query/handler.py ${LAMBDA_TASK_ROOT}/handler.py
COPY lambdas/query/query_guard.py ${LAMBDA_TASK_ROOT}/query_guard.py

CMD ["handler.lambda_handler"]
