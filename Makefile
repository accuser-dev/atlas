# Atlas Infrastructure Makefile
# Manages Docker image builds and OpenTofu deployments for multiple environments

# Environment selection (default: iapetus)
ENV ?= iapetus
ENV_DIR := environments/$(ENV)

# Incus remote for cluster environments (empty for local)
INCUS_REMOTE := $(if $(filter cluster01,$(ENV)),cluster01:,)

.PHONY: help build-all build-atlantis \
        list-images \
        bootstrap bootstrap-init bootstrap-plan bootstrap-apply \
        init plan apply destroy import import-dynamic clean-incus clean-images \
        deploy deploy-full validate clean clean-docker clean-tofu clean-bootstrap format \
        backup-snapshot backup-export backup-list backup-dynamic \
        test test-health test-connectivity test-storage test-network \
        configure-ovn-chassis verify-ovn-chassis \
        ansible-setup configure configure-runner configure-runner-register \
        configure-prometheus configure-forgejo configure-forgejo-full \
        configure-postgresql configure-postgresql-full \
        configure-alertmanager configure-step-ca configure-step-ca-full \
        configure-mosquitto configure-mosquitto-full \
        configure-alloy configure-grafana configure-grafana-full \
        configure-loki configure-coredns \
        configure-openfga configure-openfga-full \
        configure-dex configure-dex-full

# Default target
help:
	@echo "Atlas Infrastructure Management"
	@echo ""
	@echo "Current environment: $(ENV)"
	@echo "Environment directory: $(ENV_DIR)"
	@echo ""
	@echo "Usage: make <target> [ENV=iapetus|cluster01]"
	@echo ""
	@echo "Bootstrap Commands (run once per environment):"
	@echo "  make bootstrap         - Complete bootstrap process (init + apply)"
	@echo "  make bootstrap-init    - Initialize bootstrap OpenTofu"
	@echo "  make bootstrap-plan    - Plan bootstrap changes"
	@echo "  make bootstrap-apply   - Apply bootstrap (creates storage bucket)"
	@echo ""
	@echo "Docker Commands:"
	@echo "  make build-all         - Build all Docker images locally (for testing)"
	@echo "  make build-atlantis    - Build Atlantis image"
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
	@echo "  make import            - Import existing Incus resources into state (legacy)"
	@echo "  make import-dynamic    - Import using dynamic discovery from tofu output"
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
	@echo "  make backup-dynamic    - Backup using dynamic discovery from tofu output"
	@echo ""
	@echo "Test Commands:"
	@echo "  make test              - Run all integration tests"
	@echo "  make test-health       - Run service health tests"
	@echo "  make test-connectivity - Run service connectivity tests"
	@echo "  make test-storage      - Run storage tests"
	@echo "  make test-network      - Run network isolation tests"
	@echo ""
	@echo "OVN Commands (cluster01 only):"
	@echo "  make configure-ovn-chassis ENV=cluster01  - Configure OVN on all cluster nodes"
	@echo "  make verify-ovn-chassis ENV=cluster01     - Verify OVN chassis registration"
	@echo ""
	@echo "Ansible Commands (Hybrid Terraform + Ansible):"
	@echo "  make ansible-setup                        - Install Ansible Galaxy requirements"
	@echo "  make configure                            - Run full Ansible configuration"
	@echo "  make configure-runner                     - Configure Forgejo runners only"
	@echo "  make configure-runner-register            - Configure + register (needs FORGEJO_RUNNER_TOKEN)"
	@echo "  make configure-alloy                      - Configure Alloy log collector"
	@echo "  make configure-grafana[-full]             - Configure Grafana (full needs GRAFANA_ADMIN_PASSWORD)"
	@echo "  make configure-loki                       - Configure Loki log aggregation"
	@echo "  make configure-coredns                    - Configure CoreDNS"
	@echo "  make configure-openfga[-full]             - Configure OpenFGA (full needs OPENFGA_PRESHARED_KEYS)"
	@echo "  make configure-dex[-full]                 - Configure Dex (full needs DEX_GITHUB_CLIENT_*)"
	@echo "  make deploy-full                          - Apply Terraform + run Ansible configure"
	@echo ""
	@echo "Utility Commands:
	@echo "  make format            - Format OpenTofu files"
	@echo "  make clean             - Clean all build artifacts"
	@echo "  make clean-docker      - Clean Docker build cache"
	@echo "  make clean-tofu        - Clean OpenTofu state and cache"
	@echo "  make clean-bootstrap   - Clean bootstrap OpenTofu state"
	@echo ""
	@echo "Examples:"
	@echo "  make plan                    # Plan iapetus (default)"
	@echo "  make plan ENV=cluster01      # Plan cluster01 environment"
	@echo "  make deploy ENV=iapetus      # Deploy to iapetus"
	@echo "  make bootstrap ENV=cluster01 # Bootstrap cluster01 environment"

