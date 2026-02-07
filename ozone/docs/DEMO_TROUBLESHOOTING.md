# Demo Troubleshooting Guide

## Quick Diagnostics

### Check Demo Status
```bash
# Verify infrastructure is deployed
cd infra && terraform output

# Check Lambda function exists
make logs

# Test API health
make test-health

# Verify frontend config
cat src/frontend/config.json
```

## Common Issues

### 1. "Could not get API endpoint from Terraform"

**Symptom**: `deploy-demo.sh` fails with error
```
Error: Could not get API endpoint from Terraform output.
```

**Cause**: Infrastructure not deployed yet

**Solution**:
```bash
# Deploy infrastructure first
make deploy ENV=dev

# Then deploy demo
make demo
```

### 2. "CORS Error" in Browser Console

**Symptom**: Browser shows:
```
Access to fetch has been blocked by CORS policy
```

**Cause**: API Gateway CORS misconfiguration

**Solution**:
```bash
# Check CORS settings
cd infra
terraform state show module.api_gateway.aws_apigatewayv2_api.main

# Redeploy API Gateway
terraform apply -target=module.api_gateway
```

**Verify CORS in** `infra/modules/api-gateway/main.tf`:
```terraform
cors_configuration {
  allow_origins = ["*"]  # Or specific domain
  allow_methods = ["POST", "GET", "OPTIONS"]
  allow_headers = ["Content-Type", "Authorization", "X-Request-Id"]
}
```

### 3. "404 Not Found" on /chat or /chat-direct

**Symptom**: API returns 404

**Cause**: Routes not deployed

**Solution**:
```bash
# Check routes exist
cd infra
terraform state list | grep route

# Should see:
# module.api_gateway.aws_apigatewayv2_route.chat
# module.api_gateway.aws_apigatewayv2_route.chat_direct
# module.api_gateway.aws_apigatewayv2_route.health

# If missing, redeploy:
terraform apply
```

### 4. "Connection Refused" on localhost:8080

**Symptom**: Can't connect to local server

**Cause**: Server not running or wrong port

**Solution**:
```bash
# Check if port is in use
lsof -i :8080

# Kill existing process if needed
kill -9 <PID>

# Restart server
cd src/frontend
python3 -m http.server 8080

# Or try different port
python3 -m http.server 3000
```

### 5. Lambda Returns 500 Internal Error

**Symptom**: All requests fail with 500

**Cause**: Multiple possible issues

**Solution**:
```bash
# Check Lambda logs
make logs

# Common issues:
# 1. Bedrock permissions missing
# 2. Guardrail ID not set
# 3. Python dependencies missing

# Check environment variables
aws lambda get-function-configuration \
  --function-name $(cd infra && terraform output -raw lambda_function_name) \
  | jq '.Environment.Variables'

# Should see:
# - BEDROCK_MODEL_ID
# - GUARDRAIL_ID
# - RISK_THRESHOLD
```

### 6. "Request Timeout" Errors

**Symptom**: Requests take forever, then timeout

**Cause**: Lambda cold start or Bedrock throttling

**Solution**:
```bash
# Check Lambda timeout setting (should be 30s+)
aws lambda get-function-configuration \
  --function-name $(cd infra && terraform output -raw lambda_function_name) \
  | jq '.Timeout'

# If too low, update in infra/modules/lambda/main.tf
# timeout = 30

# Warm up Lambda
make test-health
```

### 7. Config.json Not Found

**Symptom**: Frontend shows "API endpoint not configured"

**Cause**: Missing config.json file

**Solution**:
```bash
# Auto-generate config
./scripts/deploy-demo.sh

# Or create manually
cd src/frontend
echo '{
  "apiEndpoint": "YOUR_API_ENDPOINT_HERE",
  "version": "1.0.0"
}' > config.json

# Get endpoint
cd ../../infra
terraform output -raw api_endpoint
```

### 8. "Unauthorized" or 403 Forbidden (Wrong Type)

**Symptom**: API returns 403 but not from WAF

**Cause**: API Gateway authorization or AWS WAF blocking

**Solution**:
```bash
# Check if AWS WAF is blocking
aws wafv2 list-web-acls --scope REGIONAL --region us-east-1

# Check IP is not blocked
# Test from different network

# Temporarily disable AWS WAF (testing only)
# In infra/modules/waf/main.tf, comment out rules
```

### 9. WAF Toggle Not Working

**Symptom**: Toggle changes but behavior stays same

**Cause**: JavaScript error or wrong endpoint

**Solution**:
```bash
# Check browser console for errors
# Should see API calls to /chat or /chat-direct

# Verify endpoints in app.js:
# const endpoint = wafEnabled ? '/chat' : '/chat-direct';

# Test both endpoints manually:
curl -X POST "$API_ENDPOINT/chat" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test","user_id":"test"}'

curl -X POST "$API_ENDPOINT/chat-direct" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test","user_id":"test"}'
```

