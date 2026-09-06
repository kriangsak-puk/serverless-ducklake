module "networking" {
  source = "./modules/networking"

  name_prefix                    = var.name_prefix
  vpc_cidr                       = var.vpc_cidr
  public_subnet_cidrs            = var.public_subnet_cidrs
  private_subnet_cidrs           = var.private_subnet_cidrs
  availability_zones             = var.availability_zones
  enable_ecr_interface_endpoints = var.enable_ecr_interface_endpoints
  enable_secretsmanager_endpoint = var.enable_secretsmanager_endpoint
}

module "storage" {
  source = "./modules/storage"

  name_prefix                           = var.name_prefix
  raw_zone_ia_transition_days           = var.raw_zone_ia_transition_days
  raw_zone_glacier_transition_days      = var.raw_zone_glacier_transition_days
  raw_zone_deep_archive_transition_days = var.raw_zone_deep_archive_transition_days
}

module "catalog_db" {
  source = "./modules/catalog_db"

  name_prefix          = var.name_prefix
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  rds_sg_id            = module.networking.rds_sg_id
  instance_class       = var.db_instance_class
  engine_version       = var.db_engine_version
  allocated_storage_gb = var.db_allocated_storage_gb
  db_name              = var.db_name
  db_username          = var.db_username
  superset_db_name     = var.superset_db_name
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix = var.name_prefix
  repo_names  = concat(keys(var.lambda_functions), ["superset"])
}

module "lambda_functions" {
  source = "./modules/lambda_functions"

  name_prefix         = var.name_prefix
  functions           = var.lambda_functions
  image_uris          = { for name, url in module.ecr.repository_urls : name => "${url}:${var.image_tag}" }
  private_subnet_ids  = module.networking.private_subnet_ids
  lambda_sg_id        = module.networking.lambda_sg_id
  raw_bucket_arn      = module.storage.raw_bucket_arn
  curated_bucket_arn  = module.storage.curated_bucket_arn
  raw_bucket_name     = module.storage.raw_bucket_name
  curated_bucket_name = module.storage.curated_bucket_name
  db_host             = module.catalog_db.db_host
  db_port             = module.catalog_db.db_port
  db_name             = module.catalog_db.db_name
  db_username         = module.catalog_db.db_username
  db_password         = module.catalog_db.db_password
  superset_db_name    = module.catalog_db.superset_db_name
}

module "step_functions" {
  source = "./modules/step_functions"

  name_prefix            = var.name_prefix
  ingest_function_arn    = module.lambda_functions.function_arns["ingest"]
  transform_function_arn = module.lambda_functions.function_arns["transform"]
}

module "eventbridge" {
  source = "./modules/eventbridge"

  name_prefix            = var.name_prefix
  state_machine_arn      = module.step_functions.state_machine_arn
  maintain_function_arn  = module.lambda_functions.function_arns["maintain"]
  maintain_function_name = module.lambda_functions.function_names["maintain"]
  pipeline_schedule_cron = var.pipeline_schedule_cron
  maintain_schedule_cron = var.maintain_schedule_cron
}

module "api_gateway" {
  source = "./modules/api_gateway"

  name_prefix               = var.name_prefix
  query_function_arn        = module.lambda_functions.function_arns["query"]
  query_function_name       = module.lambda_functions.function_names["query"]
  query_function_invoke_arn = module.lambda_functions.invoke_arns["query"]
}

module "superset" {
  source = "./modules/superset"

  name_prefix         = var.name_prefix
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  alb_sg_id           = module.networking.alb_sg_id
  fargate_sg_id       = module.networking.fargate_sg_id
  image               = var.superset_image != "" ? var.superset_image : "${module.ecr.repository_urls["superset"]}:${var.image_tag}"
  cpu                 = var.superset_cpu
  memory_mb           = var.superset_memory_mb
  curated_bucket_arn  = module.storage.curated_bucket_arn
  curated_bucket_name = module.storage.curated_bucket_name
  db_host             = module.catalog_db.db_host
  db_port             = module.catalog_db.db_port
  superset_db_name    = module.catalog_db.superset_db_name
  ducklake_db_name    = module.catalog_db.db_name
  db_username         = module.catalog_db.db_username
  db_password         = module.catalog_db.db_password
  scale_up_cron       = var.superset_scale_up_cron
  scale_down_cron     = var.superset_scale_down_cron
}