# Docker image configuration
IMAGE_TAG ?= latest
STEP_VERSION := $(shell cat .step-version 2>/dev/null || echo "0.28.6")

# =============================================================================
# Service Configuration
# =============================================================================
# Resource mappings are now dynamically generated via 'tofu output managed_resources'
# Use 'make import-dynamic' and 'make clean-incus-dynamic' for automatic discovery.
#
# Legacy hardcoded lists are kept as fallback for environments without state.
# See outputs.tf managed_resources for authoritative mappings.
# =============================================================================

# Legacy hardcoded lists (fallback for initial bootstrap)
ATLAS_NETWORKS := development testing staging production management gitops
ATLAS_PROFILES := grafana loki prometheus step-ca node-exporter alertmanager mosquitto cloudflared atlantis coredns dex openfga haproxy alloy ovn-central
ATLAS_SERVICES := grafana01 loki01 prometheus01 step-ca01 node-exporter01 alertmanager01 mosquitto01 cloudflared01 atlantis01 coredns01 dex01 openfga01 haproxy01 alloy01 ovn-central01
ATLAS_VOLUMES := grafana01-data prometheus01-data loki01-data step-ca01-data alertmanager01-data mosquitto01-data atlantis01-data dex01-data openfga01-data ovn-central01-data

# Docker image names (local builds for testing)
ATLANTIS_IMAGE := atlas/atlantis:$(IMAGE_TAG)

# Build all Docker images
build-all: build-atlantis
	@echo "All images built successfully"

# Build individual Docker images
build-atlantis:
	@echo "Building Atlantis image..."
	docker build -t $(ATLANTIS_IMAGE) docker/atlantis/
	@echo "Atlantis image built: $(ATLANTIS_IMAGE)"

# List Docker images
list-images:
	@echo "Atlas Docker images:"
	@docker images | grep -E "(REPOSITORY|atlas)" || echo "No atlas images found"

# Bootstrap commands
bootstrap: bootstrap-init bootstrap-apply
	@echo ""
	@echo "========================================"
	@echo "Bootstrap complete for $(ENV)!"
	@echo "========================================"
	@echo ""
	@echo "Next steps:"
	@echo "1. Initialize main OpenTofu project:"
	@echo "   make init ENV=$(ENV)"
	@echo ""
	@echo "2. Deploy infrastructure:"
	@echo "   make deploy ENV=$(ENV)"

bootstrap-init:
	@echo "Initializing bootstrap OpenTofu for $(ENV)..."
	cd $(ENV_DIR)/bootstrap && tofu init

bootstrap-plan:
	@echo "Planning bootstrap changes for $(ENV)..."
	cd $(ENV_DIR)/bootstrap && tofu plan

bootstrap-apply:
	@echo "Applying bootstrap configuration for $(ENV)..."
	@echo "This will create:"
	@echo "  - Incus storage buckets configuration"
	@echo "  - Storage pool for OpenTofu state"
	@echo "  - Storage bucket for OpenTofu state"
	@echo "  - S3 access credentials"
	@echo ""
	cd $(ENV_DIR)/bootstrap && tofu apply
	@echo ""
	@echo "Bootstrap applied successfully!"
	@echo "Backend configuration saved to: $(ENV_DIR)/backend.hcl"

