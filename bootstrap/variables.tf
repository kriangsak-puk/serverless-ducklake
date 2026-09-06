variable "region" {
  description = "AWS region to create the state bucket/lock table in. Must match terraform/backend.tf."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names. Must match terraform/variables.tf name_prefix."
  type        = string
  default     = "ducklake"
}
