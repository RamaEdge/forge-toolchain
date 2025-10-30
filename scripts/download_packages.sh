#!/bin/bash
# ForgeOS Toolchain Package Download Script
# Downloads all packages from forge-packages releases on GitHub
# Extracts required packages for toolchain builds

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

# Detect project root
detect_project_root

# Load configuration
BUILD_JSON="$PROJECT_ROOT/build.json"
if [[ ! -f "$BUILD_JSON" ]]; then
    log_error "build.json not found: $BUILD_JSON"
    exit 1
fi

# Check required tools
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed"
    log_info "Install: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    log_error "GitHub CLI (gh) is required but not installed"
    log_info "Install: https://cli.github.com"
    exit 1
fi

# Load configuration from build.json
FORGE_PACKAGES_VERSION=$(jq -r '.build.repository.forge_packages_version // "v1.0.2"' "$BUILD_JSON")
PACKAGES_DIR="$PROJECT_ROOT/$(jq -r '.build.directories.packages' "$BUILD_JSON")"
EXTRACTED_DIR="$PROJECT_ROOT/$(jq -r '.build.directories.extracted' "$BUILD_JSON")"

log_info "ForgeOS Toolchain Package Download System"
log_info "forge-packages version: $FORGE_PACKAGES_VERSION"
echo ""

# Create directories
mkdir -p "$PACKAGES_DIR"
mkdir -p "$EXTRACTED_DIR"

# =============================================================================
# Download forge-packages release (all files)
# =============================================================================

log_info "Downloading forge-packages release: $FORGE_PACKAGES_VERSION"

if [[ -n "$(ls -A "$PACKAGES_DIR" 2>/dev/null)" ]]; then
    log_warning "Packages directory not empty, skipping download"
    log_info "To re-download, run: rm -rf $PACKAGES_DIR/*"
else
    if gh release download "$FORGE_PACKAGES_VERSION" \
        -R ramaedge/forge-packages \
        -D "$PACKAGES_DIR" \
        --skip-existing 2>&1; then
        log_success "forge-packages downloaded to: $PACKAGES_DIR"
    else
        log_error "Failed to download forge-packages release"
        log_info "Check if release $FORGE_PACKAGES_VERSION exists: https://github.com/ramaedge/forge-packages/releases"
        exit 1
    fi
fi

# =============================================================================
# Extract required packages
# =============================================================================

log_info "Extracting required packages..."
echo ""

# Get required packages from build.json
REQUIRED_PACKAGES=$(jq -r '.build.toolchain.required_packages[]' "$BUILD_JSON" 2>/dev/null)
MUSL_PACKAGES=$(jq -r '.build.toolchain.libc.musl[]' "$BUILD_JSON" 2>/dev/null)
GNU_PACKAGES=$(jq -r '.build.toolchain.libc.gnu[]' "$BUILD_JSON" 2>/dev/null)

# Combine all packages (unique)
ALL_PACKAGES=$(echo -e "$REQUIRED_PACKAGES\n$MUSL_PACKAGES\n$GNU_PACKAGES" | sort -u)

extracted_count=0
skipped_count=0
failed_count=0

# Extract each package
while IFS= read -r package_name; do
    [[ -z "$package_name" ]] && continue
    
    # Find tarball(s) matching the package name
    tarballs=$(find "$PACKAGES_DIR" -name "${package_name}-*.tar.xz" -o -name "${package_name}-*.tar.gz" -o -name "${package_name}-*.tar.bz2" 2>/dev/null)
    
    if [[ -z "$tarballs" ]]; then
        log_warning "No tarball found for: $package_name"
        continue
    fi
    
    while IFS= read -r tarball; do
        [[ -z "$tarball" ]] && continue
        
        # Extract directory name (e.g., binutils-2.45.tar.xz -> binutils-2.45)
        basename_tar=$(basename "$tarball")
        extracted_name=$(echo "$basename_tar" | sed -E 's/\.tar\.(xz|gz|bz2)$//')
        extracted_path="$EXTRACTED_DIR/$extracted_name"
        
        # Skip if already extracted
        if [[ -d "$extracted_path" ]]; then
            log_info "Already extracted: $extracted_name"
            skipped_count=$((skipped_count + 1))
            continue
        fi
        
        # Extract the tarball
        log_info "Extracting: $basename_tar"
        if tar -xf "$tarball" -C "$EXTRACTED_DIR" 2>&1; then
            log_success "Extracted: $extracted_name"
            extracted_count=$((extracted_count + 1))
        else
            log_error "Failed to extract: $basename_tar"
            failed_count=$((failed_count + 1))
        fi
    done <<< "$tarballs"
done <<< "$ALL_PACKAGES"

# =============================================================================
# Summary
# =============================================================================

echo ""
log_info "═══════════════════════════════════════════════════"
log_info "  Download & Extraction Summary"
log_info "═══════════════════════════════════════════════════"
echo ""

package_count=$(find "$PACKAGES_DIR" -type f \( -name "*.tar.xz" -o -name "*.tar.gz" -o -name "*.tar.bz2" \) 2>/dev/null | wc -l | tr -d ' ')
log_info "Downloaded: $package_count files in $PACKAGES_DIR"
log_info "Extracted: $extracted_count packages"
log_info "Skipped: $skipped_count already extracted"
if [[ $failed_count -gt 0 ]]; then
    log_warning "Failed: $failed_count packages"
fi
log_info "Extracted to: $EXTRACTED_DIR"

echo ""
if [[ $failed_count -gt 0 ]]; then
    log_error "Some packages failed to extract!"
    exit 1
fi
log_success "Packages ready for toolchain builds!"