# OpenTofu commands
init:
	@echo "Initializing OpenTofu with remote backend for $(ENV)..."
	@if [ -f $(ENV_DIR)/backend.hcl ]; then \
		cd $(ENV_DIR) && tofu init -backend-config=backend.hcl; \
	else \
		echo "ERROR: backend.hcl not found for $(ENV)!"; \
		echo ""; \
		echo "You must run bootstrap first:"; \
		echo "  make bootstrap ENV=$(ENV)"; \
		echo ""; \
		exit 1; \
	fi

plan:
	@echo "Planning OpenTofu changes for $(ENV)..."
	cd $(ENV_DIR) && tofu plan

apply:
	@echo "=========================================="
	@echo "WARNING: Applying infrastructure changes"
	@echo "Environment: $(ENV)"
	@echo "=========================================="
	@echo ""
	@echo "This will modify your infrastructure based on the current configuration."
	@echo ""
	@echo "Recommended: Review the plan first with 'make plan ENV=$(ENV)'"
	@echo ""
	@echo "OpenTofu will prompt for confirmation before applying."
	@echo ""
	cd $(ENV_DIR) && tofu apply

destroy:
	@echo "=========================================="
	@echo "⚠️  WARNING: DESTRUCTIVE OPERATION"
	@echo "Environment: $(ENV)"
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
	cd $(ENV_DIR) && tofu destroy
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
	@echo "Importing existing Incus resources into OpenTofu state for $(ENV)..."
	@echo "This will import networks, profiles, volumes, and instances that already exist."
	@echo ""
	@cd $(ENV_DIR) && \
	for net in $(ATLAS_NETWORKS); do \
		if incus network show $$net >/dev/null 2>&1; then \
			echo "Importing network: $$net"; \
			tofu import "incus_network.$$net" "$$net" 2>/dev/null || true; \
		fi; \
	done
	@cd $(ENV_DIR) && \
	for profile in $(ATLAS_PROFILES); do \
		if incus profile show $$profile >/dev/null 2>&1; then \
			echo "Importing profile: $$profile"; \
			module=$$(echo $$profile | tr '-' '_'); \
			tofu import "module.$${module}01.incus_profile.$$module" "$$profile" 2>/dev/null || true; \
		fi; \
	done
	@cd $(ENV_DIR) && \
	for vol in $(ATLAS_VOLUMES); do \
		if incus storage volume show local $$vol >/dev/null 2>&1; then \
			echo "Importing volume: $$vol"; \
			base=$$(echo $$vol | sed 's/-data$$//'); \
			module=$$(echo $$base | tr '-' '_'); \
			resource=$$(echo $$base | sed 's/01$$//' | tr '-' '_'); \
			tofu import "module.$$module.incus_storage_volume.$${resource}_data[0]" "local/$$vol" 2>/dev/null || true; \
		fi; \
	done
	@cd $(ENV_DIR) && \
	for inst in $(ATLAS_SERVICES); do \
		if incus info $$inst >/dev/null 2>&1; then \
			echo "Importing instance: $$inst"; \
			module=$$(echo $$inst | tr '-' '_'); \
			resource=$$(echo $$inst | sed 's/01$$//' | tr '-' '_'); \
			tofu import "module.$$module.incus_instance.$$resource" "$$inst" 2>/dev/null || true; \
		fi; \
	done
	@echo ""
	@echo "Import complete. Run 'make plan ENV=$(ENV)' to see any remaining drift."

