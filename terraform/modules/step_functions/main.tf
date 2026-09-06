# STANDARD, not EXPRESS: Express workflows cap execution at 5 minutes, and Transform is
# speced for up to 15. See docs/architecture.md for the full reasoning — this is a
# correctness fix, not a cost preference (at this run volume, Standard's cost is
# negligible either way).

data "aws_iam_policy_document" "assume_sfn" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn" {
  name               = "${var.name_prefix}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.assume_sfn.json
}

resource "aws_iam_role_policy" "sfn_invoke_lambda" {
  name = "${var.name_prefix}-sfn-invoke-lambda"
  role = aws_iam_role.sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = [var.ingest_function_arn, var.transform_function_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "sfn_logging" {
  name = "${var.name_prefix}-sfn-logging"
  role = aws_iam_role.sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "sfn" {
  name              = "/aws/states/${var.name_prefix}-pipeline"
  retention_in_days = 14
}

resource "aws_sfn_state_machine" "pipeline" {
  name     = "${var.name_prefix}-pipeline"
  type     = "STANDARD"
  role_arn = aws_iam_role.sfn.arn

  definition = templatefile("${path.module}/definition.asl.json.tpl", {
    ingest_function_arn    = var.ingest_function_arn
    transform_function_arn = var.transform_function_arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
}
