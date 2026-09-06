# Two independent schedules: the Ingest->Transform pipeline (via Step Functions), and the
# Maintain (compact/expire) Lambda, invoked directly — no need to wrap housekeeping in its
# own state machine.

data "aws_iam_policy_document" "assume_events" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

# --- Pipeline schedule -> Step Functions ---

resource "aws_iam_role" "start_pipeline" {
  name               = "${var.name_prefix}-eventbridge-start-pipeline"
  assume_role_policy = data.aws_iam_policy_document.assume_events.json
}

resource "aws_iam_role_policy" "start_pipeline" {
  name = "${var.name_prefix}-start-pipeline"
  role = aws_iam_role.start_pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = var.state_machine_arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "pipeline_schedule" {
  name                = "${var.name_prefix}-pipeline-schedule"
  description         = "Daily trigger for the Ingest->Transform pipeline"
  schedule_expression = var.pipeline_schedule_cron
}

resource "aws_cloudwatch_event_target" "pipeline_schedule" {
  rule     = aws_cloudwatch_event_rule.pipeline_schedule.name
  arn      = var.state_machine_arn
  role_arn = aws_iam_role.start_pipeline.arn
}

# --- Maintain schedule -> Lambda direct invoke ---

resource "aws_cloudwatch_event_rule" "maintain_schedule" {
  name                = "${var.name_prefix}-maintain-schedule"
  description         = "Daily trigger for compaction/snapshot expiry"
  schedule_expression = var.maintain_schedule_cron
}

resource "aws_cloudwatch_event_target" "maintain_schedule" {
  rule  = aws_cloudwatch_event_rule.maintain_schedule.name
  arn   = var.maintain_function_arn
  input = jsonencode({ action = "compact" })
}

resource "aws_lambda_permission" "maintain_schedule" {
  statement_id  = "AllowEventBridgeInvokeMaintain"
  action        = "lambda:InvokeFunction"
  function_name = var.maintain_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.maintain_schedule.arn
}
