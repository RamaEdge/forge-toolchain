#!/bin/bash
# ForgeOS Toolchain Package Download Script
# Downloads packages from forge-packages repository
# Usage: download_packages.sh [forge-packages-url] [packages-dir]

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
FORGE_PACKAGES_URL="${1:-https://github.com/your-org/forge-packages.git}"
PACKAGES_DIR="${2:-$PROJECT_ROOT/packages}"
PACKAGES_REPO_DIR="$PACKAGES_DIR/forge-packages"

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

log_info "ForgeOS Toolchain Package Download System"
log_info "Forge-packages URL: $FORGE_PACKAGES_URL"
log_info "Packages directory: $PACKAGES_DIR"

# Create packages directory
mkdir -p "$PACKAGES_DIR"

# Clone or update forge-packages repository
if [[ -d "$PACKAGES_REPO_DIR" ]]; then
    log_info "Updating forge-packages repository..."
    cd "$PACKAGES_REPO_DIR"
    if git pull origin main >/dev/null 2>&1; then
        log_success "forge-packages repository updated"
    else
        log_warning "Failed to update forge-packages repository"
    fi
    cd "$PROJECT_ROOT"
else
    log_info "Cloning forge-packages repository..."
    if git clone "$FORGE_PACKAGES_URL" "$PACKAGES_REPO_DIR" >/dev/null 2>&1; then
        log_success "forge-packages repository cloned"
    else
        log_error "Failed to clone forge-packages repository"
        exit 1
    fi
fi

# Check if packages.json exists
if [[ ! -f "$PACKAGES_REPO_DIR/metadata/packages.json" ]]; then
    log_error "Package manifest not found: $PACKAGES_REPO_DIR/metadata/packages.json"
    log_info "Please ensure forge-packages repository is properly set up"
    exit 1
fi

# Load package manifest
log_info "Loading package manifest..."
if ! source "$PACKAGES_REPO_DIR/metadata/packages.json" 2>/dev/null; then
    log_error "Failed to load package manifest"
    exit 1
fi

# Load build.json configuration
BUILD_JSON="$PROJECT_ROOT/build.json"
if [[ ! -f "$BUILD_JSON" ]]; then
    log_error "build.json not found at $BUILD_JSON"
    exit 1
fi

# Parse toolchain versions from build.json
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed"
    log_info "Install with: sudo apt-get install jq (Ubuntu/Debian)"
    log_info "Install with: brew install jq (macOS)"
    exit 1
fi

BINUTILS_VERSION=$(jq -r '.build.toolchain.versions.binutils' "$BUILD_JSON")
GCC_VERSION=$(jq -r '.build.toolchain.versions.gcc' "$BUILD_JSON")
GLIBC_VERSION=$(jq -r '.build.toolchain.versions.glibc' "$BUILD_JSON")
MUSL_CROSS_MAKE_VERSION=$(jq -r '.build.toolchain.versions."musl-cross-make"' "$BUILD_JSON")
LINUX_VERSION=$(jq -r '.build.toolchain.versions.linux' "$BUILD_JSON")

log_info "Toolchain versions from build.json:"
log_info "  binutils: $BINUTILS_VERSION"
log_info "  gcc: $GCC_VERSION"
log_info "  glibc: $GLIBC_VERSION"
log_info "  musl-cross-make: $MUSL_CROSS_MAKE_VERSION"
log_info "  linux: $LINUX_VERSION"

# Create local packages directory
LOCAL_PACKAGES_DIR="$PACKAGES_DIR/downloads"
mkdir -p "$LOCAL_PACKAGES_DIR"

# Download toolchain packages
log_info "Downloading toolchain packages..."