# Dynamic import using tofu output (recommended when state exists)
import-dynamic:
	@echo "Importing Incus resources using dynamic discovery for $(ENV)..."
	@echo "This uses 'tofu output managed_resources' for accurate mappings."
	@echo ""
	@if ! cd $(ENV_DIR) && tofu output managed_resources >/dev/null 2>&1; then \
		echo "ERROR: Cannot read managed_resources output."; \
		echo "Ensure 'tofu apply' has been run at least once."; \
		echo "For initial import, use 'make import' instead."; \
		exit 1; \
	fi
	@cd $(ENV_DIR) && \
	echo "Importing profiles..." && \
	for mapping in $$(tofu output -json managed_resources | jq -r '.profiles | to_entries[] | "\(.key):\(.value)"'); do \
		name=$${mapping%%:*}; \
		tf_path=$${mapping#*:}; \
		if incus profile show $(INCUS_REMOTE)$$name >/dev/null 2>&1; then \
			echo "  Importing profile: $$name -> $$tf_path"; \
			tofu import "$$tf_path" "$(INCUS_REMOTE)$$name" 2>/dev/null || true; \
		fi; \
	done
	@cd $(ENV_DIR) && \
	echo "Importing instances..." && \
	for mapping in $$(tofu output -json managed_resources | jq -r '.instances | to_entries[] | "\(.key):\(.value)"'); do \
		name=$${mapping%%:*}; \
		tf_path=$${mapping#*:}; \
		if incus info $(INCUS_REMOTE)$$name >/dev/null 2>&1; then \
			echo "  Importing instance: $$name -> $$tf_path"; \
			tofu import "$$tf_path" "$(INCUS_REMOTE)$$name" 2>/dev/null || true; \
		fi; \
	done
	@cd $(ENV_DIR) && \
	echo "Importing volumes..." && \
	for mapping in $$(tofu output -json managed_resources | jq -r '.volumes | to_entries[] | "\(.key):\(.value)"'); do \
		name=$${mapping%%:*}; \
		tf_path=$${mapping#*:}; \
		if incus storage volume show $(INCUS_REMOTE)local $$name >/dev/null 2>&1; then \
			echo "  Importing volume: $$name -> $$tf_path"; \
			tofu import "$$tf_path" "$(INCUS_REMOTE)local/$$name" 2>/dev/null || true; \
		fi; \
	done
	@echo ""
	@echo "Dynamic import complete. Run 'make plan ENV=$(ENV)' to verify."

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
	@echo "Cleanup complete. Run 'make deploy ENV=$(ENV)' for a fresh deployment."

# Pre-deployment validation
validate:
	@$(ENV_DIR)/scripts/validate.sh

# Combined deployment
deploy: apply
	@echo "Deployment complete for $(ENV)!"
	@echo ""
	@echo "Run 'cd $(ENV_DIR) && tofu output' to see endpoints"

# Cleanup targets
clean: clean-docker clean-tofu
	@echo "Cleanup complete"

clean-docker:
	@echo "Cleaning Docker build cache..."
	docker builder prune -f

clean-tofu:
	@echo "Cleaning OpenTofu cache for $(ENV)..."
	rm -rf $(ENV_DIR)/.terraform
	rm -f $(ENV_DIR)/.terraform.lock.hcl
	@echo "Note: OpenTofu state files preserved"

clean-bootstrap:
	@echo "Cleaning bootstrap OpenTofu for $(ENV)..."
	rm -rf $(ENV_DIR)/bootstrap/.terraform
	rm -f $(ENV_DIR)/bootstrap/.terraform.lock.hcl
	rm -f $(ENV_DIR)/bootstrap/.credentials
	@echo "Note: Bootstrap state files preserved"

# Development helpers
format:
	@echo "Formatting OpenTofu files..."
	tofu fmt -recursive modules/
	tofu fmt -recursive environments/

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

# Dynamic backup using tofu output (recommended when state exists)
backup-dynamic:
	@echo "Creating snapshots using dynamic discovery for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output managed_resources >/dev/null 2>&1; then \
		echo "ERROR: Cannot read managed_resources output."; \
		echo "Ensure 'tofu apply' has been run. Use 'make backup-snapshot' as fallback."; \
		exit 1; \
	fi
	@TIMESTAMP=$$(date +%Y%m%d-%H%M%S); \
	cd $(ENV_DIR) && \
	for vol in $$(tofu output -json managed_resources | jq -r '.volumes | keys[]'); do \
		if incus storage volume show $(INCUS_REMOTE)local $$vol >/dev/null 2>&1; then \
			echo "  Snapshotting: $$vol -> backup-$$TIMESTAMP"; \
			incus storage volume snapshot $(INCUS_REMOTE)local $$vol "backup-$$TIMESTAMP"; \
		else \
			echo "  Skipping (not found): $$vol"; \
		fi; \
	done
	@echo ""
	@echo "Dynamic backup complete."

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

# =============================================================================
# OVN Chassis Configuration (cluster01 only)
# =============================================================================

# Configure OVN on all IncusOS cluster nodes
# This enables OVN networking by connecting each node to the OVN southbound database
configure-ovn-chassis:
	@if [ "$(ENV)" != "cluster01" ]; then \
		echo "ERROR: OVN chassis configuration is only applicable to cluster01"; \
		echo "Usage: make configure-ovn-chassis ENV=cluster01"; \
		exit 1; \
	fi
	@echo "Configuring OVN chassis on cluster01 nodes..."
	@echo ""
	@# Check if OVN is enabled
	@NETWORK_BACKEND=$$(cd $(ENV_DIR) && tofu output -raw network_backend 2>/dev/null); \
	if [ "$$NETWORK_BACKEND" != "ovn" ]; then \
		echo "ERROR: OVN is not enabled in cluster01 (network_backend=$$NETWORK_BACKEND)"; \
		exit 1; \
	fi
	@# Get southbound connection from Terraform output
	@SOUTHBOUND=$$(cd $(ENV_DIR) && tofu output -raw ovn_central_southbound_connection 2>/dev/null); \
	if [ -z "$$SOUTHBOUND" ]; then \
		echo "ERROR: Could not get OVN southbound connection from Terraform output"; \
		echo "Ensure ovn-central is deployed: make apply ENV=cluster01"; \
		exit 1; \
	fi; \
	echo "OVN Southbound: $$SOUTHBOUND"; \
	echo ""; \
	# Get node names and IPs from Terraform output \
	NODES=$$(cd $(ENV_DIR) && tofu output -json cluster_nodes | jq -r '.[]'); \
	IPS=$$(cd $(ENV_DIR) && tofu output -json cluster_ips | jq -r '.[]'); \
	# Convert to arrays \
	NODE_ARRAY=($$NODES); \
	IP_ARRAY=($$IPS); \
	# Configure each node \
	for i in $${!NODE_ARRAY[@]}; do \
		NODE=$${NODE_ARRAY[$$i]}; \
		IP=$${IP_ARRAY[$$i]}; \
		echo "Configuring $$NODE (tunnel_address=$$IP)..."; \
		echo '{"config": {"database": "'$$SOUTHBOUND'", "enabled": true, "tunnel_address": "'$$IP'"}}' | \
			incus admin os service edit ovn cluster01: --target=$$NODE; \
		if [ $$? -eq 0 ]; then \
			echo "  ✓ $$NODE configured"; \
		else \
			echo "  ✗ $$NODE failed"; \
		fi; \
	done; \
	echo ""; \
	echo "Chassis configuration complete."; \
	echo "Run 'make verify-ovn-chassis ENV=cluster01' to verify registration."

# Verify OVN chassis registration
verify-ovn-chassis:
	@if [ "$(ENV)" != "cluster01" ]; then \
		echo "ERROR: OVN chassis verification is only applicable to cluster01"; \
		exit 1; \
	fi
	@echo "Verifying OVN chassis registration..."
	@echo ""
	@# Check network backend
	@NETWORK_BACKEND=$$(cd $(ENV_DIR) && tofu output -raw network_backend 2>/dev/null); \
	if [ "$$NETWORK_BACKEND" != "ovn" ]; then \
		echo "ERROR: OVN is not enabled in cluster01"; \
		exit 1; \
	fi
	@echo "=== OVN Southbound Database Status ==="
	@incus exec cluster01:ovn-central01 -- ovn-sbctl show
	@echo ""
	@echo "=== Expected Nodes ==="
	@cd $(ENV_DIR) && tofu output -json cluster_nodes | jq -r '.[]'
	@echo ""
	@CHASSIS_COUNT=$$(incus exec cluster01:ovn-central01 -- ovn-sbctl show 2>/dev/null | grep -c "Chassis" || echo "0"); \
	NODE_COUNT=$$(cd $(ENV_DIR) && tofu output -json cluster_nodes | jq 'length'); \
	echo "Chassis registered: $$CHASSIS_COUNT / $$NODE_COUNT"; \
	if [ "$$CHASSIS_COUNT" -ge "$$NODE_COUNT" ]; then \
		echo "✓ All chassis registered"; \
	else \
		echo "✗ Some chassis missing - run 'make configure-ovn-chassis ENV=cluster01'"; \
		exit 1; \
	fi

# =============================================================================
# Ansible Configuration (Hybrid Terraform + Ansible)
# =============================================================================

# Install Ansible Galaxy requirements (run once)
ansible-setup:
	@echo "Installing Ansible Galaxy requirements..."
	cd ansible && ansible-galaxy collection install -r requirements.yml --force
	@echo ""
	@echo "Ansible setup complete."

# Run full Ansible configuration for all services
configure:
	@echo "Running Ansible configuration for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/site.yml
	@echo ""
	@echo "Configuration complete for $(ENV)."

# Configure Forgejo runners only (without registration)
configure-runner:
	@echo "Configuring Forgejo runners for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/forgejo-runner.yml --skip-tags register
	@echo ""
	@echo "Runner configuration complete (registration skipped)."
	@echo "To register, run: FORGEJO_RUNNER_TOKEN=<token> make configure-runner-register ENV=$(ENV)"

# Configure and register Forgejo runners (requires FORGEJO_RUNNER_TOKEN)
configure-runner-register:
	@echo "Configuring and registering Forgejo runners for $(ENV)..."
	@if [ -z "$$FORGEJO_RUNNER_TOKEN" ]; then \
		echo "ERROR: FORGEJO_RUNNER_TOKEN environment variable not set."; \
		echo ""; \
		echo "Get a registration token from Forgejo:"; \
		echo "  1. Go to Admin > Actions > Runners"; \
		echo "  2. Click 'Create new runner'"; \
		echo "  3. Copy the registration token"; \
		echo ""; \
		echo "Then run:"; \
		echo "  FORGEJO_RUNNER_TOKEN=<token> make configure-runner-register ENV=$(ENV)"; \
		exit 1; \
	fi
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) FORGEJO_RUNNER_TOKEN="$$FORGEJO_RUNNER_TOKEN" ansible-playbook playbooks/forgejo-runner.yml
	@echo ""
	@echo "Runner configuration and registration complete."
	@echo "Check Forgejo Admin > Actions > Runners to verify the runner is online."

# Full deployment: Terraform apply + Ansible configure
deploy-full: apply configure
	@echo ""
	@echo "Full deployment complete for $(ENV)!"
	@echo "Terraform infrastructure deployed and Ansible configuration applied."

# =============================================================================
# Individual Service Configuration Targets
# =============================================================================

# Configure Prometheus (no secrets required)
configure-prometheus:
	@echo "Configuring Prometheus for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/prometheus.yml
	@echo ""
	@echo "Prometheus configuration complete."

# Configure Forgejo (without secrets)
configure-forgejo:
	@echo "Configuring Forgejo for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/forgejo.yml --skip-tags secrets
	@echo ""
	@echo "Forgejo configuration complete (secrets skipped)."
	@echo "To configure with secrets, run: FORGEJO_DB_PASSWORD=<pw> FORGEJO_ADMIN_PASSWORD=<pw> make configure-forgejo-full ENV=$(ENV)"

# Configure Forgejo with secrets (requires FORGEJO_DB_PASSWORD and FORGEJO_ADMIN_PASSWORD)
configure-forgejo-full:
	@echo "Configuring Forgejo with secrets for $(ENV)..."
	@if [ -z "$$FORGEJO_DB_PASSWORD" ] || [ -z "$$FORGEJO_ADMIN_PASSWORD" ]; then \
		echo "ERROR: FORGEJO_DB_PASSWORD and FORGEJO_ADMIN_PASSWORD environment variables required."; \
		echo ""; \
		echo "Run:"; \
		echo "  FORGEJO_DB_PASSWORD=<password> FORGEJO_ADMIN_PASSWORD=<password> make configure-forgejo-full ENV=$(ENV)"; \
		exit 1; \
	fi
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) FORGEJO_DB_PASSWORD="$$FORGEJO_DB_PASSWORD" FORGEJO_ADMIN_PASSWORD="$$FORGEJO_ADMIN_PASSWORD" ansible-playbook playbooks/forgejo.yml
	@echo ""
	@echo "Forgejo configuration with secrets complete."

# Configure PostgreSQL (without user passwords)
configure-postgresql:
	@echo "Configuring PostgreSQL for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/postgresql.yml --skip-tags users
	@echo ""
	@echo "PostgreSQL configuration complete (user creation skipped)."
	@echo "To configure with users, run: POSTGRESQL_ADMIN_PASSWORD=<pw> make configure-postgresql-full ENV=$(ENV)"

# Configure PostgreSQL with user passwords (requires POSTGRESQL_ADMIN_PASSWORD)
configure-postgresql-full:
	@echo "Configuring PostgreSQL with users for $(ENV)..."
	@if [ -z "$$POSTGRESQL_ADMIN_PASSWORD" ]; then \
		echo "ERROR: POSTGRESQL_ADMIN_PASSWORD environment variable required."; \
		echo ""; \
		echo "Run:"; \
		echo "  POSTGRESQL_ADMIN_PASSWORD=<password> make configure-postgresql-full ENV=$(ENV)"; \
		exit 1; \
	fi
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) POSTGRESQL_ADMIN_PASSWORD="$$POSTGRESQL_ADMIN_PASSWORD" ansible-playbook playbooks/postgresql.yml
	@echo ""
	@echo "PostgreSQL configuration with users complete."

