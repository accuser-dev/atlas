#!/bin/sh
# Entrypoint for step-ca Certificate Authority
# Initializes CA on first run and starts the CA server
set -eu

# =============================================================================
# Logging Functions
# =============================================================================
log_info()  { echo "INFO:  $*"; }
log_warn()  { echo "WARN:  $*" >&2; }
log_error() { echo "ERROR: $*" >&2; }

# =============================================================================
# Configuration
# =============================================================================
STEPPATH="${STEPPATH:-/home/step}"
CONFIG_FILE="${STEPPATH}/config/ca.json"
PASSWORD_FILE="${STEPPATH}/secrets/password"

# =============================================================================
# Functions
# =============================================================================

# Generate a random password if not provided
generate_password() {
    if [ -n "${STEPCA_PASSWORD:-}" ]; then
        echo "${STEPCA_PASSWORD}"
    else
        # Generate a secure random password
        head -c 32 /dev/urandom | base64 | tr -d '\n'
    fi
}

# Initialize the CA if not already initialized
initialize_ca() {
    if [ -f "${CONFIG_FILE}" ]; then
        log_info "CA already initialized, skipping initialization"
        return 0
    fi

    log_info "Initializing Step CA..."

    # Validate required environment variables
    if [ -z "${STEPCA_NAME:-}" ]; then
        log_error "STEPCA_NAME is required for CA initialization"
        return 1
    fi

    if [ -z "${STEPCA_DNS:-}" ]; then
        log_error "STEPCA_DNS is required for CA initialization"
        return 1
    fi

    if [ -z "${STEPCA_ADDRESS:-}" ]; then
        log_error "STEPCA_ADDRESS is required for CA initialization"
        return 1
    fi

    if [ -z "${STEPCA_PROVISIONER:-}" ]; then
        log_error "STEPCA_PROVISIONER is required for CA initialization"
        return 1
    fi

    # Create secrets directory
    if ! mkdir -p "${STEPPATH}/secrets"; then
        log_error "Failed to create secrets directory"
        return 1
    fi

    # Generate or use provided password
    PASSWORD=$(generate_password)
    if ! echo "${PASSWORD}" > "${PASSWORD_FILE}"; then
        log_error "Failed to write password file"
        return 1
    fi

    if ! chmod 600 "${PASSWORD_FILE}"; then
        log_error "Failed to set password file permissions"
        return 1
    fi

    # Initialize the CA with ACME provisioner
    log_info "Running step ca init..."
    if ! step ca init \
        --name="${STEPCA_NAME}" \
        --dns="${STEPCA_DNS}" \
        --address="${STEPCA_ADDRESS}" \
        --provisioner="${STEPCA_PROVISIONER}" \
        --password-file="${PASSWORD_FILE}" \
        --provisioner-password-file="${PASSWORD_FILE}" \
        --acme \
        --deployment-type=standalone; then
        log_error "Failed to initialize CA"
        return 1
    fi

    # Update certificate durations in config
    log_info "Configuring certificate durations..."

    # The default config needs adjustment for our use case
    # We'll modify the authority claims for shorter cert lifetimes
    if command -v jq >/dev/null 2>&1; then
        # Backup original config
        if ! cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak"; then
            log_warn "Failed to backup config file"
        fi

        # Update default certificate duration (24h) and max duration
        if ! jq '.authority.claims.defaultTLSCertDuration = "24h" |
            .authority.claims.maxTLSCertDuration = "168h" |
            .authority.claims.minTLSCertDuration = "1h"' \
            "${CONFIG_FILE}.bak" > "${CONFIG_FILE}"; then
            log_warn "Failed to update certificate durations, using defaults"
            cp "${CONFIG_FILE}.bak" "${CONFIG_FILE}"
        fi
    else
        log_warn "jq not available, using default certificate durations"
    fi

    log_info "CA initialization complete"
    log_info "Root CA certificate: ${STEPPATH}/certs/root_ca.crt"
}

# Export root CA certificate and fingerprint to well-known locations for easy access
export_root_ca() {
    if [ ! -f "${STEPPATH}/certs/root_ca.crt" ]; then
        log_warn "Root CA certificate not found, skipping export"
        return 0
    fi

    # Make root CA available at a predictable path
    if ! cp "${STEPPATH}/certs/root_ca.crt" "${STEPPATH}/root-ca.pem"; then
        log_error "Failed to export root CA"
        return 1
    fi

    if ! chmod 644 "${STEPPATH}/root-ca.pem"; then
        log_warn "Failed to set permissions on root-ca.pem"
    fi

    log_info "Root CA exported to ${STEPPATH}/root-ca.pem"

    # Export fingerprint for service bootstrapping
    FINGERPRINT=$(step certificate fingerprint "${STEPPATH}/certs/root_ca.crt")
    if [ -z "${FINGERPRINT}" ]; then
        log_error "Failed to calculate CA fingerprint"
        return 1
    fi

    if ! echo "${FINGERPRINT}" > "${STEPPATH}/fingerprint"; then
        log_error "Failed to write fingerprint file"
        return 1
    fi

    if ! chmod 644 "${STEPPATH}/fingerprint"; then
        log_warn "Failed to set permissions on fingerprint file"
    fi

    log_info "======================================================"
    log_info "CA FINGERPRINT: ${FINGERPRINT}"
    log_info "======================================================"
    log_info "Use this fingerprint to configure TLS for services."
    log_info "Fingerprint also saved to: ${STEPPATH}/fingerprint"
}

# =============================================================================
# Main
# =============================================================================
main() {
    # Initialize CA if needed
    if ! initialize_ca; then
        log_error "CA initialization failed"
        exit 1
    fi

    # Export root CA and fingerprint
    if ! export_root_ca; then
        log_error "Failed to export root CA"
        exit 1
    fi

    log_info "Starting Step CA server..."
    exec step-ca "${CONFIG_FILE}" --password-file="${PASSWORD_FILE}"
}

main "$@"
