# Architecture Documentation

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         User / Client                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Amazon CloudFront (CDN)                       │
│  - Global edge locations                                        │
│  - TLS termination                                              │
│  - DDoS protection (AWS Shield)                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Protected by WAF
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AWS WAF (Layer 1)                          │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  • Managed Rules: Common exploits, bad inputs          │    │
│  │  • Bot Control: Detect and block automated attacks     │    │
│  │  • Rate Limiting: 2000 req/5min per IP                 │    │
│  │  • Size Constraints: Max 128KB request                 │    │
│  │  • Custom Rules: Block suspicious prompt patterns      │    │
│  └────────────────────────────────────────────────────────┘    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ If allowed
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   API Gateway (HTTP API)                         │
│  - Throttling: 500 burst, 100 req/sec                          │
│  - CORS configuration                                           │
│  - Access logging to CloudWatch                                 │
│  - Routes: POST /chat, GET /health                             │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Lambda Integration
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                  VPC (Private Subnets)                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         AI WAF Lambda Function (Layer 2)                 │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────┐    │  │
│  │  │ 1. Input Validation & Parsing                  │    │  │
│  │  │    - Parse JSON request                        │    │  │
│  │  │    - Extract prompt, user_id, context, tools   │    │  │
│  │  └────────────────────────────────────────────────┘    │  │
│  │                       ▼                                 │  │
│  │  ┌────────────────────────────────────────────────┐    │  │
│  │  │ 2. Pre-LLM Semantic Classifier                 │    │  │
│  │  │    - Bedrock Claude Haiku classification       │    │  │
│  │  │    - Pattern matching (forbidden phrases)      │    │  │
│  │  │    - Risk scoring (0-100)                      │    │  │
│  │  │    - Intent detection                          │    │  │
│  │  │                                                 │    │  │
│  │  │    If risk_score >= 70 → BLOCK                │    │  │
│  │  └────────────────────────────────────────────────┘    │  │
│  │                       ▼                                 │  │
│  │  ┌────────────────────────────────────────────────┐    │  │
│  │  │ 3. Policy Engine                               │    │  │
│  │  │    - Check RBAC permissions                    │    │  │
│  │  │    - Validate tool usage policies              │    │  │
│  │  │    - Apply rate limits                         │    │  │
│  │  └────────────────────────────────────────────────┘    │  │
│  │                       ▼                                 │  │
│  │  ┌────────────────────────────────────────────────┐    │  │
│  │  │ 4. LLM Invocation with Guardrails (Layer 3)   │    │  │
│  │  │    - Call Bedrock Runtime API                  │    │  │
│  │  │    - Attach Guardrail ID                       │    │  │
│  │  │    - Bedrock filters prompt attacks (HIGH)     │    │  │
│  │  │    - Content moderation (hate, violence, etc)  │    │  │
│  │  │                                                 │    │  │
│  │  │    If blocked by Guardrail → BLOCK            │    │  │
│  │  └────────────────────────────────────────────────┘    │  │
│  │                       ▼                                 │  │
│  │  ┌────────────────────────────────────────────────┐    │  │
│  │  │ 5. Output Verification (Layer 4)               │    │  │
│  │  │    - Schema validation                         │    │  │
│  │  │    - Secret detection (AWS keys, passwords)    │    │  │
│  │  │    - PII detection (email, phone, SSN)         │    │  │
│  │  │    - System prompt leakage check               │    │  │
│  │  │    - Adversarial content check                 │    │  │
│  │  │                                                 │    │  │
│  │  │    If unsafe output → BLOCK                    │    │  │
│  │  └────────────────────────────────────────────────┘    │  │
│  │                       ▼                                 │  │
│  │  ┌────────────────────────────────────────────────┐    │  │
│  │  │ 6. Tool Safety Verification                    │    │  │
│  │  │    - Validate tool is allowed                  │    │  │
│  │  │    - Check parameter constraints               │    │  │
│  │  │    - Verify user permissions (RBAC)            │    │  │
│  │  │    - Enforce limits (e.g., max transfer $1000) │    │  │
│  │  │    - Flag for human approval if needed         │    │  │
│  │  │                                                 │    │  │
│  │  │    If policy violation → BLOCK                 │    │  │
│  │  └────────────────────────────────────────────────┘    │  │
│  │                       ▼                                 │  │
│  │  ┌────────────────────────────────────────────────┐    │  │
│  │  │ 7. Logging & Metrics (Layer 5)                 │    │  │
│  │  │    - Log to Kinesis Firehose                   │    │  │
│  │  │    - Publish CloudWatch metrics                │    │  │
│  │  │    - X-Ray tracing                             │    │  │
│  │  └────────────────────────────────────────────────┘    │  │
│  │                       ▼                                 │  │
│  │               Return Response                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Connected via VPC Endpoints (Private):                        │
│    - Bedrock Runtime                                           │
│    - Secrets Manager                                           │
│    - CloudWatch Logs                                           │
│    - S3                                                        │
└─────────────────────────────────────────────────────────────────┘

                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
