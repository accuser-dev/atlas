# Atlas Infrastructure Makefile
# Manages Docker image builds and Terraform deployments

.PHONY: help \
        setup bootstrap init plan apply destroy \
        bootstrap-init bootstrap-plan bootstrap-apply \
        terraform-init terraform-plan terraform-apply terraform-destroy \
        build-all build-caddy build-grafana build-loki build-prometheus \
        list-images format clean clean-docker clean-terraform clean-bootstrap

# Default target
help:
	@echo "Atlas Infrastructure Management"
	@echo ""
	@echo "Quick Start (fresh installation):"
	@echo "  make setup             - Complete setup: bootstrap + init + plan"
	@echo ""
	@echo "Standard Workflow:"
	@echo "  make bootstrap         - One-time setup (creates state bucket + init)"
	@echo "  make plan              - Plan infrastructure changes"
	@echo "  make apply             - Apply infrastructure changes"
	@echo "  make destroy           - Destroy all infrastructure"
	@echo ""
	@echo "Docker Commands:"
	@echo "  make build-all         - Build all Docker images locally"
	@echo "  make build-<service>   - Build specific image (caddy/grafana/loki/prometheus)"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make init              - Re-initialize Terraform (after provider changes)"
	@echo "  make format            - Format Terraform files"
	@echo "  make clean             - Clean all build artifacts"
	@echo ""
	@echo "Note: Production images are published via GitHub Actions to ghcr.io"

#==============================================================================
# Primary Workflow Commands
#==============================================================================

# Complete setup from scratch
setup: bootstrap plan
	@echo ""
	@echo "========================================"
	@echo "Setup complete!"
	@echo "========================================"
	@echo ""
	@echo "Review the plan above, then run:"
	@echo "  make apply"

# One-time bootstrap (creates storage bucket and initializes terraform)
bootstrap: _check_incus bootstrap-init bootstrap-apply init
	@echo ""
	@echo "========================================"
	@echo "Bootstrap complete!"
	@echo "========================================"
	@echo ""
	@echo "Next: Run 'make plan' to see infrastructure changes"

# Initialize terraform (with auto-bootstrap check)
init:
	@if [ ! -f terraform/backend.hcl ]; then \
		echo "ERROR: backend.hcl not found. Run 'make bootstrap' first."; \
		exit 1; \
	fi
	@echo "Initializing Terraform..."
	@cd terraform && terraform init -backend-config=backend.hcl

# Plan changes (Atlantis-compatible)
plan: _ensure_init
	@echo "Planning infrastructure changes..."
	@cd terraform && terraform plan

# Apply changes (Atlantis-compatible)
apply: _ensure_init
	@echo "Applying infrastructure changes..."
	@cd terraform && terraform apply
	@echo ""
	@echo "Deployment complete! Run 'cd terraform && terraform output' for endpoints."

# Destroy infrastructure
destroy: _ensure_init
	@echo "Destroying infrastructure..."
	@cd terraform && terraform destroy

#==============================================================================
# Bootstrap Sub-commands (for debugging/advanced use)
#==============================================================================

bootstrap-init:
	@echo "Initializing bootstrap Terraform..."
	@cd terraform/bootstrap && terraform init

bootstrap-plan:
	@echo "Planning bootstrap changes..."
	@cd terraform/bootstrap && terraform plan

bootstrap-apply:
	@echo "Creating state storage bucket..."
	@cd terraform/bootstrap && terraform apply -auto-approve
	@echo "Backend configuration saved to: terraform/backend.hcl"

#==============================================================================
# Terraform Aliases (backwards compatibility)
#==============================================================================

terraform-init: init
terraform-plan: plan
terraform-apply: apply
terraform-destroy: destroy
deploy: apply

#==============================================================================
# Docker Commands
#==============================================================================

IMAGE_TAG ?= latest
CADDY_IMAGE := atlas/caddy:$(IMAGE_TAG)
GRAFANA_IMAGE := atlas/grafana:$(IMAGE_TAG)
LOKI_IMAGE := atlas/loki:$(IMAGE_TAG)
PROMETHEUS_IMAGE := atlas/prometheus:$(IMAGE_TAG)

build-all: build-caddy build-grafana build-loki build-prometheus
	@echo "All images built successfully"

build-caddy:
	@echo "Building Caddy image..."
	@docker build -t $(CADDY_IMAGE) docker/caddy/

build-grafana:
	@echo "Building Grafana image..."
	@docker build -t $(GRAFANA_IMAGE) docker/grafana/

build-loki:
	@echo "Building Loki image..."
	@docker build -t $(LOKI_IMAGE) docker/loki/

build-prometheus:
	@echo "Building Prometheus image..."
	@docker build -t $(PROMETHEUS_IMAGE) docker/prometheus/

list-images:
	@docker images | grep -E "(REPOSITORY|atlas)" || echo "No atlas images found"

#==============================================================================
# Utility Commands
#==============================================================================

format:
	@echo "Formatting Terraform files..."
	@cd terraform && terraform fmt -recursive

clean: clean-docker clean-terraform
	@echo "Cleanup complete"

clean-docker:
	@echo "Cleaning Docker build cache..."
	@docker builder prune -f 2>/dev/null || true

clean-terraform:
	@echo "Cleaning Terraform cache..."
	@rm -rf terraform/.terraform
	@rm -f terraform/.terraform.lock.hcl

clean-bootstrap:
	@echo "Cleaning bootstrap Terraform..."
	@rm -rf terraform/bootstrap/.terraform
	@rm -f terraform/bootstrap/.terraform.lock.hcl
	@rm -f terraform/bootstrap/.credentials

#==============================================================================
# Internal Helpers
#==============================================================================

_check_incus:
	@command -v incus >/dev/null 2>&1 || { \
		echo "ERROR: incus command not found."; \
		echo "Please install Incus first: https://linuxcontainers.org/incus/"; \
		exit 1; \
	}

_ensure_init:
	@if [ ! -f terraform/backend.hcl ]; then \
		echo "ERROR: backend.hcl not found. Run 'make bootstrap' first."; \
		exit 1; \
	fi
	@if [ ! -d terraform/.terraform ] || [ ! -f terraform/.terraform/terraform.tfstate ]; then \
		echo "Terraform not initialized. Running init..."; \
		cd terraform && terraform init -backend-config=backend.hcl; \
	fi
