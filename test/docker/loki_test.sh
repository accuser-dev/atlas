#!/usr/bin/env bash
# Smoke tests for Loki container
# Tests: startup, ready endpoint, non-root user, port listening
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser/atlas/loki:latest}"
CONTAINER_NAME="loki-test-${GITHUB_RUN_ID:-local}"

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

echo "========================================="
echo "Testing Loki container: ${IMAGE}"
echo "========================================="

# Test 1: Container starts successfully
# Note: Loki needs writable storage for chunks/index, use tmpfs for testing
echo ""
echo "Test 1: Container startup..."
docker run -d --name "${CONTAINER_NAME}" \
  --tmpfs /loki:uid=10001,gid=10001 \
  "${IMAGE}"
echo "✅ Container started"

# Test 2: Wait for Loki to be ready (max 60s)
echo ""
echo "Test 2: Waiting for Loki to be ready..."
TIMEOUT=60
ELAPSED=0
until docker exec "${CONTAINER_NAME}" wget -qO- http://localhost:3100/ready 2>/dev/null | grep -q "ready"; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "❌ Loki did not become ready within ${TIMEOUT}s"
    docker logs "${CONTAINER_NAME}"
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo "  Waiting... (${ELAPSED}s)"
done
echo "✅ Loki is ready (took ${ELAPSED}s)"

# Test 3: Ready endpoint responds correctly
echo ""
echo "Test 3: Ready endpoint..."
READY=$(docker exec "${CONTAINER_NAME}" wget -qO- http://localhost:3100/ready)
if [ "${READY}" != "ready" ]; then
  echo "❌ Ready endpoint returned unexpected response: ${READY}"
  exit 1
fi
echo "✅ Ready endpoint responds correctly"

# Test 4: Port 3100 is listening
echo ""
echo "Test 4: Port listening..."
if ! docker exec "${CONTAINER_NAME}" sh -c "ss -tuln 2>/dev/null || netstat -tuln" | grep -q ":3100"; then
  echo "❌ Port 3100 is not listening"
  exit 1
fi
echo "✅ Port 3100 is listening"

# Test 5: Running as non-root user
echo ""
echo "Test 5: Non-root user..."
CONTAINER_UID=$(docker exec "${CONTAINER_NAME}" id -u)
if [ "${CONTAINER_UID}" = "0" ]; then
  echo "❌ Container is running as root (UID 0)"
  exit 1
fi
echo "✅ Running as non-root user (UID: ${CONTAINER_UID})"

# Test 6: Working directory is set correctly
echo ""
echo "Test 6: Working directory..."
WORKDIR=$(docker exec "${CONTAINER_NAME}" pwd)
if [ "${WORKDIR}" != "/loki" ]; then
  echo "❌ Working directory is ${WORKDIR}, expected /loki"
  exit 1
fi
echo "✅ Working directory is /loki"

echo ""
echo "========================================="
echo "✅ All Loki container tests passed!"
echo "========================================="
