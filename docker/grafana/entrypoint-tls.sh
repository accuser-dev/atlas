#!/bin/sh
# TLS-aware entrypoint for Grafana
# Requests certificate from step-ca and configures TLS if enabled
set -e

TLS_DIR="/etc/grafana/tls"
CERT_FILE="${TLS_DIR}/grafana.crt"
KEY_FILE="${TLS_DIR}/grafana.key"
CA_FILE="${TLS_DIR}/ca.crt"

# Function to request certificate from step-ca
request_certificate() {
    echo "Requesting certificate from step-ca..."

    # Bootstrap trust to the CA
    step ca bootstrap --ca-url "${STEPCA_URL}" --fingerprint "${STEPCA_FINGERPRINT}" --force

    # Get hostname for certificate
    HOSTNAME=$(hostname)

    # Request certificate using ACME
    step ca certificate "${HOSTNAME}" "${CERT_FILE}" "${KEY_FILE}" \
        --ca-url "${STEPCA_URL}" \
        --provisioner acme \
        --not-after "${CERT_DURATION}" \
        --force

    # Copy root CA for client verification
    cp "$(step path)/certs/root_ca.crt" "${CA_FILE}"

    echo "Certificate obtained successfully"
}

# Main logic
if [ "${ENABLE_TLS}" = "true" ]; then
    echo "TLS mode enabled"

    # Validate required environment variables
    if [ -z "${STEPCA_URL}" ]; then
        echo "ERROR: STEPCA_URL is required when ENABLE_TLS=true"
        exit 1
    fi

    if [ -z "${STEPCA_FINGERPRINT}" ]; then
        echo "ERROR: STEPCA_FINGERPRINT is required when ENABLE_TLS=true"
        exit 1
    fi

    # Request certificate
    request_certificate

    # Start Grafana with TLS via environment variables
    # Grafana reads these from environment
    export GF_SERVER_PROTOCOL="https"
    export GF_SERVER_CERT_FILE="${CERT_FILE}"
    export GF_SERVER_CERT_KEY="${KEY_FILE}"

    echo "Starting Grafana with TLS..."
    exec /run.sh "$@"
else
    echo "TLS mode disabled, starting Grafana normally..."
    exec /run.sh "$@"
fi
