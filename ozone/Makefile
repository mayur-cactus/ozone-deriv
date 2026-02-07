.PHONY: help init plan apply deploy deploy-lambda test clean destroy

# Variables
ENV ?= dev
REGION ?= us-east-1

# Colors for output
COLOR_RESET = \033[0m
COLOR_BOLD = \033[1m
COLOR_GREEN = \033[32m
COLOR_YELLOW = \033[33m
COLOR_BLUE = \033[34m

help: ## Show this help message
	@echo "$(COLOR_BOLD)AI WAF - Available Commands$(COLOR_RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(COLOR_GREEN)%-20s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(COLOR_YELLOW)Usage:$(COLOR_RESET)"
	@echo "  make <command> [ENV=dev|staging|prod]"
	@echo ""
	@echo "$(COLOR_YELLOW)Examples:$(COLOR_RESET)"
	@echo "  make init                 # Initialize Terraform"
	@echo "  make plan ENV=dev         # Plan dev deployment"
	@echo "  make deploy ENV=prod      # Deploy to production"
	@echo "  make test                 # Run attack scenarios"

check-aws: ## Check AWS credentials
	@echo "$(COLOR_BLUE)Checking AWS credentials...$(COLOR_RESET)"
	@aws sts get-caller-identity > /dev/null 2>&1 || (echo "$(COLOR_YELLOW)AWS credentials not configured. Run 'aws configure'$(COLOR_RESET)" && exit 1)
	@echo "$(COLOR_GREEN)✓ AWS credentials OK$(COLOR_RESET)"

check-terraform: ## Check Terraform installation
	@echo "$(COLOR_BLUE)Checking Terraform...$(COLOR_RESET)"
	@command -v terraform > /dev/null 2>&1 || (echo "$(COLOR_YELLOW)Terraform not installed$(COLOR_RESET)" && exit 1)
	@echo "$(COLOR_GREEN)✓ Terraform OK ($(shell terraform version -json | jq -r '.terraform_version'))$(COLOR_RESET)"

check-prereqs: check-aws check-terraform ## Check all prerequisites
	@echo "$(COLOR_GREEN)✓ All prerequisites met$(COLOR_RESET)"

setup: ## Run initial setup (creates terraform.tfvars, checks prerequisites)
	@echo "$(COLOR_BLUE)Running initial setup...$(COLOR_RESET)"
	chmod +x scripts/setup.sh
	./scripts/setup.sh

init: check-prereqs ## Initialize Terraform
	@echo "$(COLOR_BLUE)Initializing Terraform...$(COLOR_RESET)"
	cd infra && terraform init -upgrade
	@echo "$(COLOR_GREEN)✓ Terraform initialized$(COLOR_RESET)"

validate: init ## Validate Terraform configuration
	@echo "$(COLOR_BLUE)Validating Terraform configuration...$(COLOR_RESET)"
	cd infra && terraform validate
	@echo "$(COLOR_GREEN)✓ Configuration valid$(COLOR_RESET)"

format: ## Format Terraform files
	@echo "$(COLOR_BLUE)Formatting Terraform files...$(COLOR_RESET)"
	terraform fmt -recursive infra/
	@echo "$(COLOR_GREEN)✓ Files formatted$(COLOR_RESET)"

plan: validate ## Plan Terraform deployment
	@echo "$(COLOR_BLUE)Planning deployment for $(ENV)...$(COLOR_RESET)"
	./scripts/deploy.sh $(ENV) plan

apply: validate ## Apply Terraform configuration
	@echo "$(COLOR_BLUE)Applying configuration for $(ENV)...$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)This will create/modify AWS resources$(COLOR_RESET)"
	./scripts/deploy.sh $(ENV) apply

deploy: apply deploy-lambda ## Full deployment (infrastructure + Lambda)
	@echo "$(COLOR_GREEN)✓ Deployment complete!$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BOLD)Outputs:$(COLOR_RESET)"
	@cd infra && terraform output

build-lambda: ## Build Lambda deployment package
	@echo "$(COLOR_BLUE)Building Lambda package...$(COLOR_RESET)"
	cd src/lambda/ai-waf-gateway && chmod +x build.sh && ./build.sh
	@echo "$(COLOR_GREEN)✓ Lambda package built$(COLOR_RESET)"

deploy-lambda: build-lambda ## Deploy Lambda code
	@echo "$(COLOR_BLUE)Deploying Lambda code...$(COLOR_RESET)"
	./scripts/deploy-lambda.sh
	@echo "$(COLOR_GREEN)✓ Lambda deployed$(COLOR_RESET)"

test: ## Run attack scenario tests
	@echo "$(COLOR_BLUE)Running attack scenario tests...$(COLOR_RESET)"
	chmod +x scripts/test-scenarios.sh
	./scripts/test-scenarios.sh

test-health: ## Test API health endpoint
	@echo "$(COLOR_BLUE)Testing health endpoint...$(COLOR_RESET)"
	@API_ENDPOINT=$$(cd infra && terraform output -raw api_endpoint 2>/dev/null) && \
	curl -s "$$API_ENDPOINT/health" | jq '.'

demo: ## Deploy interactive chatbot demo
	@echo "$(COLOR_BLUE)Deploying demo chatbot...$(COLOR_RESET)"
	chmod +x scripts/deploy-demo.sh
	./scripts/deploy-demo.sh

demo-local: ## Run demo chatbot locally
	@echo "$(COLOR_BLUE)Starting local demo server...$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)Make sure config.json is configured with your API endpoint$(COLOR_RESET)"
	@echo ""
	@echo "Opening browser at http://localhost:8080"
	@cd src/frontend && python3 -m http.server 8080

configure-frontend: ## Configure frontend API endpoint
	@echo "$(COLOR_BLUE)Configuring frontend...$(COLOR_RESET)"
	chmod +x scripts/configure-frontend.sh
	./scripts/configure-frontend.sh

deploy-frontend: demo ## Deploy frontend to S3 + CloudFront (alias for demo)

logs: ## Tail Lambda logs
	@echo "$(COLOR_BLUE)Tailing Lambda logs...$(COLOR_RESET)"
	@FUNCTION_NAME=$$(cd infra && terraform output -raw lambda_function_name 2>/dev/null) && \
	aws logs tail "/aws/lambda/$$FUNCTION_NAME" --follow

logs-waf: ## Tail WAF logs
	@echo "$(COLOR_BLUE)Tailing WAF logs...$(COLOR_RESET)"
	aws logs tail "/aws/waf/ai-waf-$(ENV)" --follow

metrics: ## Show CloudWatch metrics
	@echo "$(COLOR_BLUE)Fetching CloudWatch metrics...$(COLOR_RESET)"
	@aws cloudwatch list-metrics --namespace AI-WAF | jq '.Metrics[] | .MetricName' | sort | uniq

dashboard: ## Open CloudWatch dashboard
	@echo "$(COLOR_BLUE)Dashboard URL:$(COLOR_RESET)"
	@cd infra && terraform output cloudwatch_dashboard_url

outputs: ## Show Terraform outputs
	@cd infra && terraform output

state-list: ## List Terraform resources
	@cd infra && terraform state list

state-show: ## Show specific Terraform resource (usage: make state-show RESOURCE=module.vpc.aws_vpc.main)
	@cd infra && terraform state show $(RESOURCE)

clean: ## Clean build artifacts
	@echo "$(COLOR_BLUE)Cleaning build artifacts...$(COLOR_RESET)"
	rm -f src/lambda/ai-waf-gateway/deployment.zip
	rm -rf src/lambda/ai-waf-gateway/build
	rm -f infra/tfplan
	@echo "$(COLOR_GREEN)✓ Cleaned$(COLOR_RESET)"

destroy: ## Destroy all infrastructure (WARNING: DESTRUCTIVE)
	@echo "$(COLOR_YELLOW)WARNING: This will destroy all infrastructure in $(ENV)!$(COLOR_RESET)"
	@read -p "Are you sure? Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || exit 1
	./scripts/deploy.sh $(ENV) destroy

cost-estimate: ## Estimate monthly costs (requires infracost)
	@command -v infracost > /dev/null 2>&1 || (echo "$(COLOR_YELLOW)Install infracost: https://www.infracost.io/docs/$(COLOR_RESET)" && exit 1)
	@echo "$(COLOR_BLUE)Estimating costs...$(COLOR_RESET)"
	cd infra && infracost breakdown --path .

security-scan: ## Run security scan (requires tfsec)
	@command -v tfsec > /dev/null 2>&1 || (echo "$(COLOR_YELLOW)Install tfsec: https://github.com/aquasecurity/tfsec$(COLOR_RESET)" && exit 1)
	@echo "$(COLOR_BLUE)Running security scan...$(COLOR_RESET)"
	tfsec infra/

docs: ## Generate documentation
	@echo "$(COLOR_BLUE)Documentation files:$(COLOR_RESET)"
	@ls -1 docs/*.md README.md SETUP_COMPLETE.md

invoke-lambda: ## Invoke Lambda directly with test payload
	@echo "$(COLOR_BLUE)Invoking Lambda...$(COLOR_RESET)"
	@FUNCTION_NAME=$$(cd infra && terraform output -raw lambda_function_name 2>/dev/null) && \
	echo '{"body":"{\"prompt\":\"test\",\"user_id\":\"test\"}","rawPath":"/chat"}' > /tmp/test-event.json && \
	aws lambda invoke \
		--function-name "$$FUNCTION_NAME" \
		--payload file:///tmp/test-event.json \
		--cli-binary-format raw-in-base64-out \
		/tmp/response.json && \
	cat /tmp/response.json | jq '.' && \
	rm /tmp/test-event.json /tmp/response.json

quick-start: ## Quick start guide
	@cat docs/QUICKSTART.md

architecture: ## Show architecture documentation
	@cat docs/ARCHITECTURE.md

setup-complete: ## Show setup completion guide
	@cat SETUP_COMPLETE.md

# Development helpers
dev-setup: init ## Setup development environment
	@echo "$(COLOR_BLUE)Setting up development environment...$(COLOR_RESET)"
	cp infra/terraform.tfvars.example infra/terraform.tfvars || true
	@echo "$(COLOR_YELLOW)Edit infra/terraform.tfvars with your settings$(COLOR_RESET)"
	@echo "$(COLOR_GREEN)✓ Development environment ready$(COLOR_RESET)"

dev-deploy: ## Quick dev deployment
	@$(MAKE) deploy ENV=dev

dev-test: ## Quick dev test
	@$(MAKE) test

dev-logs: ## View dev logs
	@$(MAKE) logs

# CI/CD helpers
ci-validate: check-prereqs validate ## CI validation
	@echo "$(COLOR_GREEN)✓ CI validation passed$(COLOR_RESET)"

ci-plan: ci-validate ## CI plan
	@$(MAKE) plan ENV=$(ENV)

ci-apply: ci-validate ## CI apply
	@$(MAKE) apply ENV=$(ENV)

# Info commands
version: ## Show version information
	@echo "$(COLOR_BOLD)Version Information$(COLOR_RESET)"
	@echo "Terraform: $$(terraform version -json | jq -r '.terraform_version')"
	@echo "AWS CLI: $$(aws --version | cut -d' ' -f1)"
	@echo "Python: $$(python3 --version)"
	@echo "Region: $(REGION)"
	@echo "Environment: $(ENV)"

whoami: check-aws ## Show current AWS identity
	@echo "$(COLOR_BOLD)AWS Identity$(COLOR_RESET)"
	@aws sts get-caller-identity | jq '.'

regions: ## List available AWS regions
	@aws ec2 describe-regions --query 'Regions[].RegionName' --output table

# Utility commands
zip-project: ## Create project archive
	@echo "$(COLOR_BLUE)Creating project archive...$(COLOR_RESET)"
	@timestamp=$$(date +%Y%m%d-%H%M%S) && \
	tar -czf "ai-waf-$$timestamp.tar.gz" \
		--exclude='.git' \
		--exclude='*.tfstate*' \
		--exclude='.terraform' \
		--exclude='*.zip' \
		--exclude='node_modules' \
		--exclude='__pycache__' \
		. && \
	echo "$(COLOR_GREEN)✓ Archive created: ai-waf-$$timestamp.tar.gz$(COLOR_RESET)"

backup-state: ## Backup Terraform state
	@echo "$(COLOR_BLUE)Backing up Terraform state...$(COLOR_RESET)"
	@timestamp=$$(date +%Y%m%d-%H%M%S) && \
	cd infra && \
	terraform state pull > "../terraform-state-backup-$$timestamp.json" && \
	echo "$(COLOR_GREEN)✓ State backed up: terraform-state-backup-$$timestamp.json$(COLOR_RESET)"

.DEFAULT_GOAL := help
