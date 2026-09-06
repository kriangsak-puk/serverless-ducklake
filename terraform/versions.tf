terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # verified no breaking changes affect this repo's resources (v5->v6 upgrade guide)
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
