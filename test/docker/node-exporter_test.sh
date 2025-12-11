#!/usr/bin/env bash
# Smoke tests for Node Exporter container
# Tests: image inspection, startup, version, labels
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser-dev/atlas/node-exporter:latest}"
CONTAINER_NAME="node-exporter-test-${GITHUB_RUN_ID:-local}"

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

echo "========================================="
echo "Testing Node Exporter container: ${IMAGE}"
echo "========================================="

# Test 1: Container image exists and can be inspected
echo ""
echo "Test 1: Image inspection..."
if ! docker inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "❌ Image cannot be inspected"
  exit 1
fi
echo "✅ Image exists and can be inspected"

# Test 2: Node Exporter version command works
echo ""
echo "Test 2: Node Exporter version..."
VERSION=$(docker run --rm "${IMAGE}" --version 2>&1 || true)
if [[ ! "${VERSION}" =~ node_exporter ]]; then
  echo "❌ Node Exporter version command failed"
  echo "Output: ${VERSION}"
  exit 1
fi
echo "✅ Node Exporter version: ${VERSION}"

# Test 3: Container starts successfully
# Note: The image has default args for Incus host mounts (--path.rootfs=/host etc.)
# For Docker testing, we override with empty args to run with container-local paths
echo ""
echo "Test 3: Container startup..."
docker run -d --name "${CONTAINER_NAME}" "${IMAGE}" --path.rootfs=/ --path.procfs=/proc --path.sysfs=/sys
sleep 3
# Check container is running
if ! docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" | grep -q "${CONTAINER_NAME}"; then
  echo "❌ Container is not running"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
echo "✅ Container started and running"

# Test 4: Node Exporter is listening (check logs for startup message)
echo ""
echo "Test 4: Node Exporter listening..."
LOGS=$(docker logs "${CONTAINER_NAME}" 2>&1)
if ! echo "${LOGS}" | grep -q "Listening on"; then
  echo "❌ Node Exporter not listening (no startup message in logs)"
  echo "Logs: ${LOGS}"
  exit 1
fi
echo "✅ Node Exporter is listening"

# Test 5: Check container labels
echo ""
echo "Test 5: Container labels..."
LABEL=$(docker inspect --format '{{index .Config.Labels "org.opencontainers.image.title"}}' "${IMAGE}")
if [ -z "${LABEL}" ]; then
  echo "⚠️  OCI title label not set (optional)"
else
  echo "✅ OCI title label: ${LABEL}"
fi

# Test 6: Health check is configured
echo ""
echo "Test 6: Health check configuration..."
HEALTHCHECK=$(docker inspect --format '{{json .Config.Healthcheck}}' "${IMAGE}")
if [ "${HEALTHCHECK}" = "null" ] || [ -z "${HEALTHCHECK}" ]; then
  echo "❌ No health check configured"
  exit 1
fi
echo "✅ Health check configured: ${HEALTHCHECK}"

echo ""
echo "========================================="
echo "✅ All Node Exporter container tests passed!"
echo "========================================="
