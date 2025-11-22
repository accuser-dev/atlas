# Terraform Infrastructure

This directory contains the Terraform configuration for the Atlas monitoring stack infrastructure.

## Quick Start

```bash
# From project root - recommended approach
make terraform-init    # Initialize with backend configuration
make terraform-plan    # Preview changes
make terraform-apply   # Apply changes

# Or use the init wrapper script
./terraform/init.sh    # Validates prerequisites and initializes
```

## Important: Initialization

**Do not run `terraform init` directly** - it will fail because the S3 backend requires configuration that must be provided via `-backend-config`.

### Correct Ways to Initialize

1. **Use the Makefile (recommended)**:
   ```bash
   make terraform-init
   ```

2. **Use the init wrapper script**:
   ```bash
   cd terraform
   ./init.sh
   ```

3. **Manual initialization with backend config**:
   ```bash
   cd terraform
   terraform init -backend-config=backend.hcl
   ```

### Why This Is Required

The project uses an S3-compatible backend (Incus storage buckets) for remote state storage. The backend credentials are stored in `backend.hcl` (gitignored) and must be provided during initialization.

If you see this error:
```
Error: Error asking for input to configure backend "s3": bucket: EOF
```

It means you're running `terraform init` without the required backend configuration.

## First-Time Setup

For a fresh installation:

1. **Bootstrap the infrastructure** (creates storage bucket for state):
   ```bash
   make bootstrap
   ```

2. **Initialize Terraform**:
   ```bash
   make terraform-init
   ```

3. **Deploy**:
   ```bash
   make deploy
   ```

See [BACKEND_SETUP.md](BACKEND_SETUP.md) for detailed backend configuration instructions.

## Directory Structure

```
terraform/
├── init.sh              # Initialization wrapper script
├── main.tf              # Module instantiations
├── variables.tf         # Variable definitions
├── networks.tf          # Network configuration
├── outputs.tf           # Output values
├── providers.tf         # Provider configuration
├── versions.tf          # Version constraints and backend
├── backend.hcl          # Backend credentials (gitignored)
├── backend.hcl.example  # Backend config template
├── terraform.tfvars     # Variable values (gitignored)
├── BACKEND_SETUP.md     # Backend setup guide
├── bootstrap/           # Bootstrap project (local state)
└── modules/             # Reusable Terraform modules
    ├── caddy/
    ├── grafana/
    ├── loki/
    └── prometheus/
```

## Common Commands

```bash
# From project root
make terraform-init      # Initialize with remote backend
make terraform-plan      # Plan changes
make terraform-apply     # Apply changes
make terraform-destroy   # Destroy infrastructure
make format              # Format Terraform files

# Direct Terraform commands (after initialization)
cd terraform
terraform plan
terraform apply
terraform output
terraform state list
```

## Configuration Files

### terraform.tfvars (gitignored)

Contains sensitive variables:
```hcl
cloudflare_api_token = "your-token"
# Network configuration, etc.
```

### backend.hcl (gitignored)

Contains S3 backend credentials (Terraform 1.6+ syntax):
```hcl
bucket     = "atlas-terraform-state"
access_key = "your-access-key"
secret_key = "your-secret-key"

# Terraform 1.6+ requires endpoints block
endpoints = {
  s3 = "http://localhost:8555"
}
```

## Troubleshooting

### "Error asking for input to configure backend"

Run `make terraform-init` or `./init.sh` instead of `terraform init`.

### "backend.hcl not found"

Run `make bootstrap` to create the storage bucket and generate credentials.

### State lock errors

The Incus S3 backend doesn't support state locking. Ensure only one person applies changes at a time.
