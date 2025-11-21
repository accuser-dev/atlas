#!/usr/bin/env bash
# Smoke tests for Caddy container
# Tests: startup, health check, non-root user
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser/atlas/caddy:latest}"
CONTAINER_NAME="caddy-test-${GITHUB_RUN_ID:-local}"

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

echo "========================================="
echo "Testing Caddy container: ${IMAGE}"
echo "========================================="

# Test 1: Container starts successfully
echo ""
echo "Test 1: Container startup..."
docker run -d --name "${CONTAINER_NAME}" "${IMAGE}"
echo "✅ Container started"

# Test 2: Container stays running (not crashing)
echo ""
echo "Test 2: Container stability (5s)..."
sleep 5
if ! docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" | grep -q "${CONTAINER_NAME}"; then
  echo "❌ Container is not running"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
echo "✅ Container is stable"

# Test 3: Health check passes (caddy version)
echo ""
echo "Test 3: Health check..."
if ! docker exec "${CONTAINER_NAME}" caddy version; then
  echo "❌ Health check failed"
  exit 1
fi
echo "✅ Health check passed"

# Test 4: Running as non-root user
echo ""
echo "Test 4: Non-root user..."
CONTAINER_USER=$(docker exec "${CONTAINER_NAME}" whoami 2>/dev/null || docker exec "${CONTAINER_NAME}" id -un)
if [ "${CONTAINER_USER}" = "root" ]; then
  echo "❌ Container is running as root"
  exit 1
fi
echo "✅ Running as non-root user: ${CONTAINER_USER}"

# Test 5: Working directory is set correctly
echo ""
echo "Test 5: Working directory..."
WORKDIR=$(docker exec "${CONTAINER_NAME}" pwd)
if [ "${WORKDIR}" != "/srv" ]; then
  echo "❌ Working directory is ${WORKDIR}, expected /srv"
  exit 1
fi
echo "✅ Working directory is /srv"

echo ""
echo "========================================="
echo "✅ All Caddy container tests passed!"
echo "========================================="
