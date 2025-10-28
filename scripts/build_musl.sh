#!/bin/bash
# ForgeOS Toolchain Build Script
# Builds cross-compilation toolchains (musl/glibc)
# Usage: build_toolchain.sh [ARCH] [TOOLCHAIN]

set -euo pipefail

# Script configuration - Detect project root using git
if ! PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    echo "Warning: Not in a git repository. Using fallback project root detection." >&2
    echo "Project root: $PROJECT_ROOT" >&2
fi

# Load configuration
. "$PROJECT_ROOT/scripts/load_config.sh"

# Parameters
ARCH="${1:-aarch64}"
TOOLCHAIN="${2:-musl}"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/artifacts}"

# Colors
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

# Common configuration
PACKAGES_DIR="${PACKAGES_DIR:-$PROJECT_ROOT/packages/downloads}"

# Package versions (from build.json or defaults)
BINUTILS_VERSION="${BINUTILS_VERSION:-2.45}"
GCC_VERSION="${GCC_VERSION:-15.2.0}"
MUSL_VERSION="${MUSL_VERSION:-1.2.5}"
GLIBC_VERSION="${GLIBC_VERSION:-2.42}"
LINUX_HEADERS_VERSION="${LINUX_HEADERS_VERSION:-6.12.49}"

# Build logic based on toolchain type
case "$TOOLCHAIN" in
    "musl")
        TARGET="$ARCH-linux-musl"
        TOOLCHAIN_OUTPUT="$OUTPUT_DIR/$ARCH-musl"
        BUILD_ROOT="$BUILD_DIR/musl-toolchain"
        LIBC_TYPE="musl"
        LIBC_VERSION="$MUSL_VERSION"
        LIBC_FILENAME="musl-$MUSL_VERSION.tar.gz"
        ;;
    "gnu"|"glibc")
        TARGET="$ARCH-linux-gnu"
        TOOLCHAIN_OUTPUT="$OUTPUT_DIR/$ARCH-gnu"
        BUILD_ROOT="$BUILD_DIR/glibc-toolchain"
        LIBC_TYPE="glibc"
        LIBC_VERSION="$GLIBC_VERSION"
        LIBC_FILENAME="glibc-$GLIBC_VERSION.tar.xz"
        ;;
    *)
        log_error "Unknown toolchain: $TOOLCHAIN"
        log_info "Supported toolchains: musl, gnu, glibc"
        exit 1
        ;;
esac

log_info "Building $LIBC_TYPE toolchain for $ARCH"
log_info "Target: $TARGET"
log_info "Packages directory: $PACKAGES_DIR"
log_info "Build directory: $BUILD_ROOT"
log_info "Output directory: $TOOLCHAIN_OUTPUT"

# Check for required packages
log_info "Checking for required packages..."
for pkg in "binutils-$BINUTILS_VERSION.tar.xz" "gcc-$GCC_VERSION.tar.xz" "$LIBC_FILENAME" "linux-$LINUX_HEADERS_VERSION.tar.xz"; do
    pkg_file="$PACKAGES_DIR/$pkg"
    if [[ ! -f "$pkg_file" ]]; then
        log_error "Required package not found: $pkg_file"
        log_info "Download packages first: make download-packages"
        exit 1
    fi
    log_success "Found: $pkg"
done

# Create build directories
mkdir -p "$BUILD_ROOT" "$TOOLCHAIN_OUTPUT"

# Extract packages
log_info "Extracting packages..."
tar -xf "$PACKAGES_DIR/binutils-$BINUTILS_VERSION.tar.xz" -C "$BUILD_ROOT" || { log_error "Failed to extract binutils"; exit 1; }
tar -xf "$PACKAGES_DIR/gcc-$GCC_VERSION.tar.xz" -C "$BUILD_ROOT" || { log_error "Failed to extract gcc"; exit 1; }
tar -xf "$PACKAGES_DIR/$LIBC_FILENAME" -C "$BUILD_ROOT" || { log_error "Failed to extract $LIBC_TYPE"; exit 1; }
tar -xf "$PACKAGES_DIR/linux-$LINUX_HEADERS_VERSION.tar.xz" -C "$BUILD_ROOT" || { log_error "Failed to extract linux headers"; exit 1; }
log_success "Packages extracted"

# Create target directories
mkdir -p "$TOOLCHAIN_OUTPUT/share/info" "$TOOLCHAIN_OUTPUT/share/man"
mkdir -p "$TOOLCHAIN_OUTPUT/$TARGET"

# Get absolute paths
TOOLCHAIN_OUTPUT_ABS="$(cd "$TOOLCHAIN_OUTPUT" && pwd)"
TOOLCHAIN_TARGET_ABS="$TOOLCHAIN_OUTPUT_ABS/$TARGET"
LINUX_HEADERS_ABS="$(cd "$BUILD_ROOT/linux-$LINUX_HEADERS_VERSION/include" && pwd)"

# Build binutils
log_info "Building binutils..."
BINUTILS_DIR="$BUILD_ROOT/binutils-$BINUTILS_VERSION"
BINUTILS_BUILD_DIR="$BINUTILS_DIR/build"
mkdir -p "$BINUTILS_BUILD_DIR"

pushd "$BINUTILS_BUILD_DIR" > /dev/null
"$BINUTILS_DIR/configure" \
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

# Build GCC (stage 1 - bootstrap)
log_info "Building GCC (stage 1 - bootstrap)..."
GCC_DIR="$BUILD_ROOT/gcc-$GCC_VERSION"
GCC_BUILD_DIR="$GCC_DIR/build"
mkdir -p "$GCC_BUILD_DIR"

pushd "$GCC_BUILD_DIR" > /dev/null
"$GCC_DIR/configure" \
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

# Build libc (musl or glibc)
case "$TOOLCHAIN" in
    "musl")
        log_info "Building musl..."
        MUSL_DIR="$BUILD_ROOT/musl-$MUSL_VERSION"
        
        if [[ ! -f "$TOOLCHAIN_TARGET_ABS/lib/libc.so" ]]; then
            pushd "$MUSL_DIR" > /dev/null
            export PATH="$TOOLCHAIN_OUTPUT_ABS/bin:$PATH"
            export CC="gcc"
            export CROSS_COMPILE=""
            export CFLAGS="-O2"
            export LDFLAGS=""
            
            ./configure \
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
        GLIBC_DIR="$BUILD_ROOT/glibc-$GLIBC_VERSION"
        GLIBC_BUILD_DIR="$GLIBC_DIR/build"
        mkdir -p "$GLIBC_BUILD_DIR"
        
        if [[ ! -f "$TOOLCHAIN_TARGET_ABS/lib/libc.so.6" ]]; then
            pushd "$GLIBC_BUILD_DIR" > /dev/null
            "$GLIBC_DIR/configure" \
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

# Verify toolchain
log_info "Verifying toolchain..."
if [[ -f "$TOOLCHAIN_OUTPUT_ABS/bin/$TARGET-gcc" ]]; then
    "$TOOLCHAIN_OUTPUT_ABS/bin/$TARGET-gcc" --version | head -1
    log_success "Toolchain verification complete"
else
    log_error "Toolchain verification failed"
    exit 1
fi

log_success "$LIBC_TYPE toolchain build complete: $TOOLCHAIN_OUTPUT_ABS"
