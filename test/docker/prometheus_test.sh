#!/usr/bin/env bash
# Smoke tests for Prometheus container
# Tests: startup, ready endpoint, non-root user, port listening
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser/atlas/prometheus:latest}"
CONTAINER_NAME="prometheus-test-${GITHUB_RUN_ID:-local}"

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

echo "========================================="
echo "Testing Prometheus container: ${IMAGE}"
echo "========================================="

# Test 1: Container starts successfully
echo ""
echo "Test 1: Container startup..."
docker run -d --name "${CONTAINER_NAME}" "${IMAGE}"
echo "✅ Container started"

# Test 2: Wait for Prometheus to be ready (max 60s)
echo ""
echo "Test 2: Waiting for Prometheus to be ready..."
TIMEOUT=60
ELAPSED=0
until docker exec "${CONTAINER_NAME}" wget -qO- http://localhost:9090/-/ready 2>/dev/null | grep -q "Ready"; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "❌ Prometheus did not become ready within ${TIMEOUT}s"
    docker logs "${CONTAINER_NAME}"
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo "  Waiting... (${ELAPSED}s)"
done
echo "✅ Prometheus is ready (took ${ELAPSED}s)"

# Test 3: Ready endpoint responds correctly
echo ""
echo "Test 3: Ready endpoint..."
READY=$(docker exec "${CONTAINER_NAME}" wget -qO- http://localhost:9090/-/ready)
if ! echo "${READY}" | grep -q "Ready"; then
  echo "❌ Ready endpoint returned unexpected response: ${READY}"
  exit 1
fi
echo "✅ Ready endpoint responds correctly"

# Test 4: Port 9090 is listening
echo ""
echo "Test 4: Port listening..."
if ! docker exec "${CONTAINER_NAME}" sh -c "ss -tuln 2>/dev/null || netstat -tuln" | grep -q ":9090"; then
  echo "❌ Port 9090 is not listening"
  exit 1
fi
echo "✅ Port 9090 is listening"

# Test 5: Running as non-root user
echo ""
echo "Test 5: Non-root user..."
CONTAINER_USER=$(docker exec "${CONTAINER_NAME}" id -un 2>/dev/null || echo "nobody")
CONTAINER_UID=$(docker exec "${CONTAINER_NAME}" id -u)
if [ "${CONTAINER_UID}" = "0" ]; then
  echo "❌ Container is running as root (UID 0)"
  exit 1
fi
echo "✅ Running as non-root user: ${CONTAINER_USER} (UID: ${CONTAINER_UID})"

# Test 6: Working directory is set correctly
echo ""
echo "Test 6: Working directory..."
WORKDIR=$(docker exec "${CONTAINER_NAME}" pwd)
if [ "${WORKDIR}" != "/prometheus" ]; then
  echo "❌ Working directory is ${WORKDIR}, expected /prometheus"
  exit 1
fi
echo "✅ Working directory is /prometheus"

# Test 7: Metrics endpoint is accessible
echo ""
echo "Test 7: Metrics endpoint..."
if ! docker exec "${CONTAINER_NAME}" wget -qO- http://localhost:9090/metrics | grep -q "prometheus_build_info"; then
  echo "❌ Metrics endpoint not accessible or missing expected metric"
  exit 1
fi
echo "✅ Metrics endpoint accessible"

echo ""
echo "========================================="
echo "✅ All Prometheus container tests passed!"
echo "========================================="
