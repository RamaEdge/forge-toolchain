#!/bin/bash
# ForgeOS Toolchain Configuration Loader
# Loads build.json configuration
# Usage: source scripts/load_config.sh

# Script configuration - Detect project root using git
if ! PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    echo "Warning: Not in a git repository. Using fallback project root detection." >&2
    echo "Project root: $PROJECT_ROOT" >&2
fi

# Load build.json configuration
BUILD_JSON="$PROJECT_ROOT/build.json"

if [[ ! -f "$BUILD_JSON" ]]; then
    echo "Error: build.json not found at $BUILD_JSON" >&2
    return 1
fi

# Parse build.json using jq
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed" >&2
    echo "Install with: sudo apt-get install jq (Ubuntu/Debian)" >&2
    echo "Install with: brew install jq (macOS)" >&2
    return 1
fi

# Load configuration variables
export FORGEOS_VERSION=$(jq -r '.metadata.version // "0.1.0"' "$BUILD_JSON")
export FORGEOS_DESCRIPTION=$(jq -r '.metadata.description // "ForgeOS Toolchain Build Configuration"' "$BUILD_JSON")

# Build directories
export BUILD_DIR=$(jq -r '.build.directories.build' "$BUILD_JSON")
export ARTIFACTS_DIR=$(jq -r '.build.directories.output' "$BUILD_JSON")
export PACKAGES_DIR=$(jq -r '.build.directories.packages' "$BUILD_JSON")

# Make paths absolute
BUILD_DIR="$PROJECT_ROOT/$BUILD_DIR"
ARTIFACTS_DIR="$PROJECT_ROOT/$ARTIFACTS_DIR"
PACKAGES_DIR="$PROJECT_ROOT/$PACKAGES_DIR"

# Architecture configuration
export DEFAULT_ARCH=$(jq -r '.build.architecture.default' "$BUILD_JSON")
export SUPPORTED_ARCHS=$(jq -r '.build.architecture.supported[]' "$BUILD_JSON" | tr '\n' ' ')

# Repository configuration
export REPO_NAME=$(jq -r '.build.repository.name' "$BUILD_JSON")
export REPO_VERSION=$(jq -r '.build.repository.version' "$BUILD_JSON")
export FORGE_PACKAGES_URL=$(jq -r '.build.repository.forge_packages_url' "$BUILD_JSON")
export FORGE_PACKAGES_VERSION=$(jq -r '.build.repository.forge_packages_version' "$BUILD_JSON")

# Security configuration
export CHECKSUM_VERIFICATION=$(jq -r '.build.security.checksum_verification' "$BUILD_JSON")

# Toolchain configuration
export TOOLCHAIN_TYPES="musl gnu"
export DEFAULT_TOOLCHAIN="musl"

# Platform configuration
export CURRENT_PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$CURRENT_PLATFORM" in
    "linux")
        export MAKE_JOBS=$(nproc 2>/dev/null || echo 4)
        export MAKE_CMD="make"
        ;;
    "darwin"|"macos")
        export MAKE_JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
        export MAKE_CMD="gmake"
        ;;
    *)
        export MAKE_JOBS=4
        export MAKE_CMD="make"
        ;;
esac

# Set SOURCE_DATE_EPOCH for reproducible builds
export SOURCE_DATE_EPOCH=$(date +%s)

# Set default values if not provided
export ARCH="${ARCH:-$DEFAULT_ARCH}"
export TOOLCHAIN="${TOOLCHAIN:-$DEFAULT_TOOLCHAIN}"

# Set toolchain-specific variables
case "$TOOLCHAIN" in
    "musl")
        export TARGET="$ARCH-linux-musl"
        export CROSS_COMPILE="$TARGET-"
        export OUTPUT_DIR="$ARTIFACTS_DIR/$ARCH-musl"
        ;;
    "gnu"|"glibc")
        export TARGET="$ARCH-linux-gnu"
        export CROSS_COMPILE="$TARGET-"
        export OUTPUT_DIR="$ARTIFACTS_DIR/$ARCH-gnu"
        ;;
    *)
        echo "Error: Unknown toolchain: $TOOLCHAIN" >&2
        echo "Supported toolchains: $TOOLCHAIN_TYPES" >&2
        return 1
        ;;
esac

# Print configuration if sourced interactively
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ForgeOS Toolchain Configuration:"
    echo "  Version: $FORGEOS_VERSION"
    echo "  Description: $FORGEOS_DESCRIPTION"
    echo "  Architecture: $ARCH"
    echo "  Toolchain: $TOOLCHAIN"
    echo "  Target: $TARGET"
    echo "  Cross-compile: $CROSS_COMPILE"
    echo ""
    echo "Directories:"
    echo "  Build: $BUILD_DIR"
    echo "  Artifacts: $ARTIFACTS_DIR"
    echo "  Packages: $PACKAGES_DIR"
    echo "  Output: $OUTPUT_DIR"
    echo ""
    echo "Platform:"
    echo "  Platform: $CURRENT_PLATFORM"
    echo "  Make jobs: $MAKE_JOBS"
    echo "  Make command: $MAKE_CMD"
    echo "  Source date epoch: $SOURCE_DATE_EPOCH"
    echo ""
    echo "Configuration loaded successfully!"
fi
