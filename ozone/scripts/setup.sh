#!/bin/bash
set -e

echo "======================================"
echo "AI WAF - Quick Setup Helper"
echo "======================================"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFRA_DIR="$SCRIPT_DIR/../infra"

# Check if terraform.tfvars exists
if [ ! -f "$INFRA_DIR/terraform.tfvars" ]; then
    echo "📝 Creating terraform.tfvars from example..."
    cp "$INFRA_DIR/terraform.tfvars.example" "$INFRA_DIR/terraform.tfvars"
    echo "✓ Created terraform.tfvars"
    echo ""
    echo "⚠️  IMPORTANT: Please edit infra/terraform.tfvars with your settings:"
    echo "   - aws_region (your preferred AWS region)"
    echo "   - alarm_email (for CloudWatch alerts)"
    echo "   - environment (dev/staging/prod)"
    echo ""
    echo "Run: nano infra/terraform.tfvars"
    echo "Or: code infra/terraform.tfvars"
    echo ""
else
    echo "✓ terraform.tfvars already exists"
fi

# Check AWS credentials
echo "Checking AWS credentials..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo "✓ AWS credentials configured"
    aws sts get-caller-identity --query 'Account' --output text | xargs echo "  AWS Account:"
else
    echo "❌ AWS credentials not configured"
    echo "   Run: aws configure"
    exit 1
fi

echo ""
echo "Checking prerequisites..."

# Check Terraform
if command -v terraform > /dev/null 2>&1; then
    echo "✓ Terraform installed: $(terraform version -json | jq -r '.terraform_version')"
else
    echo "❌ Terraform not installed"
    echo "   Install from: https://developer.hashicorp.com/terraform/downloads"
    exit 1
fi

# Check Python
if command -v python3 > /dev/null 2>&1; then
    echo "✓ Python installed: $(python3 --version)"
else
    echo "❌ Python 3 not installed"
    exit 1
fi

# Check jq (optional but helpful)
if command -v jq > /dev/null 2>&1; then
    echo "✓ jq installed"
else
    echo "⚠️  jq not installed (optional, but recommended)"
    echo "   Install: brew install jq"
fi

echo ""
echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Review/edit configuration:"
echo "   nano infra/terraform.tfvars"
echo ""
echo "2. Deploy infrastructure:"
echo "   make deploy ENV=dev"
echo ""
echo "3. Launch demo chatbot:"
echo "   make demo-local"
echo ""
echo "For detailed instructions, see:"
echo "  - README.md"
echo "  - docs/QUICKSTART.md"
echo ""
