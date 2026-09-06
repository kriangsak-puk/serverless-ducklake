# db.t4g.micro single-AZ Postgres, not Aurora Serverless v2 — avoids ASv2 resume latency
# hitting Query Lambda's p99 after the catalog DB has been idle. See docs/architecture.md.
#
# Note: this instance is created with a single initial database (the DuckLake catalog,
# var.db_name). The Superset metastore database (var.superset_db_name) is created
# idempotently by the Maintain Lambda's init_catalog action, not by Terraform — Terraform
# runs from outside the VPC and this instance is intentionally not publicly accessible, so
# it has no network path to run a second CREATE DATABASE itself.

resource "random_password" "db" {
  length  = 32
  special = false # keep it libpq/URL-safe; still high entropy at 32 chars alnum
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "${var.name_prefix}-db-subnet-group" }
}

resource "aws_db_instance" "catalog" {
  identifier     = "${var.name_prefix}-catalog"
  engine         = "postgres"
  engine_version = var.engine_version

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage_gb
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 7
  skip_final_snapshot     = true # v1 / learning project — revisit for a real production bar
  deletion_protection     = false

  tags = { Name = "${var.name_prefix}-catalog-db" }
}
