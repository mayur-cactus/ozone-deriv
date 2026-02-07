#!/bin/bash
set -e

echo "======================================"
echo "Upload Frontend to S3"
echo "======================================"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FRONTEND_DIR="$SCRIPT_DIR/../src/frontend"
INFRA_DIR="$SCRIPT_DIR/../infra"

# Check if infrastructure is deployed
if [ ! -d "$INFRA_DIR/.terraform" ]; then
    echo "Error: Terraform not initialized."
    echo "Please deploy infrastructure first: make deploy ENV=dev"
    exit 1
fi

# Get bucket name and CloudFront ID from Terraform
cd "$INFRA_DIR"

BUCKET_NAME=$(terraform output -raw frontend_bucket_name 2>/dev/null || echo "")
CLOUDFRONT_ID=$(terraform output -raw frontend_cloudfront_id 2>/dev/null || echo "")
FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "")

if [ -z "$BUCKET_NAME" ]; then
    echo "Error: Could not get frontend bucket name from Terraform."
    echo "Make sure frontend hosting is enabled and deployed."
    echo ""
    echo "Add to terraform.tfvars:"
    echo "  enable_frontend_hosting = true"
    echo ""
    echo "Then run: terraform apply -var=\"environment=dev\""
    exit 1
fi

echo "S3 Bucket: $BUCKET_NAME"
echo "CloudFront Distribution: $CLOUDFRONT_ID"
echo "Frontend URL: $FRONTEND_URL"
echo ""

# Get API endpoint and update config.json
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
if [ -n "$API_ENDPOINT" ]; then
    echo "Updating config.json with API endpoint..."
    cat > "$FRONTEND_DIR/config.json" << EOF
{
  "api_endpoint": "$API_ENDPOINT"
}
EOF
    echo "✓ Updated config.json with API endpoint: $API_ENDPOINT"
else
    echo "⚠ Warning: Could not get API endpoint. config.json may need manual update."
fi
echo ""

# Upload files to S3
echo "Uploading files to S3..."
aws s3 sync "$FRONTEND_DIR" "s3://$BUCKET_NAME/" \
    --exclude "*.md" \
    --exclude ".DS_Store" \
    --exclude "*.example" \
    --exclude "node_modules/*" \
    --cache-control "public, max-age=300" \
    --delete

echo "✓ Files uploaded successfully"
echo ""

# Invalidate CloudFront cache
if [ -n "$CLOUDFRONT_ID" ]; then
    echo "Invalidating CloudFront cache..."
    aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_ID" \
        --paths "/*" > /dev/null
    echo "✓ CloudFront cache invalidated"
    echo ""
fi

echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "Frontend URL: $FRONTEND_URL"
echo ""
echo "Files uploaded:"
ls -lh "$FRONTEND_DIR" | grep -E '\.(html|css|js|json)$' || true
echo ""
echo "To test, open: $FRONTEND_URL"
echo ""
