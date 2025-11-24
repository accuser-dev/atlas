# OpenTofu Remote State Backend Setup

This guide explains how to configure OpenTofu to use Incus storage buckets as a remote state backend, providing encrypted and secure state management without external dependencies.

## Overview

Instead of storing OpenTofu state locally, we use Incus's built-in S3-compatible storage buckets. This provides:

- **Encryption**: State data encrypted at rest
- **Self-hosted**: No external cloud dependencies
- **S3-compatible**: Works with OpenTofu's S3 backend
- **Integrated**: Uses existing Incus infrastructure
- **Secure**: Access controlled via S3 credentials

## Two Setup Methods

Choose the method that fits your situation:

### Method 1: Automated Bootstrap (Recommended)

**Use this for**: Fresh Incus installations, first-time setup

The bootstrap OpenTofu project automates all setup steps:

```bash
# From project root
make bootstrap

# Or manually:
cd terraform/bootstrap
tofu init
tofu apply
cd ..
tofu init -backend-config=backend.hcl
```

See [bootstrap/README.md](bootstrap/README.md) for details.

### Method 2: Manual Setup

**Use this for**: Custom configurations, understanding the process, troubleshooting

Follow the detailed manual steps below.

---

## Method 1: Automated Bootstrap (Recommended)

The bootstrap process creates everything needed for remote state:

1. **Navigate to bootstrap directory**:
   ```bash
   cd terraform/bootstrap
   ```

2. **Initialize and apply**:
   ```bash
   tofu init
   tofu apply
   ```

3. **Review the output** - Bootstrap creates:
   - Storage buckets configuration
   - Storage pool (`terraform-state`)
   - Storage bucket (`atlas-terraform-state`)
   - S3 credentials
   - Backend config file (`../backend.hcl`)

4. **Initialize main project**:
   ```bash
   cd ..
   tofu init -backend-config=backend.hcl
   ```

5. **Deploy infrastructure**:
   ```bash
   tofu apply
   ```

**That's it!** The bootstrap handles all the setup automatically.

For customization options, see [bootstrap/README.md](bootstrap/README.md).

---

## Method 2: Manual Setup

## Prerequisites

- Incus installed and running (`incus admin init` completed)
- Admin access to configure Incus
- Network connectivity to Incus host
- OpenTofu >= 1.6.0 (uses `endpoints.s3` syntax instead of deprecated `endpoint`)

## Manual Setup Instructions

### 1. Configure Incus Storage Buckets Address

First, configure Incus to serve S3 API on a specific address:

```bash
# Set the storage buckets address (listens on all interfaces, port 8555)
incus config set core.storage_buckets_address :8555

# Or bind to specific IP for security
incus config set core.storage_buckets_address 127.0.0.1:8555
```

### 2. Create Storage Pool (if needed)

If you don't have an existing storage pool, create one:

```bash
# List existing pools
incus storage list

# Create a new pool (using dir driver for simplicity)
incus storage create terraform-state dir

# Or use ZFS for better performance
incus storage create terraform-state zfs size=10GB
```

### 3. Create Storage Bucket

Create a dedicated bucket for Terraform state:

```bash
# Create bucket
incus storage bucket create terraform-state atlas-terraform-state

# Verify bucket was created
incus storage bucket list terraform-state
```

### 4. Generate S3 Credentials

Create access credentials for OpenTofu to use:

```bash
# Create credentials (replace with your own names)
incus storage bucket key create terraform-state atlas-terraform-state terraform-access

# This will output:
# Access key: <ACCESS_KEY>
# Secret key: <SECRET_KEY>
```

**Important**: Save these credentials securely. You'll need them for OpenTofu configuration.

### 5. Configure OpenTofu Backend

The backend configuration is already included in `versions.tf`. You need to provide the credentials via environment variables or a backend config file.

#### Option A: Environment Variables (Recommended)

