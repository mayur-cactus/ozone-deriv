#!/bin/bash
set -e

echo "Building and deploying Lambda functions..."

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_DIR="$SCRIPT_DIR/../src/lambda"

# Get Lambda function name from Terraform output
LAMBDA_FUNCTION_NAME=$(cd "$SCRIPT_DIR/../infra" && terraform output -raw lambda_function_name 2>/dev/null || echo "")

if [ -z "$LAMBDA_FUNCTION_NAME" ]; then
    echo "Error: Could not get Lambda function name from Terraform output."
    echo "Please deploy infrastructure first using scripts/deploy.sh"
    exit 1
fi

echo "Lambda function: $LAMBDA_FUNCTION_NAME"
echo ""

# Build AI WAF Gateway Lambda
echo "Building AI WAF Gateway Lambda..."
cd "$SRC_DIR/ai-waf-gateway"

if [ ! -f "build.sh" ]; then
    echo "Error: build.sh not found"
    exit 1
fi

chmod +x build.sh
./build.sh

echo ""
echo "Deploying to AWS Lambda..."
aws lambda update-function-code \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --zip-file fileb://deployment.zip \
    --no-cli-pager

echo ""
echo "Waiting for Lambda update to complete..."
aws lambda wait function-updated \
    --function-name "$LAMBDA_FUNCTION_NAME"

echo ""
echo "Lambda deployment complete!"
echo ""

# Get function info
aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --query 'Configuration.{FunctionName:FunctionName,Runtime:Runtime,LastModified:LastModified,CodeSize:CodeSize}' \
    --output table

echo ""
echo "Done!"