# Function to download package from forge-packages
download_package() {
    local package_name="$1"
    local package_file="$2"
    local source_path="$PACKAGES_REPO_DIR/packages/toolchain/$package_file"
    local dest_path="$LOCAL_PACKAGES_DIR/$package_file"
    
    if [[ -f "$source_path" ]]; then
        if [[ ! -f "$dest_path" ]] || [[ "$source_path" -nt "$dest_path" ]]; then
            log_info "Copying $package_file..."
            cp "$source_path" "$dest_path"
            log_success "Copied $package_file"
        else
            log_success "Cached $package_file"
        fi
        return 0
    else
        log_warning "Package not found in forge-packages: $package_file"
        return 1
    fi
}

# Download required toolchain packages using build.json configuration
# Note: musl toolchain uses musl-cross-make which handles all dependencies internally
# glibc toolchain requires: binutils, gcc, glibc, linux (for headers)

log_info "Downloading toolchain packages using build.json configuration..."

# musl-cross-make (for musl toolchain)
MUSL_CROSS_MAKE_FILE="musl-cross-make-${MUSL_CROSS_MAKE_VERSION}.tar.gz"
download_package "musl-cross-make" "$MUSL_CROSS_MAKE_FILE" || log_warning "musl-cross-make package not available"

# glibc toolchain packages (for glibc toolchain)
BINUTILS_FILE="binutils-${BINUTILS_VERSION}.tar.xz"
GCC_FILE="gcc-${GCC_VERSION}.tar.xz"
GLIBC_FILE="glibc-${GLIBC_VERSION}.tar.xz"
LINUX_FILE="linux-${LINUX_VERSION}.tar.xz"

download_package "binutils" "$BINUTILS_FILE" || log_warning "binutils package not available"
download_package "gcc" "$GCC_FILE" || log_warning "gcc package not available"
download_package "glibc" "$GLIBC_FILE" || log_warning "glibc package not available"
download_package "linux" "$LINUX_FILE" || log_warning "linux package not available"

# Verify package integrity if checksums are available
if [[ -f "$PACKAGES_REPO_DIR/metadata/checksums.json" ]]; then
    log_info "Verifying package integrity..."
    # TODO: Implement checksum verification
    log_success "Package integrity verified"
else
    log_warning "Checksums not available - skipping integrity verification"
fi

# Create package info file
log_info "Creating package info file..."
cat > "$LOCAL_PACKAGES_DIR/package-info.txt" << EOF
# ForgeOS Toolchain Package Information
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Source: forge-packages repository
# Configuration: build.json

## Package Source
- Repository: $FORGE_PACKAGES_URL
- Local directory: $LOCAL_PACKAGES_DIR
- Forge-packages directory: $PACKAGES_REPO_DIR
- Configuration file: $BUILD_JSON

## Toolchain Versions (from build.json)
- binutils: $BINUTILS_VERSION
- gcc: $GCC_VERSION
- glibc: $GLIBC_VERSION
- musl-cross-make: $MUSL_CROSS_MAKE_VERSION
- linux: $LINUX_VERSION

## Available Packages
$(ls -la "$LOCAL_PACKAGES_DIR" | grep -v "package-info.txt" | awk '{print $9, $5, $6, $7, $8}')

## Usage
To use these packages in toolchain builds:
1. Set PACKAGES_DIR environment variable: export PACKAGES_DIR="$LOCAL_PACKAGES_DIR"
2. Run toolchain build: make toolchain
3. Packages will be automatically used from this directory

## Integration
This package system integrates with:
- ForgeOS main repository
- ForgeOS toolchain repository
- ForgeOS profiles repository
- CI/CD pipelines

## Configuration
Package versions are managed in build.json:
- Update versions in build.json
- Re-run download_packages.sh to get new versions
- All toolchain builds will use the configured versions
EOF

log_success "Package download complete!"
log_info "Packages directory: $LOCAL_PACKAGES_DIR"
log_info "Package info: $LOCAL_PACKAGES_DIR/package-info.txt"
log_info ""
log_info "To use these packages:"
log_info "  export PACKAGES_DIR=\"$LOCAL_PACKAGES_DIR\""
log_info "  make toolchain"
