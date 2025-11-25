# Migration Guide

## Project Reorganization

This document explains the changes made to reorganize the Atlas infrastructure project.

## What Changed

### Before (Old Structure)
```
atlas/
├── *.tf                    # Terraform files in root
├── modules/                # Terraform modules in root
│   ├── caddy/
│   ├── grafana/
│   ├── loki/
│   └── prometheus/
├── .terraform/
├── terraform.tfstate
└── CLAUDE.md
```

### After (New Structure)
```
atlas/
├── docker/                 # NEW: Custom Docker images
│   ├── caddy/
│   ├── grafana/
│   ├── loki/
│   └── prometheus/
├── terraform/              # MOVED: All Terraform files
│   ├── *.tf               # Terraform configuration
│   ├── modules/           # Terraform modules
│   ├── .terraform/
│   └── terraform.tfvars
├── Makefile               # NEW: Build automation
├── README.md              # NEW: Quick start guide
└── CLAUDE.md              # UPDATED: Architecture docs
```

## Changes You Need to Make

### 1. Terraform Working Directory

**Before:**
```bash
tofu init
tofu plan
tofu apply
```

**After:**
```bash
cd terraform
tofu init
tofu plan
tofu apply

# Or from root:
make terraform-init
make terraform-plan
make terraform-apply
```

### 2. Terraform State Files

The existing `terraform.tfstate` files are in the root directory. You have two options:

**Option A: Move state files (recommended)**
```bash
mv terraform.tfstate* terraform/
```

**Option B: Keep state in root and configure Terraform**

Add to `terraform/versions.tf`:
```hcl
terraform {
  backend "local" {
    path = "../terraform.tfstate"
  }
}
```

### 3. Module Paths

Module paths in Terraform remain the same (relative to the terraform/ directory):
```hcl
module "grafana01" {
  source = "./modules/grafana"  # Still works!
  # ...
}
```

### 4. Using the Makefile

**Before:**
```bash
tofu init
tofu plan
tofu apply
```

**After:**
```bash
make deploy                 # Build images + apply OpenTofu
make terraform-init         # Just initialize
make terraform-plan         # Just plan
make terraform-apply        # Just apply
```

### 5. Custom Docker Images (Optional)

You can now customize Docker images before deployment:

```bash
# 1. Edit docker/grafana/Dockerfile
# 2. Build the image
make build-grafana

# 3. Update terraform/main.tf to use custom image
# image = "ghcr:atlas/grafana:latest"

# 4. Apply changes
make terraform-apply
```

## Breaking Changes

### None for Existing Deployments

This reorganization is **non-breaking** for existing infrastructure:
- Container names remain the same
- Network configuration unchanged
- Storage volumes preserved
- No changes to running containers

### For Development Workflow

- Terraform commands must be run from `terraform/` directory
- Or use Makefile targets from root directory
- Module development happens in `terraform/modules/`
- Docker customization happens in `docker/`

## Recommendations

1. **Move state files** to `terraform/` directory:
   ```bash
   mv terraform.tfstate* terraform/
   ```

2. **Use Makefile** for common operations:
   ```bash
   make help    # See all available commands
   make deploy  # One-command deployment
   ```

3. **Update CI/CD** if applicable:
   - Change working directory to `terraform/` for Terraform commands
   - Add Docker build steps if using custom images

4. **Update documentation** references:
   - File paths now include `terraform/` or `docker/` prefix
   - Update any scripts that reference old paths

## Reverting (If Needed)

If you need to revert to the old structure:

```bash
# Move Terraform files back to root
mv terraform/*.tf .
mv terraform/modules .
mv terraform/.terraform .
mv terraform/.terraform.lock.hcl .

# Remove new directories
rm -rf docker/
rm -f Makefile README.md MIGRATION.md

# Restore old .gitignore
git checkout .gitignore
```

## Questions?

See:
- [README.md](README.md) - Quick start and usage
- [CLAUDE.md](CLAUDE.md) - Detailed architecture documentation
- [Makefile](Makefile) - Available commands
