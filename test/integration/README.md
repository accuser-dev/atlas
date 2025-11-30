# Integration Tests

This directory contains integration tests for the Atlas infrastructure. These tests verify that deployed services are healthy, can communicate with each other, have proper storage, and are correctly isolated on their networks.

## Prerequisites

- Infrastructure deployed via `make deploy`
- `incus` command available and configured
- At least one container running

## Running Tests

### Run All Tests

```bash
# Via Makefile (recommended)
make test

# Directly
./test/integration/run-tests.sh
```

### Run Specific Test Suites

```bash
# Via Makefile
make test-health        # Service health checks
make test-connectivity  # Inter-service connectivity
make test-storage       # Storage and persistence
make test-network       # Network isolation

# Directly with options
./test/integration/run-tests.sh health
./test/integration/run-tests.sh -v connectivity  # Verbose output
./test/integration/run-tests.sh -q storage       # Quiet mode (failures only)
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show detailed output including commands |
| `-q, --quiet` | Only show failures |
| `-h, --help` | Show help message |

## Test Suites

### Health Tests (`health`)

Verifies that each service is healthy and responding:

| Service | Check |
|---------|-------|
| Grafana | `/api/health` endpoint |
| Prometheus | `/-/ready` and `/-/healthy` endpoints |
| Loki | `/ready` endpoint |
| Alertmanager | `/-/ready` endpoint |
| step-ca | `step ca health` command |
| Caddy | Admin API at `:2019/config/` |
| Node Exporter | `/metrics` endpoint |
| Mosquitto | Process running check |
| Cloudflared | `/metrics` endpoint (if deployed) |

### Connectivity Tests (`connectivity`)

Verifies inter-service communication:

- Grafana can reach Prometheus and Loki
- Prometheus can scrape all targets (Grafana, Loki, Alertmanager, Node Exporter)
- Caddy can reach Grafana backend
- Prometheus has active scrape targets

### Storage Tests (`storage`)

Verifies persistent storage is working:

- Data volumes are mounted at correct paths
- Volumes are writable
- Service-specific data exists (e.g., Prometheus WAL, step-ca certificates)
- Volume ownership is correct for each service

### Network Tests (`network`)

Verifies network configuration and isolation:

- Services on management network can communicate
- Caddy has access to required networks
- DNS resolution works (`.incus` domain)
- External connectivity (NAT) is functional

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed, or prerequisites not met |

## Test Output

```
[INFO] Starting integration tests...

[INFO] === Service Health Tests ===
[PASS] Grafana health endpoint
[PASS] Prometheus ready endpoint
[PASS] Prometheus healthy endpoint
[SKIP] Alertmanager ready endpoint (container not running)
...

[INFO] === Test Summary ===
  Total:   25
  Passed:  22
  Failed:  0
  Skipped: 3
```

## Adding New Tests

To add new tests, edit `run-tests.sh` and add test cases to the appropriate function:

```bash
# In the appropriate test_* function
if container_running "newservice01"; then
    run_test "New service health check" \
        "incus exec newservice01 -- wget -q --spider http://localhost:8080/health"
else
    skip_test "New service health check" "container not running"
fi
```

## Troubleshooting

### Tests Fail to Start

```
Error: incus command not found
```
Ensure `incus` is installed and in your PATH.

```
Error: No Incus containers found
```
Deploy infrastructure first with `make deploy`.

### Specific Test Failures

Run with verbose mode to see detailed output:

```bash
./test/integration/run-tests.sh -v health
```

This shows the exact commands being run and their output on failure.

### Container Not Running

If a container is not running, tests for that service will be skipped:

```
[SKIP] Grafana health endpoint (container not running)
```

Check container status with:
```bash
incus list
```

Start a stopped container with:
```bash
incus start <container-name>
```
