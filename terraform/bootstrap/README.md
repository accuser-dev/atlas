# Bootstrap Terraform Project

This Terraform project bootstraps the prerequisites for the main Atlas infrastructure by setting up Incus storage buckets for encrypted remote state management.

## Purpose

The bootstrap project creates:
1. OCI remotes for container registries (ghcr, docker)
2. Incus storage buckets configuration
3. Storage pool for Terraform state
4. Storage bucket for Terraform state
5. S3 access credentials
6. Backend configuration file for main project

## When to Use

Run this bootstrap **once** when:
- Setting up Atlas on a fresh Incus installation
- Incus has been initialized (`incus admin init`) but no storage buckets configured
- You need to recreate the Terraform state backend

## Prerequisites

- Incus installed and initialized (`incus admin init`)
- OpenTofu >= 1.9.0
- Access to run `incus` commands (requires sudo or lxd/incus group membership)

## Usage

### Quick Start

```bash
# 1. Navigate to bootstrap directory
cd terraform/bootstrap

# 2. Initialize OpenTofu
tofu init

# 3. Review the plan
tofu plan

# 4. Apply (creates storage bucket and credentials)
tofu apply

# 5. Return to main terraform directory
cd ..

# 6. Initialize main project with remote backend
tofu init -backend-config=backend.hcl

# 7. Deploy infrastructure
tofu apply
```

### Using Makefile (Recommended)

```bash
# Run bootstrap from project root
make bootstrap

# Then deploy main infrastructure
make deploy
```

### Remote Incus Setup

To bootstrap a remote Incus server, the Incus client must be configured to connect to that remote.

**Step 1: Add the remote (one-time)**

```bash
# Add remote Incus server (interactive - sets up TLS cert)
incus remote add production https://192.168.1.100:8443

# You'll be prompted to:
# 1. Accept the server's certificate
# 2. Provide the trust password (set during incus admin init)

# Verify the remote was added
incus remote list
```

**Step 2: Configure which remote to use**

You have three options:

**Option A: Set as default remote (simplest)**
```bash
incus remote switch production
# Now all incus commands and Terraform use this remote by default
```

**Option B: Use environment variable (recommended for multiple remotes)**
```bash
export INCUS_REMOTE=production
# Run bootstrap
cd terraform/bootstrap
tofu apply
```

**Option C: Set in terraform.tfvars (persists with project)**
```hcl
# terraform/bootstrap/terraform.tfvars
incus_remote = "production"
```

**Step 3: Configure S3 endpoint for remote**

Create or update `terraform.tfvars`:

```hcl
# terraform/bootstrap/terraform.tfvars

# Required: S3 endpoint must point to the remote server
storage_buckets_endpoint = "http://192.168.1.100:8555"

# Required: Server must listen on accessible interface
storage_buckets_address = "0.0.0.0:8555"

# Optional: customize storage settings
incus_remote = "production"  # If not using default or env var
storage_pool_driver = "zfs"  # Use ZFS if available
```

**Step 4: Run bootstrap**

```bash
cd terraform/bootstrap
tofu init
tofu apply

# Or from project root:
make bootstrap
```

**Important Notes for Remote Setup:**

- **Port 8443**: Required for Incus API (already configured if `incus remote add` worked)
- **Port 8555**: Required for S3 API access to storage buckets
  - Must be accessible from your workstation
  - Firewall rules may be needed
- **S3 endpoint**: Must use the remote server's IP or hostname
- **Storage buckets address**: Must listen on `0.0.0.0:8555` or the server's network interface (not `127.0.0.1`)

**Security: SSH Tunneling**

For secure access over untrusted networks, use SSH tunneling:

```bash
# Create SSH tunnel for S3 API
ssh -L 8555:localhost:8555 user@192.168.1.100

# In another terminal, use localhost endpoint
cd terraform/bootstrap
cat > terraform.tfvars <<EOF
incus_remote = "production"
storage_buckets_endpoint = "http://localhost:8555"
storage_buckets_address = "0.0.0.0:8555"  # On remote server
EOF
tofu apply
```

## What It Creates

### 1. OCI Remotes
Configures Incus remotes for pulling container images from OCI registries:
- `ghcr` → `https://ghcr.io` (GitHub Container Registry)
- `docker` → `https://docker.io` (Docker Hub)

