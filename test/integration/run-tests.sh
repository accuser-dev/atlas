#!/usr/bin/env bash
# Integration test runner for Atlas infrastructure
#
# Usage:
#   ./test/integration/run-tests.sh [OPTIONS] [TEST_SUITE...]
#
# Options:
#   -v, --verbose    Show detailed output
#   -q, --quiet      Only show failures
#   -h, --help       Show this help message
#
# Test Suites:
#   health           Service health checks
#   connectivity     Inter-service connectivity
#   storage          Storage and persistence
#   network          Network isolation
#   all              Run all tests (default)
#
# Examples:
#   ./test/integration/run-tests.sh              # Run all tests
#   ./test/integration/run-tests.sh health       # Run only health tests
#   ./test/integration/run-tests.sh -v storage   # Run storage tests with verbose output

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Options
VERBOSE=${VERBOSE:-false}
QUIET=${QUIET:-false}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Helper Functions
# ============================================================================

show_help() {
    head -30 "$0" | grep '^#' | sed 's/^# \?//'
    exit 0
}

log_info() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

log_pass() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${GREEN}[PASS]${NC} $*"
    fi
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_skip() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${YELLOW}[SKIP]${NC} $*"
    fi
}

# Run a single test
# Usage: run_test "test_name" "test_command"
run_test() {
    local name="$1"
    local cmd="$2"

    ((TESTS_RUN++))
    log_verbose "Running: $cmd"

    if eval "$cmd" > /dev/null 2>&1; then
        ((TESTS_PASSED++))
        log_pass "$name"
        return 0
    else
        ((TESTS_FAILED++))
        log_fail "$name"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  Command: $cmd"
            eval "$cmd" 2>&1 | sed 's/^/  /'
        fi
        return 1
    fi
}

# Skip a test with reason
skip_test() {
    local name="$1"
    local reason="$2"

    ((TESTS_RUN++))
    ((TESTS_SKIPPED++))
    log_skip "$name ($reason)"
}

# Check if a container exists and is running
container_running() {
    local name="$1"
    incus list --format csv -c s "$name" 2>/dev/null | grep -q "RUNNING"
}

# Check if a container exists
container_exists() {
    local name="$1"
    incus list --format csv -c n 2>/dev/null | grep -q "^${name}$"
}

# ============================================================================
# Test Suites
# ============================================================================

test_health() {
    log_info "=== Service Health Tests ==="

    # Grafana health
    if container_running "grafana01"; then
        run_test "Grafana health endpoint" \
            "incus exec grafana01 -- wget -q --spider http://localhost:3000/api/health"
    else
        skip_test "Grafana health endpoint" "container not running"
    fi

    # Prometheus health
    if container_running "prometheus01"; then
        run_test "Prometheus ready endpoint" \
            "incus exec prometheus01 -- wget -q --spider http://localhost:9090/-/ready"
        run_test "Prometheus healthy endpoint" \
            "incus exec prometheus01 -- wget -q --spider http://localhost:9090/-/healthy"
    else
        skip_test "Prometheus health endpoints" "container not running"
    fi

    # Loki health
    if container_running "loki01"; then
        run_test "Loki ready endpoint" \
            "incus exec loki01 -- wget -q --spider http://localhost:3100/ready"
    else
        skip_test "Loki ready endpoint" "container not running"
    fi

    # Alertmanager health
    if container_running "alertmanager01"; then
        run_test "Alertmanager ready endpoint" \
            "incus exec alertmanager01 -- wget -q --spider http://localhost:9093/-/ready"
    else
        skip_test "Alertmanager ready endpoint" "container not running"
    fi

    # step-ca health
    if container_running "step-ca01"; then
        run_test "step-ca health endpoint" \
            "incus exec step-ca01 -- step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt 2>/dev/null"
    else
        skip_test "step-ca health endpoint" "container not running"
    fi

    # Caddy health
    if container_running "caddy01"; then
        run_test "Caddy admin API" \
            "incus exec caddy01 -- wget -q --spider http://localhost:2019/config/"
    else
        skip_test "Caddy admin API" "container not running"
    fi

    # Node Exporter health
    if container_running "node-exporter01"; then
        run_test "Node Exporter metrics endpoint" \
            "incus exec node-exporter01 -- wget -q --spider http://localhost:9100/metrics"
    else
        skip_test "Node Exporter metrics endpoint" "container not running"
    fi

    # Mosquitto health
    if container_running "mosquitto01"; then
        run_test "Mosquitto process running" \
            "incus exec mosquitto01 -- pgrep -x mosquitto"
    else
        skip_test "Mosquitto process" "container not running"
    fi

    # Cloudflared health (optional)
    if container_running "cloudflared01"; then
        run_test "Cloudflared metrics endpoint" \
            "incus exec cloudflared01 -- wget -q --spider http://localhost:2000/metrics"
    else
        skip_test "Cloudflared metrics endpoint" "container not deployed"
    fi
}

