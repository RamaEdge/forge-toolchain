#!/bin/bash
# ForgeOS Toolchain Build Script
# Builds cross-compilation toolchains (musl/glibc)

set -euo pipefail

# Script configuration - Detect project root using git
if ! PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    echo "Warning: Not in a git repository. Using fallback project root detection." >&2
    echo "Project root: $PROJECT_ROOT" >&2
fi

# Load centralized versions from load_config
. "$PROJECT_ROOT/scripts/load_config.sh"

# Parameters
ARCH="${1:-aarch64}"
TOOLCHAIN="${2:-musl}"
ARTIFACTS_DIR="${3:-$PROJECT_ROOT/artifacts}"

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

# Build configuration
BUILD_DIR="$PROJECT_ROOT/build/toolchain"
DOWNLOADS_DIR="$PROJECT_ROOT/packages/downloads"
TOOLCHAIN_OUTPUT="$ARTIFACTS_DIR/$ARCH-$TOOLCHAIN"

# Cross-compilation settings
if [[ "$TOOLCHAIN" == "musl" ]]; then
    TARGET="$ARCH-linux-musl"
    CROSS_COMPILE="$TARGET-"
else
    TARGET="$ARCH-linux-gnu"
    CROSS_COMPILE="$TARGET-"
fi

log_info "Building $TOOLCHAIN toolchain for $ARCH"
log_info "Target: $TARGET"
log_info "Build directory: $BUILD_DIR"
log_info "Output directory: $TOOLCHAIN_OUTPUT"

# Create build directories
mkdir -p "$BUILD_DIR"
mkdir -p "$TOOLCHAIN_OUTPUT"

# Check if toolchain already exists and is complete
if [[ -f "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"gcc ]] && \
   [[ -f "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"g++ ]] && \
   [[ -f "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"ar ]] && \
   [[ -f "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"ld ]]; then
    log_success "Complete toolchain already exists at $TOOLCHAIN_OUTPUT"
    log_info "Skipping toolchain build (use 'make clean-toolchain' to rebuild)"
    exit 0
fi

