variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to all resource names (e.g. ducklake-raw, ducklake-transform)."
  type        = string
  default     = "ducklake"
}

# ---- Networking ----

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "Must have exactly 2 entries, matching the subnet CIDR lists above."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_ecr_interface_endpoints" {
  description = "Off by default (see docs/architecture.md) — Lambda image pulls don't need these. Flip on only if empirically required, at ~$7.30/mo per endpoint per AZ."
  type        = bool
  default     = false
}

variable "enable_secretsmanager_endpoint" {
  description = "Off by default — v1 uses plain Lambda env vars for DB credentials, not Secrets Manager."
  type        = bool
  default     = false
}

# ---- Storage ----

variable "raw_zone_ia_transition_days" {
  type    = number
  default = 30
}

variable "raw_zone_glacier_transition_days" {
  type    = number
  default = 90
}

variable "raw_zone_deep_archive_transition_days" {
  type    = number
  default = 180
}

# ---- Catalog DB ----

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "RDS Postgres major version. 17 verified working against the ducklake postgres extension in local testing; 18 is also available on RDS if you want the newest major version."
  type        = string
  default     = "17"
}

variable "db_allocated_storage_gb" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "ducklake_catalog"
}

variable "db_username" {
  type    = string
  default = "ducklake_app"
}

variable "superset_db_name" {
  description = "Separate logical database on the same RDS instance for Superset's own metastore."
  type        = string
  default     = "superset_meta"
}

# ---- ECR / Lambda images ----

variable "lambda_functions" {
  description = "Per-function config: memory (MB), timeout (s), ephemeral storage (MB), whether it needs VPC+RDS access."
  type = map(object({
    memory_mb            = number
    timeout_s            = number
    ephemeral_storage_mb = number
    needs_vpc            = bool
  }))
  default = {
    ingest = {
      memory_mb            = 512
      timeout_s            = 300
      ephemeral_storage_mb = 512
      needs_vpc            = false
    }
    transform = {
      memory_mb            = 3008
      timeout_s            = 900
      ephemeral_storage_mb = 10240
      needs_vpc            = true
    }
    maintain = {
      memory_mb            = 2048
      timeout_s            = 900
      ephemeral_storage_mb = 4096
      needs_vpc            = true
    }
    query = {
      memory_mb            = 1024
      timeout_s            = 60
      ephemeral_storage_mb = 512
      needs_vpc            = true
    }
  }
}

variable "image_tag" {
  description = "Tag to deploy for all Lambda images (git sha or 'latest'). Set by scripts/build_and_push_image.sh output."
  type        = string
  default     = "latest"
}

# ---- Step Functions / EventBridge ----

variable "pipeline_schedule_cron" {
  description = "EventBridge cron for the Ingest->Transform pipeline (UTC)."
  type        = string
  default     = "cron(0 6 * * ? *)" # 06:00 UTC daily
}

variable "maintain_schedule_cron" {
  description = "EventBridge cron for the Maintain (compact/expire) Lambda (UTC)."
  type        = string
  default     = "cron(30 6 * * ? *)" # 06:30 UTC daily, after the pipeline
}

# ---- Superset ----

variable "superset_image" {
  description = "Container image for Superset (ECR URL). Set after building/pushing it."
  type        = string
  default     = ""
}

variable "superset_cpu" {
  type    = number
  default = 512 # 0.5 vCPU
}

variable "superset_memory_mb" {
  type    = number
  default = 1024
}

variable "superset_scale_up_cron" {
  description = "Application Auto Scaling cron to scale Superset to desired_count=1 (business hours start, UTC)."
  type        = string
  default     = "cron(0 13 ? * MON-FRI *)" # 08:00 US Eastern ~ 13:00 UTC
}

variable "superset_scale_down_cron" {
  description = "Application Auto Scaling cron to scale Superset to desired_count=0 (business hours end, UTC)."
  type        = string
  default     = "cron(0 23 ? * MON-FRI *)" # 18:00 US Eastern ~ 23:00 UTC
}
