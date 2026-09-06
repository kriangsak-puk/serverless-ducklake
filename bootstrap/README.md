# Bootstrap

Creates the S3 bucket + DynamoDB table that `terraform/` uses as its remote state backend.
Run this **once**, before anything under `terraform/`. It uses local state itself (there's
nothing to bootstrap it with).

```bash
cd bootstrap
terraform init
terraform apply

terraform output state_bucket_name
terraform output lock_table_name
```

Copy those two values into `../terraform/backend.tf`, then proceed with
`cd ../terraform && terraform init`.

Do not `terraform destroy` this once real state depends on it — the S3 bucket has
`prevent_destroy` set for that reason.