┌───────────────────────┐    ┌─────────────────────────┐
│  Amazon Bedrock       │    │  Monitoring &           │
│  - Foundation Models  │    │  Observability          │
│  - Guardrails         │    │                         │
│    • Prompt Attack    │    │  ┌───────────────────┐  │
│    • Content Filters  │    │  │ CloudWatch        │  │
│    • PII Detection    │    │  │  - Logs           │  │
│    • Topic Blocking   │    │  │  - Metrics        │  │
│                       │    │  │  - Alarms         │  │
│  Models:              │    │  │  - Dashboard      │  │
│  - Claude 3 Haiku     │    │  └───────────────────┘  │
│  - Claude 3 Sonnet    │    │                         │
└───────────────────────┘    │  ┌───────────────────┐  │
                             │  │ Kinesis Firehose  │  │
                             │  │  → S3 Logs        │  │
                             │  │  → OpenSearch*    │  │
                             │  └───────────────────┘  │
                             │                         │
                             │  ┌───────────────────┐  │
                             │  │ SNS Topics        │  │
                             │  │  - Email alerts   │  │
                             │  │  - Slack webhooks │  │
                             │  └───────────────────┘  │
                             └─────────────────────────┘
```

## Request Flow Diagram

```
User Request
    │
    ▼
┌─────────────────┐
│ CloudFront      │ → Cache Check → If cached, return
└────────┬────────┘
         │ If not cached
         ▼
┌─────────────────┐
│ AWS WAF         │ → Rule evaluation
└────────┬────────┘
         │
         ├─[Block]─→ Return 403 with reason
         │
         └─[Allow]─→
                   ▼
         ┌─────────────────┐
         │ API Gateway     │ → Throttling check
         └────────┬────────┘
                  │
                  ├─[Rate limit]─→ Return 429
                  │
                  └─[Allow]─→
                            ▼
                  ┌─────────────────┐
                  │ Lambda: Parse   │
                  └────────┬────────┘
                           ▼
                  ┌─────────────────┐
                  │ Classifier      │ → Risk score calculation
                  └────────┬────────┘
                           │
                           ├─[Risk >= 70]─→ Block + Log
                           │
                           └─[Risk < 70]─→
                                         ▼
                                ┌─────────────────┐
                                │ Bedrock+Guard   │
                                └────────┬────────┘
                                         │
                                         ├─[Blocked]─→ Block + Log
                                         │
                                         └─[Allowed]─→
                                                     ▼
                                            ┌─────────────────┐
                                            │ Output Verify   │
                                            └────────┬────────┘
                                                     │
                                                     ├─[Unsafe]─→ Block + Log
                                                     │
                                                     └─[Safe]─→
                                                               ▼
                                                      ┌─────────────────┐
                                                      │ Tool Verify     │
                                                      └────────┬────────┘
                                                               │
                                                               ├─[Violation]─→ Block
                                                               │
                                                               └─[OK]─→
                                                                       ▼
                                                              ┌─────────────────┐
                                                              │ Log + Metrics   │
                                                              └────────┬────────┘
                                                                       ▼
                                                              Return 200 + Response
