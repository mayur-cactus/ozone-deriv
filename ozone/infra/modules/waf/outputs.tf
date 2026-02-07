output "cloudfront_web_acl_id" {
  description = "CloudFront WAF Web ACL ID"
  value       = var.enable_cloudfront_waf ? aws_wafv2_web_acl.cloudfront[0].id : null
}

output "cloudfront_web_acl_arn" {
  description = "CloudFront WAF Web ACL ARN"
  value       = var.enable_cloudfront_waf ? aws_wafv2_web_acl.cloudfront[0].arn : null
}

output "regional_web_acl_id" {
  description = "Regional WAF Web ACL ID"
  value       = aws_wafv2_web_acl.regional.id
}

output "regional_web_acl_arn" {
  description = "Regional WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.regional.arn
}

output "waf_log_group_name" {
  description = "CloudWatch Log Group name for WAF logs"
  value       = aws_cloudwatch_log_group.waf_logs.name
}
