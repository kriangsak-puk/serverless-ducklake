variable "name_prefix" {
  type = string
}

variable "query_function_arn" {
  type = string
}

variable "query_function_name" {
  type = string
}

variable "query_function_invoke_arn" {
  type = string
}

variable "throttle_burst_limit" {
  type    = number
  default = 10
}

variable "throttle_rate_limit" {
  type    = number
  default = 5
}
