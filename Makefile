# Atlas Infrastructure Makefile
# Manages Docker image builds and OpenTofu deployments

.PHONY: help build-all build-atlantis build-caddy build-grafana build-loki build-prometheus \
        list-images \
        bootstrap bootstrap-init bootstrap-plan bootstrap-apply \
        init plan apply destroy import clean-incus clean-images \
        deploy validate clean clean-docker clean-tofu clean-bootstrap format \
        backup-snapshot backup-export backup-list \
        test test-health test-connectivity test-storage test-network

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
	@echo "  make build-atlantis    - Build Atlantis image"
	@echo "  make build-caddy       - Build Caddy image"
	@echo "  make build-grafana     - Build Grafana image"
	@echo "  make build-loki        - Build Loki image"
	@echo "  make build-prometheus  - Build Prometheus image"
	@echo "  make list-images       - List Docker images"
	@echo ""
	@echo "Note: Production images are built and published via GitHub Actions"
	@echo "      Images are published to ghcr.io/accuser-dev/atlas/*:latest"
	@echo ""
	@echo "OpenTofu Commands:"
	@echo "  make init              - Initialize OpenTofu with remote backend"
	@echo "  make plan              - Plan OpenTofu changes"
	@echo "  make apply             - Apply OpenTofu changes"
	@echo "  make destroy           - Destroy infrastructure and remove cached images"
	@echo "  make import            - Import existing Incus resources into state"
	@echo "  make clean-incus       - Remove orphaned Incus resources not in state"
	@echo "  make clean-images      - Remove Atlas images from Incus cache"
	@echo ""
	@echo "Deployment Commands:"
	@echo "  make validate          - Run pre-deployment validation checks"
	@echo "  make deploy            - Apply OpenTofu (pulls images from ghcr.io)"
	@echo ""
	@echo "Backup Commands:"
	@echo "  make backup-snapshot   - Create snapshots of all storage volumes"
	@echo "  make backup-export     - Export all volumes to tarballs (stops services)"
	@echo "  make backup-list       - List all volume snapshots"
	@echo ""
	@echo "Test Commands:"
	@echo "  make test              - Run all integration tests"
	@echo "  make test-health       - Run service health tests"
	@echo "  make test-connectivity - Run service connectivity tests"
	@echo "  make test-storage      - Run storage tests"
	@echo "  make test-network      - Run network isolation tests"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make format            - Format OpenTofu files"
	@echo "  make clean             - Clean all build artifacts"
	@echo "  make clean-docker      - Clean Docker build cache"
	@echo "  make clean-tofu        - Clean OpenTofu state and cache"
	@echo "  make clean-bootstrap   - Clean bootstrap OpenTofu state"

# Docker image configuration
IMAGE_TAG ?= latest

# =============================================================================
# Service Configuration
# =============================================================================
# NOTE: When adding new services, update these lists:
#   - ATLAS_SERVICES: All container instance names
#   - ATLAS_VOLUMES: All storage volume names
#   - ATLAS_PROFILES: All profile names (generic, not instance-specific)
#   - ATLAS_NETWORKS: All network names
#
# The import and clean-incus targets use module name mappings defined inline
# due to Terraform naming conventions (e.g., step-ca -> step_ca01).
# =============================================================================

ATLAS_NETWORKS := development testing staging production management
ATLAS_PROFILES := caddy grafana loki prometheus step-ca node-exporter alertmanager mosquitto cloudflared
ATLAS_SERVICES := caddy01 grafana01 loki01 prometheus01 step-ca01 node-exporter01 alertmanager01 mosquitto01 cloudflared01
ATLAS_VOLUMES := grafana01-data prometheus01-data loki01-data step-ca01-data alertmanager01-data mosquitto01-data