### 10. No Response from Lambda

**Symptom**: Request hangs, no response

**Cause**: Lambda stuck or not invoked

**Solution**:
```bash
# Check CloudWatch logs in real-time
make logs

# Send test request
curl -v -X POST "$API_ENDPOINT/chat" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test","user_id":"test"}'

# Check Lambda metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=$(cd infra && terraform output -raw lambda_function_name) \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum
```

## Verification Checklist

### Before Demo
- [ ] Infrastructure deployed: `terraform output`
- [ ] Lambda deployed: `make deploy-lambda`
- [ ] API endpoint working: `make test-health`
- [ ] Config.json exists: `cat src/frontend/config.json`
- [ ] Local server running: `http://localhost:8080`
- [ ] Toggle switches between endpoints
- [ ] Attack scenarios populate text box
- [ ] Metrics update correctly

### During Demo
- [ ] Test legitimate query first (builds confidence)
- [ ] Show attack blocked with WAF ON
- [ ] Toggle WAF OFF, retry attack
- [ ] Point out metrics dashboard
- [ ] Explain risk scores
- [ ] Clear chat between major demos

### After Demo
- [ ] Check logs for errors: `make logs`
- [ ] Review metrics: CloudWatch dashboard
- [ ] Note any issues for fixing
- [ ] Export chat for documentation

## Debug Mode

### Enable Verbose Logging
```javascript
// In app.js, add at top:
const DEBUG = true;

// Add logging:
if (DEBUG) console.log('Sending request:', requestBody);
if (DEBUG) console.log('Response:', response);
```

### Check Network Tab
1. Open browser DevTools (F12)
2. Go to Network tab
3. Send request
4. Click on request to see:
   - Request headers
   - Request payload
   - Response headers
   - Response body
   - Status code

### Lambda Debug
```python
# In main.py, add more logging:
logger.setLevel('DEBUG')
logger.debug(f"Received event: {json.dumps(event)}")
logger.debug(f"WAF enabled: {waf_enabled}")
logger.debug(f"Risk score: {risk_score}")
```

## Performance Issues

### Slow Response Times

**Expected**: 500-2000ms
**Acceptable**: < 3000ms
**Problem**: > 5000ms

**Solutions**:
```bash
# 1. Check Lambda cold starts
# Warm up function first
for i in {1..5}; do make test-health; done

# 2. Check Bedrock throttling
aws servicequotas get-service-quota \
  --service-code bedrock \
  --quota-code L-68XXXXXX

# 3. Reduce Lambda timeout noise
# Use smaller model (Haiku instead of Sonnet)

# 4. Enable provisioned concurrency (costs more)
aws lambda put-provisioned-concurrency-config \
  --function-name FUNCTION_NAME \
  --provisioned-concurrent-executions 1
```

## Getting Help

### Collect Debug Info
```bash
# Run this and share output:
echo "=== System Info ==="
sw_vers  # macOS version
python3 --version
terraform version
aws --version

echo "=== Terraform State ==="
cd infra && terraform output

echo "=== Lambda Config ==="
aws lambda get-function-configuration \
  --function-name $(terraform output -raw lambda_function_name)

echo "=== Recent Logs ==="
make logs | head -50

echo "=== Frontend Config ==="
cat ../src/frontend/config.json
```

### Support Resources
- Check docs: `docs/troubleshooting.md`
- Lambda logs: `make logs`
- Test scenarios: `make test`
- Architecture: `docs/ARCHITECTURE.md`

## Emergency Reset

### Nuclear Option (Fresh Start)
```bash
# WARNING: Destroys everything!

# 1. Destroy infrastructure
make destroy ENV=dev

# 2. Clean build artifacts
make clean

# 3. Redeploy from scratch
make deploy ENV=dev
make deploy-lambda
make demo

# Takes ~15 minutes
```

### Quick Reset (Keep Infrastructure)
```bash
# Just redeploy Lambda
make deploy-lambda

# Restart local server
# Ctrl+C, then:
make demo-local
```

## Still Stuck?

1. **Read the error message carefully**
2. **Check CloudWatch logs**: `make logs`
3. **Verify all prerequisites**: AWS CLI, Terraform, Python
4. **Test incrementally**: Health → Chat → Demo
5. **Compare with working example**: Test scenarios
6. **Ask for help**: Share debug info above

---

**Remember**: Most issues are configuration or deployment order. Follow the steps in order:
1. Deploy infrastructure (`make deploy`)
2. Deploy Lambda (`make deploy-lambda`)
3. Deploy demo (`make demo`)
4. Test (`make test`)
