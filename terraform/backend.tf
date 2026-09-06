# Fill these in from `terraform output` in ../bootstrap after running it once.
# Terraform does not allow variables here, so these are literal values.
terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_bootstrap_state_bucket_name"
    key            = "ducklake/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE_WITH_bootstrap_lock_table_name"
    encrypt        = true
  }
}