```

## Security Layers in Detail

### Layer 1: Network Perimeter (AWS WAF)
**Purpose**: Block volumetric attacks and known bad patterns
- **AWS Managed Rules**: Protection against OWASP Top 10, SQLi, XSS
- **Bot Control**: Detect and mitigate bot traffic
- **Rate Limiting**: Prevent abuse (2000 req/5min per IP)
- **Size Constraints**: Block oversized payloads (>128KB)
- **Custom Pattern Rules**: Block obvious prompt injection strings

**Performance**: ~1-5ms overhead

### Layer 2: Semantic Analysis (Pre-LLM Classifier)
**Purpose**: Detect adversarial intent in natural language
- **Bedrock Classification**: Use fast Claude Haiku model
- **Risk Scoring**: 0-100 scale based on multiple factors
- **Pattern Matching**: Regex + string matching for known attacks
- **Context Analysis**: Consider user history, session data

**Performance**: ~200-500ms

**Decision Logic**:
```python
if risk_score >= 70:
    BLOCK
elif risk_score >= 40:
    ALLOW with enhanced monitoring
else:
    ALLOW
```

### Layer 3: Model-Level Protection (Bedrock Guardrails)
**Purpose**: Built-in model safety filters
- **Prompt Attack Filter**: HIGH strength
- **Content Moderation**: Hate, violence, sexual content, etc.
- **Topic Blocking**: Deny specific topics (jailbreak, injection)
- **PII Filtering**: Block/anonymize sensitive data
- **Word Filters**: Block profanity and specific phrases

**Performance**: ~100-300ms (integrated into LLM call)

### Layer 4: Output Verification
**Purpose**: Ensure LLM output is safe before returning
- **Schema Validation**: Ensure structured output matches expected format
- **Secret Detection**: AWS keys, passwords, tokens
- **PII Detection**: Email, phone, SSN, credit cards
- **System Prompt Leakage**: Check for system instruction reveals
- **Adversarial Content**: Detect malicious instructions in output

**Performance**: ~50-100ms

### Layer 5: Tool Safety & RBAC
**Purpose**: Prevent unauthorized or dangerous tool usage
- **Allowlist**: Only approved tools can be called
- **Parameter Validation**: Enforce constraints (e.g., max transfer amount)
- **RBAC**: User role determines allowed tools
- **Human-in-the-Loop**: Flag high-risk actions for approval
- **Audit Logging**: Record all tool calls

**Performance**: ~10-50ms

## Data Flow

### Successful Request
```
User → CloudFront → WAF → API GW → Lambda →
  [Classifier: PASS] →
  [Bedrock+Guardrail: PASS] →
  [Output Verify: PASS] →
  [Tool Verify: PASS] →
  [Log Event] →
← Response
```

**Total Latency**: ~800ms - 2000ms (P95)

### Blocked Request (Prompt Injection)
```
User → CloudFront → WAF → API GW → Lambda →
  [Classifier: BLOCK, risk=85] →
  [Log Security Event] →
  [Publish Metrics] →
