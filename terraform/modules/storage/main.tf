data "aws_caller_identity" "current" {}

# --- Raw zone: landing bucket for unprocessed source data, tiered to cold storage over time ---

resource "aws_s3_bucket" "raw" {
  bucket = "${var.name_prefix}-raw-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "tier-raw-data"
    status = "Enabled"

    filter {}

    transition {
      days          = var.raw_zone_ia_transition_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.raw_zone_glacier_transition_days
      storage_class = "GLACIER"
    }

    transition {
      days          = var.raw_zone_deep_archive_transition_days
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# --- Curated zone: live DuckLake Parquet table data. No lifecycle transitions — this is
#     hot/live data, not an archive. Versioning is deliberately OFF: DuckLake does its own
#     snapshot/versioning at the table level, and turning on S3 versioning here would just
#     double storage cost without adding real recovery — with the tradeoff that a bug in
#     the Maintain Lambda's compaction/expiry logic that deletes live Parquet files has
#     no S3-level undo. ---

resource "aws_s3_bucket" "curated" {
  bucket = "${var.name_prefix}-curated-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "curated" {
  bucket                  = aws_s3_bucket.curated.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "curated" {
  bucket = aws_s3_bucket.curated.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
