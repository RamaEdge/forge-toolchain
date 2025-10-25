#!/bin/bash
# ForgeOS Toolchain Verification Script
# Verifies that a built toolchain is working correctly
# Usage: verify_toolchain.sh <arch> <toolchain> <artifacts_dir>

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

log_info "Verifying $TOOLCHAIN toolchain for $ARCH"
log_info "Target: $TARGET"
log_info "Toolchain directory: $TOOLCHAIN_DIR"

# Check if toolchain directory exists
if [[ ! -d "$TOOLCHAIN_DIR" ]]; then
    log_error "Toolchain directory not found: $TOOLCHAIN_DIR"
    log_info "Please build the toolchain first: make toolchain TOOLCHAIN=$TOOLCHAIN ARCH=$ARCH"
    exit 1
fi

# Check if environment script exists
if [[ ! -f "$TOOLCHAIN_DIR/env.sh" ]]; then
    log_error "Environment script not found: $TOOLCHAIN_DIR/env.sh"
    exit 1
fi

# Source the environment script
log_info "Loading toolchain environment..."
source "$TOOLCHAIN_DIR/env.sh"

# Verify toolchain binaries
verify_binary() {
    local binary="$1"
    local name="$2"
    local expected_target="$3"
    
    if [[ -f "$binary" ]]; then
        if [[ -x "$binary" ]]; then
            # Check if binary is executable and returns version info
            if "$binary" --version >/dev/null 2>&1; then
                local version="$("$binary" --version | head -n1)"
                log_success "$name: $version"
                
                # Check target architecture
                if echo "$version" | grep -q "$expected_target"; then
                    log_success "$name target: $expected_target"
                else
                    log_warning "$name target: unexpected (expected: $expected_target)"
                fi
                return 0
            else
                log_error "$name: not executable or broken"
                return 1
            fi
        else
            log_error "$name: not executable"
            return 1
        fi
    else
        log_error "$name: not found"
        return 1
    fi
}

# Verify all toolchain binaries
log_info "Verifying toolchain binaries..."
echo ""

local errors=0

# Core compilers
if ! verify_binary "$CC" "GCC" "$TARGET"; then
    ((errors++))
fi

if ! verify_binary "$CXX" "G++" "$TARGET"; then
    ((errors++))
fi

# Build tools
if ! verify_binary "$AR" "AR" "$TARGET"; then
    ((errors++))
fi

if ! verify_binary "$STRIP" "STRIP" "$TARGET"; then
    ((errors++))
fi

if ! verify_binary "$RANLIB" "RANLIB" "$TARGET"; then
    ((errors++))
fi

if ! verify_binary "$NM" "NM" "$TARGET"; then
    ((errors++))
fi

if ! verify_binary "$OBJCOPY" "OBJCOPY" "$TARGET"; then
    ((errors++))
fi

if ! verify_binary "$OBJDUMP" "OBJDUMP" "$TARGET"; then
    ((errors++))
fi

if ! verify_binary "$READELF" "READELF" "$TARGET"; then
    ((errors++))
fi

echo ""

# Test compilation
log_info "Testing toolchain compilation..."

# Create test source files
TEST_DIR="/tmp/forgeos-toolchain-test-$$"
mkdir -p "$TEST_DIR"

# C test program
cat > "$TEST_DIR/test.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>

int main() {
    printf("Hello from ForgeOS %s toolchain!\n", "musl");
    return 0;
}
EOF

# C++ test program
cat > "$TEST_DIR/test.cpp" << 'EOF'
#include <iostream>
#include <string>

int main() {
    std::string message = "Hello from ForgeOS C++ toolchain!";
    std::cout << message << std::endl;
    return 0;
}
EOF

# Test C compilation
log_info "Testing C compilation..."
if "$CC" -static -o "$TEST_DIR/test_c" "$TEST_DIR/test.c" 2>/dev/null; then
    log_success "C compilation: passed"
else
    log_error "C compilation: failed"
    ((errors++))
fi

# Test C++ compilation
log_info "Testing C++ compilation..."
if "$CXX" -static -o "$TEST_DIR/test_cpp" "$TEST_DIR/test.cpp" 2>/dev/null; then
    log_success "C++ compilation: passed"
else
    log_error "C++ compilation: failed"
    ((errors++))
fi

# Test static linking
log_info "Testing static linking..."
if [[ -f "$TEST_DIR/test_c" ]] && [[ -f "$TEST_DIR/test_cpp" ]]; then
    # Check if binaries are statically linked
    if ldd "$TEST_DIR/test_c" 2>/dev/null | grep -q "not a dynamic executable"; then
        log_success "Static linking: passed"
    else
        log_warning "Static linking: may not be fully static"
    fi
else
    log_warning "Static linking: cannot test (compilation failed)"
fi

# Test cross-compilation target
log_info "Testing cross-compilation target..."
if [[ -f "$TEST_DIR/test_c" ]]; then
    # Check if binary is for the correct target
    if file "$TEST_DIR/test_c" | grep -q "$ARCH"; then
        log_success "Cross-compilation target: $ARCH"
    else
        log_warning "Cross-compilation target: unexpected"
    fi
else
    log_warning "Cross-compilation target: cannot test (compilation failed)"
fi

# Clean up test files
rm -rf "$TEST_DIR"

echo ""

# Check toolchain info file
if [[ -f "$TOOLCHAIN_DIR/toolchain.info" ]]; then
    log_success "Toolchain info file: found"
    log_info "Toolchain info: $TOOLCHAIN_DIR/toolchain.info"
else
    log_warning "Toolchain info file: not found"
fi

# Summary
echo ""
if [[ $errors -eq 0 ]]; then
    log_success "Toolchain verification completed successfully!"
    log_info "Toolchain: $TOOLCHAIN_DIR"
    log_info "Environment: $TOOLCHAIN_DIR/env.sh"
    log_info "Target: $TARGET"
    log_info "Cross-compile: $CROSS_COMPILE"
    exit 0
else
    log_error "Toolchain verification failed with $errors errors"
    log_info "Please check the toolchain build and try again"
    exit 1
fi
