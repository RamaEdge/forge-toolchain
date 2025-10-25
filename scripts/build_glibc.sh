#!/bin/bash
# ForgeOS glibc Toolchain Build Script
# Builds glibc-based cross-compilation toolchain
# Usage: build_glibc.sh <arch> <build_dir> <artifacts_dir> [platform]

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
BUILD_DIR="${2:-build}"
ARTIFACTS_DIR="${3:-artifacts}"
PLATFORM="${4:-$(uname -s | tr '[:upper:]' '[:lower:]')}"

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
TARGET="$ARCH-linux-gnu"
CROSS_COMPILE="$TARGET-"
TOOLCHAIN_OUTPUT="$ARTIFACTS_DIR/$ARCH-gnu"

# Version information (from build.json or defaults)
BINUTILS_VERSION="${BINUTILS_VERSION:-2.42}"
GCC_VERSION="${GCC_VERSION:-13.2.0}"
GLIBC_VERSION="${GLIBC_VERSION:-2.38}"
LINUX_HEADERS_VERSION="${LINUX_VERSION:-6.6.0}"

# Platform-specific settings
case "$PLATFORM" in
    "linux")
        MAKE_JOBS="$(nproc 2>/dev/null || echo 4)"
        MAKE_CMD="make"
        ;;
    "darwin"|"macos")
        MAKE_JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
        MAKE_CMD="gmake"
        ;;
    *)
        MAKE_JOBS="4"
        MAKE_CMD="make"
        log_warning "Unknown platform: $PLATFORM, using 4 parallel jobs"
        ;;
esac

log_info "Building glibc toolchain for $ARCH"
log_info "Target: $TARGET"
log_info "Platform: $PLATFORM"
log_info "Build directory: $BUILD_DIR"
log_info "Output directory: $TOOLCHAIN_OUTPUT"
log_info "Parallel jobs: $MAKE_JOBS"

# Create build directories
mkdir -p "$BUILD_DIR"
mkdir -p "$TOOLCHAIN_OUTPUT"

# Check if toolchain already exists and is complete
if [[ -f "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"gcc ]] && \
   [[ -f "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"g++ ]] && \
   [[ -f "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"ar ]] && \
   [[ -f "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"ld ]]; then
    log_success "Complete glibc toolchain already exists at $TOOLCHAIN_OUTPUT"
    exit 0
fi

# Download sources if not present
download_source() {
    local name="$1"
    local version="$2"
    local url="$3"
    local dir="$BUILD_DIR/$name-$version"
    
    if [[ ! -d "$dir" ]]; then
        log_info "Downloading $name $version..."
        cd "$BUILD_DIR"
        if ! curl -L "$url" | tar -xz; then
            log_error "Failed to download $name"
            exit 1
        fi
        log_success "$name downloaded"
    fi
}

# Download all sources
download_source "binutils" "$BINUTILS_VERSION" "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.xz"
download_source "gcc" "$GCC_VERSION" "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz"
download_source "glibc" "$GLIBC_VERSION" "https://ftp.gnu.org/gnu/glibc/glibc-$GLIBC_VERSION.tar.xz"
download_source "linux" "$LINUX_HEADERS_VERSION" "https://www.kernel.org/pub/linux/kernel/v6.x/linux-$LINUX_HEADERS_VERSION.tar.xz"

# Set up paths
BINUTILS_DIR="$BUILD_DIR/binutils-$BINUTILS_VERSION"
GCC_DIR="$BUILD_DIR/gcc-$GCC_VERSION"
GLIBC_DIR="$BUILD_DIR/glibc-$GLIBC_VERSION"
LINUX_HEADERS_DIR="$BUILD_DIR/linux-$LINUX_HEADERS_VERSION"

# Build binutils
log_info "Building binutils..."
BINUTILS_BUILD_DIR="$BINUTILS_DIR/build"
mkdir -p "$BINUTILS_BUILD_DIR"
cd "$BINUTILS_BUILD_DIR"

"$BINUTILS_DIR/configure" \
    --target="$TARGET" \
    --prefix="$TOOLCHAIN_OUTPUT" \
    --disable-multilib \
    --disable-werror \
    --enable-shared \
    --enable-static

$MAKE_CMD -j"$MAKE_JOBS"
$MAKE_CMD install
cd "$PROJECT_ROOT"
log_success "binutils built"

# Install Linux headers
log_info "Installing Linux headers..."
LINUX_HEADERS_BUILD_DIR="$LINUX_HEADERS_DIR/build"
mkdir -p "$LINUX_HEADERS_BUILD_DIR"
cd "$LINUX_HEADERS_BUILD_DIR"

"$LINUX_HEADERS_DIR/configure" \
    --target="$TARGET" \
    --prefix="$TOOLCHAIN_OUTPUT" \
    --with-headers="$LINUX_HEADERS_DIR/usr/include"

$MAKE_CMD install-headers
cd "$PROJECT_ROOT"
log_success "Linux headers installed"

# Build glibc
log_info "Building glibc..."
GLIBC_BUILD_DIR="$GLIBC_DIR/build"
mkdir -p "$GLIBC_BUILD_DIR"
cd "$GLIBC_BUILD_DIR"

"$GLIBC_DIR/configure" \
    --target="$TARGET" \
    --prefix="$TOOLCHAIN_OUTPUT" \
    --with-headers="$TOOLCHAIN_OUTPUT/include" \
    --disable-multilib \
    --enable-shared \
    --enable-static \
    --disable-werror

