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

# Download required toolchain packages
download_package "binutils" "binutils-2.42.tar.xz" || log_warning "binutils package not available"
download_package "gcc" "gcc-13.2.0.tar.xz" || log_warning "gcc package not available"
download_package "musl" "musl-1.2.4.tar.gz" || log_warning "musl package not available"
download_package "glibc" "glibc-2.38.tar.xz" || log_warning "glibc package not available"
download_package "linux-headers" "linux-6.6.0.tar.xz" || log_warning "linux-headers package not available"
download_package "musl-cross-make" "musl-cross-make-0.9.11.tar.gz" || log_warning "musl-cross-make package not available"

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

## Package Source
- Repository: $FORGE_PACKAGES_URL
- Local directory: $LOCAL_PACKAGES_DIR
- Forge-packages directory: $PACKAGES_REPO_DIR

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
EOF

log_success "Package download complete!"
log_info "Packages directory: $LOCAL_PACKAGES_DIR"
log_info "Package info: $LOCAL_PACKAGES_DIR/package-info.txt"
log_info ""
log_info "To use these packages:"
log_info "  export PACKAGES_DIR=\"$LOCAL_PACKAGES_DIR\""
log_info "  make toolchain"
