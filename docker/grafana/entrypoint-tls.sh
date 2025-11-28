#!/bin/sh
# TLS-aware entrypoint for Grafana
# Requests certificate from step-ca and configures TLS if enabled
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
TLS_DIR="/etc/grafana/tls"
CERT_FILE="${TLS_DIR}/grafana.crt"
KEY_FILE="${TLS_DIR}/grafana.key"
CA_FILE="${TLS_DIR}/ca.crt"

# =============================================================================
# Functions
# =============================================================================

# Request certificate from step-ca
request_certificate() {
    log_info "Requesting certificate from step-ca..."

    # Bootstrap trust to the CA
    if ! step ca bootstrap --ca-url "${STEPCA_URL}" --fingerprint "${STEPCA_FINGERPRINT}" --force; then
        log_error "Failed to bootstrap CA trust"
        return 1
    fi

    # Get hostname for certificate
    HOSTNAME=$(hostname)
    log_info "Requesting certificate for hostname: ${HOSTNAME}"

    # Request certificate using ACME
    if ! step ca certificate "${HOSTNAME}" "${CERT_FILE}" "${KEY_FILE}" \
        --ca-url "${STEPCA_URL}" \
        --provisioner acme \
        --not-after "${CERT_DURATION:-24h}" \
        --force; then
        log_error "Failed to obtain certificate"
        return 1
    fi

    # Copy root CA for client verification
    if ! cp "$(step path)/certs/root_ca.crt" "${CA_FILE}"; then
        log_error "Failed to copy root CA certificate"
        return 1
    fi

    log_info "Certificate obtained successfully"
}

# Validate required TLS environment variables
validate_tls_config() {
    local valid=true

    if [ -z "${STEPCA_URL:-}" ]; then
        log_error "STEPCA_URL is required when ENABLE_TLS=true"
        valid=false
    fi

    if [ -z "${STEPCA_FINGERPRINT:-}" ]; then
        log_error "STEPCA_FINGERPRINT is required when ENABLE_TLS=true"
        valid=false
    fi

    if [ "${valid}" = "false" ]; then
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================
main() {
    if [ "${ENABLE_TLS:-false}" = "true" ]; then
        log_info "TLS mode enabled"

        # Validate configuration
        if ! validate_tls_config; then
            log_error "TLS configuration validation failed"
            exit 1
        fi

        # Request certificate
        if ! request_certificate; then
            log_error "Certificate request failed"
            exit 1
        fi

        # Configure Grafana for TLS via environment variables
        export GF_SERVER_PROTOCOL="https"
        export GF_SERVER_CERT_FILE="${CERT_FILE}"
        export GF_SERVER_CERT_KEY="${KEY_FILE}"

        log_info "Starting Grafana with TLS..."
    else
        log_info "TLS mode disabled, starting Grafana normally..."
    fi

    exec /run.sh "$@"
}

main "$@"