# Configure Alertmanager (no secrets required)
configure-alertmanager:
	@echo "Configuring Alertmanager for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/alertmanager.yml
	@echo ""
	@echo "Alertmanager configuration complete."

# Configure step-ca (without CA initialization)
configure-step-ca:
	@echo "Configuring step-ca for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/step-ca.yml --skip-tags init
	@echo ""
	@echo "step-ca configuration complete (initialization skipped)."
	@echo "To initialize CA, run: STEP_CA_PASSWORD=<pw> make configure-step-ca-full ENV=$(ENV)"

# Configure step-ca with CA initialization (requires STEP_CA_PASSWORD)
configure-step-ca-full:
	@echo "Configuring and initializing step-ca for $(ENV)..."
	@if [ -z "$$STEP_CA_PASSWORD" ]; then \
		echo "ERROR: STEP_CA_PASSWORD environment variable required."; \
		echo ""; \
		echo "Run:"; \
		echo "  STEP_CA_PASSWORD=<password> make configure-step-ca-full ENV=$(ENV)"; \
		exit 1; \
	fi
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) STEP_CA_PASSWORD="$$STEP_CA_PASSWORD" ansible-playbook playbooks/step-ca.yml
	@echo ""
	@echo "step-ca configuration and initialization complete."

# Configure Mosquitto (without user passwords)
configure-mosquitto:
	@echo "Configuring Mosquitto for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/mosquitto.yml --skip-tags users
	@echo ""
	@echo "Mosquitto configuration complete (user creation skipped)."
	@echo "To configure with users, run: make configure-mosquitto-full ENV=$(ENV)"

