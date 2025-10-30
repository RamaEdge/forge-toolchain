#!/bin/bash
# ForgeOS Toolchain Build Script
# Builds cross-compilation toolchains (musl/glibc)
# Usage: build_toolchain.sh [ARCH] [TOOLCHAIN]

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

# Detect project root
detect_project_root

# Load configuration
. "$PROJECT_ROOT/scripts/load_config.sh"

# Parameters
ARCH="${1:-aarch64}"
TOOLCHAIN="${2:-musl}"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/artifacts}"

# Get toolchain configuration
get_toolchain_config "$ARCH" "$TOOLCHAIN" || exit 1

# Common configuration
PACKAGES_EXTRACTED="$PROJECT_ROOT/packages/extracted"
PACKAGES_DIR="${PACKAGES_DIR:-$PROJECT_ROOT/packages/downloads}"

# Build logic based on toolchain type
case "$TOOLCHAIN" in
    "musl")
        # OUTPUT_DIR already includes arch-toolchain from Makefile or defaults to artifacts
        TOOLCHAIN_OUTPUT="${OUTPUT_DIR:-$PROJECT_ROOT/artifacts/$ARCH-musl}"
        BUILD_ROOT="$BUILD_DIR/musl-toolchain"
        LIBC_TYPE="musl"
        LIBC_PATTERN="musl-*"
        ;;
    "gnu"|"glibc")
        # OUTPUT_DIR already includes arch-toolchain from Makefile or defaults to artifacts
        TOOLCHAIN_OUTPUT="${OUTPUT_DIR:-$PROJECT_ROOT/artifacts/$ARCH-gnu}"
        BUILD_ROOT="$BUILD_DIR/glibc-toolchain"
        LIBC_TYPE="glibc"
        LIBC_PATTERN="glibc-*"
        ;;
    *)
        log_error "Unknown toolchain: $TOOLCHAIN"
        log_info "Supported toolchains: musl, gnu, glibc"
        exit 1
        ;;
esac

log_info "Building $LIBC_TYPE toolchain for $ARCH"
log_info "Target: $TARGET"
log_info "Extracted packages: $PACKAGES_EXTRACTED"
log_info "Build directory: $BUILD_ROOT"
log_info "Output directory: $TOOLCHAIN_OUTPUT"

# =============================================================================
# Find required pre-extracted packages
# =============================================================================

log_info "Locating pre-extracted packages..."

# Find pre-extracted package directories
BINUTILS_SRC=$(find "$PACKAGES_EXTRACTED" -maxdepth 1 -type d -name "binutils-*" | head -1)
GCC_SRC=$(find "$PACKAGES_EXTRACTED" -maxdepth 1 -type d -name "gcc-*" | head -1)
LIBC_SRC=$(find "$PACKAGES_EXTRACTED" -maxdepth 1 -type d -name "$LIBC_PATTERN" | head -1)
LINUX_SRC=$(find "$PACKAGES_EXTRACTED" -maxdepth 1 -type d -name "linux-*" | head -1)

# Verify all packages found
missing_packages=()
[[ -z "$BINUTILS_SRC" ]] && missing_packages+=("binutils")
[[ -z "$GCC_SRC" ]] && missing_packages+=("gcc")
[[ -z "$LIBC_SRC" ]] && missing_packages+=("$LIBC_TYPE")
[[ -z "$LINUX_SRC" ]] && missing_packages+=("linux")

