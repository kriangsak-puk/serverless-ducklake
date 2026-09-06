resource "aws_cloudwatch_log_group" "function" {
  for_each          = var.functions
  name              = "/aws/lambda/${var.name_prefix}-${each.key}"
  retention_in_days = 14
}

resource "aws_lambda_function" "this" {
  for_each = var.functions

  function_name = "${var.name_prefix}-${each.key}"
  role          = aws_iam_role.function[each.key].arn

  package_type = "Image"
  image_uri    = var.image_uris[each.key]

  # Graviton (arm64) — cheaper than x86_64 and what scripts/build_and_push_image.sh builds
  # for by default. Must match the image's actual architecture or the function fails at
  # invoke time with an exec format error.
  architectures = ["arm64"]

  memory_size = each.value.memory_mb
  timeout     = each.value.timeout_s

  ephemeral_storage {
    size = each.value.ephemeral_storage_mb
  }

  dynamic "vpc_config" {
    for_each = each.value.needs_vpc ? [1] : []
    content {
      subnet_ids         = var.private_subnet_ids
      security_group_ids = [var.lambda_sg_id]
    }
  }

  environment {
    variables = {
      RAW_BUCKET       = var.raw_bucket_name
      CURATED_BUCKET   = var.curated_bucket_name
      DB_HOST          = var.db_host
      DB_PORT          = tostring(var.db_port)
      DB_NAME          = var.db_name
      DB_USER          = var.db_username
      DB_PASSWORD      = var.db_password
      SUPERSET_DB_NAME = var.superset_db_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.function]
}