# Configure Mosquitto with users (user passwords from Terraform vars)
configure-mosquitto-full:
	@echo "Configuring Mosquitto with users for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/mosquitto.yml
	@echo ""
	@echo "Mosquitto configuration with users complete."

# Configure Alloy (no secrets required)
configure-alloy:
	@echo "Configuring Alloy for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/alloy.yml
	@echo ""
	@echo "Alloy configuration complete."

# Configure Grafana (without admin password)
configure-grafana:
	@echo "Configuring Grafana for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/grafana.yml --skip-tags secrets
	@echo ""
	@echo "Grafana configuration complete (admin password skipped)."
	@echo "To configure with admin password, run: GRAFANA_ADMIN_PASSWORD=<pw> make configure-grafana-full ENV=$(ENV)"

# Configure Grafana with admin password (requires GRAFANA_ADMIN_PASSWORD)
configure-grafana-full:
	@echo "Configuring Grafana with admin password for $(ENV)..."
	@if [ -z "$$GRAFANA_ADMIN_PASSWORD" ]; then \
		echo "ERROR: GRAFANA_ADMIN_PASSWORD environment variable required."; \
		echo ""; \
		echo "Run:"; \
		echo "  GRAFANA_ADMIN_PASSWORD=<password> make configure-grafana-full ENV=$(ENV)"; \
		exit 1; \
	fi
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) GRAFANA_ADMIN_PASSWORD="$$GRAFANA_ADMIN_PASSWORD" ansible-playbook playbooks/grafana.yml
	@echo ""
	@echo "Grafana configuration with admin password complete."

