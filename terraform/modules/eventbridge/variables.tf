variable "name_prefix" {
  type = string
}

variable "state_machine_arn" {
  type = string
}

variable "maintain_function_arn" {
  type = string
}

variable "maintain_function_name" {
  type = string
}

variable "pipeline_schedule_cron" {
  type = string
}

variable "maintain_schedule_cron" {
  type = string
}
