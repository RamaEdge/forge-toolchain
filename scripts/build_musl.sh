#!/bin/bash
# ForgeOS musl Toolchain Build Script
# Builds musl-based cross-compilation toolchain
# Usage: build_musl.sh <arch> <build_dir> <artifacts_dir> [platform]

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
TARGET="$ARCH-linux-musl"
CROSS_COMPILE="$TARGET-"
TOOLCHAIN_OUTPUT="$ARTIFACTS_DIR/$ARCH-musl"
MUSL_CROSS_MAKE_VERSION="0.9.11"

# Platform-specific settings
case "$PLATFORM" in
    "linux")
        MAKE_JOBS="$(nproc 2>/dev/null || echo 4)"
        ;;
    "darwin"|"macos")
        MAKE_JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
        ;;
    *)
        MAKE_JOBS="4"
        log_warning "Unknown platform: $PLATFORM, using 4 parallel jobs"
        ;;
esac

log_info "Building musl toolchain for $ARCH"
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
    log_success "Complete musl toolchain already exists at $TOOLCHAIN_OUTPUT"
    exit 0
fi

# Check for forge-packages integration
PACKAGES_DIR="${PACKAGES_DIR:-$PROJECT_ROOT/packages/downloads}"
MUSL_CROSS_MAKE_SOURCE="$PACKAGES_DIR/musl-cross-make-$MUSL_CROSS_MAKE_VERSION.tar.gz"
MUSL_CROSS_MAKE_DIR="$BUILD_DIR/musl-cross-make-$MUSL_CROSS_MAKE_VERSION"

# Download musl-cross-make if not present
if [[ ! -d "$MUSL_CROSS_MAKE_DIR" ]]; then
    if [[ -f "$MUSL_CROSS_MAKE_SOURCE" ]]; then
        log_info "Using musl-cross-make from forge-packages..."
        cd "$BUILD_DIR"
        if tar -xzf "$MUSL_CROSS_MAKE_SOURCE"; then
            log_success "musl-cross-make extracted from forge-packages"
        else
            log_error "Failed to extract musl-cross-make from forge-packages"
            exit 1
        fi
    else
        log_info "Downloading musl-cross-make $MUSL_CROSS_MAKE_VERSION from internet..."
        cd "$BUILD_DIR"
        if ! curl -L "https://github.com/richfelker/musl-cross-make/archive/v$MUSL_CROSS_MAKE_VERSION.tar.gz" | tar -xz; then
            log_error "Failed to download musl-cross-make"
            log_info "Consider setting up forge-packages for offline builds"
            exit 1
        fi
        log_success "musl-cross-make downloaded from internet"
    fi
fi

# Create musl-cross-make configuration
log_info "Configuring musl-cross-make for $TARGET..."
cd "$MUSL_CROSS_MAKE_DIR"

# Create config.mak
cat > config.mak << EOF
# ForgeOS musl toolchain configuration
TARGET = $TARGET
OUTPUT = $TOOLCHAIN_OUTPUT
COMMON_CONFIG += CC="gcc"
COMMON_CONFIG += CXX="g++"
COMMON_CONFIG += AR="ar"
COMMON_CONFIG += RANLIB="ranlib"
COMMON_CONFIG += NM="nm"
COMMON_CONFIG += STRIP="strip"
COMMON_CONFIG += OBJCOPY="objcopy"
COMMON_CONFIG += OBJDUMP="objdump"
COMMON_CONFIG += READELF="readelf"

# Build configuration
GCC_CONFIG += --enable-languages=c,c++
GCC_CONFIG += --disable-multilib
GCC_CONFIG += --disable-libssp
GCC_CONFIG += --disable-libgomp
GCC_CONFIG += --disable-libmudflap
GCC_CONFIG += --disable-libsanitizer
GCC_CONFIG += --disable-libatomic
GCC_CONFIG += --disable-libquadmath
GCC_CONFIG += --disable-shared
GCC_CONFIG += --disable-threads
GCC_CONFIG += --disable-libstdcxx-pch

# musl configuration
MUSL_CONFIG += --enable-shared
MUSL_CONFIG += --enable-static

# Build flags for reproducible builds
COMMON_CFLAGS += -fno-stack-protector
COMMON_CFLAGS += -fno-unwind-tables
COMMON_CFLAGS += -fno-asynchronous-unwind-tables
COMMON_CFLAGS += -Os

# Linker flags
COMMON_LDFLAGS += -Wl,--build-id=sha1
EOF

log_success "musl-cross-make configured"

# Build the toolchain
log_info "Building musl toolchain (this may take a while)..."
if make -j"$MAKE_JOBS"; then
    log_success "musl toolchain built successfully"
else
    log_error "musl toolchain build failed"
    exit 1
fi

# Verify the toolchain
log_info "Verifying musl toolchain..."
if "$TOOLCHAIN_OUTPUT/bin/$CROSS_COMPILE"gcc --version >/dev/null 2>&1; then
    log_success "musl toolchain verification passed"
else
    log_error "musl toolchain verification failed"
    exit 1
fi

# Create environment script
log_info "Creating environment script..."
cat > "$TOOLCHAIN_OUTPUT/env.sh" << EOF
#!/bin/bash
# ForgeOS musl toolchain environment setup
# Generated by build_musl.sh

# Toolchain configuration
export ARCH="$ARCH"
export TOOLCHAIN_TYPE="musl"
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
export CFLAGS="-static -Os -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables"
export CXXFLAGS="-static -Os -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables"
export LDFLAGS="-static -Wl,--build-id=sha1"

echo "ForgeOS musl toolchain environment loaded"
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
# ForgeOS musl Toolchain Information
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Source date epoch: $SOURCE_DATE_EPOCH

ARCH=$ARCH
TOOLCHAIN_TYPE=musl
TARGET=$TARGET
CROSS_COMPILE=$CROSS_COMPILE
PLATFORM=$PLATFORM
MUSL_CROSS_MAKE_VERSION=$MUSL_CROSS_MAKE_VERSION

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
CFLAGS=-static -Os -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables
CXXFLAGS=-static -Os -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables
LDFLAGS=-static -Wl,--build-id=sha1
EOF

log_success "Toolchain info file created: $TOOLCHAIN_OUTPUT/toolchain.info"

log_success "musl toolchain build complete: $TOOLCHAIN_OUTPUT"
log_info "To use this toolchain, source: $TOOLCHAIN_OUTPUT/env.sh"