# Configure Loki (no secrets required)
configure-loki:
	@echo "Configuring Loki for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/loki.yml
	@echo ""
	@echo "Loki configuration complete."

# Configure CoreDNS (no secrets required)
configure-coredns:
	@echo "Configuring CoreDNS for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/coredns.yml
	@echo ""
	@echo "CoreDNS configuration complete."

# Configure OpenFGA (without preshared keys)
configure-openfga:
	@echo "Configuring OpenFGA for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/openfga.yml --skip-tags secrets
	@echo ""
	@echo "OpenFGA configuration complete (preshared keys skipped)."
	@echo "To configure with preshared keys, run: OPENFGA_PRESHARED_KEYS=<keys> make configure-openfga-full ENV=$(ENV)"

# Configure OpenFGA with preshared keys (requires OPENFGA_PRESHARED_KEYS)
configure-openfga-full:
	@echo "Configuring OpenFGA with preshared keys for $(ENV)..."
	@if [ -z "$$OPENFGA_PRESHARED_KEYS" ]; then \
		echo "ERROR: OPENFGA_PRESHARED_KEYS environment variable required."; \
		echo ""; \
		echo "Run:"; \
		echo "  OPENFGA_PRESHARED_KEYS=<key1,key2> make configure-openfga-full ENV=$(ENV)"; \
		exit 1; \
	fi
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) OPENFGA_PRESHARED_KEYS="$$OPENFGA_PRESHARED_KEYS" ansible-playbook playbooks/openfga.yml
	@echo ""
	@echo "OpenFGA configuration with preshared keys complete."

