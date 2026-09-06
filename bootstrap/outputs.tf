output "state_bucket_name" {
  value       = aws_s3_bucket.tf_state.id
  description = "Paste into terraform/backend.tf as the `bucket` value."
}

output "lock_table_name" {
  value       = aws_dynamodb_table.tf_lock.name
  description = "Paste into terraform/backend.tf as the `dynamodb_table` value."
}

output "region" {
  value = var.region
}
