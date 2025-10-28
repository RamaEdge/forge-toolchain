#!/bin/bash
# ForgeOS Toolchain Release Upload Script
# Uploads existing toolchain release archives to GitHub
# Usage: upload_release.sh VERSION [--arch ARCH] [--toolchain TOOLCHAIN]

set -uo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[✓]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1" >&2; }
log_error() { echo -e "${RED}[✗]${NC} $1" >&2; }

# Default values
ARCH="aarch64"
TOOLCHAIN="musl"

# Parse arguments
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    log_error "VERSION is required: upload_release.sh VERSION [--arch ARCH] [--toolchain TOOLCHAIN]"
    exit 1
fi

shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            ARCH="${2:-}"
            if [[ -z "$ARCH" ]]; then
                log_error "--arch requires a value"
                exit 1
            fi
            shift 2 || true
            ;;
        --toolchain)
            TOOLCHAIN="${2:-}"
            if [[ -z "$TOOLCHAIN" ]]; then
                log_error "--toolchain requires a value"
                exit 1
            fi
            shift 2 || true
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "Uploading toolchain release: $VERSION"
log_info "Architecture: $ARCH"
log_info "Toolchain: $TOOLCHAIN"
echo ""

# Check release exists
if ! gh release view "$VERSION" > /dev/null 2>&1; then
    log_error "Release not found: $VERSION"
    log_info "Create release first: gh release create $VERSION"
    exit 1
fi

log_success "Release found: $VERSION"
echo ""

# Find and upload release archives
RELEASES_DIR="$PROJECT_ROOT/releases"
ARCHIVE_NAME="${TOOLCHAIN}-${ARCH}-${VERSION}.tar.gz"
ARCHIVE_PATH="$RELEASES_DIR/$ARCHIVE_NAME"
CHECKSUMS_FILE="$RELEASES_DIR/${TOOLCHAIN}-${ARCH}-${VERSION}-SHA256SUMS.txt"

log_info "Checking for release artifacts..."

if [[ ! -f "$ARCHIVE_PATH" ]]; then
    log_error "Release archive not found: $ARCHIVE_PATH"
    log_info "Create archive first: make release-toolchain VERSION=$VERSION ARCH=$ARCH TOOLCHAIN=$TOOLCHAIN"
    exit 1
fi

log_success "Found: $ARCHIVE_NAME ($(du -h "$ARCHIVE_PATH" | cut -f1))"

if [[ ! -f "$CHECKSUMS_FILE" ]]; then
    log_warning "Checksums file not found: $CHECKSUMS_FILE"
    log_info "Creating checksums..."
    cd "$RELEASES_DIR"
    sha256sum "$ARCHIVE_NAME" > "${TOOLCHAIN}-${ARCH}-${VERSION}-SHA256SUMS.txt"
    cd - > /dev/null
    log_success "Checksums created"
fi

log_success "Found: $(basename "$CHECKSUMS_FILE")"
echo ""

# Upload to GitHub
log_info "Uploading to GitHub release..."
cd "$PROJECT_ROOT"

# Upload archive
log_info "Uploading: $ARCHIVE_NAME"
if ! gh release upload "$VERSION" "$ARCHIVE_PATH" --clobber; then
    log_error "Failed to upload: $ARCHIVE_PATH"
    exit 1
fi
log_success "Uploaded: $ARCHIVE_NAME"

# Upload checksums
log_info "Uploading: $(basename "$CHECKSUMS_FILE")"
if ! gh release upload "$VERSION" "$CHECKSUMS_FILE" --clobber; then
    log_error "Failed to upload checksums"
    exit 1
fi
log_success "Uploaded: $(basename "$CHECKSUMS_FILE")"

echo ""
log_success "Release upload complete!"

# Get repository URL for display
REPO_URL=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null | sed 's/.*://' | sed 's/.git//' || echo "ramaedge/forge-toolchain")
log_info "Release URL: https://github.com/$REPO_URL/releases/tag/$VERSION"

exit 0