# Build musl toolchain using pre-downloaded packages
build_musl_toolchain() {
    log_info "Building musl toolchain using pre-downloaded packages..."
    
    # Check for required packages
    local binutils_tar="$DOWNLOADS_DIR/binutils-${BINUTILS_VERSION}.tar.xz"
    local gcc_tar="$DOWNLOADS_DIR/gcc-${GCC_VERSION}.tar.xz"
    local musl_tar="$DOWNLOADS_DIR/musl-${MUSL_VERSION}.tar.gz"
    local linux_tar="$DOWNLOADS_DIR/linux-${LINUX_VERSION}.tar.xz"
    
    for pkg in "$binutils_tar" "$gcc_tar" "$musl_tar" "$linux_tar"; do
        if [[ ! -f "$pkg" ]]; then
            log_error "Required package not found: $pkg"
            log_info "Please run 'make download-packages' first"
            exit 1
        fi
    done
    
    # Create build directories
    local build_root="$BUILD_DIR/musl-toolchain"
    mkdir -p "$build_root"
    
    # Extract packages
    log_info "Extracting toolchain packages..."
    tar -xf "$binutils_tar" -C "$build_root" || { log_error "Failed to extract binutils"; exit 1; }
    tar -xf "$gcc_tar" -C "$build_root" || { log_error "Failed to extract GCC"; exit 1; }
    tar -xf "$musl_tar" -C "$build_root" || { log_error "Failed to extract musl"; exit 1; }
    tar -xf "$linux_tar" -C "$build_root" || { log_error "Failed to extract Linux headers"; exit 1; }
    
    # Set up environment
    export PATH="$TOOLCHAIN_OUTPUT/bin:$PATH"
    export PREFIX="$TOOLCHAIN_OUTPUT"
    export DESTDIR=""
    export INSTALL_PREFIX="$TOOLCHAIN_OUTPUT"
    
    # Create target directories to prevent system directory creation
    mkdir -p "$TOOLCHAIN_OUTPUT/share/info"
    mkdir -p "$TOOLCHAIN_OUTPUT/share/man"
    mkdir -p "$TOOLCHAIN_OUTPUT/share"
    
    # Get absolute paths
    local toolchain_output_abs="$(cd "$TOOLCHAIN_OUTPUT" && pwd)"
    local toolchain_target_abs="$toolchain_output_abs/$TARGET"
    
    # Build binutils first
    log_info "Building binutils..."
    local binutils_dir="$build_root/binutils-${BINUTILS_VERSION}"
    local binutils_build_dir="$binutils_dir/build"
    mkdir -p "$binutils_build_dir"
    
    pushd "$binutils_build_dir" > /dev/null
    "$binutils_dir/configure" \
        --target="$TARGET" \
        --prefix="$toolchain_output_abs" \
        --disable-nls \
        --disable-werror \
        --disable-multilib \
        --infodir="$toolchain_output_abs/share/info" \
        --mandir="$toolchain_output_abs/share/man" \
        --datadir="$toolchain_output_abs/share"
    gmake -j$(nproc 2>/dev/null || echo 4)
    gmake DESTDIR="" install
    popd > /dev/null
    
    # Build GCC (stage 1 - bootstrap)
    log_info "Building GCC (stage 1)..."
    local gcc_dir="$build_root/gcc-${GCC_VERSION}"
    local gcc_build_dir="$gcc_dir/build"
    mkdir -p "$gcc_build_dir"
    
    pushd "$gcc_build_dir" > /dev/null
    "$gcc_dir/configure" \
        --target="$TARGET" \
        --prefix="$toolchain_output_abs" \
        --enable-languages=c \
        --disable-libssp \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libsanitizer \
        --disable-libatomic \
        --disable-libquadmath \
        --disable-multilib \
        --with-sysroot="$toolchain_target_abs" \
        --with-newlib \
        --disable-shared \
        --disable-threads \
        --disable-libstdcxx-pch \
        --infodir="$toolchain_output_abs/share/info" \
        --mandir="$toolchain_output_abs/share/man" \
        --datadir="$toolchain_output_abs/share"
    gmake -j$(nproc 2>/dev/null || echo 4) all-gcc
    gmake DESTDIR="" install-gcc
    popd > /dev/null
    
    # Build musl
    log_info "Building musl..."
    local musl_dir="$build_root/musl-${MUSL_VERSION}"
    
    # Check if musl is already built
    if [[ -f "$toolchain_target_abs/lib/libc.so" ]] && [[ -f "$toolchain_target_abs/bin/musl-gcc" ]]; then
        log_success "musl already built - skipping"
        return 0
    fi
    
    pushd "$musl_dir" > /dev/null
    # Set up cross-compilation environment for musl build
    # Use host compiler to build musl, not the cross-compiler
    export PATH="$TOOLCHAIN_OUTPUT/bin:$PATH"
    export CC="gcc"  # Use host gcc, not cross-compiler
    export CROSS_COMPILE=""  # Clear cross-compile for musl build
    export CFLAGS="-O2"
    export LDFLAGS=""
    ./configure \
        --prefix="$toolchain_target_abs" \
        --disable-shared \
        --infodir="$toolchain_output_abs/share/info" \
        --mandir="$toolchain_output_abs/share/man" \
        --datadir="$toolchain_output_abs/share" \
        "$TARGET"
    gmake -j$(nproc 2>/dev/null || echo 4)
    gmake DESTDIR="" install
    popd > /dev/null
    
    log_success "musl toolchain built successfully"
}

