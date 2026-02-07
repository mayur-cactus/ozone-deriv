variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name to monitor"
  type        = string
}

variable "api_gateway_id" {
  description = "API Gateway ID to monitor"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  type        = string
  default     = null
}

variable "enable_opensearch" {
  description = "Enable OpenSearch for log analytics"
  type        = bool
  default     = false
}

variable "opensearch_instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch instances"
  type        = number
  default     = 1
}

variable "alarm_email" {
  description = "Email for CloudWatch alarms"
  type        = string
  default     = ""
}

variable "enable_anomaly_detection" {
  description = "Enable anomaly detection"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "Logging level"
  type        = string
  default     = "INFO"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
