variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "enable_ecr_interface_endpoints" {
  type    = bool
  default = false
}

variable "enable_secretsmanager_endpoint" {
  type    = bool
  default = false
}
