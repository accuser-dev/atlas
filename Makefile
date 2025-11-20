# Atlas Infrastructure Makefile
# Manages Docker image builds and Terraform deployments

.PHONY: help build-all build-caddy build-grafana build-loki build-prometheus \
        list-images \
        terraform-init terraform-plan terraform-apply terraform-destroy \
        deploy clean clean-docker clean-terraform format

# Default target
help:
	@echo "Atlas Infrastructure Management"
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
	@echo "      Images are published to ghcr.io/accuser/atlas/atlas-*:latest"
	@echo ""
	@echo "Terraform Commands:"
	@echo "  make terraform-init    - Initialize Terraform"
	@echo "  make terraform-plan    - Plan Terraform changes"
	@echo "  make terraform-apply   - Apply Terraform changes"
	@echo "  make terraform-destroy - Destroy infrastructure"
	@echo ""
	@echo "Deployment Commands:"
	@echo "  make deploy            - Apply Terraform (pulls images from ghcr.io)"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make format            - Format Terraform files"
	@echo "  make clean             - Clean all build artifacts"
	@echo "  make clean-docker      - Clean Docker build cache"
	@echo "  make clean-terraform   - Clean Terraform state and cache"

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

# Terraform commands
terraform-init:
	@echo "Initializing Terraform..."
	cd terraform && terraform init

terraform-plan:
	@echo "Planning Terraform changes..."
	cd terraform && terraform plan

terraform-apply:
	@echo "Applying Terraform changes..."
	cd terraform && terraform apply

terraform-destroy:
	@echo "Destroying infrastructure..."
	cd terraform && terraform destroy

# Combined deployment
deploy: terraform-apply
	@echo "Deployment complete!"
	@echo ""
	@echo "Run 'cd terraform && terraform output' to see endpoints"

# Cleanup targets
clean: clean-docker clean-terraform
	@echo "Cleanup complete"

clean-docker:
	@echo "Cleaning Docker build cache..."
	docker builder prune -f

clean-terraform:
	@echo "Cleaning Terraform cache..."
	rm -rf terraform/.terraform
	rm -f terraform/.terraform.lock.hcl
	@echo "Note: Terraform state files preserved"

# Development helpers
format:
	@echo "Formatting Terraform files..."
	cd terraform && terraform fmt -recursive
