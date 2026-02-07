#!/bin/bash
set -e

echo "======================================"
echo "AI WAF Demo Chatbot Deployment"
echo "======================================"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FRONTEND_DIR="$SCRIPT_DIR/../src/frontend"
INFRA_DIR="$SCRIPT_DIR/../infra"

# Check if infrastructure is deployed
if [ ! -d "$INFRA_DIR/.terraform" ]; then
    echo "Error: Terraform not initialized. Please deploy infrastructure first:"
    echo "  make deploy ENV=dev"
    exit 1
fi

# Get API endpoint from Terraform output
echo "Fetching configuration from Terraform..."
cd "$INFRA_DIR"

API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
BUCKET_NAME=$(terraform output -raw frontend_bucket_name 2>/dev/null || echo "")
CLOUDFRONT_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "")
CLOUDFRONT_ID=$(terraform output -raw frontend_cloudfront_id 2>/dev/null || echo "")

if [ -z "$API_ENDPOINT" ]; then
    echo "Error: Could not get API endpoint from Terraform output."
    echo "Please deploy infrastructure first using: make deploy ENV=dev"
    exit 1
fi

echo "API Endpoint: $API_ENDPOINT"
echo ""

# Create config.json for frontend
echo "Creating frontend configuration..."
cat > "$FRONTEND_DIR/config.json" << EOF
{
  "api_endpoint": "$API_ENDPOINT"
}
EOF

echo "✓ Created config.json"
echo ""

# Deploy to S3 (if configured)
if [ -n "$BUCKET_NAME" ] && [ "$BUCKET_NAME" != "null" ]; then
    echo "======================================"
    echo "Deploying to AWS S3 + CloudFront"
    echo "======================================"
    echo ""
    echo "S3 Bucket: $BUCKET_NAME"
    echo "CloudFront URL: $CLOUDFRONT_URL"
    echo ""
    
    # Sync files to S3
    echo "Uploading files to S3..."
    aws s3 sync "$FRONTEND_DIR" "s3://$BUCKET_NAME/" \
        --exclude "*.md" \
        --exclude ".DS_Store" \
        --exclude "*.example" \
        --delete \
        --cache-control "public, max-age=300"
    
    echo "✓ Files uploaded to S3"
    echo ""
    
    # Invalidate CloudFront cache
    if [ -n "$CLOUDFRONT_ID" ] && [ "$CLOUDFRONT_ID" != "null" ]; then
        echo "Invalidating CloudFront cache..."
        aws cloudfront create-invalidation \
            --distribution-id "$CLOUDFRONT_ID" \
            --paths "/*" > /dev/null
        echo "✓ CloudFront cache invalidated"
        echo ""
    fi
    
    echo "======================================"
    echo "🎉 Deployment Complete!"
    echo "======================================"
    echo ""
    echo "Frontend URL: $CLOUDFRONT_URL"
    echo "API Endpoint: $API_ENDPOINT"
    echo ""
    echo "Open the demo in your browser:"
    echo "  $CLOUDFRONT_URL"
    echo ""
else
    echo "======================================"
    echo "Local Development Setup"
    echo "======================================"
    echo ""
    echo "Frontend hosting not enabled in Terraform."
    echo "To enable, set enable_frontend_hosting = true in terraform.tfvars"
    echo ""
    echo "For now, run locally:"
    echo ""
    echo "1. Start a local web server:"
    echo "   cd $FRONTEND_DIR"
    echo "   python3 -m http.server 8080"
    echo ""
    echo "2. Open browser:"
    echo "   http://localhost:8080"
    echo ""
    echo "API Endpoint configured: $API_ENDPOINT"
    echo ""
fi

echo "Configuration file created at:"
echo "  $FRONTEND_DIR/config.json"
echo ""
