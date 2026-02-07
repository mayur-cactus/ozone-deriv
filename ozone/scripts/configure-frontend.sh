#!/bin/bash
set -e

echo "======================================"
echo "Frontend API Configuration"
echo "======================================"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FRONTEND_DIR="$SCRIPT_DIR/../src/frontend"
INFRA_DIR="$SCRIPT_DIR/../infra"

# Try to get API endpoint from Terraform
API_ENDPOINT=""
if [ -f "$INFRA_DIR/terraform.tfstate" ]; then
    echo "Attempting to fetch API endpoint from Terraform..."
    cd "$INFRA_DIR"
    API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
fi

# If not found, ask user
if [ -z "$API_ENDPOINT" ]; then
    echo "Could not fetch API endpoint from Terraform."
    echo ""
    read -p "Enter your API Gateway endpoint URL: " API_ENDPOINT
fi

if [ -z "$API_ENDPOINT" ]; then
    echo "Error: No API endpoint provided."
    exit 1
fi

echo ""
echo "Configuring frontend with API endpoint:"
echo "  $API_ENDPOINT"
echo ""

# Create config.json
cat > "$FRONTEND_DIR/config.json" << EOF
{
  "api_endpoint": "$API_ENDPOINT"
}
EOF

echo "✓ Created $FRONTEND_DIR/config.json"
echo ""
echo "You can now run the demo:"
echo "  make demo-local"
echo ""
echo "Or open index.html directly in your browser."
echo ""
