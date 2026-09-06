# Fill these in from `terraform output` in ../bootstrap after running it once.
# Terraform does not allow variables here, so these are literal values.
terraform {
  backend "s3" {
    bucket         = "ducklake-tf-state-095833340753"
    key            = "ducklake/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ducklake-tf-lock"
    encrypt        = true
  }
}
