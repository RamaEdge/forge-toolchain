#!/bin/bash
# ForgeOS Toolchain Release Creation Script
# Creates a GitHub release with minimal toolchain archives (both musl and gnu)
# Only essential files (bin/ and sysroot/) are included
# Usage: create_release.sh VERSION [--arch ARCH] [--no-cleanup] [--no-build]

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
TOOLCHAINS=("musl" "gnu")
CLEANUP=true
BUILD=true

# Parse arguments
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    log_error "VERSION is required: create_release.sh VERSION [--arch ARCH] [--no-cleanup] [--no-build]"
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
        --no-cleanup)
            CLEANUP=false
            shift || true
            ;;
        --no-build)
            BUILD=false
            shift || true
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "Creating toolchain release: $VERSION"
log_info "Architecture: $ARCH"
log_info "Toolchains: ${TOOLCHAINS[@]}"
echo ""

# Create releases directory
RELEASES_DIR="$PROJECT_ROOT/releases"
mkdir -p "$RELEASES_DIR"

# Build all toolchains if requested
if [[ "$BUILD" == true ]]; then
    log_info "Building toolchains..."
    for toolchain in "${TOOLCHAINS[@]}"; do
        log_info "  Building $toolchain toolchain..."
        cd "$PROJECT_ROOT"
        if ! make toolchain ARCH="$ARCH" TOOLCHAIN="$toolchain" > /dev/null 2>&1; then
            log_error "Failed to build $toolchain toolchain"
            exit 1
        fi
        log_success "  $toolchain toolchain built"
    done
    echo ""
fi

# Create minimal archives for each toolchain
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"

for toolchain in "${TOOLCHAINS[@]}"; do
    log_info "Processing $toolchain toolchain..."
    
    OUTPUT_DIR="$ARTIFACTS_DIR/${ARCH}-${toolchain}"
    
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        log_error "Toolchain not found at: $OUTPUT_DIR"
        exit 1
    fi
    
    # Create temporary directory for minimal archive
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Copy only essential files (bin and sysroot)
    log_info "  Copying essential files..."
    mkdir -p "$TEMP_DIR/bin"
    mkdir -p "$TEMP_DIR/${ARCH}-linux-${toolchain}"
    
    # Copy all binaries from bin/
    cp -r "$OUTPUT_DIR/bin/"* "$TEMP_DIR/bin/" || true
    
    # Copy sysroot (C library, headers, essential libs)
    cp -r "$OUTPUT_DIR/${ARCH}-linux-${toolchain}/"* "$TEMP_DIR/${ARCH}-linux-${toolchain}/" || true
    
    # Create release archive (minimal)
    ARCHIVE_NAME="${toolchain}-${ARCH}-${VERSION}.tar.gz"
    ARCHIVE_PATH="$RELEASES_DIR/$ARCHIVE_NAME"
    
    log_info "  Creating archive: $ARCHIVE_NAME..."
    
    if [[ -f "$ARCHIVE_PATH" ]]; then
        log_warning "  Archive already exists, removing..."
        rm -f "$ARCHIVE_PATH"
    fi
    
    cd "$TEMP_DIR"
    if ! tar -czf "$ARCHIVE_PATH" .; then
        log_error "Failed to create archive: $ARCHIVE_PATH"
        exit 1
    fi
    cd - > /dev/null
    
    ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
    log_success "  Archive created: $ARCHIVE_NAME ($ARCHIVE_SIZE)"
    
    # Generate checksums
    log_info "  Generating checksums..."
    cd "$TEMP_DIR"
    find . -type f -exec sha256sum {} \; > "$RELEASES_DIR/${toolchain}-${ARCH}-${VERSION}-SHA256SUMS.txt"
    cd - > /dev/null
    log_success "  Checksums generated"
done

echo ""

