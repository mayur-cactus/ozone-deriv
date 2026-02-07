output "guardrail_id" {
  description = "Bedrock Guardrail ID"
  value       = aws_bedrock_guardrail.main.guardrail_id
}

output "guardrail_arn" {
  description = "Bedrock Guardrail ARN"
  value       = aws_bedrock_guardrail.main.guardrail_arn
}

output "guardrail_version" {
  description = "Bedrock Guardrail version"
  value       = aws_bedrock_guardrail_version.main.version
}

output "secrets_manager_arn" {
  description = "Secrets Manager ARN for Bedrock config"
  value       = aws_secretsmanager_secret.bedrock_config.arn
}
