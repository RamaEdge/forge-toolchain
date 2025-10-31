#!/bin/bash
# ForgeOS Toolchain Build Script
# Builds cross-compilation toolchains (musl/glibc)
# Usage: build_toolchain.sh [ARCH] [TOOLCHAIN]

set -euo pipefail

# =============================================================================
# SETUP
# =============================================================================

# Load utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"
detect_project_root
. "$PROJECT_ROOT/scripts/load_config.sh"

# Parameters from command line (fallback if not exported by Makefile)
ARCH_PARAM="${1:-aarch64}"
TOOLCHAIN_PARAM="${2:-musl}"

# Validate Makefile provides required variables
: "${OUTPUT_DIR:?ERROR: Must be called via Makefile}"

# Use ARCH and TOOLCHAIN from Makefile exports if available, otherwise from parameters
ARCH="${ARCH:-$ARCH_PARAM}"
TOOLCHAIN="${TOOLCHAIN:-$TOOLCHAIN_PARAM}"

# Determine libc type and compute TARGET triple
case "$TOOLCHAIN" in
    musl) 
        LIBC_TYPE="musl"
        LIBC_PATTERN="musl-*"
        TARGET="${TARGET:-$ARCH-linux-musl}"
        ;;
    gnu|glibc) 
        LIBC_TYPE="glibc"
        LIBC_PATTERN="glibc-*"
        TARGET="${TARGET:-$ARCH-linux-gnu}"
        ;;
    *) 
        log_error "Unknown toolchain: $TOOLCHAIN"
        exit 1
        ;;
esac

# Start centralized logging (after we have the correct ARCH and TOOLCHAIN values)
start_build_log "build-toolchain" "${TOOLCHAIN}-${ARCH}"

# Build paths
BUILD_ROOT="$BUILD_DIR/${LIBC_TYPE}-toolchain"
TOOLCHAIN_OUTPUT="$OUTPUT_DIR"
PACKAGES_EXTRACTED="$PROJECT_ROOT/packages/extracted"

log_info "Building $LIBC_TYPE toolchain for $ARCH"
log_info "Target: $TARGET"
log_info "Output: $TOOLCHAIN_OUTPUT"

# =============================================================================
# PACKAGE DISCOVERY
# =============================================================================

# Find pre-extracted packages (Makefile ensures they exist)
BINUTILS_SRC=$(find "$PACKAGES_EXTRACTED" -maxdepth 1 -type d -name "binutils-*" -print -quit)
GCC_SRC=$(find "$PACKAGES_EXTRACTED" -maxdepth 1 -type d -name "gcc-*" -print -quit)
LIBC_SRC=$(find "$PACKAGES_EXTRACTED" -maxdepth 1 -type d -name "$LIBC_PATTERN" -print -quit)
LINUX_SRC=$(find "$PACKAGES_EXTRACTED" -maxdepth 1 -type d -name "linux-*" -print -quit)

log_success "Found: $(basename "$BINUTILS_SRC")"
log_success "Found: $(basename "$GCC_SRC")"
log_success "Found: $(basename "$LIBC_SRC")"
log_success "Found: $(basename "$LINUX_SRC")"

# =============================================================================
# DIRECTORY SETUP
# =============================================================================

log_info "Setting up build directories..."

# Create all needed directories
mkdir -p "$BUILD_ROOT"/{binutils-build,gcc-build,libc-build} \
         "$TOOLCHAIN_OUTPUT/share"/{info,man} \
         "$TOOLCHAIN_OUTPUT/$TARGET"

# Resolve absolute paths once
TOOLCHAIN_OUTPUT_ABS="$(cd "$TOOLCHAIN_OUTPUT" && pwd)"
TOOLCHAIN_TARGET_ABS="$TOOLCHAIN_OUTPUT_ABS/$TARGET"

log_success "Build directories ready"

# =============================================================================
# BUILD BINUTILS
# =============================================================================

log_info "Building binutils..."

pushd "$BUILD_ROOT/binutils-build" > /dev/null
"$BINUTILS_SRC/configure" \
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
# BUILD GCC (stage 1 - bootstrap)
# =============================================================================

log_info "Building GCC (stage 1 - bootstrap)..."

pushd "$BUILD_ROOT/gcc-build" > /dev/null
"$GCC_SRC/configure" \
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
# INSTALL LINUX HEADERS
# =============================================================================

log_info "Installing Linux kernel headers..."

# Map architecture to Linux kernel arch name
case "$ARCH" in
    aarch64) KERNEL_ARCH="arm64" ;;
    x86_64) KERNEL_ARCH="x86_64" ;;
    *) KERNEL_ARCH="$ARCH" ;;
esac

make -C "$LINUX_SRC" \
    ARCH="$KERNEL_ARCH" \
    INSTALL_HDR_PATH="$TOOLCHAIN_TARGET_ABS" \
    headers_install

log_success "Linux headers installed to $TOOLCHAIN_TARGET_ABS/include"

# =============================================================================
# BUILD LIBC (musl or glibc)
# =============================================================================

build_libc() {
    case "$TOOLCHAIN" in
        "musl")
            log_info "Building musl..."
            pushd "$BUILD_ROOT/libc-build" > /dev/null
            
            "$LIBC_SRC/configure" \
                --prefix="$TOOLCHAIN_TARGET_ABS" \
                --disable-shared \
                "$TARGET"
            
            make -j$(nproc 2>/dev/null || echo 4)
            make DESTDIR="" install
            popd > /dev/null
            log_success "musl built"
            ;;
            
        "gnu"|"glibc")
            log_info "Building glibc..."
            pushd "$BUILD_ROOT/libc-build" > /dev/null
            
            "$LIBC_SRC/configure" \
                --target="$TARGET" \
                --prefix="$TOOLCHAIN_TARGET_ABS" \
                --with-headers="$TOOLCHAIN_TARGET_ABS/include" \
                --disable-multilib \
                --host="$TARGET" \
                --enable-kernel=3.2.0 \
                --enable-obsolete-rpc \
                libc_cv_forced_unwind=yes
            
            make -j$(nproc 2>/dev/null || echo 4)
            make DESTDIR="" install
            popd > /dev/null
            log_success "glibc built"
            ;;
    esac
}

build_libc

# =============================================================================
# VERIFY TOOLCHAIN
# =============================================================================

log_info "Verifying toolchain..."

if [[ -f "$TOOLCHAIN_OUTPUT_ABS/bin/$TARGET-gcc" ]]; then
    "$TOOLCHAIN_OUTPUT_ABS/bin/$TARGET-gcc" --version | head -1
    log_success "Toolchain verification complete"
    log_success "$LIBC_TYPE toolchain build complete: $TOOLCHAIN_OUTPUT"
    end_build_log "success"
    exit 0
else
    log_error "Toolchain verification failed - gcc not found"
    end_build_log "failure"
    exit 1
fi
