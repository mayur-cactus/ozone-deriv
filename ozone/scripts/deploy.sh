#!/bin/bash
set -e

echo "======================================"
echo "AI WAF Infrastructure Deployment"
echo "======================================"
echo ""

# Check prerequisites
command -v terraform >/dev/null 2>&1 || { echo "Error: terraform is not installed." >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "Error: AWS CLI is not installed." >&2; exit 1; }

# Check AWS credentials
aws sts get-caller-identity > /dev/null 2>&1 || { echo "Error: AWS credentials not configured." >&2; exit 1; }

echo "Prerequisites check passed ✓"
echo ""

# Get environment
if [ -z "$1" ]; then
    echo "Usage: $0 <environment> [action]"
    echo "Environments: dev, staging, prod"
    echo "Actions: plan, apply, destroy (default: plan)"
    exit 1
fi

ENVIRONMENT=$1
ACTION=${2:-plan}

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Invalid environment. Must be dev, staging, or prod."
    exit 1
fi

if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
    echo "Error: Invalid action. Must be plan, apply, or destroy."
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFRA_DIR="$SCRIPT_DIR/../infra"
ENV_DIR="$INFRA_DIR/environments/$ENVIRONMENT"

if [ ! -d "$ENV_DIR" ]; then
    echo "Error: Environment directory not found: $ENV_DIR"
    exit 1
fi

cd "$INFRA_DIR"

echo "Environment: $ENVIRONMENT"
echo "Action: $ACTION"
echo "Working directory: $(pwd)"
echo ""

# Initialize Terraform
echo "Initializing Terraform..."
terraform init -upgrade
echo ""

# Validate configuration
echo "Validating Terraform configuration..."
terraform validate
echo ""

# Format check
echo "Checking Terraform formatting..."
terraform fmt -check || true
echo ""

# Run the action
case $ACTION in
    plan)
        echo "Running Terraform plan..."
        terraform plan \
            -var="environment=$ENVIRONMENT" \
            -out=tfplan
        echo ""
        echo "Plan saved to tfplan"
        echo "To apply: $0 $ENVIRONMENT apply"
        ;;
    
    apply)
        echo "Applying Terraform configuration..."
        
        if [ -f tfplan ]; then
            echo "Using saved plan..."
            terraform apply tfplan
            rm tfplan
        else
            echo "No saved plan found. Running fresh apply..."
            terraform apply \
                -var="environment=$ENVIRONMENT" \
                -auto-approve=false
        fi
        
        echo ""
        echo "======================================"
        echo "Deployment Complete!"
        echo "======================================"
        echo ""
        terraform output
        ;;
    
    destroy)
        echo "WARNING: This will destroy all infrastructure in $ENVIRONMENT!"
        echo ""
        read -p "Are you sure? Type 'yes' to confirm: " confirmation
        
        if [ "$confirmation" = "yes" ]; then
            terraform destroy \
                -var="environment=$ENVIRONMENT" \
                -auto-approve=false
        else
            echo "Destruction cancelled."
            exit 0
        fi
        ;;
esac

echo ""
echo "Done!"