$MAKE_CMD -j"$MAKE_JOBS"
$MAKE_CMD install
cd "$PROJECT_ROOT"
log_success "glibc built"

# Build GCC (stage 1 - bootstrap)
log_info "Building GCC (stage 1)..."
GCC_BUILD_DIR="$GCC_DIR/build"
mkdir -p "$GCC_BUILD_DIR"
cd "$GCC_BUILD_DIR"

"$GCC_DIR/configure" \
    --target="$TARGET" \
    --prefix="$TOOLCHAIN_OUTPUT" \
    --enable-languages=c,c++ \
    --disable-libssp \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libsanitizer \
    --disable-libatomic \
    --disable-libquadmath \
    --disable-multilib \
    --with-sysroot="$TOOLCHAIN_OUTPUT" \
    --with-newlib \
    --disable-shared \
    --disable-threads \
    --disable-libstdcxx-pch

$MAKE_CMD -j"$MAKE_JOBS" all-gcc
$MAKE_CMD install-gcc
cd "$PROJECT_ROOT"
log_success "GCC stage 1 built"

# Build glibc (full build)
log_info "Building glibc (full build)..."
cd "$GLIBC_BUILD_DIR"
$MAKE_CMD -j"$MAKE_JOBS"
$MAKE_CMD install
cd "$PROJECT_ROOT"
log_success "glibc full build complete"

# Build GCC (stage 2 - full)
log_info "Building GCC (stage 2)..."
cd "$GCC_BUILD_DIR"
$MAKE_CMD -j"$MAKE_JOBS" all
$MAKE_CMD install
cd "$PROJECT_ROOT"
log_success "GCC stage 2 built"

# Verify the toolchain
log_info "Verifying glibc toolchain..."
if "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"gcc --version >/dev/null 2>&1; then
    log_success "glibc toolchain verification passed"
else
    log_error "glibc toolchain verification failed"
    exit 1
fi

# Create environment script
log_info "Creating environment script..."
cat > "$TOOLCHAIN_OUTPUT/env.sh" << EOF
#!/bin/bash
# ForgeOS glibc toolchain environment setup
# Generated by build_glibc.sh

# Toolchain configuration
export ARCH="$ARCH"
export TOOLCHAIN_TYPE="gnu"
export TARGET="$TARGET"
export CROSS_COMPILE="$CROSS_COMPILE"
export SYSROOT="$TOOLCHAIN_OUTPUT"

# Toolchain paths
export TOOLCHAIN_BIN="$TOOLCHAIN_OUTPUT/bin"
export TOOLCHAIN_LIB="$TOOLCHAIN_OUTPUT/lib"
export TOOLCHAIN_INCLUDE="$TOOLCHAIN_OUTPUT/include"

# Update PATH
export PATH="\$TOOLCHAIN_BIN:\$PATH"

# Compiler variables
export CC="\$CROSS_COMPILE"gcc
export CXX="\$CROSS_COMPILE"g++
export AR="\$CROSS_COMPILE"ar
export STRIP="\$CROSS_COMPILE"strip
export RANLIB="\$CROSS_COMPILE"ranlib
export NM="\$CROSS_COMPILE"nm
export OBJCOPY="\$CROSS_COMPILE"objcopy
export OBJDUMP="\$CROSS_COMPILE"objdump
export READELF="\$CROSS_COMPILE"readelf

# Build flags for reproducible builds
export CFLAGS="-Os -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables"
export CXXFLAGS="-Os -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables"
export LDFLAGS="-Wl,--build-id=sha1"

echo "ForgeOS glibc toolchain environment loaded"
echo "  Architecture: \$ARCH"
echo "  Target: \$TARGET"
echo "  Cross-compile: \$CROSS_COMPILE"
echo "  Sysroot: \$SYSROOT"
EOF

chmod +x "$TOOLCHAIN_OUTPUT/env.sh"
log_success "Environment script created: $TOOLCHAIN_OUTPUT/env.sh"

# Create toolchain info file
log_info "Creating toolchain info file..."
cat > "$TOOLCHAIN_OUTPUT/toolchain.info" << EOF
# ForgeOS glibc Toolchain Information
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Source date epoch: $SOURCE_DATE_EPOCH

ARCH=$ARCH
TOOLCHAIN_TYPE=gnu
TARGET=$TARGET
CROSS_COMPILE=$CROSS_COMPILE
PLATFORM=$PLATFORM

# Version information
BINUTILS_VERSION=$BINUTILS_VERSION
GCC_VERSION=$GCC_VERSION
GLIBC_VERSION=$GLIBC_VERSION
LINUX_HEADERS_VERSION=$LINUX_HEADERS_VERSION

# Toolchain binaries
GCC=$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"gcc"
GXX=$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"g++"
AR=$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"ar"
STRIP=$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"strip"
RANLIB=$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"ranlib"
NM=$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"nm"
OBJCOPY=$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"objcopy"
OBJDUMP=$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"objdump"
READELF=$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"readelf"

# Build flags
CFLAGS=-Os -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables
CXXFLAGS=-Os -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables
LDFLAGS=-Wl,--build-id=sha1
EOF

log_success "Toolchain info file created: $TOOLCHAIN_OUTPUT/toolchain.info"

log_success "glibc toolchain build complete: $TOOLCHAIN_OUTPUT"
log_info "To use this toolchain, source: $TOOLCHAIN_OUTPUT/env.sh"
