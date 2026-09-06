{
  "Comment": "Ingest -> Transform pipeline",
  "StartAt": "Ingest",
  "States": {
    "Ingest": {
      "Type": "Task",
      "Resource": "${ingest_function_arn}",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed"],
          "IntervalSeconds": 30,
          "MaxAttempts": 2,
          "BackoffRate": 2.0
        }
      ],
      "Next": "Transform"
    },
    "Transform": {
      "Type": "Task",
      "Resource": "${transform_function_arn}",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed"],
          "IntervalSeconds": 30,
          "MaxAttempts": 2,
          "BackoffRate": 2.0
        }
      ],
      "End": true
    }
  }
}
