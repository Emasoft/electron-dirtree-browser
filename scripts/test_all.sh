#!/bin/bash
# Cross-platform parallel test script for DirTree Browser
# Runs tests on all platforms simultaneously using Docker containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_COMPOSE="$PROJECT_DIR/docker/docker-compose.yml"
LOG_DIR="$PROJECT_DIR/test-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Create log directory
setup_logs() {
    mkdir -p "$LOG_DIR"
    log_info "Test logs will be saved to: $LOG_DIR"
}

# Run a single test in background
run_test() {
    local platform=$1
    local log_file="$LOG_DIR/${TIMESTAMP}_test_${platform}.log"

    log_test "Starting $platform test..."

    # Use docker compose (v2) or docker-compose (v1)
    if docker compose version &> /dev/null 2>&1; then
        docker compose -f "$DOCKER_COMPOSE" run --rm "test-$platform" > "$log_file" 2>&1 &
    else
        docker-compose -f "$DOCKER_COMPOSE" run --rm "test-$platform" > "$log_file" 2>&1 &
    fi

    echo $!
}

# Check test result
check_result() {
    local pid=$1
    local platform=$2
    local log_file="$LOG_DIR/${TIMESTAMP}_test_${platform}.log"

    wait $pid
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        if grep -q "PASSED" "$log_file"; then
            log_info "$platform: ${GREEN}PASSED${NC}"
            return 0
        else
            log_warn "$platform: ${YELLOW}SKIPPED${NC} (no artifacts found)"
            return 0
        fi
    else
        log_error "$platform: ${RED}FAILED${NC}"
        echo "  Log: $log_file"
        return 1
    fi
}

# Main test execution
run_all_tests() {
    local platforms=("$@")
    local pids=()
    local results=()

    log_info "Starting parallel tests for ${#platforms[@]} platforms..."
    echo ""

    # Start all tests in parallel
    for platform in "${platforms[@]}"; do
        pid=$(run_test "$platform")
        pids+=("$pid:$platform")
    done

    echo ""
    log_info "Waiting for tests to complete..."
    echo ""

    # Wait for all tests and collect results
    local failed=0
    for entry in "${pids[@]}"; do
        pid="${entry%%:*}"
        platform="${entry##*:}"

        if ! check_result "$pid" "$platform"; then
            ((failed++))
        fi
    done

    echo ""
    return $failed
}

# Print usage
usage() {
    echo "Usage: $0 [OPTIONS] [PLATFORMS...]"
    echo ""
    echo "Run cross-platform tests using Docker containers."
    echo ""
    echo "Platforms:"
    echo "  linux-x64     Test Linux x64 build (AppImage)"
    echo "  windows-x64   Test Windows x64 build (portable exe)"
    echo "  linux-arm64   Test Linux ARM64 build (requires ARM64 Docker)"
    echo "  all           Test all platforms (default)"
    echo ""
    echo "Options:"
    echo "  --build-first   Build before testing"
    echo "  --help          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                        # Test all platforms"
    echo "  $0 linux-x64 windows-x64  # Test specific platforms"
    echo "  $0 --build-first all      # Build and test all"
}

# Build before testing
build_first() {
    log_info "Building all platforms before testing..."
    "$SCRIPT_DIR/build-all.sh" all
}

# Main entry point
main() {
    local build=false
    local platforms=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --build-first)
                build=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            all)
                platforms=("linux-x64" "windows-x64")
                # Add arm64 only if platform supports it
                if docker version --format '{{.Server.Arch}}' 2>/dev/null | grep -q arm64; then
                    platforms+=("linux-arm64")
                fi
                shift
                ;;
            linux-x64|windows-x64|linux-arm64)
                platforms+=("$1")
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Default to all if no platforms specified
    if [ ${#platforms[@]} -eq 0 ]; then
        platforms=("linux-x64" "windows-x64")
        # Add arm64 only if platform supports it
        if docker version --format '{{.Server.Arch}}' 2>/dev/null | grep -q arm64; then
            platforms+=("linux-arm64")
        fi
    fi

    echo ""
    echo "=================================="
    echo "  DirTree Browser - Test Suite"
    echo "=================================="
    echo ""

    check_prerequisites
    setup_logs

    if [ "$build" = true ]; then
        build_first
    fi

    # Check if release directory exists
    if [ ! -d "$PROJECT_DIR/release" ]; then
        log_warn "No release directory found. Run './scripts/build-all.sh' first or use --build-first"
        exit 1
    fi

    run_all_tests "${platforms[@]}"
    local failed=$?

    echo "=================================="
    if [ $failed -eq 0 ]; then
        log_info "All tests passed!"
        echo "=================================="
        exit 0
    else
        log_error "$failed platform(s) failed"
        echo "=================================="
        echo "Check logs in: $LOG_DIR"
        exit 1
    fi
}

main "$@"
