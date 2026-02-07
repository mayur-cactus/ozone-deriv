#!/bin/bash
set -e

echo "Building AI WAF Lambda deployment package..."

# Navigate to lambda directory
cd "$(dirname "$0")"

# Create build directory
rm -rf build
mkdir -p build

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt -t build/ --platform manylinux2014_aarch64 --only-binary=:all:

# Copy source code
echo "Copying source code..."
cp main.py build/

# Create deployment package
echo "Creating deployment package..."
cd build
zip -r ../deployment.zip . -q
cd ..

# Cleanup
rm -rf build

echo "Deployment package created: deployment.zip"
echo "Size: $(du -h deployment.zip | cut -f1)"
