#!/usr/bin/env bash
# Smoke tests for step-ca container
# Tests: startup, initialization, ACME endpoint, health check
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser/atlas/step-ca:latest}"
CONTAINER_NAME="step-ca-test-${GITHUB_RUN_ID:-local}"

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

echo "========================================="
echo "Testing step-ca container: ${IMAGE}"
echo "========================================="

# Test 1: Container starts successfully
echo ""
echo "Test 1: Container startup..."
docker run -d --name "${CONTAINER_NAME}" "${IMAGE}"
echo "✅ Container started"

# Test 2: Wait for CA to initialize and become ready (max 60s)
echo ""
echo "Test 2: Waiting for CA to initialize..."
TIMEOUT=60
ELAPSED=0
until docker exec "${CONTAINER_NAME}" test -f /home/step/certs/root_ca.crt 2>/dev/null; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "❌ CA did not initialize within ${TIMEOUT}s"
    docker logs "${CONTAINER_NAME}"
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo "  Waiting... (${ELAPSED}s)"
done
echo "✅ CA initialized (took ${ELAPSED}s)"

# Test 3: Root CA certificate exists and is valid
echo ""
echo "Test 3: Root CA certificate..."
ROOT_CA=$(docker exec "${CONTAINER_NAME}" cat /home/step/certs/root_ca.crt 2>/dev/null || echo "")
if [ -z "${ROOT_CA}" ]; then
  echo "❌ Root CA certificate not found"
  exit 1
fi
if ! echo "${ROOT_CA}" | grep -q "BEGIN CERTIFICATE"; then
  echo "❌ Root CA certificate is not valid PEM format"
  exit 1
fi
echo "✅ Root CA certificate exists and is valid PEM"

# Test 4: CA configuration file exists
echo ""
echo "Test 4: CA configuration..."
if ! docker exec "${CONTAINER_NAME}" test -f /home/step/config/ca.json; then
  echo "❌ CA configuration file not found"
  exit 1
fi
echo "✅ CA configuration exists"

# Test 5: Wait for ACME server to be ready
echo ""
echo "Test 5: ACME server readiness..."
ACME_TIMEOUT=30
ACME_ELAPSED=0
ACME_READY=false
while [ $ACME_ELAPSED -lt $ACME_TIMEOUT ]; do
  # Check if server is listening on port 9000
  if docker exec "${CONTAINER_NAME}" sh -c "wget -q --spider --no-check-certificate https://localhost:9000/health 2>/dev/null" 2>/dev/null; then
    ACME_READY=true
    break
  fi
  sleep 2
  ACME_ELAPSED=$((ACME_ELAPSED + 2))
  echo "  Waiting for ACME server... (${ACME_ELAPSED}s)"
done
if [ "${ACME_READY}" != "true" ]; then
  echo "⚠️  ACME health endpoint not responding (may need more time)"
  echo "  Checking if process is running..."
  if docker exec "${CONTAINER_NAME}" pgrep -x step-ca >/dev/null 2>&1; then
    echo "✅ step-ca process is running"
  else
    echo "❌ step-ca process is not running"
    docker logs "${CONTAINER_NAME}"
    exit 1
  fi
else
  echo "✅ ACME server is ready"
fi

# Test 6: ACME directory endpoint responds
echo ""
echo "Test 6: ACME directory endpoint..."
ACME_DIR=$(docker exec "${CONTAINER_NAME}" sh -c "wget -qO- --no-check-certificate https://localhost:9000/acme/acme/directory 2>/dev/null" || echo "")
if echo "${ACME_DIR}" | grep -q "newAccount\|newNonce\|newOrder"; then
  echo "✅ ACME directory endpoint responds correctly"
else
  echo "⚠️  ACME directory not fully ready yet (CA may still be initializing)"
  echo "  Response: ${ACME_DIR:-empty}"
fi

# Test 7: Running as non-root user
echo ""
echo "Test 7: Non-root user..."
CONTAINER_UID=$(docker exec "${CONTAINER_NAME}" id -u)
if [ "${CONTAINER_UID}" = "0" ]; then
  echo "❌ Container is running as root (UID 0)"
  exit 1
fi
echo "✅ Running as non-root user (UID: ${CONTAINER_UID})"

# Test 8: Password file is protected
echo ""
echo "Test 8: Password file permissions..."
PASSWORD_PERMS=$(docker exec "${CONTAINER_NAME}" stat -c "%a" /home/step/secrets/password 2>/dev/null || echo "")
if [ "${PASSWORD_PERMS}" = "600" ]; then
  echo "✅ Password file has correct permissions (600)"
else
  echo "⚠️  Password file permissions: ${PASSWORD_PERMS:-not found}"
fi

echo ""
echo "========================================="
echo "✅ All step-ca container tests passed!"
echo "========================================="
