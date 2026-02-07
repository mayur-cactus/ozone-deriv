output "kinesis_stream_arn" {
  description = "Kinesis Firehose delivery stream ARN"
  value       = aws_kinesis_firehose_delivery_stream.logs.arn
}

output "kinesis_stream_name" {
  description = "Kinesis Firehose delivery stream name"
  value       = aws_kinesis_firehose_delivery_stream.logs.name
}

output "log_bucket_name" {
  description = "S3 bucket name for logs"
  value       = aws_s3_bucket.logs.id
}

output "cloudfront_log_bucket" {
  description = "S3 bucket name for CloudFront logs"
  value       = aws_s3_bucket.cloudfront_logs.id
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "opensearch_endpoint" {
  description = "OpenSearch endpoint"
  value       = null # Implement when OpenSearch module is added
}