if [[ ${#missing_packages[@]} -gt 0 ]]; then
    log_error "Required packages not found in $PACKAGES_EXTRACTED:"
    for pkg in "${missing_packages[@]}"; do
        log_error "  - $pkg"
    done
    log_info "Run download-packages first: make download-packages"
    exit 1
fi

log_success "Found: $(basename "$BINUTILS_SRC")"
log_success "Found: $(basename "$GCC_SRC")"
log_success "Found: $(basename "$LIBC_SRC")"
log_success "Found: $(basename "$LINUX_SRC")"

# =============================================================================
# Setup build directories (out-of-tree builds)
# =============================================================================

log_info "Setting up out-of-tree build directories..."

# Create build directories (not copying sources, just build dirs)
mkdir -p "$BUILD_ROOT" "$TOOLCHAIN_OUTPUT"

# Use extracted sources directly (read-only)
BINUTILS_SRC_DIR="$BINUTILS_SRC"
GCC_SRC_DIR="$GCC_SRC"
LIBC_SRC_DIR="$LIBC_SRC"
LINUX_SRC_DIR="$LINUX_SRC"

# Create separate build directories for each component
BINUTILS_BUILD_DIR="$BUILD_ROOT/binutils-build"
GCC_BUILD_DIR="$BUILD_ROOT/gcc-build"
LIBC_BUILD_DIR="$BUILD_ROOT/libc-build"

log_success "Build directories ready"

# Create target directories
mkdir -p "$TOOLCHAIN_OUTPUT/share/info" "$TOOLCHAIN_OUTPUT/share/man"
mkdir -p "$TOOLCHAIN_OUTPUT/$TARGET"

# Get absolute paths
TOOLCHAIN_OUTPUT_ABS="$(cd "$TOOLCHAIN_OUTPUT" && pwd)"
TOOLCHAIN_TARGET_ABS="$TOOLCHAIN_OUTPUT_ABS/$TARGET"
LINUX_HEADERS_ABS="$(cd "$LINUX_SRC_DIR/include" && pwd)"

# =============================================================================
# Build binutils
# =============================================================================

log_info "Building binutils..."
mkdir -p "$BINUTILS_BUILD_DIR"

pushd "$BINUTILS_BUILD_DIR" > /dev/null
"$BINUTILS_SRC_DIR/configure" \
    --target="$TARGET" \
    --prefix="$TOOLCHAIN_OUTPUT_ABS" \
    --disable-nls \
    --disable-werror \
    --disable-multilib \
    --infodir="$TOOLCHAIN_OUTPUT_ABS/share/info" \
    --mandir="$TOOLCHAIN_OUTPUT_ABS/share/man" \
    --datadir="$TOOLCHAIN_OUTPUT_ABS/share"
make -j$(nproc 2>/dev/null || echo 4)
make DESTDIR="" install
popd > /dev/null
log_success "binutils built"

# =============================================================================
# Build GCC (stage 1 - bootstrap)
# =============================================================================

log_info "Building GCC (stage 1 - bootstrap)..."
mkdir -p "$GCC_BUILD_DIR"

pushd "$GCC_BUILD_DIR" > /dev/null
"$GCC_SRC_DIR/configure" \
    --target="$TARGET" \
    --prefix="$TOOLCHAIN_OUTPUT_ABS" \
    --enable-languages=c \
    --disable-libssp \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libsanitizer \
    --disable-libatomic \
    --disable-libquadmath \
    --disable-multilib \
    --with-sysroot="$TOOLCHAIN_TARGET_ABS" \
    --with-newlib \
    --disable-shared \
    --disable-threads \
    --disable-libstdcxx-pch \
    --infodir="$TOOLCHAIN_OUTPUT_ABS/share/info" \
    --mandir="$TOOLCHAIN_OUTPUT_ABS/share/man" \
    --datadir="$TOOLCHAIN_OUTPUT_ABS/share"
make -j$(nproc 2>/dev/null || echo 4) all-gcc
make DESTDIR="" install-gcc
popd > /dev/null
log_success "GCC stage 1 built"

# =============================================================================
# Build libc (musl or glibc)
# =============================================================================

case "$TOOLCHAIN" in
    "musl")
        log_info "Building musl..."
        
        if [[ ! -f "$TOOLCHAIN_TARGET_ABS/lib/libc.so" ]]; then
            mkdir -p "$LIBC_BUILD_DIR"
            pushd "$LIBC_BUILD_DIR" > /dev/null
            export PATH="$TOOLCHAIN_OUTPUT_ABS/bin:$PATH"
            export CC="gcc"
            export CROSS_COMPILE=""
            export CFLAGS="-O2"
            export LDFLAGS=""
            
            "$LIBC_SRC_DIR/configure" \
                --prefix="$TOOLCHAIN_TARGET_ABS" \
                --disable-shared \
                --infodir="$TOOLCHAIN_OUTPUT_ABS/share/info" \
                --mandir="$TOOLCHAIN_OUTPUT_ABS/share/man" \
                --datadir="$TOOLCHAIN_OUTPUT_ABS/share" \
                "$TARGET"
            make -j$(nproc 2>/dev/null || echo 4)
            make DESTDIR="" install
            popd > /dev/null
            log_success "musl built"
        else
            log_success "musl already built - skipping"
        fi
        ;;
    "gnu"|"glibc")
        log_info "Building glibc headers..."
        mkdir -p "$LIBC_BUILD_DIR"
        
        if [[ ! -f "$TOOLCHAIN_TARGET_ABS/lib/libc.so.6" ]]; then
            pushd "$LIBC_BUILD_DIR" > /dev/null
            "$LIBC_SRC_DIR/configure" \
                --target="$TARGET" \
                --prefix="$TOOLCHAIN_TARGET_ABS" \
                --with-headers="$LINUX_HEADERS_ABS" \
                --disable-multilib \
                --infodir="$TOOLCHAIN_OUTPUT_ABS/share/info" \
                --mandir="$TOOLCHAIN_OUTPUT_ABS/share/man" \
                --datadir="$TOOLCHAIN_OUTPUT_ABS/share"
            make DESTDIR="" install-headers
            popd > /dev/null
            log_success "glibc headers installed"
        else
            log_success "glibc already built - skipping"
        fi
        ;;
esac

# =============================================================================
# Verify toolchain
# =============================================================================

log_info "Verifying toolchain..."
if [[ -f "$TOOLCHAIN_OUTPUT_ABS/bin/$TARGET-gcc" ]]; then
    "$TOOLCHAIN_OUTPUT_ABS/bin/$TARGET-gcc" --version | head -1
    log_success "Toolchain verification complete"
else
    log_error "Toolchain verification failed"
    exit 1
fi

log_success "$LIBC_TYPE toolchain build complete: $TOOLCHAIN_OUTPUT_ABS"

