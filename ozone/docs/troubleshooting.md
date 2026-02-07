# Troubleshooting Guide

## Common Issues and Solutions

### 1. Terraform Errors

#### Error: "Error acquiring the state lock"

**Solution:**
```bash
# List DynamoDB locks
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

#### Error: "No declaration found for var.X"

**Cause:** Variables not properly defined or terraform.tfvars not loaded

**Solution:**
```bash
# Ensure terraform.tfvars exists
cp infra/terraform.tfvars.example infra/terraform.tfvars

# Validate configuration
cd infra
terraform validate
```

#### Error: "Insufficient permissions"

**Solution:**
```bash
# Check current AWS identity
aws sts get-caller-identity

# Ensure IAM user/role has these managed policies:
# - AmazonVPCFullAccess
# - AWSLambda_FullAccess
# - CloudWatchFullAccess
# - AmazonBedrockFullAccess
# - CloudFrontFullAccess
# - IAMFullAccess (for role creation)
```

### 2. Bedrock Issues

#### Error: "Access Denied" when invoking Bedrock

**Cause:** Model access not enabled for your account

**Solution:**
1. Go to AWS Console > Bedrock > Model access
2. Request access to Claude models
3. Wait for approval (usually instant for most regions)
4. Update Lambda IAM policy with correct model ARN

```bash
# Verify available models
aws bedrock list-foundation-models --region us-east-1
```

#### Error: "Throttling" from Bedrock

**Solution:**
```bash
# Increase Lambda reserved concurrency
aws lambda put-function-concurrency \
  --function-name ai-waf-dev-ai-waf \
  --reserved-concurrent-executions 10

# Or request quota increase in Service Quotas
```

### 3. Lambda Issues

#### Lambda Times Out

**Symptoms:** 30-second timeout errors

**Solution:**
```hcl
# In terraform.tfvars
lambda_timeout     = 60  # Increase to 60 seconds
lambda_memory_size = 2048  # More memory = faster CPU
```

```bash
./scripts/deploy.sh dev apply
```

#### Import Error: "boto3 could not be resolved"

**Cause:** Missing dependencies in deployment package

**Solution:**
```bash
cd src/lambda/ai-waf-gateway

# Rebuild with dependencies
rm deployment.zip
./build.sh

# Redeploy
cd ../../..
./scripts/deploy-lambda.sh
```

#### VPC Lambda Can't Access Internet

**Symptoms:** Bedrock calls fail, timeouts

**Solution:**
1. Ensure NAT Gateway is enabled:
```hcl
# In terraform.tfvars
enable_nat_gateway = true
```

2. Check VPC endpoints are created:
```bash
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=<YOUR_VPC_ID>"
```

3. Verify security group allows outbound HTTPS:
```bash
# Check Lambda security group
aws ec2 describe-security-groups --group-ids <SG_ID>
```

### 4. API Gateway Issues

#### CORS Errors in Browser

**Solution:**
```hcl
# In terraform.tfvars
cors_allow_origins = ["https://your-frontend-domain.com"]
```

Or for development:
```hcl
cors_allow_origins = ["*"]
```

```bash
./scripts/deploy.sh dev apply
```

#### 429 Too Many Requests

**Cause:** Hitting throttle limits

**Solution:**
```hcl
# In terraform.tfvars
api_throttle_burst_limit = 1000
api_throttle_rate_limit  = 500
```

#### 502 Bad Gateway

**Symptoms:** Intermittent 502 errors

**Causes:**
1. Lambda timeout
2. Lambda cold start
3. Memory exhaustion

**Solutions:**
```bash
# Check Lambda errors
aws logs tail /aws/lambda/ai-waf-dev-ai-waf --follow --filter-pattern "ERROR"

# Increase provisioned concurrency (reduces cold starts)
aws lambda put-provisioned-concurrency-config \
  --function-name ai-waf-dev-ai-waf \
  --provisioned-concurrent-executions 2 \
  --qualifier $LATEST
```

### 5. WAF Issues

#### Legitimate Requests Blocked

**Symptoms:** 403 errors for valid requests

**Solution:**
1. Check WAF logs:
```bash
aws logs tail /aws/waf/ai-waf-dev --follow
```

2. Identify blocking rule
3. Adjust rule in `infra/modules/waf/main.tf`:

```hcl
# Change from "block" to "count" for testing
action {
  count {}  # Instead of block {}
}
```

4. Or add exception:
```hcl
rule {
  name = "WhitelistRule"
  priority = 0  # Runs first
  
  action {
    allow {}
  }
  
  statement {
    byte_match_statement {
      search_string = "your-safe-pattern"
      # ...
    }
  }
}
```

#### False Positives on Pattern Matching

**Solution:**
Edit `src/policies/security-policy.json`:

```json
{
  "forbidden_patterns": {
    "patterns": [
      {
        "pattern": "your-pattern",
        "severity": "medium",  // Lower from "high"
        "action": "monitor"    // Change from "block"
      }
    ]
  }
}
```

Redeploy Lambda:
```bash
./scripts/deploy-lambda.sh
```

### 6. CloudFront Issues

#### CloudFront Not Forwarding Requests

**Symptoms:** Requests don't reach API Gateway

**Solution:**
1. Check CloudFront distribution status:
```bash
aws cloudfront get-distribution --id <DISTRIBUTION_ID>
```

2. Ensure distribution is "Deployed" (not "In Progress")

3. Check cache behavior:
```hcl
# In modules/cloudfront/main.tf
default_cache_behavior {
  min_ttl     = 0
  default_ttl = 0  # Disable caching for testing
  max_ttl     = 0
}
```

#### SSL Certificate Errors

**Symptoms:** "Certificate doesn't match domain"

**Solution:**
1. Certificate must be in us-east-1 (CloudFront requirement)
2. Create ACM certificate:
```bash
aws acm request-certificate \
  --domain-name api.yourdomain.com \
  --validation-method DNS \
  --region us-east-1
