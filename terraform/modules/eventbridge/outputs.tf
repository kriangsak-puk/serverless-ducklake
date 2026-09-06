output "pipeline_schedule_rule_arn" {
  value = aws_cloudwatch_event_rule.pipeline_schedule.arn
}

output "maintain_schedule_rule_arn" {
  value = aws_cloudwatch_event_rule.maintain_schedule.arn
}
