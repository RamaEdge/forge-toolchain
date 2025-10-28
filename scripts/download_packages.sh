#!/bin/bash
# ForgeOS Toolchain Package Download Script
# Downloads packages from forge-packages releases on GitHub
# Usage: download_packages.sh [PACKAGE_NAME] [RELEASE_VERSION]

# Don't use -e globally since downloads might fail
set -uo pipefail

# Script configuration - Detect project root using git
if ! PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[✓]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1" >&2; }
log_error() { echo -e "${RED}[✗]${NC} $1" >&2; }

# Load configuration
BUILD_JSON="$PROJECT_ROOT/build.json"
if [[ ! -f "$BUILD_JSON" ]]; then
    log_error "build.json not found: $BUILD_JSON"
    exit 1
fi

# Check jq dependency
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed"
    exit 1
fi

# Check curl dependency
if ! command -v curl >/dev/null 2>&1; then
    log_error "curl is required but not installed"
    exit 1
fi

# Parse arguments
PACKAGE_NAME="${1:-}"
RELEASE_VERSION="${2:-}"

# Load from build.json if not provided
if [[ -z "$RELEASE_VERSION" ]]; then
    RELEASE_VERSION=$(jq -r '.build.repository.forge_packages_version // "v1.0.0"' "$BUILD_JSON")
fi

FORGE_PACKAGES_RELEASES=$(jq -r '.build.repository.forge_packages_releases // "https://github.com/RamaEdge/forge-packages/releases"' "$BUILD_JSON")

DOWNLOAD_MODE="all"
if [[ -n "$PACKAGE_NAME" ]]; then
    DOWNLOAD_MODE="single"
    # Verify package exists in build.json
    if ! jq -e ".build.packages.\"$PACKAGE_NAME\"" "$BUILD_JSON" > /dev/null 2>&1; then
        log_error "Package not found in build.json: $PACKAGE_NAME"
        exit 1
    fi
fi

log_info "ForgeOS Toolchain Package Download System"
log_info "Release Version: $RELEASE_VERSION"
log_info "Source: $FORGE_PACKAGES_RELEASES"
log_info ""

# Determine which packages to download
if [[ "$DOWNLOAD_MODE" == "single" ]]; then
    log_info "Download Mode: Single Package"
    log_info "Package: $PACKAGE_NAME"
    PACKAGES_TO_DOWNLOAD=$(echo "$PACKAGE_NAME")
else
    log_info "Download Mode: All Packages"
    log_info "Loading packages from build.json..."
    PACKAGES_TO_DOWNLOAD=$(jq -r '.build.packages | keys[]' "$BUILD_JSON" 2>/dev/null || echo "")
fi

echo ""

# Create packages directory
PACKAGES_DIR="$PROJECT_ROOT/packages/downloads"
mkdir -p "$PACKAGES_DIR"

# Download each package
total=0
downloaded=0
cached=0
failed=0

# Process packages
while IFS= read -r package_name; do
    if [[ -z "$package_name" ]]; then
        continue
    fi
    
    version=$(jq -r ".build.packages.\"$package_name\".version" "$BUILD_JSON" 2>/dev/null || echo "unknown")
    filename=$(jq -r ".build.packages.\"$package_name\".filename" "$BUILD_JSON" 2>/dev/null || echo "")
    url=$(jq -r ".build.packages.\"$package_name\".url" "$BUILD_JSON" 2>/dev/null || echo "")
    
    if [[ -z "$filename" ]] || [[ -z "$url" ]]; then
        log_warning "Skipping $package_name - missing filename or url"
        continue
    fi
    
    # Replace release version in URL (e.g., /v1.0.0 -> /v1.0.1)
    url=$(echo "$url" | sed "s|/v[0-9]\+\.[0-9]\+\.[0-9]\+|/$RELEASE_VERSION|g")
    
    filepath="$PACKAGES_DIR/$filename"
    ((total++))
    
    # Check if already downloaded
    if [[ -f "$filepath" ]]; then
        log_success "Cached: $filename ($version)"
        ((cached++))
        continue
    fi
    
    log_info "Downloading: $filename ($version)"
    log_info "  URL: $url"
    
    # Try downloading with gh first if package is from GitHub releases
    if [[ "$url" == *"github.com"*"releases/download"* ]] && command -v gh >/dev/null 2>&1; then
        # Extract release info from URL
        gh_repo=$(echo "$url" | sed 's|.*/\([^/]*/[^/]*\)/releases.*|\1|')
        gh_tag=$(echo "$url" | sed 's|.*releases/download/\([^/]*\)/.*|\1|')
        
        log_info "  Using GitHub CLI for download..."
        if gh release download "$gh_tag" -R "$gh_repo" -p "$filename" -D "$PACKAGES_DIR" --clobber 2>/dev/null; then
            log_success "Downloaded: $filename"
            ((downloaded++))
            continue
        else
            log_warning "GitHub CLI download failed, trying curl..."
        fi
    fi
    
    # Download with error handling (don't exit on failure)
    if curl -L -f --connect-timeout 30 --max-time 600 \
        --progress-bar \
        -o "$filepath" "$url" 2>/dev/null; then
        log_success "Downloaded: $filename"
        ((downloaded++))
    else
        log_error "Failed to download: $filename"
        log_info "  URL: $url"
        rm -f "$filepath"
        ((failed++))
    fi
done <<< "$PACKAGES_TO_DOWNLOAD"

# Summary
echo ""
log_info "═══════════════════════════════════════════════════"
log_info "  Download Summary"
log_info "═══════════════════════════════════════════════════"
echo ""
log_info "Mode: $DOWNLOAD_MODE"
log_info "Release: $RELEASE_VERSION"
log_info "Total packages: $total"
log_info "Downloaded: $downloaded"
log_info "Cached: $cached"
log_info "Failed: $failed"
log_info "Output directory: $PACKAGES_DIR"
echo ""

if [[ $failed -eq 0 ]] && [[ $total -gt 0 ]]; then
    log_success "All packages ready! ✨"
    log_info ""
    log_info "To use packages in toolchain builds:"
    log_info "  export PACKAGES_DIR=\"$PACKAGES_DIR\""
    log_info "  make toolchain"
    exit 0
elif [[ $total -eq 0 ]]; then
    log_warning "No packages found to download"
    exit 0
else
    log_error "Some packages failed to download"
    log_info "Try updating RELEASE_VERSION in build.json or check repository URL"
    exit 1
fi
