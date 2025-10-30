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

# Build directories
export BUILD_DIR=$(jq -r '.build.directories.build' "$BUILD_JSON")
export ARTIFACTS_DIR=$(jq -r '.build.directories.output' "$BUILD_JSON")
export PACKAGES_DIR=$(jq -r '.build.directories.packages' "$BUILD_JSON")

# Make paths absolute
BUILD_DIR="$PROJECT_ROOT/$BUILD_DIR"
ARTIFACTS_DIR="$PROJECT_ROOT/$ARTIFACTS_DIR"
PACKAGES_DIR="$PROJECT_ROOT/$PACKAGES_DIR"

# Toolchain configuration
export TOOLCHAIN_TYPES="musl gnu"
export DEFAULT_TOOLCHAIN="musl"

# Set default architecture (aarch64 is default, can be overridden)
export ARCH="${ARCH:-aarch64}"

# Target triple configuration (set by get_toolchain_config)
export TARGET=""
export CROSS_COMPILE=""