# Docker image names (local builds for testing)
ATLANTIS_IMAGE := atlas/atlantis:$(IMAGE_TAG)
CADDY_IMAGE := atlas/caddy:$(IMAGE_TAG)
GRAFANA_IMAGE := atlas/grafana:$(IMAGE_TAG)
LOKI_IMAGE := atlas/loki:$(IMAGE_TAG)
PROMETHEUS_IMAGE := atlas/prometheus:$(IMAGE_TAG)

# Build all Docker images
build-all: build-atlantis build-caddy build-grafana build-loki build-prometheus
	@echo "All images built successfully"

# Build individual Docker images
build-atlantis:
	@echo "Building Atlantis image..."
	docker build -t $(ATLANTIS_IMAGE) docker/atlantis/
	@echo "Atlantis image built: $(ATLANTIS_IMAGE)"

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
	@echo "  - All containers ($(ATLAS_SERVICES))"
	@echo "  - All storage volumes (data will be DELETED)"
	@echo "  - All profiles"
	@echo "  - All networks"
	@echo "  - All cached container images"
	@echo ""
	@echo "This action is IRREVERSIBLE!"
	@echo ""
	@echo "OpenTofu will prompt for confirmation before destroying."
	@echo ""
	cd terraform && tofu destroy
	@$(MAKE) clean-images

# Clean cached Incus images
clean-images:
	@echo "Removing Atlas container images from Incus cache..."
	@echo ""
	@images=$$(incus image list --format csv 2>/dev/null | grep -E "ghcr.io/accuser-dev/atlas" | cut -d',' -f2); \
	if [ -z "$$images" ]; then \
		echo "No Atlas images found in cache."; \
	else \
		for fingerprint in $$images; do \
			alias=$$(incus image list --format csv 2>/dev/null | grep "$$fingerprint" | cut -d',' -f1); \
			echo "  Removing: $$alias ($$fingerprint)"; \
			incus image delete "$$fingerprint" 2>/dev/null || true; \
		done; \
		echo ""; \
		echo "Image cleanup complete."; \
	fi

# Import existing resources into state
# Note: Module names use underscores (step_ca01) while Incus uses hyphens (step-ca01)
import:
	@echo "Importing existing Incus resources into OpenTofu state..."
	@echo "This will import networks, profiles, volumes, and instances that already exist."
	@echo ""
	@cd terraform && \
	for net in $(ATLAS_NETWORKS); do \
		if incus network show $$net >/dev/null 2>&1; then \
			echo "Importing network: $$net"; \
			tofu import "incus_network.$$net" "$$net" 2>/dev/null || true; \
		fi; \
	done
	@cd terraform && \
	for profile in $(ATLAS_PROFILES); do \
		if incus profile show $$profile >/dev/null 2>&1; then \
			echo "Importing profile: $$profile"; \
			module=$$(echo $$profile | tr '-' '_'); \
			tofu import "module.$${module}01.incus_profile.$$module" "$$profile" 2>/dev/null || true; \
		fi; \
	done
	@cd terraform && \
	for vol in $(ATLAS_VOLUMES); do \
		if incus storage volume show local $$vol >/dev/null 2>&1; then \
			echo "Importing volume: $$vol"; \
			base=$$(echo $$vol | sed 's/-data$$//'); \
			module=$$(echo $$base | tr '-' '_'); \
			resource=$$(echo $$base | sed 's/01$$//' | tr '-' '_'); \
			tofu import "module.$$module.incus_storage_volume.$${resource}_data[0]" "local/$$vol" 2>/dev/null || true; \
		fi; \
	done
	@cd terraform && \
	for inst in $(ATLAS_SERVICES); do \
		if incus info $$inst >/dev/null 2>&1; then \
			echo "Importing instance: $$inst"; \
			module=$$(echo $$inst | tr '-' '_'); \
			resource=$$(echo $$inst | sed 's/01$$//' | tr '-' '_'); \
			tofu import "module.$$module.incus_instance.$$resource" "$$inst" 2>/dev/null || true; \
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
	@for inst in $(ATLAS_SERVICES); do \
		if incus info $$inst >/dev/null 2>&1; then \
			echo "  Removing instance: $$inst"; \
			incus delete $$inst --force 2>/dev/null || true; \
		fi; \
	done
	@echo "Removing profiles..."
	@for profile in $(ATLAS_PROFILES); do \
		if incus profile show $$profile >/dev/null 2>&1; then \
			echo "  Removing profile: $$profile"; \
			incus profile delete $$profile 2>/dev/null || true; \
		fi; \
	done
	@echo "Removing storage volumes..."
	@for vol in $(ATLAS_VOLUMES); do \
		if incus storage volume show local $$vol >/dev/null 2>&1; then \
			echo "  Removing volume: $$vol"; \
			incus storage volume delete local $$vol 2>/dev/null || true; \
		fi; \
	done
	@echo "Removing networks..."
	@for net in $(ATLAS_NETWORKS); do \
		if incus network show $$net >/dev/null 2>&1; then \
			echo "  Removing network: $$net"; \
			incus network delete $$net 2>/dev/null || true; \
		fi; \
	done
	@echo ""
	@echo "Cleanup complete. Run 'make deploy' for a fresh deployment."

