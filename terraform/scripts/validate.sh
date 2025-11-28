#!/usr/bin/env bash
# Pre-deployment validation script for Atlas infrastructure
# Catches common configuration errors before deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++)) || true
}

warn() {
    echo -e "${YELLOW}!${NC} $1"
    ((WARNINGS++)) || true
}

info() {
    echo -e "  $1"
}

# Get script directory and terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "Atlas Pre-Deployment Validation"
echo "================================"
echo ""

# =============================================================================
# ENVIRONMENT CHECKS
# =============================================================================
echo "Checking environment..."
echo ""

# Check OpenTofu/Terraform
if command -v tofu &>/dev/null; then
    TOFU_VERSION=$(tofu version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || tofu version | head -1)
    pass "OpenTofu installed ($TOFU_VERSION)"
elif command -v terraform &>/dev/null; then
    TF_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || terraform version | head -1)
    pass "Terraform installed ($TF_VERSION)"
else
    fail "Neither OpenTofu nor Terraform is installed"
fi

# Check Incus
if command -v incus &>/dev/null; then
    if incus list &>/dev/null; then
        INCUS_VERSION=$(incus version 2>/dev/null | head -1 || echo "unknown")
        pass "Incus is running ($INCUS_VERSION)"
    else
        fail "Incus is installed but not accessible (check permissions)"
    fi
else
    fail "Incus is not installed"
fi

# Check required storage pool
if incus storage show local &>/dev/null 2>&1; then
    pass "Storage pool 'local' exists"
else
    fail "Storage pool 'local' does not exist"
    info "Run: incus storage create local dir"
fi

# Check network connectivity to ghcr.io
if curl -sf --max-time 5 "https://ghcr.io/v2/" &>/dev/null || curl -sf --max-time 5 -I "https://ghcr.io" &>/dev/null; then
    pass "Network connectivity to ghcr.io"
else
    warn "Cannot reach ghcr.io (image pulls may fail)"
fi

echo ""

# =============================================================================
# CONFIGURATION CHECKS
# =============================================================================
echo "Checking configuration..."
echo ""

