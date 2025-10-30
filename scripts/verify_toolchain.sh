#!/bin/bash
# ForgeOS Toolchain Verification Script
# Verifies that a built toolchain is working correctly
# Tests compilation, linking, and binary architecture
# Usage: verify_toolchain.sh [ARCH] [TOOLCHAIN] [ARTIFACTS_DIR]

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

# Detect project root
detect_project_root

# Parameters
ARCH="${1:-aarch64}"
TOOLCHAIN="${2:-musl}"
ARTIFACTS_DIR="${3:-$PROJECT_ROOT/artifacts}"

# Get toolchain configuration
get_toolchain_config "$ARCH" "$TOOLCHAIN" || exit 1

# Toolchain directory
case "$TOOLCHAIN" in
    "musl")
        TOOLCHAIN_DIR="$ARTIFACTS_DIR/$ARCH-musl"
        ;;
    "gnu"|"glibc")
        TOOLCHAIN_DIR="$ARTIFACTS_DIR/$ARCH-gnu"
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

# =============================================================================
# Set up toolchain environment (no env.sh needed)
# =============================================================================

export PATH="$TOOLCHAIN_DIR/bin:$PATH"
export CC="$TOOLCHAIN_DIR/bin/$TARGET-gcc"
export CXX="$TOOLCHAIN_DIR/bin/$TARGET-g++"
export AR="$TOOLCHAIN_DIR/bin/$TARGET-ar"
export STRIP="$TOOLCHAIN_DIR/bin/$TARGET-strip"
export RANLIB="$TOOLCHAIN_DIR/bin/$TARGET-ranlib"
export NM="$TOOLCHAIN_DIR/bin/$TARGET-nm"
export OBJCOPY="$TOOLCHAIN_DIR/bin/$TARGET-objcopy"
export OBJDUMP="$TOOLCHAIN_DIR/bin/$TARGET-objdump"
export READELF="$TOOLCHAIN_DIR/bin/$TARGET-readelf"
export LD="$TOOLCHAIN_DIR/bin/$TARGET-ld"
export AS="$TOOLCHAIN_DIR/bin/$TARGET-as"

# =============================================================================
# Verify toolchain binaries
# =============================================================================

log_info "Verifying toolchain binaries..."
echo ""

errors=0

# Helper function to verify binary
verify_binary() {
    local binary="$1"
    local name="$2"
    
    if [[ ! -f "$binary" ]]; then
        log_error "$name: not found"
        return 1
    fi
    
    if [[ ! -x "$binary" ]]; then
        log_error "$name: not executable"
        return 1
    fi
    
    if ! "$binary" --version >/dev/null 2>&1; then
        log_error "$name: not working"
        return 1
    fi
    
    local version="$("$binary" --version 2>/dev/null | head -n1)"
    log_success "$name: $version"
    return 0
}

# Verify all toolchain binaries
verify_binary "$CC" "GCC" || ((errors++))
verify_binary "$CXX" "G++" || ((errors++))
verify_binary "$AR" "AR" || ((errors++))
verify_binary "$LD" "LD" || ((errors++))
verify_binary "$AS" "AS" || ((errors++))
verify_binary "$STRIP" "STRIP" || ((errors++))
verify_binary "$RANLIB" "RANLIB" || ((errors++))
verify_binary "$NM" "NM" || ((errors++))
verify_binary "$OBJCOPY" "OBJCOPY" || ((errors++))
verify_binary "$OBJDUMP" "OBJDUMP" || ((errors++))
verify_binary "$READELF" "READELF" || ((errors++))

echo ""

# =============================================================================
# Test compilation
# =============================================================================

log_info "Testing toolchain compilation..."

# Create test directory
TEST_DIR="/tmp/forgeos-toolchain-test-$$"
mkdir -p "$TEST_DIR"

# Cleanup function
cleanup_test() {
    rm -rf "$TEST_DIR"
}
trap cleanup_test EXIT

# C test program
cat > "$TEST_DIR/test.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
    printf("Hello from ForgeOS toolchain!\n");
    printf("Target: %s\n", "TEST_ARCH");
    return 0;
}
EOF

# C++ test program
cat > "$TEST_DIR/test.cpp" << 'EOF'
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
if [[ -f "$TEST_DIR/test_c" ]]; then
    log_info "Testing static linking..."
    if ldd "$TEST_DIR/test_c" 2>/dev/null | grep -q "not a dynamic executable"; then
        log_success "Static linking: passed"
    else
        log_warning "Static linking: binary may not be fully static"
    fi
fi

# Test cross-compilation target
if [[ -f "$TEST_DIR/test_c" ]]; then
    log_info "Testing cross-compilation target..."
    if file "$TEST_DIR/test_c" | grep -q "$ARCH"; then
        log_success "Cross-compilation target: $ARCH"
    else
        log_warning "Cross-compilation target: unexpected architecture"
    fi
fi

# Test simple build flags
log_info "Testing build flags..."
if echo 'int main(){return 0;}' | "$CC" -x c - -o "$TEST_DIR/test_flags" 2>/dev/null; then
    log_success "Build flags: working"
else
    log_error "Build flags: failed"
    ((errors++))
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
if [[ $errors -eq 0 ]]; then
    log_success "Toolchain verification completed successfully!"
    log_info "Toolchain: $TOOLCHAIN_DIR"
    log_info "Target: $TARGET"
    log_info "Cross-compile prefix: $CROSS_COMPILE"
    log_info "All tests passed!"
    exit 0
else
    log_error "Toolchain verification failed with $errors errors"
    log_info "Please check the toolchain build and try again"
    exit 1
fi
