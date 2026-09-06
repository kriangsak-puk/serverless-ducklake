# Build context is the repo root (see scripts/build_and_push_image.sh).
FROM ducklake-base:latest

COPY lambdas/transform/handler.py ${LAMBDA_TASK_ROOT}/handler.py
COPY lambdas/transform/transform_runner.py ${LAMBDA_TASK_ROOT}/transform_runner.py
COPY sql/ ${LAMBDA_TASK_ROOT}/sql/

CMD ["handler.lambda_handler"]
