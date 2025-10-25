#!/bin/bash
# ForgeOS Toolchain Test Script
# Tests toolchain functionality with sample programs
# Usage: test_toolchain.sh <arch> <toolchain> <artifacts_dir>

set -euo pipefail

# Script configuration - Detect project root using git
# This ensures we find the correct root regardless of script location or invocation directory
if ! PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    # Fallback to script-based detection if not in a git repository
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    echo "Warning: Not in a git repository. Using fallback project root detection." >&2
    echo "Project root: $PROJECT_ROOT" >&2
fi

# Parameters
ARCH="${1:-aarch64}"
TOOLCHAIN="${2:-musl}"
ARTIFACTS_DIR="${3:-artifacts}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

# Toolchain configuration
case "$TOOLCHAIN" in
    "musl")
        TARGET="$ARCH-linux-musl"
        CROSS_COMPILE="$TARGET-"
        TOOLCHAIN_DIR="$ARTIFACTS_DIR/$ARCH-musl"
        ;;
    "gnu"|"glibc")
        TARGET="$ARCH-linux-gnu"
        CROSS_COMPILE="$TARGET-"
        TOOLCHAIN_DIR="$ARTIFACTS_DIR/$ARCH-gnu"
        ;;
    *)
        log_error "Unknown toolchain: $TOOLCHAIN"
        log_info "Supported toolchains: musl, gnu, glibc"
        exit 1
        ;;
esac

log_info "Testing $TOOLCHAIN toolchain for $ARCH"
log_info "Target: $TARGET"
log_info "Toolchain directory: $TOOLCHAIN_DIR"

# Check if toolchain exists
if [[ ! -d "$TOOLCHAIN_DIR" ]]; then
    log_error "Toolchain directory not found: $TOOLCHAIN_DIR"
    log_info "Please build the toolchain first: make toolchain TOOLCHAIN=$TOOLCHAIN ARCH=$ARCH"
    exit 1
fi

# Source the environment script
log_info "Loading toolchain environment..."
source "$TOOLCHAIN_DIR/env.sh"

# Create test directory
TEST_DIR="/tmp/forgeos-toolchain-test-$$"
mkdir -p "$TEST_DIR"

# Test C compilation
log_info "Testing C compilation..."
cat > "$TEST_DIR/hello.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
    printf("Hello from ForgeOS %s toolchain!\n", "musl");
    printf("This is a test of the cross-compilation toolchain.\n");
    return 0;
}
EOF

if "$CC" -static -o "$TEST_DIR/hello_c" "$TEST_DIR/hello.c" 2>/dev/null; then
    log_success "C compilation: passed"
else
    log_error "C compilation: failed"
    exit 1
fi

# Test C++ compilation
log_info "Testing C++ compilation..."
cat > "$TEST_DIR/hello.cpp" << 'EOF'
#include <iostream>
#include <string>
#include <vector>

int main() {
    std::string message = "Hello from ForgeOS C++ toolchain!";
    std::vector<std::string> words = {"This", "is", "a", "test"};
    
    std::cout << message << std::endl;
    for (const auto& word : words) {
        std::cout << word << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
EOF

if "$CXX" -static -o "$TEST_DIR/hello_cpp" "$TEST_DIR/hello.cpp" 2>/dev/null; then
    log_success "C++ compilation: passed"
else
    log_error "C++ compilation: failed"
    exit 1
fi

# Test static linking
log_info "Testing static linking..."
if ldd "$TEST_DIR/hello_c" 2>/dev/null | grep -q "not a dynamic executable"; then
    log_success "Static linking: passed"
else
    log_warning "Static linking: may not be fully static"
fi

# Test cross-compilation target
log_info "Testing cross-compilation target..."
if file "$TEST_DIR/hello_c" | grep -q "$ARCH"; then
    log_success "Cross-compilation target: $ARCH"
else
    log_warning "Cross-compilation target: unexpected"
fi

# Test toolchain binaries
log_info "Testing toolchain binaries..."
for binary in "$CC" "$CXX" "$AR" "$STRIP" "$RANLIB" "$NM" "$OBJCOPY" "$OBJDUMP" "$READELF"; do
    if [[ -x "$binary" ]] && "$binary" --version >/dev/null 2>&1; then
        log_success "$(basename "$binary"): working"
    else
        log_error "$(basename "$binary"): failed"
        exit 1
    fi
done

# Test build flags
log_info "Testing build flags..."
if echo 'int main(){return 0;}' | "$CC" -x c - -o "$TEST_DIR/test_flags" 2>/dev/null; then
    log_success "Build flags: working"
else
    log_error "Build flags: failed"
    exit 1
fi

# Clean up
rm -rf "$TEST_DIR"

log_success "Toolchain test completed successfully!"
log_info "Toolchain: $TOOLCHAIN_DIR"
log_info "Target: $TARGET"
log_info "Cross-compile: $CROSS_COMPILE"
log_info "All tests passed!"
