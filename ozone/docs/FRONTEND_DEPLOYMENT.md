# Frontend Deployment Guide

## Overview

The AI WAF demo frontend can be deployed in three ways:

1. **AWS S3 + CloudFront** (Recommended for production)
2. **Local Development Server** (For testing)
3. **Other Static Hosting** (Netlify, Vercel, etc.)

---

## Option 1: AWS S3 + CloudFront (Recommended)

### Prerequisites

- AWS account with credentials configured
- Terraform deployed (infrastructure must exist)
- AWS CLI installed

### Steps

#### 1. Enable Frontend Hosting in Terraform

Edit `infra/terraform.tfvars` and add:

```hcl
enable_frontend_hosting = true
```

#### 2. Deploy Infrastructure

```bash
# Deploy or update infrastructure
make deploy ENV=dev

# This creates:
# - S3 bucket for static hosting
# - CloudFront distribution
# - Automatic API endpoint configuration
```

#### 3. Deploy Frontend Files

```bash
# Deploy to AWS
make demo

# Or manually:
./scripts/deploy-demo.sh
```

#### 4. Access Your Frontend

```bash
# Get the frontend URL
cd infra && terraform output frontend_url

# Example output:
# https://d1234567890abc.cloudfront.net
```

### What Gets Deployed

- `index.html` - Main chatbot interface
- `styles.css` - Styling
- `app.js` - Frontend logic (embedded in HTML)
- `config.json` - Auto-generated API endpoint configuration

### Updating the Frontend

```bash
# Make changes to src/frontend/*
# Then redeploy:
make demo

# CloudFront cache is automatically invalidated
```

---

## Option 2: Local Development Server

### Quick Start

```bash
# Configure API endpoint
make configure-frontend

# Start local server
make demo-local

# Open http://localhost:8080 in your browser
```

### Manual Configuration

1. **Create config.json**:

```bash
cd src/frontend
cp config.json.example config.json
```

2. **Edit config.json** with your API endpoint:

```json
{
  "api_endpoint": "https://YOUR_API_GATEWAY_ID.execute-api.us-east-1.amazonaws.com"
}
```

3. **Start server**:

```bash
python3 -m http.server 8080
# or
npx http-server -p 8080
```

4. **Open browser**: `http://localhost:8080`

---

## Option 3: Other Static Hosting Services

### Netlify

1. **Connect repository** to Netlify

2. **Build settings**:
   - Build command: (none needed)
   - Publish directory: `src/frontend`

3. **Environment variables**:
   ```
   API_ENDPOINT=https://your-api-gateway.amazonaws.com
   ```

4. **Deploy**: Netlify will auto-deploy on push

### Vercel

1. **Install Vercel CLI**:
   ```bash
   npm i -g vercel
   ```

2. **Deploy**:
   ```bash
   cd src/frontend
   vercel --prod
   ```

3. **Configure API endpoint** in `config.json` before deploying

### GitHub Pages

1. **Enable GitHub Pages** for your repository

2. **Copy frontend files** to `docs/` directory:
   ```bash
   cp -r src/frontend/* docs/
   ```

3. **Configure API endpoint** in `docs/config.json`

4. **Commit and push**:
   ```bash
   git add docs/
   git commit -m "Deploy frontend to GitHub Pages"
   git push
   ```

5. **Access**: `https://YOUR_USERNAME.github.io/YOUR_REPO/`

---

## Configuration

### API Endpoint Configuration

The frontend needs your API Gateway endpoint. It checks in this order:

1. **config.json** file (recommended)
2. **window.OZONE_API_ENDPOINT** JavaScript variable
3. **User prompt** (fallback)
4. **localStorage** (cached from previous prompt)

### CORS Configuration

Ensure your API Gateway has CORS enabled for your frontend domain:

```hcl
# In infra/terraform.tfvars
cors_allow_origins = ["https://your-frontend-domain.com", "http://localhost:8080"]
```

---

## Troubleshooting

### "API endpoint not configured"

**Solution**: Create `src/frontend/config.json`:

```bash
make configure-frontend
# or manually create config.json
```

### CORS Errors

**Problem**: Browser blocks API requests due to CORS policy

**Solution**: Update `cors_allow_origins` in `terraform.tfvars`:

