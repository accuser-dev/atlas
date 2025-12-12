#!/usr/bin/env bash
# Smoke tests for Atlantis container
# Tests: startup, health endpoint, non-root user, port listening
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser-dev/atlas/atlantis:latest}"
CONTAINER_NAME="atlantis-test-${GITHUB_RUN_ID:-local}"

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

echo "========================================="
echo "Testing Atlantis container: ${IMAGE}"
echo "========================================="

# Test 1: Container starts successfully
# Note: Atlantis requires certain env vars to run server, so we just run --version
echo ""
echo "Test 1: Container startup and version check..."
VERSION=$(docker run --rm "${IMAGE}" version 2>&1 || true)
if ! echo "${VERSION}" | grep -qE "atlantis|[0-9]+\.[0-9]+\.[0-9]+"; then
  echo "❌ Failed to get Atlantis version"
  echo "Output: ${VERSION}"
  exit 1
fi
echo "✅ Atlantis version: ${VERSION}"

# Test 2: Verify atlantis binary exists and is executable
echo ""
echo "Test 2: Atlantis binary..."
docker run --rm "${IMAGE}" which atlantis
echo "✅ Atlantis binary found"

# Test 3: Verify OpenTofu is available
echo ""
echo "Test 3: OpenTofu availability..."
TOFU_VERSION=$(docker run --rm --entrypoint tofu "${IMAGE}" version 2>&1 | head -1)
if ! echo "${TOFU_VERSION}" | grep -q "OpenTofu"; then
  echo "❌ OpenTofu not available"
  exit 1
fi
echo "✅ ${TOFU_VERSION}"

# Test 4: Verify Terraform is available
echo ""
echo "Test 4: Terraform availability..."
TF_VERSION=$(docker run --rm --entrypoint terraform "${IMAGE}" version 2>&1 | head -1)
if ! echo "${TF_VERSION}" | grep -q "Terraform"; then
  echo "❌ Terraform not available"
  exit 1
fi
echo "✅ ${TF_VERSION}"

# Test 5: Running as non-root user
echo ""
echo "Test 5: Non-root user..."
# Filter out entrypoint messages that appear before command output
CONTAINER_USER=$(docker run --rm "${IMAGE}" whoami 2>/dev/null | grep -v "docker-entrypoint" | tail -1)
if [ -z "${CONTAINER_USER}" ]; then
  CONTAINER_USER=$(docker run --rm "${IMAGE}" id -un | grep -v "docker-entrypoint" | tail -1)
fi
if [ "${CONTAINER_USER}" = "root" ]; then
  echo "❌ Container is running as root"
  exit 1
fi
echo "✅ Running as non-root user: ${CONTAINER_USER}"

# Test 6: Working directory is set correctly
echo ""
echo "Test 6: Working directory..."
# Filter out entrypoint messages that appear before command output
WORKDIR=$(docker run --rm "${IMAGE}" pwd | grep -v "docker-entrypoint" | tail -1)
if [ "${WORKDIR}" != "/home/atlantis" ]; then
  echo "❌ Working directory is ${WORKDIR}, expected /home/atlantis"
  exit 1
fi
echo "✅ Working directory is /home/atlantis"

# Test 7: Health endpoint (start server briefly)
echo ""
echo "Test 7: Server startup and health endpoint..."
docker run -d --name "${CONTAINER_NAME}" \
  -e ATLANTIS_GH_USER=test \
  -e ATLANTIS_GH_TOKEN=test \
  -e ATLANTIS_GH_WEBHOOK_SECRET=test \
  -e ATLANTIS_REPO_ALLOWLIST="github.com/test/*" \
  -e ATLANTIS_ATLANTIS_URL="http://localhost:4141" \
  "${IMAGE}" server

# Wait for server to start (max 30s)
TIMEOUT=30
ELAPSED=0
until docker exec "${CONTAINER_NAME}" wget -qO- http://localhost:4141/healthz 2>/dev/null; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "❌ Atlantis server did not become ready within ${TIMEOUT}s"
    docker logs "${CONTAINER_NAME}"
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo "  Waiting... (${ELAPSED}s)"
done
echo "✅ Health endpoint responds (took ${ELAPSED}s)"

# Test 8: Port 4141 is listening
echo ""
echo "Test 8: Port listening..."
if ! docker exec "${CONTAINER_NAME}" sh -c "ss -tuln 2>/dev/null || netstat -tuln" | grep -q ":4141"; then
  echo "❌ Port 4141 is not listening"
  exit 1
fi
echo "✅ Port 4141 is listening"

echo ""
echo "========================================="
echo "✅ All Atlantis container tests passed!"
echo "========================================="