```bash
export AWS_ACCESS_KEY_ID="<ACCESS_KEY>"
export AWS_SECRET_ACCESS_KEY="<SECRET_KEY>"
export TF_BACKEND_BUCKET="atlas-terraform-state"
export TF_BACKEND_ENDPOINT="http://localhost:8555"  # Or your Incus host IP
```

Then initialize OpenTofu:

```bash
cd terraform
tofu init \
  -backend-config="access_key=$AWS_ACCESS_KEY_ID" \
  -backend-config="secret_key=$AWS_SECRET_ACCESS_KEY" \
  -backend-config="bucket=$TF_BACKEND_BUCKET" \
  -backend-config="endpoint=$TF_BACKEND_ENDPOINT"
```

#### Option B: Backend Config File (For CI/CD)

Create a `backend.hcl` file (gitignored):

```hcl
# terraform/backend.hcl
# OpenTofu 1.6+ requires endpoints block instead of endpoint parameter
bucket     = "atlas-terraform-state"
access_key = "<ACCESS_KEY>"
secret_key = "<SECRET_KEY>"

endpoints = {
  s3 = "http://your-incus-host:8555"
}
```

Then initialize:

```bash
cd terraform
tofu init -backend-config=backend.hcl
```

### 6. Migrate Existing State (if applicable)

If you have existing local state, migrate it:

```bash
cd terraform

# Initialize with new backend
tofu init -migrate-state

# Verify migration
tofu state list
```

OpenTofu will prompt to copy existing state to the new backend. Answer `yes` to proceed.

### 7. Verify Remote State

```bash
# Check state is stored remotely
incus storage bucket show terraform-state atlas-terraform-state

# List objects in bucket
incus storage bucket export terraform-state atlas-terraform-state --list-only
```

## Security Considerations

### Access Control

1. **Restrict S3 API access**:
   ```bash
   # Bind to localhost only if Terraform runs on same host
   incus config set core.storage_buckets_address 127.0.0.1:8555
   ```

2. **Use firewall rules** to restrict access to port 8555

3. **Rotate credentials** regularly:
   ```bash
   # Delete old key
   incus storage bucket key delete terraform-state atlas-terraform-state terraform-access

   # Create new key
   incus storage bucket key create terraform-state atlas-terraform-state terraform-access
   ```

### Credential Storage

- **Never commit** credentials to git
- Use environment variables or secure secret management
- For CI/CD, use GitHub Secrets or similar
- Consider using a password manager for team access

### Backup

Storage buckets in Incus are backed by the storage pool, so regular backups of the pool are recommended:

```bash
# Export bucket data
incus storage bucket export terraform-state atlas-terraform-state backup.tar.gz

# Store backup securely
```

## Network Configuration

If running Terraform from a remote machine:

1. Ensure Incus host is accessible on port 8555
2. Update endpoint in backend config:
   ```hcl
   endpoint = "http://incus-host-ip:8555"
   ```
3. Consider using HTTPS with reverse proxy for production

## Troubleshooting

### Connection Refused

```bash
# Check if storage buckets address is configured
incus config get core.storage_buckets_address

# Verify Incus is listening
sudo netstat -tlnp | grep 8555
```

### Authentication Errors

```bash
# List existing keys
incus storage bucket key list terraform-state atlas-terraform-state

# Regenerate keys if needed
incus storage bucket key create terraform-state atlas-terraform-state terraform-access --force
```

### State Locking

Note: Incus storage buckets do **not** provide native state locking. For single-user projects, this is acceptable. For team collaboration, consider:

- Using Terraform Cloud (free tier)
- Implementing external locking with DynamoDB
- Using coordination via git branches

## Alternative: Terraform Cloud

If you prefer managed state with built-in locking and versioning, Terraform Cloud's free tier is an excellent alternative:

```hcl
terraform {
  cloud {
    organization = "your-org"
    workspaces {
      name = "atlas"
    }
  }
}
```

See: https://app.terraform.io/signup

## References

- [Incus Storage Buckets Documentation](https://linuxcontainers.org/incus/docs/main/howto/storage_buckets/)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Incus Storage Explanation](https://linuxcontainers.org/incus/docs/main/explanation/storage/)