# Pre-deployment validation
validate:
	@terraform/scripts/validate.sh

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

# Backup commands
backup-snapshot:
	@echo "Creating snapshots of all Atlas storage volumes..."
	@TIMESTAMP=$$(date +%Y%m%d-%H%M%S); \
	for vol in $(ATLAS_VOLUMES); do \
		if incus storage volume show local $$vol >/dev/null 2>&1; then \
			echo "  Snapshotting: $$vol -> backup-$$TIMESTAMP"; \
			incus storage volume snapshot local $$vol "backup-$$TIMESTAMP"; \
		else \
			echo "  Skipping (not found): $$vol"; \
		fi; \
	done
	@echo ""
	@echo "Snapshots created successfully."
	@echo "Use 'make backup-list' to view snapshots."

backup-export:
	@echo "=========================================="
	@echo "WARNING: This will stop all services"
	@echo "=========================================="
	@echo ""
	@echo "Exporting volumes to: ./backups/$$(date +%Y%m%d)/"
	@echo ""
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@BACKUP_DIR="./backups/$$(date +%Y%m%d)"; \
	mkdir -p "$$BACKUP_DIR"; \
	echo "Stopping services..."; \
	for svc in $(ATLAS_SERVICES); do \
		incus stop $$svc 2>/dev/null || true; \
	done; \
	echo "Exporting volumes..."; \
	for vol in $(ATLAS_VOLUMES); do \
		if incus storage volume show local $$vol >/dev/null 2>&1; then \
			echo "  Exporting: $$vol"; \
			incus storage volume export local $$vol "$$BACKUP_DIR/$$vol.tar.gz"; \
		fi; \
	done; \
	echo "Starting services..."; \
	for svc in $(ATLAS_SERVICES); do \
		incus start $$svc 2>/dev/null || true; \
	done; \
	echo ""; \
	echo "Backup complete: $$BACKUP_DIR"; \
	ls -lh "$$BACKUP_DIR"

backup-list:
	@echo "Atlas Storage Volume Snapshots"
	@echo "=============================="
	@for vol in $(ATLAS_VOLUMES); do \
		if incus storage volume show local $$vol >/dev/null 2>&1; then \
			echo ""; \
			echo "$$vol:"; \
			incus storage volume info local $$vol 2>/dev/null | grep -A 100 "Snapshots:" | grep -E "^\s+-\s+|^\s+name:" | head -20 || echo "  (no snapshots)"; \
		fi; \
	done

# Integration test targets
test:
	@./test/integration/run-tests.sh

test-health:
	@./test/integration/run-tests.sh health

test-connectivity:
	@./test/integration/run-tests.sh connectivity

test-storage:
	@./test/integration/run-tests.sh storage

test-network:
	@./test/integration/run-tests.sh network
