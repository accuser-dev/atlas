#!/usr/bin/env bash
#
# DevContainer on-create script
# Installs Incus client and GitHub CLI in the development container
#
set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check if running with sufficient privileges
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Verify required commands are available
check_dependencies() {
    local missing_deps=()

    for cmd in curl apt-get dpkg; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi

    log_info "All dependencies are available"
}

# Update package lists
update_package_lists() {
    log_info "Updating package lists..."
    if ! apt-get update; then
        log_error "Failed to update package lists"
        exit 1
    fi
}

# Install prerequisite packages
install_prerequisites() {
    log_info "Installing prerequisites (ca-certificates, curl, gnupg)..."
    if ! apt-get install -y ca-certificates curl gnupg; then
        log_error "Failed to install prerequisite packages"
        exit 1
    fi
}

# Create keyrings directory with proper permissions
setup_keyrings_directory() {
    log_info "Setting up keyrings directory..."
    if ! mkdir -p -m 755 /etc/apt/keyrings; then
        log_error "Failed to create /etc/apt/keyrings directory"
        exit 1
    fi
}

# Download and verify Zabbly (Incus) repository key
setup_zabbly_repository() {
    log_info "Setting up Zabbly Incus repository..."

    local keyring_path="/etc/apt/keyrings/zabbly.asc"

    # Download the GPG key
    if ! curl -fsSL https://pkgs.zabbly.com/key.asc -o "$keyring_path"; then
        log_error "Failed to download Zabbly GPG key"
        exit 1
    fi

    # Verify the key was downloaded
    if [[ ! -f "$keyring_path" ]]; then
        log_error "Zabbly GPG key file not found after download"
        exit 1
    fi

    # Verify the key file has content
    if [[ ! -s "$keyring_path" ]]; then
        log_error "Zabbly GPG key file is empty"
        exit 1
    fi

    log_info "Zabbly GPG key downloaded successfully"

    # Create Incus repository configuration
    if ! sh -c 'cat <<EOF > /etc/apt/sources.list.d/zabbly-incus-stable.sources
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.asc

EOF'; then
        log_error "Failed to create Zabbly repository configuration"
        exit 1
    fi

    log_info "Zabbly repository configured successfully"
}

# Download and verify GitHub CLI repository key
setup_github_cli_repository() {
    log_info "Setting up GitHub CLI repository..."

    local keyring_path="/etc/apt/keyrings/githubcli-archive-keyring.gpg"

    # Download the GPG key
    if ! curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$keyring_path"; then
        log_error "Failed to download GitHub CLI GPG key"
        exit 1
    fi

    # Verify the key was downloaded
    if [[ ! -f "$keyring_path" ]]; then
        log_error "GitHub CLI GPG key file not found after download"
        exit 1
    fi

    # Verify the key file has content
    if [[ ! -s "$keyring_path" ]]; then
        log_error "GitHub CLI GPG key file is empty"
        exit 1
    fi

    log_info "GitHub CLI GPG key downloaded successfully"

    # Create GitHub CLI repository configuration
    if ! sh -c 'cat <<EOF > /etc/apt/sources.list.d/github-cli.list
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main

EOF'; then
        log_error "Failed to create GitHub CLI repository configuration"
        exit 1
    fi

    log_info "GitHub CLI repository configured successfully"
}

# Install target packages
install_packages() {
    log_info "Updating package lists with new repositories..."
    if ! apt-get update; then
        log_error "Failed to update package lists after adding repositories"
        exit 1
    fi

    log_info "Installing gh and incus-client..."
    if ! apt-get install -y gh incus-client; then
        log_error "Failed to install packages"
        exit 1
    fi

    log_info "Packages installed successfully"
}

# Verify installations
verify_installations() {
    log_info "Verifying installations..."

    local verification_failed=0

    if command -v gh >/dev/null 2>&1; then
        local gh_version
        gh_version=$(gh --version | head -n1)
        log_info "GitHub CLI installed: $gh_version"
    else
        log_error "GitHub CLI (gh) not found after installation"
        verification_failed=1
    fi

    if command -v incus >/dev/null 2>&1; then
        local incus_version
        incus_version=$(incus version)
        log_info "Incus client installed: $incus_version"
    else
        log_error "Incus client not found after installation"
        verification_failed=1
    fi

    if [[ $verification_failed -eq 1 ]]; then
        log_error "Installation verification failed"
        exit 1
    fi
}

# Main execution
main() {
    log_info "Starting devcontainer setup..."

    check_privileges
    check_dependencies
    update_package_lists
    install_prerequisites
    setup_keyrings_directory
    setup_zabbly_repository
    setup_github_cli_repository
    install_packages
    verify_installations

    log_info "DevContainer setup completed successfully!"
}

# Run main function
main "$@"
