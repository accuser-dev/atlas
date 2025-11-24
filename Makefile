# Atlas Infrastructure Makefile
# Manages Docker image builds and OpenTofu deployments

.PHONY: help build-all build-caddy build-grafana build-loki build-prometheus \
        list-images \
        bootstrap bootstrap-init bootstrap-plan bootstrap-apply \
        init plan apply destroy import clean-incus \
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
	@echo "  make import            - Import existing Incus resources into state"
	@echo "  make clean-incus       - Remove orphaned Incus resources not in state"
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
	@echo "=========================================="
	@echo "WARNING: Applying infrastructure changes"
	@echo "=========================================="
	@echo ""
	@echo "This will modify your infrastructure based on the current configuration."
	@echo ""
	@echo "Recommended: Review the plan first with 'make plan'"
	@echo ""
	@echo "OpenTofu will prompt for confirmation before applying."
	@echo ""
	cd terraform && tofu apply

destroy:
	@echo "=========================================="
	@echo "⚠️  WARNING: DESTRUCTIVE OPERATION"
	@echo "=========================================="
	@echo ""
	@echo "This will DESTROY all infrastructure managed by OpenTofu:"
	@echo "  - All containers (caddy01, grafana01, loki01, prometheus01, step-ca01)"
	@echo "  - All storage volumes (data will be DELETED)"
	@echo "  - All profiles"
	@echo "  - All networks"
	@echo ""
	@echo "This action is IRREVERSIBLE!"
	@echo ""
	@echo "OpenTofu will prompt for confirmation before destroying."
	@echo ""
	cd terraform && tofu destroy

# Import existing resources into state
import:
	@echo "Importing existing Incus resources into OpenTofu state..."
	@echo "This will import networks, profiles, volumes, and instances that already exist."
	@echo ""
	@cd terraform && \
	for net in development testing staging production management; do \
		if incus network show $$net >/dev/null 2>&1; then \
			echo "Importing network: $$net"; \
			tofu import "incus_network.$$net" "$$net" 2>/dev/null || true; \
		fi; \
	done; \
	for svc in caddy grafana loki prometheus step-ca; do \
		if incus profile show $$svc >/dev/null 2>&1; then \
			echo "Importing profile: $$svc"; \
			case $$svc in \
				caddy) tofu import "module.caddy01.incus_profile.caddy" "$$svc" 2>/dev/null || true ;; \
				grafana) tofu import "module.grafana01.incus_profile.grafana" "$$svc" 2>/dev/null || true ;; \
				loki) tofu import "module.loki01.incus_profile.loki" "$$svc" 2>/dev/null || true ;; \
				prometheus) tofu import "module.prometheus01.incus_profile.prometheus" "$$svc" 2>/dev/null || true ;; \
				step-ca) tofu import "module.step_ca01.incus_profile.step_ca" "$$svc" 2>/dev/null || true ;; \
			esac; \
		fi; \
	done; \
	for vol in grafana01-data loki01-data prometheus01-data step-ca01-data; do \
		if incus storage volume show local $$vol >/dev/null 2>&1; then \
			echo "Importing volume: $$vol"; \
			case $$vol in \
				grafana01-data) tofu import "module.grafana01.incus_storage_volume.grafana_data[0]" "local/$$vol" 2>/dev/null || true ;; \
				loki01-data) tofu import "module.loki01.incus_storage_volume.loki_data[0]" "local/$$vol" 2>/dev/null || true ;; \
				prometheus01-data) tofu import "module.prometheus01.incus_storage_volume.prometheus_data[0]" "local/$$vol" 2>/dev/null || true ;; \
				step-ca01-data) tofu import "module.step_ca01.incus_storage_volume.step_ca_data[0]" "local/$$vol" 2>/dev/null || true ;; \
			esac; \
		fi; \
	done; \
	for inst in caddy01 grafana01 loki01 prometheus01 step-ca01; do \
		if incus info $$inst >/dev/null 2>&1; then \
			echo "Importing instance: $$inst"; \
			case $$inst in \
				caddy01) tofu import "module.caddy01.incus_instance.caddy" "$$inst" 2>/dev/null || true ;; \
				grafana01) tofu import "module.grafana01.incus_instance.grafana" "$$inst" 2>/dev/null || true ;; \
				loki01) tofu import "module.loki01.incus_instance.loki" "$$inst" 2>/dev/null || true ;; \
				prometheus01) tofu import "module.prometheus01.incus_instance.prometheus" "$$inst" 2>/dev/null || true ;; \
				step-ca01) tofu import "module.step_ca01.incus_instance.step_ca" "$$inst" 2>/dev/null || true ;; \
			esac; \
		fi; \
	done
	@echo ""
	@echo "Import complete. Run 'make plan' to see any remaining drift."

# Clean orphaned Incus resources (not managed by Terraform)
clean-incus:
	@echo "Removing orphaned Incus resources..."
	@echo "This will remove instances, profiles, and volumes not managed by OpenTofu."
	@echo ""
	@echo "WARNING: This is destructive! Press Ctrl+C within 5 seconds to cancel..."
	@sleep 5
	@echo ""
	@echo "Stopping and removing instances..."
	@for inst in caddy01 grafana01 loki01 prometheus01 step-ca01; do \
		if incus info $$inst >/dev/null 2>&1; then \
			echo "  Removing instance: $$inst"; \
			incus delete $$inst --force 2>/dev/null || true; \
		fi; \
	done
	@echo "Removing old-style profiles (instance-specific names)..."
	@for profile in caddy01 grafana01 loki01 prometheus01 step-ca01; do \
		if incus profile show $$profile >/dev/null 2>&1; then \
			echo "  Removing profile: $$profile"; \
			incus profile delete $$profile 2>/dev/null || true; \
		fi; \
	done
	@echo "Removing new-style profiles (generic names)..."
	@for profile in caddy grafana loki prometheus step-ca; do \
		if incus profile show $$profile >/dev/null 2>&1; then \
			echo "  Removing profile: $$profile"; \
			incus profile delete $$profile 2>/dev/null || true; \
		fi; \
	done
	@echo "Removing storage volumes..."
	@for vol in grafana01-data loki01-data prometheus01-data step-ca01-data; do \
		if incus storage volume show local $$vol >/dev/null 2>&1; then \
			echo "  Removing volume: $$vol"; \
			incus storage volume delete local $$vol 2>/dev/null || true; \
		fi; \
	done
	@echo "Removing networks..."
	@for net in development testing staging production management; do \
		if incus network show $$net >/dev/null 2>&1; then \
			echo "  Removing network: $$net"; \
			incus network delete $$net 2>/dev/null || true; \
		fi; \
	done
	@echo ""
	@echo "Cleanup complete. Run 'make deploy' for a fresh deployment."

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
