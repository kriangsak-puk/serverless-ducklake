variable "name_prefix" {
  type = string
}

variable "repo_names" {
  description = "Names to create one ECR repo each for (Lambda functions + the Superset image)."
  type        = list(string)
  default     = ["ingest", "transform", "maintain", "query", "superset"]
}

variable "keep_last_n_images" {
  type    = number
  default = 10
}
