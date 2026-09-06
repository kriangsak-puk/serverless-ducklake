output "vpc_id" {
  value = module.networking.vpc_id
}

output "raw_bucket_name" {
  value = module.storage.raw_bucket_name
}

output "curated_bucket_name" {
  value = module.storage.curated_bucket_name
}

output "db_host" {
  value = module.catalog_db.db_host
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "lambda_function_names" {
  value = module.lambda_functions.function_names
}

output "state_machine_arn" {
  value = module.step_functions.state_machine_arn
}

output "api_gateway_url" {
  value = module.api_gateway.invoke_url
}

output "superset_alb_dns_name" {
  value = module.superset.alb_dns_name
}

output "superset_admin_password" {
  value     = module.superset.admin_password
  sensitive = true
}
