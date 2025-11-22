#!/usr/bin/env bash
# Smoke tests for Grafana container
# Tests: startup, health endpoint, non-root user, port listening
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser/atlas/grafana:latest}"
CONTAINER_NAME="grafana-test-${GITHUB_RUN_ID:-local}"

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

echo "========================================="
echo "Testing Grafana container: ${IMAGE}"
echo "========================================="

# Test 1: Container starts successfully
echo ""
echo "Test 1: Container startup..."
docker run -d --name "${CONTAINER_NAME}" \
  -e GF_SECURITY_ADMIN_USER=admin \
  -e GF_SECURITY_ADMIN_PASSWORD=testpassword \
  "${IMAGE}"
echo "✅ Container started"

# Test 2: Wait for Grafana to be ready (max 60s)
echo ""
echo "Test 2: Waiting for Grafana to be ready..."
TIMEOUT=60
ELAPSED=0
until docker exec "${CONTAINER_NAME}" wget -qO- http://localhost:3000/api/health 2>/dev/null | grep -q "ok"; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "❌ Grafana did not become ready within ${TIMEOUT}s"
    docker logs "${CONTAINER_NAME}"
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo "  Waiting... (${ELAPSED}s)"
done
echo "✅ Grafana is ready (took ${ELAPSED}s)"

# Test 3: Health endpoint returns valid JSON
echo ""
echo "Test 3: Health endpoint..."
HEALTH=$(docker exec "${CONTAINER_NAME}" wget -qO- http://localhost:3000/api/health)
# Check for database: ok (with flexible whitespace in JSON)
if ! echo "${HEALTH}" | grep -q '"database"'; then
  echo "❌ Health endpoint returned unexpected response: ${HEALTH}"
  exit 1
fi
echo "✅ Health endpoint responds correctly"

# Test 4: Port 3000 is listening
echo ""
echo "Test 4: Port listening..."
if ! docker exec "${CONTAINER_NAME}" sh -c "ss -tuln 2>/dev/null || netstat -tuln" | grep -q ":3000"; then
  echo "❌ Port 3000 is not listening"
  exit 1
fi
echo "✅ Port 3000 is listening"

# Test 5: Running as non-root user
echo ""
echo "Test 5: Non-root user..."
CONTAINER_USER=$(docker exec "${CONTAINER_NAME}" whoami 2>/dev/null || docker exec "${CONTAINER_NAME}" id -un)
if [ "${CONTAINER_USER}" = "root" ]; then
  echo "❌ Container is running as root"
  exit 1
fi
echo "✅ Running as non-root user: ${CONTAINER_USER}"

# Test 6: Working directory is set correctly
echo ""
echo "Test 6: Working directory..."
WORKDIR=$(docker exec "${CONTAINER_NAME}" pwd)
if [ "${WORKDIR}" != "/usr/share/grafana" ]; then
  echo "❌ Working directory is ${WORKDIR}, expected /usr/share/grafana"
  exit 1
fi
echo "✅ Working directory is /usr/share/grafana"

echo ""
echo "========================================="
echo "✅ All Grafana container tests passed!"
echo "========================================="
