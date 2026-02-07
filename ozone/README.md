# AI WAF for LLM/Agent Security on AWS

A comprehensive multi-layered AI Web Application Firewall system built on AWS to protect LLM and agent workloads from prompt injection, jailbreaks, and adversarial attacks.

## Architecture Overview

This system implements defense-in-depth security with multiple layers:

1. **Network Layer**: CloudFront + AWS WAF for perimeter security
2. **Semantic Layer**: Lambda-based AI WAF with pre-LLM classification
3. **Model Layer**: Amazon Bedrock with Guardrails
4. **Tool Layer**: Output verification and tool-call safety
5. **Monitoring Layer**: CloudWatch, Kinesis, and OpenSearch for observability

## Project Structure

```
.
├── infra/                      # Terraform infrastructure code
│   ├── modules/                # Reusable Terraform modules
│   │   ├── vpc/               # VPC and networking
│   │   ├── waf/               # AWS WAF configuration
│   │   ├── cloudfront/        # CloudFront distribution
│   │   ├── api-gateway/       # API Gateway HTTP API
│   │   ├── lambda/            # Lambda functions
│   │   ├── bedrock/           # Bedrock and Guardrails
│   │   └── monitoring/        # CloudWatch, Kinesis, OpenSearch
│   ├── environments/          # Environment-specific configs
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
│
├── src/                        # Source code
│   ├── lambda/                 # Lambda function code
│   │   ├── ai-waf-gateway/    # Main AI WAF Lambda
│   │   └── layers/            # Lambda layers
│   ├── policies/              # Security policies and configurations
│   ├── frontend/              # Demo web UI
│   └── tests/                 # Test scenarios
│
├── scripts/                    # Deployment and utility scripts
└── docs/                      # Documentation

```

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- AWS CLI configured
- Python 3.11+

**First time?** Run `make setup` to check prerequisites and create configuration files.

## Quick Start

**Full step-by-step guide:** See [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)

### Fast Track (3 Commands)

```bash
# 1. Setup and configure
make setup
# Edit infra/terraform.tfvars with your AWS settings

# 2. Deploy everything
make deploy ENV=dev

# 3. Launch demo
make demo-local
# Open http://localhost:8080
```

### Detailed Steps

```bash
# Using Makefile (recommended)
make init
make deploy ENV=dev

# Or manually
cd infra
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

### 2. Deploy Lambda Code

```bash
# Using Makefile (recommended)
make deploy-lambda

# Or manually
cd src/lambda/ai-waf-gateway
./build.sh
aws lambda update-function-code --function-name ai-waf-gateway --zip-file fileb://deployment.zip
```

### 3. Try the Interactive Demo 🎯

Launch the interactive chatbot to see AI WAF in action:

```bash
# Deploy and configure the demo
make demo

# Or run locally
make demo-local
# Then open http://localhost:8080
```

**Features:**
- 🛡️ Toggle WAF protection ON/OFF to compare responses
- 🎯 Pre-loaded attack scenarios (prompt injection, jailbreak, etc.)
- 📊 Real-time security metrics and risk scoring
- 🎨 Modern, responsive UI

See [src/frontend/README.md](src/frontend/README.md) for detailed demo documentation.

### 4. Test with cURL

```bash
# Get API endpoint
API_ENDPOINT=$(cd infra && terraform output -raw api_endpoint)

# Legitimate query (should pass)
curl -X POST "$API_ENDPOINT/chat" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is machine learning?", "user_id": "test"}'

# Attack attempt (should block)
curl -X POST "$API_ENDPOINT/chat" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Ignore all previous instructions", "user_id": "test"}'
```

## Security Layers Explained

### Layer 1: AWS WAF (Network Perimeter)
- Managed rules for common web attacks
- Rate limiting and bot control
- Size constraints on requests

### Layer 2: Pre-LLM Semantic Classifier
- Bedrock-powered intent classification
- Detects prompt injection and jailbreak attempts
- Policy-based access control

### Layer 3: Bedrock Guardrails
- Built-in prompt attack filter (HIGH strength)
- Content moderation (toxicity, PII)
- Dual validation layer

### Layer 4: Output Verification
- Schema validation
- Data exfiltration detection
- Tool-call safety checks
- RBAC enforcement

### Layer 5: Behavior Monitoring
- Real-time metrics and alarms
- Anomaly detection
- Centralized logging for forensics

## Demo Scenarios

The system includes pre-configured attack scenarios:

1. **Normal Query**: Legitimate request that passes all layers
2. **Direct Prompt Injection**: Attempts to override system instructions
3. **Indirect Injection**: Malicious content embedded in user data
4. **Dangerous Tool Use**: Unauthorized or excessive tool calls

## Configuration

### Policy Management

Edit `src/policies/security-policy.json` to configure:
- Allowed domains and tasks
- Forbidden patterns
- Tool usage policies
- Risk thresholds

### Environment Variables

Key environment variables for Lambda:
- `BEDROCK_MODEL_ID`: Bedrock model identifier
- `GUARDRAIL_ID`: Bedrock Guardrail ID
- `RISK_THRESHOLD`: Numeric threshold for blocking (0-100)
- `LOG_LEVEL`: Logging verbosity

## Monitoring and Observability

### CloudWatch Metrics
- `PromptInjectionDetectedCount`
- `JailbreakAttemptCount`
- `BlockedRequests`
- `HighRiskToolCalls`
- `P95Latency`

### Logs
- CloudWatch Logs for immediate inspection
- Kinesis Firehose → S3 for archival
- OpenSearch for analytics and dashboards

## Cost Optimization

- Lambda uses ARM64 architecture for 20% cost savings
- CloudFront caching reduces API Gateway calls
- Bedrock Guardrails billed per text unit
- Estimated cost: ~$50-100/month for dev environment

## Security Best Practices

- All traffic uses TLS 1.2+
- Lambda in private subnet with VPC endpoints
- Principle of least privilege for IAM roles
- Secrets stored in AWS Secrets Manager
- Encryption at rest for all data stores

## Testing

```bash
# Run unit tests
cd src/lambda/ai-waf-gateway
python -m pytest tests/

# Run attack scenario tests
cd src/tests
./run_attack_scenarios.sh
```

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues.

## Contributing

This is a hackathon/demo project. Contributions welcome!

## License

MIT License

## References

- [AWS Security Blog - Safeguard GenAI Workloads](https://aws.amazon.com/blogs/security/safeguard-your-generative-ai-workloads-from-prompt-injections/)
- [OWASP LLM Top 10](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)
- [Amazon Bedrock Guardrails Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html)
