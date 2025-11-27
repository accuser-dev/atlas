#!/usr/bin/env bash
# Smoke tests for Mosquitto MQTT broker container
# Tests: startup, MQTT connectivity, port listening
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser/atlas/mosquitto:latest}"
CONTAINER_NAME="mosquitto-test-${GITHUB_RUN_ID:-local}"

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

echo "========================================="
echo "Testing Mosquitto container: ${IMAGE}"
echo "========================================="

# Test 1: Container starts successfully
echo ""
echo "Test 1: Container startup..."
docker run -d --name "${CONTAINER_NAME}" \
  -v /tmp/mosquitto-test:/mosquitto/data \
  "${IMAGE}"
echo "✅ Container started"

# Test 2: Wait for Mosquitto to be ready (max 30s)
echo ""
echo "Test 2: Waiting for Mosquitto to be ready..."
TIMEOUT=30
ELAPSED=0
until docker exec "${CONTAINER_NAME}" mosquitto_sub -h localhost -p 1883 -t '$SYS/broker/uptime' -C 1 -W 2 2>/dev/null; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "❌ Mosquitto did not become ready within ${TIMEOUT}s"
    docker logs "${CONTAINER_NAME}"
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo "  Waiting... (${ELAPSED}s)"
done
echo "✅ Mosquitto is ready (took ${ELAPSED}s)"

# Test 3: Can subscribe to system topic
echo ""
echo "Test 3: MQTT system topics..."
UPTIME=$(docker exec "${CONTAINER_NAME}" mosquitto_sub -h localhost -p 1883 -t '$SYS/broker/uptime' -C 1 -W 5 2>/dev/null)
if [ -z "${UPTIME}" ]; then
  echo "❌ Could not read system uptime topic"
  exit 1
fi
echo "✅ Broker uptime: ${UPTIME} seconds"

# Test 4: Can publish and subscribe
echo ""
echo "Test 4: MQTT pub/sub..."
# Start subscriber in background
docker exec "${CONTAINER_NAME}" mosquitto_sub -h localhost -p 1883 -t 'test/topic' -C 1 -W 5 > /tmp/mqtt_result.txt 2>/dev/null &
SUB_PID=$!
sleep 1
# Publish message
docker exec "${CONTAINER_NAME}" mosquitto_pub -h localhost -p 1883 -t 'test/topic' -m 'hello-atlas'
# Wait for subscriber
wait $SUB_PID || true
RESULT=$(cat /tmp/mqtt_result.txt)
if [ "${RESULT}" != "hello-atlas" ]; then
  echo "❌ Pub/sub test failed. Expected 'hello-atlas', got '${RESULT}'"
  exit 1
fi
echo "✅ MQTT pub/sub working"

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

# Test 7: Port 1883 is listening
echo ""
echo "Test 7: MQTT port listening..."
# Check via netstat or ss if available, otherwise via connection test
if docker exec "${CONTAINER_NAME}" netstat -tln 2>/dev/null | grep -q ":1883"; then
  echo "✅ Port 1883 is listening (netstat)"
elif docker exec "${CONTAINER_NAME}" mosquitto_sub -h localhost -p 1883 -t '$SYS/#' -C 1 -W 2 >/dev/null 2>&1; then
  echo "✅ Port 1883 is listening (connection test)"
else
  echo "❌ Port 1883 does not appear to be listening"
  exit 1
fi

echo ""
echo "========================================="
echo "✅ All Mosquitto container tests passed!"
echo "========================================="
