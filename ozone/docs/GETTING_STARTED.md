# Getting Started - Step by Step

## Prerequisites Check

Run this first to verify you have everything:

```bash
make setup
```

This will:
- ✅ Check AWS credentials
- ✅ Check Terraform installation  
- ✅ Check Python installation
- ✅ Create terraform.tfvars from example

## Path 1: Full AWS Deployment (Recommended)

### Step 1: Configure AWS

```bash
# If you see "AWS credentials not configured":
aws configure

# You'll need:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
```

### Step 2: Review Configuration

```bash
# Edit the generated terraform.tfvars
nano infra/terraform.tfvars

# Key settings to review:
# - environment = "dev"  (or staging/prod)
# - aws_region = "us-east-1"  (your preferred region)
# - alarm_email = "your-email@example.com"  (for alerts)
```

### Step 3: Deploy Infrastructure

```bash
# Initialize and deploy (takes ~10-15 minutes)
make deploy ENV=dev

# This will:
# - Create VPC and networking
# - Deploy Lambda function
# - Configure API Gateway
# - Set up Bedrock Guardrails
# - Create monitoring resources
```

### Step 4: Launch Demo

```bash
# Deploy and configure the chatbot demo
make demo

# Or run locally
make demo-local
# Then open: http://localhost:8080
```

### Step 5: Test Everything

```bash
# Run automated tests
make test

# Test health endpoint
make test-health

# View Lambda logs
make logs
```

## Path 2: Local Development Only

If you don't have AWS access yet or want to develop frontend first:

See [docs/LOCAL_DEVELOPMENT.md](./LOCAL_DEVELOPMENT.md) for running with a mock API.

## Common Issues

### "AWS credentials not configured"

```bash
aws configure
# Enter your credentials when prompted
```

### "Terraform not installed"

**macOS:**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Linux:**
```bash
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

**Windows:**
Download from: https://developer.hashicorp.com/terraform/downloads

### "Environment directory not found"

✅ **FIXED!** The deploy script has been updated. Just run:
```bash
make deploy ENV=dev
```

### Need to start over?

```bash
# Clean everything
make clean

# Re-run setup
make setup

# Re-deploy
make deploy ENV=dev
```

## Verify Deployment

After deployment completes, verify everything works:

```bash
# 1. Check outputs
cd infra && terraform output

# 2. Test API health
make test-health

# 3. Run attack scenarios
make test

# 4. Launch demo
make demo-local
```

## What Gets Created in AWS

When you run `make deploy ENV=dev`, Terraform creates:

**Networking:**
- 1 VPC
- 2 Public subnets
- 2 Private subnets
- 1 NAT Gateway
- Internet Gateway
- Route tables

**Compute:**
- 1 Lambda function (ARM64, 1GB RAM)
- Lambda IAM role with Bedrock permissions

**API:**
- 1 API Gateway HTTP API
- 3 Routes: /health, /chat, /chat-direct
- CloudWatch logging

**Security:**
- AWS WAF WebACL (optional)
- Bedrock Guardrails
- Security groups
- VPC endpoints

**Monitoring:**
- CloudWatch Log Groups
- CloudWatch Alarms
- Kinesis Firehose (optional)
- CloudWatch Dashboard

**Estimated Cost:**
- Dev environment: ~$50-100/month
- Most of it is NAT Gateway ($30/month)
- Lambda and Bedrock are usage-based

## Next Steps After Deployment

1. **Try the Demo** - `make demo-local`
2. **Test Attack Scenarios** - Use the dropdown in the UI
3. **Review Logs** - `make logs`
4. **Check Metrics** - CloudWatch dashboard
5. **Customize** - Edit security policies in `src/policies/security-policy.json`

## Getting Help

**Documentation:**
- Architecture: `docs/ARCHITECTURE.md`
- Troubleshooting: `docs/troubleshooting.md`
- Demo Guide: `docs/DEMO_GUIDE.md`

**Quick Commands:**
```bash
make help              # Show all available commands
make outputs           # Show Terraform outputs
make logs              # View Lambda logs
make test              # Run tests
make clean             # Clean build artifacts
make destroy ENV=dev   # Destroy infrastructure (WARNING!)
```

**Need More Help?**
- Check `docs/troubleshooting.md`
- Review Lambda logs: `make logs`
- Verify Terraform state: `make outputs`

## Success Checklist

After following these steps, you should have:

- [ ] AWS credentials configured
- [ ] terraform.tfvars created and customized
- [ ] Infrastructure deployed successfully
- [ ] Lambda function responding to /health
- [ ] Demo chatbot running locally
- [ ] Attack scenarios blocking correctly
- [ ] Metrics updating in dashboard

Congratulations! Your AI WAF is now running! 🎉
