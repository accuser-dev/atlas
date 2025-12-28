#!/usr/bin/env bash
# Terraform initialization wrapper script for cluster environment
# This script ensures proper backend configuration before running terraform init
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_CONFIG="${SCRIPT_DIR}/backend.hcl"

echo "========================================="
echo "Terraform Initialization (cluster)"
echo "========================================="

# Check if backend.hcl exists
if [ ! -f "${BACKEND_CONFIG}" ]; then
  echo ""
  echo "ERROR: backend.hcl not found!"
  echo ""
  echo "The S3 backend requires configuration that must be provided via backend.hcl."
  echo ""
  echo "To set up the backend:"
  echo "  1. Get credentials from iapetus bootstrap (make bootstrap ENV=iapetus)"
  echo "  2. Copy environments/cluster01/backend.hcl.example to backend.hcl"
  echo "  3. Update the endpoint to point to iapetus S3 API"
  echo ""
  echo "Or manually create environments/cluster01/backend.hcl with:"
  echo ""
  echo '  bucket     = "atlas-terraform-state"'
  echo '  access_key = "<your-access-key>"'
  echo '  secret_key = "<your-secret-key>"'
  echo '  endpoints  = { s3 = "http://<iapetus-ip>:8555" }'
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
