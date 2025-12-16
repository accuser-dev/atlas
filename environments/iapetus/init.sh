#!/usr/bin/env bash
# Terraform initialization wrapper script
# This script ensures proper backend configuration before running terraform init
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_CONFIG="${SCRIPT_DIR}/backend.hcl"

echo "========================================="
echo "Terraform Initialization"
echo "========================================="

# Check if backend.hcl exists
if [ ! -f "${BACKEND_CONFIG}" ]; then
  echo ""
  echo "ERROR: backend.hcl not found!"
  echo ""
  echo "The S3 backend requires configuration that must be provided via backend.hcl."
  echo ""
  echo "To set up the backend:"
  echo "  1. Run 'make bootstrap' to create the storage bucket and credentials"
  echo "  2. This will generate environments/iapetus/backend.hcl automatically"
  echo ""
  echo "Or manually create environments/iapetus/backend.hcl with (Terraform 1.6+ syntax):"
  echo ""
  echo '  bucket     = "atlas-terraform-state"'
  echo '  access_key = "<your-access-key>"'
  echo '  secret_key = "<your-secret-key>"'
  echo '  endpoints  = { s3 = "http://<incus-host>:8555" }'
  echo ""
  echo "See environments/iapetus/BACKEND_SETUP.md for detailed instructions."
  echo ""
  exit 1
fi

echo "Found backend.hcl, initializing Terraform..."
echo ""

cd "${SCRIPT_DIR}"
terraform init -backend-config=backend.hcl "$@"

echo ""
echo "========================================="
echo "Terraform initialized successfully!"
echo "========================================="
