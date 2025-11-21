# Bootstrap Terraform Project

This Terraform project bootstraps the prerequisites for the main Atlas infrastructure by setting up Incus storage buckets for encrypted remote state management.

## Purpose

The bootstrap project creates:
1. Incus storage buckets configuration
2. Storage pool for Terraform state
3. Storage bucket for Terraform state
4. S3 access credentials
5. Backend configuration file for main project

## When to Use

Run this bootstrap **once** when:
- Setting up Atlas on a fresh Incus installation
- Incus has been initialized (`incus admin init`) but no storage buckets configured
- You need to recreate the Terraform state backend

## Prerequisites

- Incus installed and initialized (`incus admin init`)
- Terraform >= 1.13.5
- Access to run `incus` commands (requires sudo or lxd/incus group membership)

## Usage

### Quick Start

```bash
# 1. Navigate to bootstrap directory
cd terraform/bootstrap

# 2. Initialize Terraform
terraform init

# 3. Review the plan
terraform plan

# 4. Apply (creates storage bucket and credentials)
terraform apply

# 5. Return to main terraform directory
cd ..

# 6. Initialize main project with remote backend
terraform init -backend-config=backend.hcl

# 7. Deploy infrastructure
terraform apply
```

### Using Makefile (Recommended)

```bash
# Run bootstrap from project root
make bootstrap

# Then deploy main infrastructure
make deploy
```

## What It Creates

### 1. Storage Buckets Configuration
Sets `core.storage_buckets_address` in Incus to enable S3 API (default: `:8555`)

### 2. Storage Pool
Creates a storage pool named `terraform-state` (default driver: `dir`)

### 3. Storage Bucket
Creates a bucket named `atlas-terraform-state` for Terraform state files

### 4. S3 Credentials
Generates access key and secret key for S3 authentication

### 5. Backend Configuration
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
terraform apply \
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
- Won't overwrite existing credentials

To regenerate credentials:
```bash
incus storage bucket key delete terraform-state atlas-terraform-state terraform-access
terraform apply
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
terraform apply -var="storage_pool_driver=dir"
```

### Credentials not generated
Check if credentials already exist:
```bash
incus storage bucket key list terraform-state atlas-terraform-state
```

Delete and recreate:
```bash
incus storage bucket key delete terraform-state atlas-terraform-state terraform-access
terraform apply
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
terraform destroy

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
