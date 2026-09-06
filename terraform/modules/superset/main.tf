# Superset's Fargate task runs in a PUBLIC subnet with a public IP, not the private
# subnets used by Transform/Maintain/Query. ECS Fargate pulls container images over the
# task's own ENI (Lambda does not — it uses the Lambda service's own infra), so a private
# subnet here would need ~3 paid interface VPC endpoints (ECR api/dkr + logs) to pull the
# image without a NAT Gateway — costing about as much as the NAT Gateway this whole design
# avoids. A public subnet + a security group that only allows inbound from the ALB gets
# free image-pull egress via the Internet Gateway while keeping RDS access over the VPC
# network. See docs/architecture.md.
#
# Apply this module LAST, after lambdas + everything else, and only once var.image points
# at a real pushed Superset image (see scripts/build_and_push_image.sh).

resource "random_password" "superset_secret_key" {
  length  = 42
  special = false
}

resource "random_password" "superset_admin_password" {
  length  = 20
  special = false
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-superset"
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }
}

resource "aws_cloudwatch_log_group" "superset" {
  name              = "/ecs/${var.name_prefix}-superset"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "superset" {
  family                   = "${var.name_prefix}-superset"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory_mb
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  # Graviton (arm64) — matches what scripts/build_and_push_image.sh builds for by default
  # and is cheaper than X86_64. Must match the pushed image's actual architecture.
  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "superset"
      image     = var.image
      essential = true
      portMappings = [
        { containerPort = 8088, protocol = "tcp" }
      ]
      environment = [
        { name = "SUPERSET_DB_HOST", value = var.db_host },
        { name = "SUPERSET_DB_PORT", value = tostring(var.db_port) },
        { name = "SUPERSET_DB_NAME", value = var.superset_db_name },
        { name = "SUPERSET_DB_USER", value = var.db_username },
        { name = "SUPERSET_DB_PASSWORD", value = var.db_password },
        { name = "SUPERSET_SECRET_KEY", value = random_password.superset_secret_key.result },
        { name = "SUPERSET_ADMIN_PASSWORD", value = random_password.superset_admin_password.result },
        { name = "DUCKLAKE_DB_HOST", value = var.db_host },
        { name = "DUCKLAKE_DB_PORT", value = tostring(var.db_port) },
        { name = "DUCKLAKE_DB_NAME", value = var.ducklake_db_name },
        { name = "DUCKLAKE_DB_USER", value = var.db_username },
        { name = "DUCKLAKE_DB_PASSWORD", value = var.db_password },
        { name = "CURATED_BUCKET", value = var.curated_bucket_name },
        { name = "AWS_REGION", value = data.aws_region.current.region },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.superset.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "superset"
        }
      }
    }
  ])
}

data "aws_region" "current" {}

resource "aws_ecs_service" "superset" {
  name            = "${var.name_prefix}-superset"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.superset.arn
  desired_count   = 1
  launch_type     = null # capacity provider strategy governs placement

  # Superset's first boot (db upgrade + fab create-admin + init, see entrypoint.sh) can
  # take ~60-90s before gunicorn is even listening. Without a grace period, ECS starts
  # counting ALB health-check failures from the moment the task is placed, decides the
  # task is unhealthy before it's finished booting, and launches a replacement — leaving
  # two tasks running against desired_count=1. 120s covers the observed boot time with
  # margin.
  health_check_grace_period_seconds = 120

  # Lets `aws ecs execute-command` open a shell in the running task — used by
  # scripts/db_tunnel.sh as a no-extra-infra way to reach the private RDS instance for ad
  # hoc debugging, instead of standing up a dedicated bastion host.
  enable_execute_command = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.fargate_sg_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.superset.arn
    container_name   = "superset"
    container_port   = 8088
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    # Application Auto Scaling scheduled actions (see autoscaling.tf) change desired_count
    # outside of Terraform on a daily cadence — ignore drift on it so `terraform apply`
    # doesn't fight the scheduler back to desired_count=1 outside business hours.
    ignore_changes = [desired_count]

    precondition {
      condition     = var.image != ""
      error_message = "var.image must point at a pushed Superset image before applying this module — see scripts/build_and_push_image.sh."
    }
  }
}
