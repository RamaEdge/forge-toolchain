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

# Track temp directories for cleanup
TEMP_DIRS=()
cleanup_temp_dirs() {
    for temp_dir in "${TEMP_DIRS[@]}"; do
        if [[ -d "$temp_dir" ]]; then
            rm -rf "$temp_dir"
        fi
    done
}
# Set trap OUTSIDE the loop to catch all temp dirs
trap 'cleanup_temp_dirs' EXIT

for toolchain in "${TOOLCHAINS[@]}"; do
    log_info "Processing $toolchain toolchain..."
    
    OUTPUT_DIR="$ARTIFACTS_DIR/${ARCH}-${toolchain}"
    
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        log_error "Toolchain not found at: $OUTPUT_DIR"
        exit 1
    fi
    
    # Create temporary directory for minimal archive
    TEMP_DIR=$(mktemp -d)
    TEMP_DIRS+=("$TEMP_DIR")  # ← Track for cleanup
    
    # Copy only essential files (bin and sysroot)
    log_info "  Copying essential files..."
    mkdir -p "$TEMP_DIR/bin"
    mkdir -p "$TEMP_DIR/${ARCH}-linux-${toolchain}"
    
    # Copy all binaries from bin/ - with error checking
    if ! cp -r "$OUTPUT_DIR/bin/"* "$TEMP_DIR/bin/" 2>/dev/null; then
        log_error "Failed to copy bin directory"
        exit 1
    fi
    
    # Verify files were copied
    if [[ -z "$(find "$TEMP_DIR/bin" -type f)" ]]; then
        log_error "No files copied to bin directory"
        exit 1
    fi
    
    # Copy sysroot (C library, headers, essential libs)
    if ! cp -r "$OUTPUT_DIR/${ARCH}-linux-${toolchain}/"* "$TEMP_DIR/${ARCH}-linux-${toolchain}/" 2>/dev/null; then
        log_error "Failed to copy sysroot directory"
        exit 1
    fi
    
    # Verify sysroot files were copied
    if [[ -z "$(find "$TEMP_DIR/${ARCH}-linux-${toolchain}" -type f)" ]]; then
        log_error "No files copied to sysroot directory"
        exit 1
    fi
    
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
    
    # Generate checksums from original artifact structure (not temp dir)
    log_info "  Generating checksums..."
    cd "$OUTPUT_DIR"
    find . -type f -exec sha256sum {} \; > "$RELEASES_DIR/${toolchain}-${ARCH}-${VERSION}-SHA256SUMS.txt"
    cd - > /dev/null
    log_success "  Checksums generated"
done

echo ""

# Generate combined release notes
log_info "Generating release notes..."
cat > "$PROJECT_ROOT/TOOLCHAIN_RELEASE_NOTES.md" << 'RELEASE_NOTES'
# ForgeOS Toolchains v${VERSION}

Complete cross-compilation toolchains for ForgeOS edge Linux distribution.

## Build Information

- **Version**: ${VERSION}
- **Architecture**: ${ARCH}
- **Build Date**: $(date -u +'%Y-%m-%dT%H:%M:%SZ')

## Available Toolchains

### musl Toolchain
- **Target Triple**: ${ARCH}-linux-musl
- **C Library**: musl (lightweight, static-friendly)
- **Compiler**: GCC 15.2.0
- **Binutils**: GNU binutils 2.45

### GNU (glibc) Toolchain
- **Target Triple**: ${ARCH}-linux-gnu
- **C Library**: glibc 2.42
- **Compiler**: GCC 15.2.0
- **Binutils**: GNU binutils 2.45

## Archive Contents

Each archive contains only essential files for cross-compilation:

- `bin/` - Compiler binaries (gcc, g++, ld, as, ar, etc.)
- `<target>/` - C library, headers, and sysroot libraries

**Note**: Removed to reduce size:
- libexec/ (GCC internals) - saves ~770 MB
- share/ (documentation) - saves ~21 MB

## Installation

Extract and use the toolchain:

```bash
# Extract archive
tar -xzf musl-${ARCH}-${VERSION}.tar.gz -C /opt/toolchain/

# Add to PATH
export PATH=/opt/toolchain/bin:$PATH

# Cross-compile with musl
${ARCH}-linux-musl-gcc -o program program.c
```

Or with GNU C Library (glibc):

```bash
# Extract glibc toolchain
tar -xzf gnu-${ARCH}-${VERSION}.tar.gz -C /opt/toolchain/

# Add to PATH
export PATH=/opt/toolchain/bin:$PATH

# Cross-compile with glibc
${ARCH}-linux-gnu-gcc -o program program.c
```

## Verification

Verify checksums:

```bash
sha256sum -c musl-${ARCH}-${VERSION}-SHA256SUMS.txt
sha256sum -c gnu-${ARCH}-${VERSION}-SHA256SUMS.txt
```

## Compatibility

- **Build Host**: Linux (x86_64 or aarch64)
- **Target**: ARM64 (aarch64)
- **Requirements**: glibc 2.17+, bash 4.0+

## Usage with ForgeOS

These toolchains are compatible with ForgeOS kernel and userland builds.

## For More Information

Visit: [ForgeOS Project](https://github.com/ramaedge/forge-os)
RELEASE_NOTES

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

# Validate all files exist before uploading
log_info "Validating release files..."
for file in "${UPLOAD_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        log_error "Required file not found: $file"
        exit 1
    fi
    log_success "  ✓ $(basename "$file")"
done
echo ""

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
