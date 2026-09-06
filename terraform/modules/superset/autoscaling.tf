# Scale-to-zero outside business hours. Superset keeps no state in the container (all
# metadata lives in RDS), so stopping/starting it freely is safe. The ALB itself is NOT
# scaled — it's a fixed hourly cost regardless of desired_count (see docs/architecture.md).

resource "aws_appautoscaling_target" "superset" {
  max_capacity       = 1
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.superset.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_scheduled_action" "scale_up" {
  name               = "${var.name_prefix}-superset-scale-up"
  service_namespace  = aws_appautoscaling_target.superset.service_namespace
  resource_id        = aws_appautoscaling_target.superset.resource_id
  scalable_dimension = aws_appautoscaling_target.superset.scalable_dimension
  schedule           = var.scale_up_cron

  scalable_target_action {
    min_capacity = 1
    max_capacity = 1
  }
}

resource "aws_appautoscaling_scheduled_action" "scale_down" {
  name               = "${var.name_prefix}-superset-scale-down"
  service_namespace  = aws_appautoscaling_target.superset.service_namespace
  resource_id        = aws_appautoscaling_target.superset.resource_id
  scalable_dimension = aws_appautoscaling_target.superset.scalable_dimension
  schedule           = var.scale_down_cron

  scalable_target_action {
    min_capacity = 0
    max_capacity = 0
  }
}