These enable pulling images using the `ghcr:` and `docker:` prefixes in Terraform:
```hcl
image = "ghcr:accuser/atlas/grafana:latest"  # Pulls from ghcr.io
image = "docker:grafana/grafana:latest"      # Pulls from Docker Hub
```

### 2. Storage Buckets Configuration
Sets `core.storage_buckets_address` in Incus to enable S3 API (default: `:8555`)

### 3. Storage Pool
Creates a storage pool named `terraform-state` (default driver: `dir`)

### 4. Storage Bucket
Creates a bucket named `atlas-terraform-state` for Terraform state files

### 5. S3 Credentials
Generates access key and secret key for S3 authentication

### 6. Backend Configuration
Creates `terraform/backend.hcl` with:
- Bucket name
- Endpoint URL
- Access credentials

## Configuration

Customize via variables in `terraform.tfvars` or command-line:

```hcl
# terraform/bootstrap/terraform.tfvars
storage_buckets_address = "127.0.0.1:8555"  # Bind to localhost only
storage_pool_driver     = "zfs"             # Use ZFS instead of dir
bucket_name             = "my-state-bucket" # Custom bucket name
```

Or via CLI:

```bash
tofu apply \
  -var="storage_pool_driver=zfs" \
  -var="storage_buckets_address=127.0.0.1:8555"
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `storage_buckets_address` | S3 API listen address | `:8555` |
| `storage_pool_name` | Name of storage pool | `terraform-state` |
| `storage_pool_driver` | Storage driver (dir, zfs, btrfs, lvm) | `dir` |
| `bucket_name` | Name of state bucket | `atlas-terraform-state` |
| `bucket_key_name` | Name for access key | `terraform-access` |
| `storage_buckets_endpoint` | S3 endpoint URL | `http://localhost:8555` |

## Security Notes

### Credentials File
- Bootstrap creates `.credentials` file with access keys
- This file is gitignored
- Store securely and delete after copying credentials

### Backend Configuration
- Creates `../backend.hcl` with credentials
- Gitignored in main project
- Contains sensitive access keys

### Storage Buckets Address
- Default `:8555` listens on all interfaces
- Use `127.0.0.1:8555` to restrict to localhost
- Configure firewall rules for remote access

## Idempotency

Bootstrap is safe to re-run:
- Checks if resources exist before creating
- Skips already-configured settings
- Won't overwrite existing credentials unless role upgrade is needed
- Automatically upgrades existing credentials from read-only to admin role

### Credential Role Management

Bootstrap creates credentials with the `admin` role, which is required for Terraform state operations (read and write). If existing credentials have a read-only role, bootstrap will automatically:
1. Delete the existing credentials
2. Recreate them with the `admin` role
3. Update the `backend.hcl` file with the new credentials

To manually regenerate credentials:
```bash
incus storage bucket key delete terraform-state atlas-terraform-state terraform-access
tofu apply
```

## Troubleshooting

### "incus daemon doesn't appear to be started"
Ensure Incus is running:
```bash
sudo systemctl start incus
incus list  # Should show no errors
```

### "Permission denied"
Add your user to the incus group:
```bash
sudo usermod -a -G incus $USER
newgrp incus
```

### Storage pool creation fails
Check available storage drivers:
```bash
incus storage list
```

Try a different driver:
```bash
tofu apply -var="storage_pool_driver=dir"
```

### Credentials not generated
Check if credentials already exist:
```bash
incus storage bucket key list terraform-state atlas-terraform-state
```

Delete and recreate:
```bash
incus storage bucket key delete terraform-state atlas-terraform-state terraform-access
tofu apply
```

## State Management

Bootstrap uses **local state** (stored in `terraform.tfstate`):
- Kept in `terraform/bootstrap/` directory
- Gitignored (should never be committed)
- Separate from main infrastructure state
- Can be backed up manually if needed

## Clean Up

To remove bootstrap resources:

```bash
cd terraform/bootstrap

# Destroy storage bucket (will lose all state!)
tofu destroy

# Or manually:
incus storage bucket delete terraform-state atlas-terraform-state
incus storage delete terraform-state
incus config unset core.storage_buckets_address
```

**Warning**: Destroying the storage bucket will delete all Terraform state for the main project!

## Related Documentation

- [Main BACKEND_SETUP.md](../BACKEND_SETUP.md) - Detailed backend configuration
- [Main project README](../../README.md) - Full project documentation
- [Incus Storage Buckets](https://linuxcontainers.org/incus/docs/main/howto/storage_buckets/) - Official Incus docs