# Configure Dex (without GitHub credentials)
configure-dex:
	@echo "Configuring Dex for $(ENV)..."
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) ansible-playbook playbooks/dex.yml --skip-tags secrets
	@echo ""
	@echo "Dex configuration complete (GitHub credentials skipped)."
	@echo "To configure with credentials, run: DEX_GITHUB_CLIENT_ID=<id> DEX_GITHUB_CLIENT_SECRET=<secret> make configure-dex-full ENV=$(ENV)"

# Configure Dex with GitHub credentials (requires DEX_GITHUB_CLIENT_ID and DEX_GITHUB_CLIENT_SECRET)
configure-dex-full:
	@echo "Configuring Dex with GitHub credentials for $(ENV)..."
	@if [ -z "$$DEX_GITHUB_CLIENT_ID" ] || [ -z "$$DEX_GITHUB_CLIENT_SECRET" ]; then \
		echo "ERROR: DEX_GITHUB_CLIENT_ID and DEX_GITHUB_CLIENT_SECRET environment variables required."; \
		echo ""; \
		echo "Run:"; \
		echo "  DEX_GITHUB_CLIENT_ID=<id> DEX_GITHUB_CLIENT_SECRET=<secret> make configure-dex-full ENV=$(ENV)"; \
		exit 1; \
	fi
	@if ! cd $(ENV_DIR) && tofu output -json >/dev/null 2>&1; then \
		echo "ERROR: Cannot read Terraform outputs."; \
		echo "Ensure 'make apply ENV=$(ENV)' has been run first."; \
		exit 1; \
	fi
	cd ansible && ENV=$(ENV) DEX_GITHUB_CLIENT_ID="$$DEX_GITHUB_CLIENT_ID" DEX_GITHUB_CLIENT_SECRET="$$DEX_GITHUB_CLIENT_SECRET" ansible-playbook playbooks/dex.yml
	@echo ""
	@echo "Dex configuration with GitHub credentials complete."
