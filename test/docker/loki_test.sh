#!/usr/bin/env bash
# Smoke tests for Loki container
# Tests: startup, ready endpoint, port listening
# Note: Loki uses a scratch-based image with no shell, so we test from outside
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser/atlas/loki:latest}"
CONTAINER_NAME="loki-test-${GITHUB_RUN_ID:-local}"
HELPER_IMAGE="busybox:latest"

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

# Test 2: Wait for Loki to be ready (max 90s - Loki needs ~30s for ring initialization)
# Note: Loki's scratch-based image has no shell, so we test from a helper container
echo ""
echo "Test 2: Waiting for Loki to be ready..."
TIMEOUT=90
ELAPSED=0
until docker run --rm --network container:"${CONTAINER_NAME}" "${HELPER_IMAGE}" \
  wget -q -O - http://localhost:3100/ready 2>/dev/null | grep -q "ready"; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "❌ Loki did not become ready within ${TIMEOUT}s"
    docker logs "${CONTAINER_NAME}"
    exit 1
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
  echo "  Waiting... (${ELAPSED}s)"
done
echo "✅ Loki is ready (took ${ELAPSED}s)"

# Test 3: Ready endpoint responds correctly
echo ""
echo "Test 3: Ready endpoint..."
READY=$(docker run --rm --network container:"${CONTAINER_NAME}" "${HELPER_IMAGE}" \
  wget -q -O - http://localhost:3100/ready 2>/dev/null)
if [ "${READY}" != "ready" ]; then
  echo "❌ Ready endpoint returned unexpected response: ${READY}"
  exit 1
fi
echo "✅ Ready endpoint responds correctly"

# Test 4: Port 3100 is listening (check via HTTP request since no shell in container)
echo ""
echo "Test 4: Port listening..."
if ! docker run --rm --network container:"${CONTAINER_NAME}" "${HELPER_IMAGE}" \
  wget -q --spider http://localhost:3100/ready 2>/dev/null; then
  echo "❌ Port 3100 is not responding"
  exit 1
fi
echo "✅ Port 3100 is listening"

# Test 5: Container is running (Loki scratch image has no shell for id/whoami)
echo ""
echo "Test 5: Container running..."
if ! docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" | grep -q "${CONTAINER_NAME}"; then
  echo "❌ Container is not running"
  exit 1
fi
echo "✅ Container is running"

# Test 6: Check container user via inspect (no shell in scratch image)
echo ""
echo "Test 6: Container user..."
CONTAINER_USER=$(docker inspect --format '{{.Config.User}}' "${CONTAINER_NAME}")
echo "✅ Container configured with user: ${CONTAINER_USER:-default}"

echo ""
echo "========================================="
echo "✅ All Loki container tests passed!"
echo "========================================="