← 403 Forbidden + Explanation
```

**Total Latency**: ~300-700ms (faster since LLM not called)

## Infrastructure Components

### Compute
- **Lambda**: 1024MB RAM, ARM64, 30s timeout
- **VPC**: Private subnets with NAT Gateway
- **VPC Endpoints**: Bedrock, Secrets Manager, CloudWatch, S3

### Storage
- **S3**: Log archive (Kinesis Firehose output)
- **Secrets Manager**: Bedrock config, CloudFront secret
- **DynamoDB**: (Optional) User session tracking, rate limiting

### Networking
- **CloudFront**: Global CDN, TLS termination
- **API Gateway**: Regional HTTP API
- **VPC**: 10.0.0.0/16, multi-AZ
- **Security Groups**: Least privilege

### Monitoring
- **CloudWatch Logs**: Lambda, API Gateway, WAF
- **CloudWatch Metrics**: Custom AI-WAF namespace
- **CloudWatch Alarms**: Error rate, latency, block rate
- **Kinesis Firehose**: Stream to S3, OpenSearch
- **X-Ray**: Distributed tracing

## Cost Breakdown (Monthly, Dev Environment)

| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 1M invocations, 1024MB, 1s avg | $20 |
| API Gateway | 1M requests | $3.50 |
| CloudFront | 100GB transfer | $8.50 |
| WAF | Base + 1M requests | $6 |
| Bedrock | 10M tokens (Haiku) | $2.50 |
| Bedrock Guardrails | 10M text units | $15 |
| CloudWatch | Logs, metrics, alarms | $10 |
| VPC | NAT Gateway (730 hrs) | $32.85 |
| Kinesis Firehose | 100GB | $0.03 |
| S3 | 100GB storage | $2.30 |
| **Total** | | **~$100/month** |

### Cost Optimizations
1. **Use ARM64 Lambda** ✓ (20% cheaper)
2. **Cache in CloudFront** (reduce API calls)
3. **Use Haiku model** ✓ (cheaper than Sonnet)
4. **Short log retention** (7 days instead of 30)
5. **Disable NAT in dev** (use VPC endpoints only)

## Scalability

### Horizontal Scaling
- **Lambda**: Auto-scales to 1000 concurrent executions (default)
- **API Gateway**: No scaling limit
- **CloudFront**: Global auto-scaling
- **Bedrock**: Managed service, auto-scales

### Vertical Scaling
- **Lambda Memory**: Increase to 2048MB+ for faster CPU
- **API Gateway Throttling**: Increase limits per account
- **Bedrock Quotas**: Request increase via Service Quotas

### High Availability
- **Multi-AZ**: VPC spans multiple AZs
- **CloudFront**: Global edge network
- **Bedrock**: AWS-managed HA
- **Lambda**: Inherent redundancy

## Security Best Practices Implemented

✅ **Encryption**
- TLS 1.2+ for all connections
- S3 encryption at rest (AES-256)
- Secrets in Secrets Manager

✅ **Least Privilege**
- IAM roles with minimal permissions
- Security group rules tightly scoped
- VPC private subnets for Lambda

✅ **Defense in Depth**
- 5 security layers (WAF → Classifier → Guardrails → Output → Tools)
- Multiple validation points
- Fail-safe defaults

✅ **Monitoring & Auditing**
- All requests logged
- Security events to Kinesis
- CloudWatch alarms for anomalies
- X-Ray tracing for debugging

✅ **Compliance**
- PII detection and filtering
- Audit trails for tool calls
- Data retention policies
- Access controls (RBAC)

## Disaster Recovery

### Backup Strategy
- **Terraform State**: S3 backend with versioning
- **Code**: Git repository
- **Logs**: S3 with lifecycle policies
- **Configuration**: Version controlled

### Recovery Procedures
1. **Infrastructure**: `terraform apply` from state
2. **Lambda Code**: Deploy from CI/CD or local build
3. **Configuration**: Restore from Git
4. **Logs**: Archived in S3, retrievable

### RTO/RPO
- **RTO** (Recovery Time Objective): 1-2 hours
- **RPO** (Recovery Point Objective): Near-zero (stateless)

## Future Enhancements

1. **Multi-Region Deployment**
   - Active-active or active-passive
   - Route53 health checks
   - Cross-region replication

2. **Advanced ML Models**
   - Custom fine-tuned classifiers
   - Anomaly detection models
   - Behavioral analysis

3. **Human-in-the-Loop**
   - Admin dashboard for approvals
   - Manual review queue
   - Feedback loop for model improvement

4. **Enhanced Observability**
   - OpenSearch dashboards
   - Grafana integration
   - Real-time threat intelligence

5. **API Authentication**
   - AWS Cognito integration
   - API key management
   - OAuth2/OIDC support

6. **Rate Limiting Enhancement**
   - DynamoDB-based distributed rate limiting
   - Per-user, per-session, per-endpoint
   - Dynamic limits based on user tier

---

*Architecture Last Updated: February 7, 2026*
