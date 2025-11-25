#!/bin/sh
set -e

STEPPATH="${STEPPATH:-/home/step}"
CONFIG_FILE="${STEPPATH}/config/ca.json"
PASSWORD_FILE="${STEPPATH}/secrets/password"

# Generate a random password if not provided
generate_password() {
    if [ -n "${STEPCA_PASSWORD}" ]; then
        echo "${STEPCA_PASSWORD}"
    else
        # Generate a secure random password
        head -c 32 /dev/urandom | base64 | tr -d '\n'
    fi
}

# Initialize the CA if not already initialized
initialize_ca() {
    if [ -f "${CONFIG_FILE}" ]; then
        echo "CA already initialized, skipping initialization"
        return 0
    fi

    echo "Initializing Step CA..."

    # Create secrets directory
    mkdir -p "${STEPPATH}/secrets"

    # Generate or use provided password
    PASSWORD=$(generate_password)
    echo "${PASSWORD}" > "${PASSWORD_FILE}"
    chmod 600 "${PASSWORD_FILE}"

    # Initialize the CA with ACME provisioner
    step ca init \
        --name="${STEPCA_NAME}" \
        --dns="${STEPCA_DNS}" \
        --address="${STEPCA_ADDRESS}" \
        --provisioner="${STEPCA_PROVISIONER}" \
        --password-file="${PASSWORD_FILE}" \
        --provisioner-password-file="${PASSWORD_FILE}" \
        --acme \
        --deployment-type=standalone

    # Update certificate durations in config
    # Use step CLI to modify the config
    echo "Configuring certificate durations..."

    # The default config needs adjustment for our use case
    # We'll modify the authority claims for shorter cert lifetimes
    if command -v jq >/dev/null 2>&1; then
        # Backup original config
        cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak"

        # Update default certificate duration (24h) and max duration
        jq '.authority.claims.defaultTLSCertDuration = "24h" |
            .authority.claims.maxTLSCertDuration = "168h" |
            .authority.claims.minTLSCertDuration = "1h"' \
            "${CONFIG_FILE}.bak" > "${CONFIG_FILE}"
    fi

    echo "CA initialization complete"
    echo "Root CA certificate: ${STEPPATH}/certs/root_ca.crt"
}

# Export root CA certificate and fingerprint to well-known locations for easy access
export_root_ca() {
    if [ -f "${STEPPATH}/certs/root_ca.crt" ]; then
        # Make root CA available at a predictable path
        cp "${STEPPATH}/certs/root_ca.crt" "${STEPPATH}/root-ca.pem"
        chmod 644 "${STEPPATH}/root-ca.pem"
        echo "Root CA exported to ${STEPPATH}/root-ca.pem"

        # Export fingerprint for service bootstrapping
        FINGERPRINT=$(step certificate fingerprint "${STEPPATH}/certs/root_ca.crt")
        echo "${FINGERPRINT}" > "${STEPPATH}/fingerprint"
        chmod 644 "${STEPPATH}/fingerprint"
        echo "======================================================"
        echo "CA FINGERPRINT: ${FINGERPRINT}"
        echo "======================================================"
        echo "Use this fingerprint to configure TLS for services."
        echo "Fingerprint also saved to: ${STEPPATH}/fingerprint"
    fi
}

# Main execution
initialize_ca
export_root_ca

echo "Starting Step CA server..."
exec step-ca "${CONFIG_FILE}" --password-file="${PASSWORD_FILE}"