```hcl
cors_allow_origins = ["https://d1234567890abc.cloudfront.net"]
```

Then redeploy:
```bash
make deploy ENV=dev
```

### CloudFront Shows Old Content

**Problem**: CloudFront cache not invalidated

**Solution**:
```bash
cd infra
CLOUDFRONT_ID=$(terraform output -raw frontend_cloudfront_id)
aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*"
```

### 403 Forbidden on S3

**Problem**: Bucket policy not allowing CloudFront access

**Solution**: Redeploy infrastructure:
```bash
make deploy ENV=dev
```

---

## Security Considerations

### Production Checklist

- [ ] Use custom domain with HTTPS (ACM certificate)
- [ ] Enable CloudFront WAF (separate from backend WAF)
- [ ] Set proper CORS origins (not "*")
- [ ] Enable CloudFront logging
- [ ] Use versioned deployments (S3 versioning)
- [ ] Implement CSP headers
- [ ] Enable CloudFront geo-restrictions if needed

### Custom Domain Setup

1. **Request ACM certificate** in `us-east-1` (for CloudFront)

2. **Add to terraform.tfvars**:
   ```hcl
   frontend_domain_name = "demo.yourcompany.com"
   acm_certificate_arn  = "arn:aws:acm:us-east-1:..."
   ```

3. **Update DNS** to point to CloudFront domain

---

## Monitoring

### CloudFront Metrics

```bash
# View CloudFront requests
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name Requests \
  --dimensions Name=DistributionId,Value=$CLOUDFRONT_ID \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### Access Logs

Enable CloudFront logging in `infra/modules/frontend/main.tf`:

```hcl
logging_config {
  include_cookies = false
  bucket          = aws_s3_bucket.logs.bucket_domain_name
  prefix          = "cloudfront/"
}
```

---

## Cost Optimization

### S3 Costs
- Static files are tiny (~50KB total)
- S3 storage cost: ~$0.001/month
- S3 requests: Minimal (cached by CloudFront)

### CloudFront Costs
- Free tier: 1TB data transfer/month
- After free tier: ~$0.085/GB
- Typical demo usage: < $1/month

### Recommendations

1. **Use CloudFront caching** (already configured)
2. **Compress assets** (CloudFront does this automatically)
3. **Use PriceClass_100** (North America + Europe only)
4. **Delete unused distributions** when not needed

---

## Advanced: CI/CD Pipeline

### GitHub Actions Example

Create `.github/workflows/deploy-frontend.yml`:

```yaml
name: Deploy Frontend

on:
  push:
    branches: [main]
    paths:
      - 'src/frontend/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Get Terraform Outputs
        run: |
          cd infra
          echo "BUCKET_NAME=$(terraform output -raw frontend_bucket_name)" >> $GITHUB_ENV
          echo "API_ENDPOINT=$(terraform output -raw api_endpoint)" >> $GITHUB_ENV
      
      - name: Create config.json
        run: |
          echo '{"api_endpoint":"${{ env.API_ENDPOINT }}"}' > src/frontend/config.json
      
      - name: Sync to S3
        run: |
          aws s3 sync src/frontend s3://${{ env.BUCKET_NAME }}/ \
            --exclude "*.md" --exclude "*.example" --delete
      
      - name: Invalidate CloudFront
        run: |
          DISTRIBUTION_ID=$(cd infra && terraform output -raw frontend_cloudfront_id)
          aws cloudfront create-invalidation \
            --distribution-id $DISTRIBUTION_ID \
            --paths "/*"
```

---

## Quick Reference

### Common Commands

```bash
# Deploy to AWS
make demo

# Run locally
make demo-local

# Configure API endpoint
make configure-frontend

# View deployment info
cd infra && terraform output

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(cd infra && terraform output -raw frontend_cloudfront_id) \
  --paths "/*"
```

### Useful Outputs

```bash
# Get all frontend info
cd infra
terraform output | grep frontend

# Get just the URL
terraform output -raw frontend_url

# Get bucket name
terraform output -raw frontend_bucket_name
```

---

## Support

For issues or questions:

1. Check [troubleshooting.md](./troubleshooting.md)
2. Review CloudWatch logs: `make logs`
3. Check browser console for errors
4. Verify API endpoint is correct in `config.json`
