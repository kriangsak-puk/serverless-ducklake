variable "name_prefix" {
  type = string
}

variable "functions" {
  description = "Per-function config, keyed by function name (ingest/transform/maintain/query)."
  type = map(object({
    memory_mb            = number
    timeout_s            = number
    ephemeral_storage_mb = number
    needs_vpc            = bool
  }))
}

variable "image_uris" {
  description = "Map of function name -> full ECR image URI (with tag) to deploy."
  type        = map(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "lambda_sg_id" {
  type = string
}

variable "raw_bucket_arn" {
  type = string
}

variable "curated_bucket_arn" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "raw_bucket_name" {
  type = string
}

variable "curated_bucket_name" {
  type = string
}

variable "superset_db_name" {
  description = "Passed to Maintain so its init_catalog action can create this database if missing."
  type        = string
}
