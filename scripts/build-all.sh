#!/bin/bash
# Cross-platform build script for DirTree Browser
# Builds Electron app with embedded Rust CLI for all supported platforms

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
XLS_REPO="https://github.com/Emasoft/xls-cross-platform.git"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect current platform
detect_platform() {
    case "$(uname -s)" in
        Darwin*)
            if [[ "$(uname -m)" == "arm64" ]]; then
                echo "macos-arm64"
            else
                echo "macos-x64"
            fi
            ;;
        Linux*)
            if [[ "$(uname -m)" == "aarch64" ]]; then
                echo "linux-arm64"
            else
                echo "linux-x64"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows-x64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Build Rust CLI for current platform
build_rust_cli_native() {
    log_info "Building xls CLI for native platform..."

    local TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"

    git clone --depth 1 "$XLS_REPO" xls
    cd xls
    cargo build --release

    mkdir -p "$PROJECT_DIR/bin"

    case "$(uname -s)" in
        Darwin*|Linux*)
            cp target/release/xls "$PROJECT_DIR/bin/xls"
            chmod +x "$PROJECT_DIR/bin/xls"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            cp target/release/xls.exe "$PROJECT_DIR/bin/xls.exe"
            ;;
    esac

    cd "$PROJECT_DIR"
    rm -rf "$TMP_DIR"

    log_info "Rust CLI built successfully"
}

# Build Electron app for current platform
build_electron_native() {
    log_info "Building Electron app for native platform..."

    cd "$PROJECT_DIR"

    # Install deps if needed
    if [ ! -d "node_modules" ]; then
        pnpm install
    fi

    # Build TypeScript
    pnpm run build

    # Build for current platform
    local PLATFORM=$(detect_platform)
    case "$PLATFORM" in
        macos-x64)
            pnpm exec electron-builder --mac --x64
            ;;
        macos-arm64)
            pnpm exec electron-builder --mac --arm64
            ;;
        linux-x64)
            pnpm exec electron-builder --linux --x64
            ;;
        linux-arm64)
            pnpm exec electron-builder --linux --arm64
            ;;
        windows-x64)
            pnpm exec electron-builder --win --x64
            ;;
        *)
            log_error "Unknown platform: $PLATFORM"
            exit 1
            ;;
    esac

    log_info "Electron app built successfully"
    log_info "Output: $PROJECT_DIR/release/"
}

# Build using Docker for cross-platform
build_docker() {
    local TARGET=$1

    log_info "Building for $TARGET using Docker..."

    cd "$PROJECT_DIR"
    docker-compose -f docker/docker-compose.yml run "build-$TARGET"

    log_info "Docker build complete for $TARGET"
}

# Main entry point
main() {
    case "${1:-native}" in
        native)
            log_info "Building for current platform: $(detect_platform)"
            build_rust_cli_native
            build_electron_native
            ;;
        linux-x64)
            build_docker "linux-x64"
            ;;
        linux-arm64)
            build_docker "linux-arm64"
            ;;
        windows-x64)
            build_docker "windows-x64"
            ;;
        all)
            log_info "Building for all platforms..."

            # Native build first
            build_rust_cli_native
            build_electron_native

            # Docker builds for other platforms
            if command -v docker &> /dev/null; then
                build_docker "linux-x64"
                build_docker "windows-x64"
            else
                log_warn "Docker not available - skipping cross-platform builds"
            fi
            ;;
        *)
            echo "Usage: $0 [native|linux-x64|linux-arm64|windows-x64|all]"
            echo ""
            echo "  native      - Build for current platform (default)"
            echo "  linux-x64   - Build for Linux x64 using Docker"
            echo "  linux-arm64 - Build for Linux ARM64 using Docker"
            echo "  windows-x64 - Build for Windows x64 using Docker"
            echo "  all         - Build for all platforms"
            exit 1
            ;;
    esac
}

main "$@"
