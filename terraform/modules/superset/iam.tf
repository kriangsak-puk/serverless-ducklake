data "aws_iam_policy_document" "assume_ecs_tasks" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Pulls the image (via ECR) and ships logs — standard execution role.
resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-superset-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# What the running Superset container itself is allowed to do: read curated Parquet.
# RDS access is via SG + username/password, not IAM, so no RDS permission needed here.
resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-superset-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
}

data "aws_iam_policy_document" "task_s3" {
  statement {
    sid       = "ListCurated"
    actions   = ["s3:ListBucket"]
    resources = [var.curated_bucket_arn]
  }
  statement {
    sid       = "ReadCurated"
    actions   = ["s3:GetObject"]
    resources = ["${var.curated_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "task_s3" {
  name   = "${var.name_prefix}-superset-task-s3"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_s3.json
}

# Required for `aws ecs execute-command` (ECS Exec) — see enable_execute_command in main.tf.
data "aws_iam_policy_document" "task_exec_command" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_exec_command" {
  name   = "${var.name_prefix}-superset-task-exec-command"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_exec_command.json
}