```

3. Update terraform.tfvars:
```hcl
ssl_certificate_arn = "arn:aws:acm:us-east-1:..."
custom_domain       = "api.yourdomain.com"
```

### 7. Monitoring Issues

#### No Metrics in CloudWatch

**Symptoms:** Dashboard shows no data

**Solutions:**
1. Check metric namespace:
```bash
aws cloudwatch list-metrics --namespace AI-WAF
```

2. Verify Lambda has permissions:
```bash
# Check Lambda role policy includes:
{
  "Effect": "Allow",
  "Action": "cloudwatch:PutMetricData",
  "Resource": "*"
}
```

3. Check logs for metric publish errors:
```bash
aws logs tail /aws/lambda/ai-waf-dev-ai-waf --follow --filter-pattern "metric"
```

#### Kinesis Firehose Not Receiving Data

**Symptoms:** S3 bucket empty, no logs

**Solutions:**
1. Check Firehose delivery stream:
```bash
aws firehose describe-delivery-stream \
  --delivery-stream-name ai-waf-dev-logs
```

2. Verify Lambda has permission to write:
```bash
# Check IAM policy includes:
{
  "Effect": "Allow",
  "Action": ["kinesis:PutRecord", "kinesis:PutRecords"],
  "Resource": "arn:aws:firehose:*:*:deliverystream/*"
}
```

3. Test manually:
```bash
aws firehose put-record \
  --delivery-stream-name ai-waf-dev-logs \
  --record '{"Data":"test message\n"}'
```

### 8. Performance Issues

#### High Latency (> 3 seconds)

**Diagnosis:**
```bash
# Check Lambda duration metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=ai-waf-dev-ai-waf \
  --start-time 2026-02-07T00:00:00Z \
  --end-time 2026-02-07T23:59:59Z \
  --period 3600 \
  --statistics Average,Maximum
```

**Solutions:**
1. **Increase Lambda memory** (more vCPU):
```hcl
lambda_memory_size = 2048  # or 3008
```

2. **Use ARM64** (faster, cheaper):
```hcl
lambda_architecture = "arm64"
```

3. **Enable VPC endpoints** (reduce NAT latency):
```hcl
enable_vpc_endpoints = true
```

4. **Use faster Bedrock model**:
```hcl
bedrock_model_id = "anthropic.claude-3-haiku-20240307-v1:0"  # Fastest
```

5. **Optimize classifier prompt** (shorter = faster)

#### Cold Starts

**Solution:**
```bash
# Enable provisioned concurrency
aws lambda put-provisioned-concurrency-config \
  --function-name ai-waf-dev-ai-waf \
  --provisioned-concurrent-executions 2 \
  --qualifier $LATEST
```

Or use Lambda SnapStart (Java) or keep-warm strategies.

### 9. Cost Issues

#### Unexpected High Bills

**Check costs:**
```bash
# Install AWS Cost Explorer CLI
pip install awscli-plugin-cost-explorer

# Check costs by service
aws ce get-cost-and-usage \
  --time-period Start=2026-02-01,End=2026-02-07 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

**Common culprits:**
1. **Bedrock tokens** - Monitor input/output tokens
2. **NAT Gateway** - $0.045/hour + data transfer
3. **CloudFront** - Data transfer costs
4. **WAF** - Per-request charges
5. **CloudWatch Logs** - Ingestion and storage

**Optimizations:**
```hcl
# Reduce log retention
retention_in_days = 7  # Instead of 30

# Disable NAT if not needed
enable_nat_gateway = false

# Use S3 Gateway endpoint (free)
enable_vpc_endpoints = true

# Reduce Bedrock calls
# - Cache results
# - Use smaller models
# - Reduce max_tokens
```

### 10. Debugging Tips

#### Enable Debug Logging

```bash
# Update Lambda environment
aws lambda update-function-configuration \
  --function-name ai-waf-dev-ai-waf \
  --environment Variables="{LOG_LEVEL=DEBUG}"
```

#### Invoke Lambda Directly

```bash
# Create test event
cat > test-event.json <<EOF
{
  "body": "{\"prompt\": \"test\", \"user_id\": \"test\"}",
  "rawPath": "/chat"
}
EOF

# Invoke
aws lambda invoke \
  --function-name ai-waf-dev-ai-waf \
  --payload file://test-event.json \
  --cli-binary-format raw-in-base64-out \
  response.json

# Check response
cat response.json | jq '.'
```

#### Check Terraform State

```bash
cd infra

# Show current state
terraform show

# List resources
terraform state list

# Inspect specific resource
terraform state show module.lambda.aws_lambda_function.ai_waf
```

#### Enable X-Ray Tracing

Already enabled in Lambda module. View traces:
```bash
# AWS Console > X-Ray > Traces
# Or use AWS CLI
aws xray get-trace-summaries \
  --start-time 2026-02-07T00:00:00Z \
  --end-time 2026-02-07T23:59:59Z
```

## Getting Help

If you're still stuck:

1. **Check AWS Service Health Dashboard**
   - https://status.aws.amazon.com

2. **Review AWS CloudWatch Insights**
   ```
   fields @timestamp, @message
   | filter @message like /ERROR/
   | sort @timestamp desc
   | limit 20
   ```

3. **Contact AWS Support** (if you have a support plan)

4. **Check GitHub Issues** (if open-sourced)

5. **AWS Forums and Stack Overflow**