# Generate combined release notes
log_info "Generating release notes..."
{
    echo "# ForgeOS Toolchains $VERSION"
    echo ""
    echo "Complete cross-compilation toolchains for ForgeOS edge Linux distribution."
    echo ""
    echo "## Build Information"
    echo ""
    echo "- **Version**: $VERSION"
    echo "- **Architecture**: $ARCH"
    echo "- **Build Date**: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo ""
    echo "## Available Toolchains"
    echo ""
    echo "### musl Toolchain"
    echo "- **Target Triple**: ${ARCH}-linux-musl"
    echo "- **C Library**: musl (lightweight, static-friendly)"
    echo "- **Compiler**: GCC 15.2.0"
    echo "- **Binutils**: GNU binutils 2.45"
    echo ""
    echo "### GNU (glibc) Toolchain"
    echo "- **Target Triple**: ${ARCH}-linux-gnu"
    echo "- **C Library**: glibc 2.42"
    echo "- **Compiler**: GCC 15.2.0"
    echo "- **Binutils**: GNU binutils 2.45"
    echo ""
    echo "## Archive Contents"
    echo ""
    echo "Each archive contains only essential files for cross-compilation:"
    echo ""
    echo "- \`bin/\` - Compiler binaries (gcc, g++, ld, as, ar, etc.)"
    echo "- \`<target>/\` - C library, headers, and sysroot libraries"
    echo ""
    echo "**Note**: Removed to reduce size:"
    echo "- libexec/ (GCC internals) - saves ~770 MB"
    echo "- share/ (documentation) - saves ~21 MB"
    echo ""
    echo "## Installation"
    echo ""
    echo "Extract and use the toolchain:"
    echo ""
    echo "\`\`\`bash"
    echo "# Extract archive"
    echo "tar -xzf musl-${ARCH}-${VERSION}.tar.gz -C /opt/toolchain/"
    echo ""
    echo "# Add to PATH"
    echo "export PATH=/opt/toolchain/bin:\$PATH"
    echo ""
    echo "# Cross-compile"
    echo "${ARCH}-linux-musl-gcc -o program program.c"
    echo "\`\`\`"
    echo ""
    echo "## Verification"
    echo ""
    echo "Verify checksums:"
    echo ""
    echo "\`\`\`bash"
    echo "sha256sum -c musl-${ARCH}-${VERSION}-SHA256SUMS.txt"
    echo "sha256sum -c gnu-${ARCH}-${VERSION}-SHA256SUMS.txt"
    echo "\`\`\`"
    echo ""
    echo "## Compatibility"
    echo ""
    echo "- **Build Host**: Linux (x86_64 or aarch64)"
    echo "- **Target**: ARM64 (aarch64)"
    echo "- **Requirements**: glibc 2.17+, bash 4.0+"
    echo ""
    echo "## Usage with ForgeOS"
    echo ""
    echo "These toolchains are compatible with ForgeOS kernel and userland builds."
    echo ""
    echo "## For More Information"
    echo ""
    echo "Visit: [ForgeOS Project](https://github.com/ramaedge/forge-os)"
} > "$PROJECT_ROOT/TOOLCHAIN_RELEASE_NOTES.md"

log_success "Release notes generated"
echo ""

# Create GitHub release with all toolchain archives
log_info "Creating GitHub release..."
cd "$PROJECT_ROOT"

# Collect all files to upload
UPLOAD_FILES=("$RELEASES_DIR"/musl-${ARCH}-${VERSION}.tar.gz \
              "$RELEASES_DIR"/musl-${ARCH}-${VERSION}-SHA256SUMS.txt \
              "$RELEASES_DIR"/gnu-${ARCH}-${VERSION}.tar.gz \
              "$RELEASES_DIR"/gnu-${ARCH}-${VERSION}-SHA256SUMS.txt \
              "TOOLCHAIN_RELEASE_NOTES.md")

# Create the release
if ! gh release create "$VERSION" \
    --title "ForgeOS Toolchains $VERSION ($ARCH)" \
    --notes-file TOOLCHAIN_RELEASE_NOTES.md \
    "${UPLOAD_FILES[@]}"; then
    log_error "Failed to create GitHub release"
    log_warning "Release may already exist. Use: gh release upload $VERSION <files>"
    exit 1
fi

log_success "GitHub release created successfully"
echo ""

# Get repository URL for display
REPO_URL=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null | sed 's/.*://' | sed 's/.git//' || echo "ramaedge/forge-toolchain")
log_info "Release URL: https://github.com/$REPO_URL/releases/tag/$VERSION"
echo ""

# Show archive sizes
for toolchain in "${TOOLCHAINS[@]}"; do
    ARCHIVE_PATH="$RELEASES_DIR/${toolchain}-${ARCH}-${VERSION}.tar.gz"
    if [[ -f "$ARCHIVE_PATH" ]]; then
        ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
        log_info "  $toolchain: $ARCHIVE_SIZE"
    fi
done

echo ""

# Cleanup artifacts if requested (like forge-packages does)
if [[ "$CLEANUP" == true ]]; then
    log_info "Cleaning up artifacts folder..."
    rm -rf "$ARTIFACTS_DIR"
    log_success "Artifacts cleaned up"
    log_info "To rebuild toolchains, run: make all-toolchains"
else
    log_info "Artifacts retained (use --no-cleanup flag if you want to delete them)"
fi

echo ""
log_success "Toolchain release complete!"
log_info "Share this URL: https://github.com/$REPO_URL/releases/tag/$VERSION"

exit 0
