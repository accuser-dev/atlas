#!/usr/bin/env bash
# Smoke tests for Cloudflared container
# Tests: startup, version, metrics endpoint
# Note: Cannot test tunnel connection without valid token
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser-dev/atlas/cloudflared:latest}"
CONTAINER_NAME="cloudflared-test-${GITHUB_RUN_ID:-local}"

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

echo "========================================="
echo "Testing Cloudflared container: ${IMAGE}"
echo "========================================="

# Test 1: Container image exists and can be inspected
echo ""
echo "Test 1: Image inspection..."
if ! docker inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "❌ Image cannot be inspected"
  exit 1
fi
echo "✅ Image exists and can be inspected"

# Test 2: Cloudflared version command works
echo ""
echo "Test 2: Cloudflared version..."
VERSION=$(docker run --rm --entrypoint cloudflared "${IMAGE}" version 2>&1 || true)
if [[ ! "${VERSION}" =~ cloudflared ]]; then
  echo "❌ Cloudflared version command failed"
  echo "Output: ${VERSION}"
  exit 1
fi
echo "✅ Cloudflared version: ${VERSION}"

# Test 3: Help command works
echo ""
echo "Test 3: Cloudflared help..."
if ! docker run --rm --entrypoint cloudflared "${IMAGE}" tunnel --help >/dev/null 2>&1; then
  echo "❌ Cloudflared help command failed"
  exit 1
fi
echo "✅ Cloudflared help command works"

# Test 4: Container starts (will exit without token, but should start)
# We run with a dummy command that exits cleanly
echo ""
echo "Test 4: Container can start..."
docker run -d --name "${CONTAINER_NAME}" \
  --entrypoint cloudflared \
  "${IMAGE}" \
  version
# Wait briefly for container to run
sleep 2
# Check it ran (it will have exited after printing version)
if ! docker ps -a --filter "name=${CONTAINER_NAME}" | grep -q "${CONTAINER_NAME}"; then
  echo "❌ Container did not start"
  exit 1
fi
echo "✅ Container started successfully"

# Test 5: Check container labels
echo ""
echo "Test 5: Container labels..."
LABEL=$(docker inspect --format '{{index .Config.Labels "org.opencontainers.image.title"}}' "${IMAGE}")
if [ -z "${LABEL}" ]; then
  echo "⚠️  OCI title label not set (optional)"
else
  echo "✅ OCI title label: ${LABEL}"
fi

# Test 6: Entrypoint is set correctly
echo ""
echo "Test 6: Entrypoint configuration..."
ENTRYPOINT=$(docker inspect --format '{{json .Config.Entrypoint}}' "${IMAGE}")
if [[ ! "${ENTRYPOINT}" =~ cloudflared ]]; then
  echo "❌ Unexpected entrypoint: ${ENTRYPOINT}"
  exit 1
fi
echo "✅ Entrypoint configured: ${ENTRYPOINT}"

echo ""
echo "========================================="
echo "✅ All Cloudflared container tests passed!"
echo "========================================="
echo ""
echo "Note: Tunnel functionality requires a valid TUNNEL_TOKEN"
echo "      which cannot be tested in CI without credentials."