test_connectivity() {
    log_info "=== Service Connectivity Tests ==="

    # Grafana -> Prometheus
    if container_running "grafana01" && container_running "prometheus01"; then
        run_test "Grafana -> Prometheus connectivity" \
            "incus exec grafana01 -- wget -q --spider http://prometheus01.incus:9090/-/healthy"
    else
        skip_test "Grafana -> Prometheus" "containers not running"
    fi

    # Grafana -> Loki
    if container_running "grafana01" && container_running "loki01"; then
        run_test "Grafana -> Loki connectivity" \
            "incus exec grafana01 -- wget -q --spider http://loki01.incus:3100/ready"
    else
        skip_test "Grafana -> Loki" "containers not running"
    fi

    # Prometheus -> Grafana (scraping)
    if container_running "prometheus01" && container_running "grafana01"; then
        run_test "Prometheus -> Grafana metrics" \
            "incus exec prometheus01 -- wget -q --spider http://grafana01.incus:3000/metrics"
    else
        skip_test "Prometheus -> Grafana" "containers not running"
    fi

    # Prometheus -> Loki (scraping)
    if container_running "prometheus01" && container_running "loki01"; then
        run_test "Prometheus -> Loki metrics" \
            "incus exec prometheus01 -- wget -q --spider http://loki01.incus:3100/metrics"
    else
        skip_test "Prometheus -> Loki" "containers not running"
    fi

    # Prometheus -> Alertmanager
    if container_running "prometheus01" && container_running "alertmanager01"; then
        run_test "Prometheus -> Alertmanager connectivity" \
            "incus exec prometheus01 -- wget -q --spider http://alertmanager01.incus:9093/-/ready"
    else
        skip_test "Prometheus -> Alertmanager" "containers not running"
    fi

    # Prometheus -> Node Exporter
    if container_running "prometheus01" && container_running "node-exporter01"; then
        run_test "Prometheus -> Node Exporter metrics" \
            "incus exec prometheus01 -- wget -q --spider http://node-exporter01.incus:9100/metrics"
    else
        skip_test "Prometheus -> Node Exporter" "containers not running"
    fi

    # Caddy -> Grafana (reverse proxy backend)
    if container_running "caddy01" && container_running "grafana01"; then
        run_test "Caddy -> Grafana backend" \
            "incus exec caddy01 -- wget -q --spider http://grafana01.incus:3000/api/health"
    else
        skip_test "Caddy -> Grafana" "containers not running"
    fi

    # Prometheus scrape targets check
    if container_running "prometheus01"; then
        run_test "Prometheus has active targets" \
            "incus exec prometheus01 -- wget -qO- http://localhost:9090/api/v1/targets 2>/dev/null | grep -q 'activeTargets'"
    else
        skip_test "Prometheus targets" "container not running"
    fi
}

