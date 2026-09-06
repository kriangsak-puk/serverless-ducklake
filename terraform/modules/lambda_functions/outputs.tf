output "function_arns" {
  value = { for name, fn in aws_lambda_function.this : name => fn.arn }
}

output "function_names" {
  value = { for name, fn in aws_lambda_function.this : name => fn.function_name }
}

output "invoke_arns" {
  value = { for name, fn in aws_lambda_function.this : name => fn.invoke_arn }
}
