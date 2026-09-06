output "db_host" {
  value = aws_db_instance.catalog.address
}

output "db_port" {
  value = aws_db_instance.catalog.port
}

output "db_name" {
  value = aws_db_instance.catalog.db_name
}

output "db_username" {
  value = aws_db_instance.catalog.username
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}

output "superset_db_name" {
  value = var.superset_db_name
}