test_storage() {
    log_info "=== Storage Tests ==="

    # Check Grafana data volume
    if container_running "grafana01"; then
        run_test "Grafana data volume mounted" \
            "incus exec grafana01 -- test -d /var/lib/grafana"
        run_test "Grafana data volume writable" \
            "incus exec grafana01 -- touch /var/lib/grafana/.write-test && incus exec grafana01 -- rm /var/lib/grafana/.write-test"
    else
        skip_test "Grafana storage" "container not running"
    fi

    # Check Prometheus data volume
    if container_running "prometheus01"; then
        run_test "Prometheus data volume mounted" \
            "incus exec prometheus01 -- test -d /prometheus"
        run_test "Prometheus data volume has data" \
            "incus exec prometheus01 -- test -d /prometheus/wal || incus exec prometheus01 -- test -d /prometheus/chunks_head"
    else
        skip_test "Prometheus storage" "container not running"
    fi

    # Check Loki data volume
    if container_running "loki01"; then
        run_test "Loki data volume mounted" \
            "incus exec loki01 -- test -d /loki"
    else
        skip_test "Loki storage" "container not running"
    fi

    # Check step-ca data volume
    if container_running "step-ca01"; then
        run_test "step-ca data volume mounted" \
            "incus exec step-ca01 -- test -d /home/step"
        run_test "step-ca has CA certificate" \
            "incus exec step-ca01 -- test -f /home/step/certs/root_ca.crt"
        run_test "step-ca has fingerprint" \
            "incus exec step-ca01 -- test -f /home/step/fingerprint"
    else
        skip_test "step-ca storage" "container not running"
    fi

    # Check Alertmanager data volume
    if container_running "alertmanager01"; then
        run_test "Alertmanager data volume mounted" \
            "incus exec alertmanager01 -- test -d /alertmanager"
    else
        skip_test "Alertmanager storage" "container not running"
    fi

    # Check Mosquitto data volume
    if container_running "mosquitto01"; then
        run_test "Mosquitto data volume mounted" \
            "incus exec mosquitto01 -- test -d /mosquitto/data"
    else
        skip_test "Mosquitto storage" "container not running"
    fi

    # Check volume ownership (Grafana)
    if container_running "grafana01"; then
        run_test "Grafana volume ownership correct" \
            "incus exec grafana01 -- stat -c '%u:%g' /var/lib/grafana | grep -q '472:472'"
    else
        skip_test "Grafana volume ownership" "container not running"
    fi

    # Check volume ownership (Prometheus)
    if container_running "prometheus01"; then
        run_test "Prometheus volume ownership correct" \
            "incus exec prometheus01 -- stat -c '%u:%g' /prometheus | grep -q '65534:65534'"
    else
        skip_test "Prometheus volume ownership" "container not running"
    fi
}

test_network() {
    log_info "=== Network Isolation Tests ==="

    # Services on management network can reach each other
    if container_running "grafana01" && container_running "prometheus01"; then
        run_test "Management network: Grafana -> Prometheus" \
            "incus exec grafana01 -- ping -c 1 -W 2 prometheus01.incus"
    else
        skip_test "Management network connectivity" "containers not running"
    fi

    # Caddy has multiple network interfaces
    if container_running "caddy01"; then
        run_test "Caddy has management network access" \
            "incus exec caddy01 -- ping -c 1 -W 2 grafana01.incus 2>/dev/null || incus exec caddy01 -- wget -q --spider --timeout=2 http://grafana01.incus:3000/api/health 2>/dev/null"
    else
        skip_test "Caddy network access" "container not running"
    fi

    # DNS resolution works
    if container_running "grafana01"; then
        run_test "DNS resolution for prometheus01.incus" \
            "incus exec grafana01 -- nslookup prometheus01.incus > /dev/null 2>&1 || incus exec grafana01 -- getent hosts prometheus01.incus"
    else
        skip_test "DNS resolution" "container not running"
    fi

    # External connectivity (NAT)
    if container_running "grafana01"; then
        run_test "External connectivity (NAT)" \
            "incus exec grafana01 -- ping -c 1 -W 5 1.1.1.1 2>/dev/null || incus exec grafana01 -- wget -q --spider --timeout=5 http://1.1.1.1 2>/dev/null"
    else
        skip_test "External connectivity" "container not running"
    fi
}

# ============================================================================
# Main
# ============================================================================

# Parse arguments
SUITES=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            SUITES+=("$1")
            shift
            ;;
    esac
done

# Default to all suites
if [[ ${#SUITES[@]} -eq 0 ]]; then
    SUITES=("all")
fi

# Check if incus is available
if ! command -v incus &> /dev/null; then
    echo "Error: incus command not found"
    exit 1
fi

# Check if any containers exist
if ! incus list --format csv -c n 2>/dev/null | grep -q .; then
    echo "Error: No Incus containers found. Deploy infrastructure first with 'make deploy'"
    exit 1
fi

log_info "Starting integration tests..."
echo ""

# Run selected test suites
for suite in "${SUITES[@]}"; do
    case $suite in
        health)
            test_health
            ;;
        connectivity)
            test_connectivity
            ;;
        storage)
            test_storage
            ;;
        network)
            test_network
            ;;
        all)
            test_health
            echo ""
            test_connectivity
            echo ""
            test_storage
            echo ""
            test_network
            ;;
        *)
            echo "Unknown test suite: $suite"
            echo "Available suites: health, connectivity, storage, network, all"
            exit 1
            ;;
    esac
    echo ""
done

# Summary
log_info "=== Test Summary ==="
echo -e "  Total:   ${TESTS_RUN}"
echo -e "  ${GREEN}Passed:  ${TESTS_PASSED}${NC}"
echo -e "  ${RED}Failed:  ${TESTS_FAILED}${NC}"
echo -e "  ${YELLOW}Skipped: ${TESTS_SKIPPED}${NC}"
echo ""

# Exit code based on failures
if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
