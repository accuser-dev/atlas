#!/usr/bin/env bash
# Smoke tests for Alertmanager container
# Tests: startup, ready endpoint, port listening
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser-dev/atlas/alertmanager:latest}"
CONTAINER_NAME="alertmanager-test-${GITHUB_RUN_ID:-local}"

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

echo "========================================="
echo "Testing Alertmanager container: ${IMAGE}"
echo "========================================="

# Test 1: Container starts successfully
echo ""
echo "Test 1: Container startup..."
docker run -d --name "${CONTAINER_NAME}" \
  --tmpfs /alertmanager:uid=65534,gid=65534 \
  "${IMAGE}"
echo "✅ Container started"

# Test 2: Wait for Alertmanager to be ready (max 60s)
echo ""
echo "Test 2: Waiting for Alertmanager to be ready..."
TIMEOUT=60
ELAPSED=0
until docker exec "${CONTAINER_NAME}" wget -q --spider http://localhost:9093/-/ready 2>/dev/null; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "❌ Alertmanager did not become ready within ${TIMEOUT}s"
    docker logs "${CONTAINER_NAME}"
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo "  Waiting... (${ELAPSED}s)"
done
echo "✅ Alertmanager is ready (took ${ELAPSED}s)"

# Test 3: Ready endpoint responds correctly
echo ""
echo "Test 3: Ready endpoint..."
HTTP_CODE=$(docker exec "${CONTAINER_NAME}" wget -q -O /dev/null -S http://localhost:9093/-/ready 2>&1 | grep "HTTP/" | awk '{print $2}')
if [ "${HTTP_CODE}" != "200" ]; then
  echo "❌ Ready endpoint returned HTTP ${HTTP_CODE}"
  exit 1
fi
echo "✅ Ready endpoint responds with HTTP 200"

# Test 4: Health endpoint responds
echo ""
echo "Test 4: Health endpoint..."
HTTP_CODE=$(docker exec "${CONTAINER_NAME}" wget -q -O /dev/null -S http://localhost:9093/-/healthy 2>&1 | grep "HTTP/" | awk '{print $2}')
if [ "${HTTP_CODE}" != "200" ]; then
  echo "❌ Health endpoint returned HTTP ${HTTP_CODE}"
  exit 1
fi
echo "✅ Health endpoint responds with HTTP 200"

# Test 5: Container is running as non-root
echo ""
echo "Test 5: Container user..."
CONTAINER_USER=$(docker exec "${CONTAINER_NAME}" id -u)
if [ "${CONTAINER_USER}" == "0" ]; then
  echo "❌ Container is running as root"
  exit 1
fi
echo "✅ Container running as non-root user (UID: ${CONTAINER_USER})"

# Test 6: Step CLI is available (for TLS support)
echo ""
echo "Test 6: Step CLI availability..."
if ! docker exec "${CONTAINER_NAME}" step version >/dev/null 2>&1; then
  echo "❌ Step CLI not available"
  exit 1
fi
echo "✅ Step CLI is available"

echo ""
echo "========================================="
echo "✅ All Alertmanager container tests passed!"
echo "========================================="
