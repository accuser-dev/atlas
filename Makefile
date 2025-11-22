# Atlas Infrastructure Makefile
# Manages Docker image builds and OpenTofu deployments

.PHONY: help build-all build-caddy build-grafana build-loki build-prometheus \
        list-images \
        bootstrap bootstrap-init bootstrap-plan bootstrap-apply \
        init plan apply destroy \
        deploy clean clean-docker clean-tofu clean-bootstrap format

# Default target
help:
	@echo "Atlas Infrastructure Management"
	@echo ""
	@echo "Bootstrap Commands (run once for fresh Incus installation):"
	@echo "  make bootstrap         - Complete bootstrap process (init + apply)"
	@echo "  make bootstrap-init    - Initialize bootstrap OpenTofu"
	@echo "  make bootstrap-plan    - Plan bootstrap changes"
	@echo "  make bootstrap-apply   - Apply bootstrap (creates storage bucket)"
	@echo ""
	@echo "Docker Commands:"
	@echo "  make build-all         - Build all Docker images locally (for testing)"
	@echo "  make build-caddy       - Build Caddy image"
	@echo "  make build-grafana     - Build Grafana image"
	@echo "  make build-loki        - Build Loki image"
	@echo "  make build-prometheus  - Build Prometheus image"
	@echo "  make list-images       - List Docker images"
	@echo ""
	@echo "Note: Production images are built and published via GitHub Actions"
	@echo "      Images are published to ghcr.io/accuser/atlas/*:latest"
	@echo ""
	@echo "OpenTofu Commands:"
	@echo "  make init              - Initialize OpenTofu with remote backend"
	@echo "  make plan              - Plan OpenTofu changes"
	@echo "  make apply             - Apply OpenTofu changes"
	@echo "  make destroy           - Destroy infrastructure"
	@echo ""
	@echo "Deployment Commands:"
	@echo "  make deploy            - Apply OpenTofu (pulls images from ghcr.io)"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make format            - Format OpenTofu files"
	@echo "  make clean             - Clean all build artifacts"
	@echo "  make clean-docker      - Clean Docker build cache"
	@echo "  make clean-tofu        - Clean OpenTofu state and cache"
	@echo "  make clean-bootstrap   - Clean bootstrap OpenTofu state"

# Docker image configuration
IMAGE_TAG ?= latest

# Docker image names (local builds for testing)
CADDY_IMAGE := atlas/caddy:$(IMAGE_TAG)
GRAFANA_IMAGE := atlas/grafana:$(IMAGE_TAG)
LOKI_IMAGE := atlas/loki:$(IMAGE_TAG)
PROMETHEUS_IMAGE := atlas/prometheus:$(IMAGE_TAG)

# Build all Docker images
build-all: build-caddy build-grafana build-loki build-prometheus
	@echo "All images built successfully"

# Build individual Docker images
build-caddy:
	@echo "Building Caddy image..."
	docker build -t $(CADDY_IMAGE) docker/caddy/
	@echo "Caddy image built: $(CADDY_IMAGE)"

build-grafana:
	@echo "Building Grafana image..."
	docker build -t $(GRAFANA_IMAGE) docker/grafana/
	@echo "Grafana image built: $(GRAFANA_IMAGE)"

build-loki:
	@echo "Building Loki image..."
	docker build -t $(LOKI_IMAGE) docker/loki/
	@echo "Loki image built: $(LOKI_IMAGE)"

build-prometheus:
	@echo "Building Prometheus image..."
	docker build -t $(PROMETHEUS_IMAGE) docker/prometheus/
	@echo "Prometheus image built: $(PROMETHEUS_IMAGE)"

# List Docker images
list-images:
	@echo "Atlas Docker images:"
	@docker images | grep -E "(REPOSITORY|atlas)" || echo "No atlas images found"

# Bootstrap commands
bootstrap: bootstrap-init bootstrap-apply
	@echo ""
	@echo "========================================"
	@echo "Bootstrap complete!"
	@echo "========================================"
	@echo ""
	@echo "Next steps:"
	@echo "1. Initialize main OpenTofu project:"
	@echo "   make init"
	@echo ""
	@echo "2. Deploy infrastructure:"
	@echo "   make deploy"

bootstrap-init:
	@echo "Initializing bootstrap OpenTofu..."
	cd terraform/bootstrap && tofu init

bootstrap-plan:
	@echo "Planning bootstrap changes..."
	cd terraform/bootstrap && tofu plan

bootstrap-apply:
	@echo "Applying bootstrap configuration..."
	@echo "This will create:"
	@echo "  - Incus storage buckets configuration"
	@echo "  - Storage pool for OpenTofu state"
	@echo "  - Storage bucket for OpenTofu state"
	@echo "  - S3 access credentials"
	@echo ""
	cd terraform/bootstrap && tofu apply
	@echo ""
	@echo "Bootstrap applied successfully!"
	@echo "Backend configuration saved to: terraform/backend.hcl"

# OpenTofu commands
init:
	@echo "Initializing OpenTofu with remote backend..."
	@if [ -f terraform/backend.hcl ]; then \
		cd terraform && tofu init -backend-config=backend.hcl; \
	else \
		echo "ERROR: backend.hcl not found!"; \
		echo ""; \
		echo "You must run bootstrap first:"; \
		echo "  make bootstrap"; \
		echo ""; \
		exit 1; \
	fi

plan:
	@echo "Planning OpenTofu changes..."
	cd terraform && tofu plan

apply:
	@echo "Applying OpenTofu changes..."
	cd terraform && tofu apply

destroy:
	@echo "Destroying infrastructure..."
	cd terraform && tofu destroy

# Combined deployment
deploy: apply
	@echo "Deployment complete!"
	@echo ""
	@echo "Run 'cd terraform && tofu output' to see endpoints"

# Cleanup targets
clean: clean-docker clean-tofu
	@echo "Cleanup complete"

clean-docker:
	@echo "Cleaning Docker build cache..."
	docker builder prune -f

clean-tofu:
	@echo "Cleaning OpenTofu cache..."
	rm -rf terraform/.terraform
	rm -f terraform/.terraform.lock.hcl
	@echo "Note: OpenTofu state files preserved"

clean-bootstrap:
	@echo "Cleaning bootstrap OpenTofu..."
	rm -rf terraform/bootstrap/.terraform
	rm -f terraform/bootstrap/.terraform.lock.hcl
	rm -f terraform/bootstrap/.credentials
	@echo "Note: Bootstrap state files preserved"

# Development helpers
format:
	@echo "Formatting OpenTofu files..."
	cd terraform && tofu fmt -recursive
