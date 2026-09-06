variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "rds_sg_id" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "engine_version" {
  type = string
}

variable "allocated_storage_gb" {
  type = number
}

variable "db_name" {
  description = "DuckLake catalog database name."
  type        = string
}

variable "db_username" {
  type = string
}

variable "superset_db_name" {
  description = "Second database on the same instance for Superset's own metastore."
  type        = string
}
