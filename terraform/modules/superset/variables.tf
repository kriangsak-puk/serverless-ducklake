variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "fargate_sg_id" {
  type = string
}

variable "image" {
  description = "Superset container image URI (ECR). Empty string disables this module's compute (see main.tf count guard)."
  type        = string
}

variable "cpu" {
  type = number
}

variable "memory_mb" {
  type = number
}

variable "curated_bucket_arn" {
  type = string
}

variable "curated_bucket_name" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "superset_db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "ducklake_db_name" {
  description = "The DuckLake catalog database name, so Superset can ATTACH it directly."
  type        = string
}

variable "scale_up_cron" {
  type = string
}

variable "scale_down_cron" {
  type = string
}
