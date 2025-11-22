# Atlas Tests

This directory contains tests for the Atlas infrastructure project.

## Directory Structure

```
test/
├── docker/           # Container smoke tests
│   ├── caddy_test.sh
│   ├── grafana_test.sh
│   ├── loki_test.sh
│   └── prometheus_test.sh
└── README.md
```

## Container Smoke Tests

The `docker/` directory contains smoke tests that verify each Docker container works correctly in isolation. These tests run automatically in the CI/CD pipeline after images are built.

### What the Tests Verify

Each test script checks:

1. **Container Startup** - Container starts without errors
2. **Service Readiness** - Service becomes ready within timeout
3. **Health Endpoint** - Health/ready endpoint responds correctly
4. **Port Listening** - Expected port is listening
5. **Non-root User** - Container runs as non-root user
6. **Working Directory** - Working directory is set correctly

### Running Tests Locally

```bash
# Build the image first
make build-caddy

# Run the test (uses local image by default)
IMAGE=atlas/caddy:latest ./test/docker/caddy_test.sh

# Or run all tests
for service in caddy grafana loki prometheus; do
  make build-${service}
  IMAGE=atlas/${service}:latest ./test/docker/${service}_test.sh
done
```

### Test Output

Successful test output looks like:

```
=========================================
Testing Caddy container: atlas/caddy:latest
=========================================

Test 1: Container startup...
✅ Container started

Test 2: Container stability (5s)...
✅ Container is stable

Test 3: Health check...
v2.10.2
✅ Health check passed

Test 4: Non-root user...
✅ Running as non-root user: caddy

Test 5: Working directory...
✅ Working directory is /srv

=========================================
✅ All Caddy container tests passed!
=========================================
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `IMAGE` | Docker image to test | `ghcr.io/accuser/atlas/<service>:latest` |
| `GITHUB_RUN_ID` | Unique ID for container naming (set by CI) | `local` |

### CI/CD Integration

Tests run automatically in GitHub Actions:

1. `tofu-validate` - Validates OpenTofu configuration
2. `docker-build` - Builds all Docker images
3. `docker-test` - Runs smoke tests for each image

The workflow uses a matrix strategy to test all services in parallel.

## Adding New Tests

### For a New Docker Service

1. Create `test/docker/<service>_test.sh`
2. Follow the existing test structure
3. Add the service to the matrix in `.github/workflows/ci.yml`

### Test Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/accuser/atlas/<service>:latest}"
CONTAINER_NAME="<service>-test-${GITHUB_RUN_ID:-local}"

cleanup() {
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

# Add your tests here...
```

## Future Testing

Additional test types are planned:

- **Infrastructure Tests** (Issue #32) - Tests against deployed Incus containers
- **Integration Tests** - Tests for service-to-service communication
- **Performance Tests** - Load testing and benchmarking

## Troubleshooting

### Test Fails with "Container is not running"

Check container logs:
```bash
docker logs <container-name>
```

### Test Timeout

Increase the timeout in the test script if the service needs more time to start.

### Permission Denied

Ensure test scripts are executable:
```bash
chmod +x test/docker/*.sh
```