# Build glibc toolchain using pre-downloaded packages
build_glibc_toolchain() {
    log_info "Building glibc toolchain using pre-downloaded packages..."
    
    # Check for required packages
    local binutils_tar="$DOWNLOADS_DIR/binutils-${BINUTILS_VERSION}.tar.xz"
    local gcc_tar="$DOWNLOADS_DIR/gcc-${GCC_VERSION}.tar.xz"
    local glibc_tar="$DOWNLOADS_DIR/glibc-${GLIBC_VERSION}.tar.xz"
    local linux_tar="$DOWNLOADS_DIR/linux-${LINUX_VERSION}.tar.xz"
    
    for pkg in "$binutils_tar" "$gcc_tar" "$glibc_tar" "$linux_tar"; do
        if [[ ! -f "$pkg" ]]; then
            log_error "Required package not found: $pkg"
            log_info "Please run 'make download-packages' first"
            exit 1
        fi
    done
    
    # Create build directories
    local build_root="$BUILD_DIR/glibc-toolchain"
    mkdir -p "$build_root"
    
    # Extract packages
    log_info "Extracting toolchain packages..."
    tar -xf "$binutils_tar" -C "$build_root" || { log_error "Failed to extract binutils"; exit 1; }
    tar -xf "$gcc_tar" -C "$build_root" || { log_error "Failed to extract GCC"; exit 1; }
    tar -xf "$glibc_tar" -C "$build_root" || { log_error "Failed to extract glibc"; exit 1; }
    tar -xf "$linux_tar" -C "$build_root" || { log_error "Failed to extract Linux headers"; exit 1; }
    
    # Set up environment
    export PATH="$TOOLCHAIN_OUTPUT/bin:$PATH"
    export PREFIX="$TOOLCHAIN_OUTPUT"
    export DESTDIR=""
    export INSTALL_PREFIX="$TOOLCHAIN_OUTPUT"
    
    # Create target directories to prevent system directory creation
    mkdir -p "$TOOLCHAIN_OUTPUT/share/info"
    mkdir -p "$TOOLCHAIN_OUTPUT/share/man"
    mkdir -p "$TOOLCHAIN_OUTPUT/share"
    
    # Get absolute paths
    local toolchain_output_abs="$(cd "$TOOLCHAIN_OUTPUT" && pwd)"
    local toolchain_target_abs="$toolchain_output_abs/$TARGET"
    local linux_headers_abs="$(cd "$build_root/linux-${LINUX_VERSION}/include" && pwd)"
    
    # Build binutils first
    log_info "Building binutils..."
    local binutils_dir="$build_root/binutils-${BINUTILS_VERSION}"
    local binutils_build_dir="$binutils_dir/build"
    mkdir -p "$binutils_build_dir"
    
    pushd "$binutils_build_dir" > /dev/null
    "$binutils_dir/configure" \
        --target="$TARGET" \
        --prefix="$toolchain_output_abs" \
        --disable-nls \
        --disable-werror \
        --disable-multilib \
        --infodir="$toolchain_output_abs/share/info" \
        --mandir="$toolchain_output_abs/share/man" \
        --datadir="$toolchain_output_abs/share"
    gmake -j$(nproc 2>/dev/null || echo 4)
    gmake DESTDIR="" install
    popd > /dev/null
    
    # Build GCC (stage 1 - bootstrap)
    log_info "Building GCC (stage 1)..."
    local gcc_dir="$build_root/gcc-${GCC_VERSION}"
    local gcc_build_dir="$gcc_dir/build"
    mkdir -p "$gcc_build_dir"
    
    pushd "$gcc_build_dir" > /dev/null
    "$gcc_dir/configure" \
        --target="$TARGET" \
        --prefix="$toolchain_output_abs" \
        --enable-languages=c \
        --disable-libssp \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libsanitizer \
        --disable-libatomic \
        --disable-libquadmath \
        --disable-multilib \
        --with-sysroot="$toolchain_target_abs" \
        --with-newlib \
        --disable-shared \
        --disable-threads \
        --disable-libstdcxx-pch \
        --infodir="$toolchain_output_abs/share/info" \
        --mandir="$toolchain_output_abs/share/man" \
        --datadir="$toolchain_output_abs/share"
    gmake -j$(nproc 2>/dev/null || echo 4) all-gcc
    gmake DESTDIR="" install-gcc
    popd > /dev/null
    
    # Build glibc headers
    log_info "Building glibc headers..."
    local glibc_dir="$build_root/glibc-${GLIBC_VERSION}"
    local glibc_build_dir="$glibc_dir/build"
    mkdir -p "$glibc_build_dir"
    
    # Check if glibc is already built
    if [[ -f "$toolchain_target_abs/lib/libc.so.6" ]] && [[ -f "$toolchain_target_abs/lib/libm.so.6" ]]; then
        log_success "glibc already built - skipping"
        return 0
    fi
    
    pushd "$glibc_build_dir" > /dev/null
    "$glibc_dir/configure" \
        --target="$TARGET" \
        --prefix="$toolchain_target_abs" \
        --with-headers="$linux_headers_abs" \
        --disable-multilib \
        --infodir="$toolchain_output_abs/share/info" \
        --mandir="$toolchain_output_abs/share/man" \
        --datadir="$toolchain_output_abs/share"
    gmake DESTDIR="" install-headers
    popd > /dev/null
    
    log_success "glibc toolchain built successfully"
}

# Main build logic
case "$TOOLCHAIN" in
    "musl")
        build_musl_toolchain
        ;;
    "gnu"|"glibc")
        build_glibc_toolchain
        ;;
    *)
        log_error "Unknown toolchain: $TOOLCHAIN"
        log_info "Supported toolchains: musl, gnu, glibc"
        exit 1
        ;;
esac

# Reset CROSS_COMPILE for verification
CROSS_COMPILE="$TARGET-"

# Verify toolchain
log_info "Verifying toolchain..."
if [[ -f "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"gcc ]]; then
    "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"gcc --version | head -1
    log_success "Toolchain verification complete"
else
    log_error "Toolchain verification failed"
    exit 1
fi

log_success "Toolchain build complete: $TOOLCHAIN_OUTPUT"