# Check terraform.tfvars exists
TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"
if [[ -f "$TFVARS_FILE" ]]; then
    pass "terraform.tfvars exists"

    # Check file permissions
    PERMS=$(stat -c %a "$TFVARS_FILE" 2>/dev/null || stat -f %Lp "$TFVARS_FILE" 2>/dev/null)
    if [[ "$PERMS" == "600" ]]; then
        pass "terraform.tfvars permissions are 600 (secure)"
    else
        warn "terraform.tfvars permissions are $PERMS (recommend 600)"
        info "Run: chmod 600 $TFVARS_FILE"
    fi

    # Check Cloudflare API token is set
    if grep -qE '^cloudflare_api_token\s*=' "$TFVARS_FILE"; then
        TOKEN_VALUE=$(grep -E '^cloudflare_api_token\s*=' "$TFVARS_FILE" | sed 's/.*=\s*"\([^"]*\)".*/\1/' | head -1)
        if [[ "$TOKEN_VALUE" == "your-cloudflare-api-token-here" ]] || [[ -z "$TOKEN_VALUE" ]]; then
            fail "cloudflare_api_token is not set (still placeholder value)"
        elif [[ ${#TOKEN_VALUE} -lt 40 ]]; then
            fail "cloudflare_api_token appears invalid (too short)"
        else
            pass "cloudflare_api_token is set"
        fi
    else
        fail "cloudflare_api_token is not defined in terraform.tfvars"
    fi

    # Check Grafana password is set and not default
    if grep -qE '^grafana_admin_password\s*=' "$TFVARS_FILE"; then
        PASSWORD_VALUE=$(grep -E '^grafana_admin_password\s*=' "$TFVARS_FILE" | sed 's/.*=\s*"\([^"]*\)".*/\1/' | head -1)
        if [[ "$PASSWORD_VALUE" == "your-secure-grafana-password-here" ]] || [[ -z "$PASSWORD_VALUE" ]]; then
            fail "grafana_admin_password is not set (still placeholder value)"
        elif [[ ${#PASSWORD_VALUE} -lt 12 ]]; then
            fail "grafana_admin_password is too short (minimum 12 characters)"
        elif [[ "$PASSWORD_VALUE" == "admin" ]] || [[ "$PASSWORD_VALUE" == "password" ]] || [[ "$PASSWORD_VALUE" == "grafana" ]]; then
            fail "grafana_admin_password uses a common default value"
        else
            pass "grafana_admin_password is set (length: ${#PASSWORD_VALUE})"
        fi
    else
        fail "grafana_admin_password is not defined in terraform.tfvars"
    fi

else
    fail "terraform.tfvars does not exist"
    info "Run: cp $TERRAFORM_DIR/terraform.tfvars.example $TFVARS_FILE"
fi

# Check backend.hcl exists
BACKEND_FILE="$TERRAFORM_DIR/backend.hcl"
if [[ -f "$BACKEND_FILE" ]]; then
    pass "backend.hcl exists"
else
    fail "backend.hcl does not exist"
    info "Run: make bootstrap"
fi

# Check terraform.tfvars is gitignored
cd "$TERRAFORM_DIR/.." || exit 1
if git check-ignore -q terraform/terraform.tfvars 2>/dev/null; then
    pass "terraform.tfvars is gitignored"
else
    warn "terraform.tfvars may not be gitignored"
fi

echo ""

# =============================================================================
# NETWORK VALIDATION
# =============================================================================
echo "Checking network configuration..."
echo ""

# Extract network ranges from tfvars (if it exists)
if [[ -f "$TFVARS_FILE" ]]; then
    # Parse network CIDRs from tfvars or use defaults
    DEV_NET=$(grep -E '^development_network_ipv4\s*=' "$TFVARS_FILE" 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "10.10.0.0/24")
    TEST_NET=$(grep -E '^testing_network_ipv4\s*=' "$TFVARS_FILE" 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "10.20.0.0/24")
    STAGE_NET=$(grep -E '^staging_network_ipv4\s*=' "$TFVARS_FILE" 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "10.30.0.0/24")
    PROD_NET=$(grep -E '^production_network_ipv4\s*=' "$TFVARS_FILE" 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "10.40.0.0/24")
    MGMT_NET=$(grep -E '^management_network_ipv4\s*=' "$TFVARS_FILE" 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "10.50.0.0/24")

    # Use defaults if empty
    [[ -z "$DEV_NET" ]] && DEV_NET="10.10.0.0/24"
    [[ -z "$TEST_NET" ]] && TEST_NET="10.20.0.0/24"
    [[ -z "$STAGE_NET" ]] && STAGE_NET="10.30.0.0/24"
    [[ -z "$PROD_NET" ]] && PROD_NET="10.40.0.0/24"
    [[ -z "$MGMT_NET" ]] && MGMT_NET="10.50.0.0/24"

    # Function to convert CIDR to network prefix for comparison
    cidr_to_prefix() {
        local cidr=$1
        local ip mask
        ip=$(echo "$cidr" | cut -d'/' -f1)
        mask=$(echo "$cidr" | cut -d'/' -f2)
        # Get first 3 octets for /24 networks
        echo "$ip" | cut -d'.' -f1-3
    }

    # Check for overlapping networks (simple check for /24 networks)
    NETWORKS=("$DEV_NET" "$TEST_NET" "$STAGE_NET" "$PROD_NET" "$MGMT_NET")
    NETWORK_NAMES=("development" "testing" "staging" "production" "management")
    OVERLAP_FOUND=false

    for i in "${!NETWORKS[@]}"; do
        for j in "${!NETWORKS[@]}"; do
            if [[ $i -lt $j ]]; then
                PREFIX_I=$(cidr_to_prefix "${NETWORKS[$i]}")
                PREFIX_J=$(cidr_to_prefix "${NETWORKS[$j]}")
                if [[ "$PREFIX_I" == "$PREFIX_J" ]]; then
                    fail "Network overlap: ${NETWORK_NAMES[$i]} and ${NETWORK_NAMES[$j]} use same prefix ($PREFIX_I)"
                    OVERLAP_FOUND=true
                fi
            fi
        done
    done

    if [[ "$OVERLAP_FOUND" == "false" ]]; then
        pass "Network ranges are unique and non-overlapping"
    fi
else
    info "Skipping network validation (no terraform.tfvars)"
fi

echo ""

# =============================================================================
# OPENTOFU VALIDATION
# =============================================================================
echo "Checking OpenTofu configuration..."
echo ""

cd "$TERRAFORM_DIR" || exit 1

# Check if initialized
if [[ -d ".terraform" ]]; then
    pass "OpenTofu is initialized"

    # Run terraform validate
    if tofu validate &>/dev/null 2>&1; then
        pass "OpenTofu configuration is valid"
    else
        fail "OpenTofu validation failed"
        info "Run: cd terraform && tofu validate"
    fi
else
    warn "OpenTofu not initialized"
    info "Run: make init"
fi

echo ""

# =============================================================================
# SUMMARY
# =============================================================================
echo "================================"
echo "Validation Summary"
echo "================================"
echo ""

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}All checks passed! Ready to deploy.${NC}"
    echo ""
    echo "Next steps:"
    echo "  make plan    # Review planned changes"
    echo "  make deploy  # Deploy infrastructure"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}Passed with $WARNINGS warning(s).${NC}"
    echo ""
    echo "You can proceed, but consider addressing the warnings above."
    exit 0
else
    echo -e "${RED}Failed with $ERRORS error(s) and $WARNINGS warning(s).${NC}"
    echo ""
    echo "Please fix the errors above before deploying."
    exit 1
fi
