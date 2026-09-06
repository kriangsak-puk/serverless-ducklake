locals {
  # Which buckets each function needs, and at what access level. Kept explicit rather than
  # granting all functions access to both buckets (least privilege).
  s3_access = {
    ingest    = { buckets = [var.raw_bucket_arn], write = true }
    transform = { buckets = [var.raw_bucket_arn, var.curated_bucket_arn], write = true }
    maintain  = { buckets = [var.curated_bucket_arn], write = true }
    query     = { buckets = [var.curated_bucket_arn], write = false }
  }
}

data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "function" {
  for_each           = var.functions
  name               = "${var.name_prefix}-${each.key}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  for_each   = var.functions
  role       = aws_iam_role.function[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Only VPC-attached functions need ENI management permissions.
resource "aws_iam_role_policy_attachment" "vpc_access" {
  for_each   = { for name, cfg in var.functions : name => cfg if cfg.needs_vpc }
  role       = aws_iam_role.function[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "s3_access" {
  for_each = local.s3_access

  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = each.value.buckets
  }

  statement {
    sid       = "ReadObjects"
    actions   = ["s3:GetObject"]
    resources = [for b in each.value.buckets : "${b}/*"]
  }

  dynamic "statement" {
    for_each = each.value.write ? [1] : []
    content {
      sid       = "WriteObjects"
      actions   = ["s3:PutObject", "s3:DeleteObject"]
      resources = [for b in each.value.buckets : "${b}/*"]
    }
  }
}

resource "aws_iam_role_policy" "s3_access" {
  for_each = local.s3_access
  name     = "${var.name_prefix}-${each.key}-s3"
  role     = aws_iam_role.function[each.key].id
  policy   = data.aws_iam_policy_document.s3_access[each.key].json
}
