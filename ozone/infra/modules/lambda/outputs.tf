output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.ai_waf.arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.ai_waf.function_name
}

output "lambda_invoke_arn" {
  description = "Lambda invoke ARN"
  value       = aws_lambda_function.ai_waf.invoke_arn
}

output "lambda_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda.arn
}

output "lambda_security_group_id" {
  description = "Lambda security group ID"
  value       = aws_security_group.lambda.id
}
