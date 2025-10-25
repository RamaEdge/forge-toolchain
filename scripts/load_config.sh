#!/bin/bash
# ForgeOS Toolchain Configuration Loader
# Loads build.json configuration for toolchain builds
# Usage: source scripts/load_config.sh

# Script configuration - Detect project root using git
# This ensures we find the correct root regardless of script location or invocation directory
if ! PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    # Fallback to script-based detection if not in a git repository
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
export FORGEOS_VERSION=$(jq -r '.metadata.version' "$BUILD_JSON")
export FORGEOS_DESCRIPTION=$(jq -r '.metadata.description' "$BUILD_JSON")
export FORGEOS_LAST_UPDATED=$(jq -r '.metadata.last_updated' "$BUILD_JSON")

# Build directories
export BUILD_DIR=$(jq -r '.build.directories.build' "$BUILD_JSON")
export ARTIFACTS_DIR=$(jq -r '.build.directories.output' "$BUILD_JSON")
export PACKAGES_DIR=$(jq -r '.build.directories.packages' "$BUILD_JSON")

# Architecture configuration
export DEFAULT_ARCH=$(jq -r '.build.architecture.default' "$BUILD_JSON")
export SUPPORTED_ARCHS=$(jq -r '.build.architecture.supported[]' "$BUILD_JSON" | tr '\n' ' ')

# Toolchain configuration
export TOOLCHAIN_TYPES=$(jq -r '.build.toolchain.types[]' "$BUILD_JSON" | tr '\n' ' ')
export DEFAULT_TOOLCHAIN=$(jq -r '.build.toolchain.default' "$BUILD_JSON")

# Toolchain versions
export BINUTILS_VERSION=$(jq -r '.build.toolchain.versions.binutils' "$BUILD_JSON")
export GCC_VERSION=$(jq -r '.build.toolchain.versions.gcc' "$BUILD_JSON")
export MUSL_VERSION=$(jq -r '.build.toolchain.versions.musl' "$BUILD_JSON")
export GLIBC_VERSION=$(jq -r '.build.toolchain.versions.glibc' "$BUILD_JSON")
export MUSL_CROSS_MAKE_VERSION=$(jq -r '.build.toolchain.versions."musl-cross-make"' "$BUILD_JSON")

# Repository configuration
export REPO_NAME=$(jq -r '.build.repository.name' "$BUILD_JSON")
export REPO_VERSION=$(jq -r '.build.repository.version' "$BUILD_JSON")
export REPO_ARCH=$(jq -r '.build.repository.arch' "$BUILD_JSON")
export FORGE_PACKAGES_URL=$(jq -r '.build.repository.forge_packages_url' "$BUILD_JSON")

# Security configuration
export SIGNING_KEY_TYPE=$(jq -r '.build.security.signing_key_type' "$BUILD_JSON")
export SIGNING_KEY_DIR=$(jq -r '.build.security.signing_key_dir' "$BUILD_JSON")
export CHECKSUM_VERIFICATION=$(jq -r '.build.security.checksum_verification' "$BUILD_JSON")
export GPG_SIGNATURES=$(jq -r '.build.security.gpg_signatures' "$BUILD_JSON")

# Build flags
export REPRODUCIBLE_BUILD=$(jq -r '.build.build_flags.reproducible' "$BUILD_JSON")
export SOURCE_DATE_EPOCH=$(jq -r '.build.build_flags.source_date_epoch' "$BUILD_JSON")
export STATIC_LINKING=$(jq -r '.build.build_flags.static_linking' "$BUILD_JSON")
export OPTIMIZATION=$(jq -r '.build.build_flags.optimization' "$BUILD_JSON")
export SECURITY_FLAGS=$(jq -r '.build.build_flags.security_flags[]' "$BUILD_JSON" | tr '\n' ' ')

# Platform configuration
export CURRENT_PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
export MAKE_JOBS=$(jq -r ".build.platforms.${CURRENT_PLATFORM}.make_jobs" "$BUILD_JSON")
export MAKE_CMD=$(jq -r ".build.platforms.${CURRENT_PLATFORM}.make_cmd" "$BUILD_JSON")

# CI/CD configuration
export CI_CD_ENABLED=$(jq -r '.build.ci_cd.enabled' "$BUILD_JSON")
export CI_PLATFORMS=$(jq -r '.build.ci_cd.platforms[]' "$BUILD_JSON" | tr '\n' ' ')

# Set SOURCE_DATE_EPOCH for reproducible builds
if [[ "$SOURCE_DATE_EPOCH" == "true" ]]; then
    export SOURCE_DATE_EPOCH=$(date +%s)
fi

# Set MAKE_JOBS based on platform
case "$CURRENT_PLATFORM" in
    "linux")
        if [[ "$MAKE_JOBS" == "nproc" ]]; then
            export MAKE_JOBS=$(nproc 2>/dev/null || echo 4)
        fi
        ;;
    "darwin"|"macos")
        if [[ "$MAKE_JOBS" == "sysctl hw.ncpu" ]]; then
            export MAKE_JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
        fi
        ;;
    *)
        export MAKE_JOBS=4
        ;;
esac

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
    echo "  Build directory: $BUILD_DIR"
    echo "  Artifacts directory: $ARTIFACTS_DIR"
    echo "  Output directory: $OUTPUT_DIR"
    echo "  Platform: $CURRENT_PLATFORM"
    echo "  Make jobs: $MAKE_JOBS"
    echo "  Make command: $MAKE_CMD"
    echo "  Reproducible build: $REPRODUCIBLE_BUILD"
    echo "  Source date epoch: $SOURCE_DATE_EPOCH"
    echo ""
    echo "Configuration loaded successfully!"
fi
