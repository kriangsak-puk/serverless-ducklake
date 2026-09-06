output "alb_dns_name" {
  value = aws_lb.superset.dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  value = aws_ecs_service.superset.name
}

output "admin_password" {
  value     = random_password.superset_admin_password.result
  sensitive = true
}
