#!/bin/bash
# ForgeOS Toolchain Release Creation Script
# Creates a GitHub release with minimal toolchain archives (both musl and gnu)
# Only essential files (bin/ and sysroot/) are included
# Usage: create_release.sh [VERSION] [--arch ARCH] [--no-cleanup] [--no-build]

set -uo pipefail

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
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    log_error "GitHub CLI (gh) is required but not installed"
    exit 1
fi

# Default values
ARCH="aarch64"
TOOLCHAINS=("musl" "gnu")
CLEANUP=true
BUILD=true

# Read version from build.json or use command-line argument
if [[ -n "${1:-}" ]] && [[ ! "$1" =~ ^-- ]]; then
    VERSION="$1"
    shift
else
    VERSION=$(jq -r '.metadata.version' "$BUILD_JSON")
fi

# Validate version format (MAJOR.MINOR.PATCH)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format: $VERSION"
    log_info "Expected format: MAJOR.MINOR.PATCH (e.g., 1.0.0)"
    exit 1
fi

# Check if version tag already exists
if git tag -l "v$VERSION" | grep -q "v$VERSION"; then
    log_error "Release v$VERSION already exists"
    log_info "Update build.json metadata.version to a new version"
    log_info "Existing tags: $(git tag -l 'v*' | tr '\n' ' ')"
    exit 1
fi

# Parse remaining arguments
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

log_info "Creating toolchain release: v$VERSION"
log_info "Architecture: $ARCH"
log_info "Toolchains: ${TOOLCHAINS[@]}"
echo ""

# =============================================================================
# Detect package versions from extracted packages
# =============================================================================

EXTRACTED_DIR="$PROJECT_ROOT/packages/extracted"

detect_package_version() {
    local package_pattern="$1"
    local dir=$(find "$EXTRACTED_DIR" -maxdepth 1 -type d -name "$package_pattern" 2>/dev/null | head -1)
    if [[ -n "$dir" ]]; then
        basename "$dir" | sed "s/^${package_pattern%-*}-//"
    else
        echo "unknown"
    fi
}

BINUTILS_VERSION=$(detect_package_version "binutils-*")
GCC_VERSION=$(detect_package_version "gcc-*")
MUSL_VERSION=$(detect_package_version "musl-*")
GLIBC_VERSION=$(detect_package_version "glibc-*")
LINUX_VERSION=$(detect_package_version "linux-*")
FORGE_PACKAGES_VERSION=$(jq -r '.build.forge_packages_version' "$BUILD_JSON")

log_info "Package versions detected:"
log_info "  binutils: $BINUTILS_VERSION"
log_info "  gcc: $GCC_VERSION"
log_info "  musl: $MUSL_VERSION"
log_info "  glibc: $GLIBC_VERSION"
log_info "  linux headers: $LINUX_VERSION"
log_info "  forge-packages: $FORGE_PACKAGES_VERSION"
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
    TEMP_DIRS+=("$TEMP_DIR")
    
    # Copy only essential files (bin and sysroot)
    log_info "  Copying essential files..."
    mkdir -p "$TEMP_DIR/bin"
    mkdir -p "$TEMP_DIR/${ARCH}-linux-${toolchain}"
    
    # Copy all binaries from bin/
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
    ARCHIVE_NAME="${toolchain}-${ARCH}-v${VERSION}.tar.gz"
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
    
    # Generate checksums from original artifact structure
    log_info "  Generating checksums..."
    cd "$OUTPUT_DIR"
    find . -type f -exec sha256sum {} \; > "$RELEASES_DIR/${toolchain}-${ARCH}-v${VERSION}-SHA256SUMS.txt"
    cd - > /dev/null
    log_success "  Checksums generated"
done

echo ""

# Generate release notes with package version information
log_info "Generating release notes..."
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

cat > "$PROJECT_ROOT/TOOLCHAIN_RELEASE_NOTES.md" << EOF
# ForgeOS Toolchains v${VERSION}

Complete cross-compilation toolchains for ForgeOS edge Linux distribution.

## Build Information

- **Toolchain Version**: v${VERSION}
- **Architecture**: ${ARCH}
- **Build Date**: ${BUILD_DATE}
- **forge-packages Version**: ${FORGE_PACKAGES_VERSION}

## Package Versions

### Common Components
- **binutils**: ${BINUTILS_VERSION}
- **gcc**: ${GCC_VERSION}
- **linux headers**: ${LINUX_VERSION}

### musl Toolchain
- **Target Triple**: ${ARCH}-linux-musl
- **C Library**: musl ${MUSL_VERSION}
- **Type**: Lightweight, static-friendly

### GNU (glibc) Toolchain
- **Target Triple**: ${ARCH}-linux-gnu
- **C Library**: glibc ${GLIBC_VERSION}
- **Type**: Full-featured, dynamic linking

## Archive Contents

Each archive contains only essential files for cross-compilation:

- \`bin/\` - Compiler binaries (gcc, g++, ld, as, ar, strip, etc.)
- \`<target>/\` - C library, headers, and sysroot libraries

**Space savings**: Excluded libexec/ (~770 MB) and share/ (~21 MB) directories.

## Installation

Extract and use the toolchain:

\`\`\`bash
# Extract musl toolchain
tar -xzf musl-${ARCH}-v${VERSION}.tar.gz -C /opt/toolchain/

# Add to PATH
export PATH=/opt/toolchain/bin:\$PATH

# Cross-compile with musl
${ARCH}-linux-musl-gcc -o program program.c
\`\`\`

For glibc toolchain:

\`\`\`bash
# Extract glibc toolchain
tar -xzf gnu-${ARCH}-v${VERSION}.tar.gz -C /opt/toolchain/

# Add to PATH
export PATH=/opt/toolchain/bin:\$PATH

# Cross-compile with glibc
${ARCH}-linux-gnu-gcc -o program program.c
\`\`\`

## Verification

Verify checksums:

\`\`\`bash
sha256sum -c musl-${ARCH}-v${VERSION}-SHA256SUMS.txt
sha256sum -c gnu-${ARCH}-v${VERSION}-SHA256SUMS.txt
\`\`\`

## Usage with ForgeOS

These toolchains are designed for building:
- Linux kernel (${LINUX_VERSION} headers included)
- BusyBox userland
- initramfs
- Edge-optimized applications

## Compatibility

- **Build Host**: Linux (x86_64 or aarch64)
- **Target**: ARM64 (aarch64)
- **Requirements**: glibc 2.17+, bash 4.0+

## For More Information

Visit: [ForgeOS Project](https://github.com/ramaedge/forge-os)
EOF

log_success "Release notes generated"
echo ""

# Create GitHub release
log_info "Creating GitHub release..."
cd "$PROJECT_ROOT"

# Collect all files to upload
UPLOAD_FILES=("$RELEASES_DIR"/musl-${ARCH}-v${VERSION}.tar.gz \
              "$RELEASES_DIR"/musl-${ARCH}-v${VERSION}-SHA256SUMS.txt \
              "$RELEASES_DIR"/gnu-${ARCH}-v${VERSION}.tar.gz \
              "$RELEASES_DIR"/gnu-${ARCH}-v${VERSION}-SHA256SUMS.txt \
              "TOOLCHAIN_RELEASE_NOTES.md")

# Validate all files exist
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
if ! gh release create "v$VERSION" \
    --title "ForgeOS Toolchains v$VERSION ($ARCH)" \
    --notes-file TOOLCHAIN_RELEASE_NOTES.md \
    "${UPLOAD_FILES[@]}"; then
    log_error "Failed to create GitHub release"
    log_warning "Release may already exist. Use: gh release upload v$VERSION <files>"
    exit 1
fi

log_success "GitHub release created successfully"
echo ""

# Get repository URL
REPO_URL=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null | sed 's/.*://' | sed 's/.git//' || echo "ramaedge/forge-toolchain")
log_info "Release URL: https://github.com/$REPO_URL/releases/tag/v$VERSION"
echo ""

# Show archive sizes
for toolchain in "${TOOLCHAINS[@]}"; do
    ARCHIVE_PATH="$RELEASES_DIR/${toolchain}-${ARCH}-v${VERSION}.tar.gz"
    if [[ -f "$ARCHIVE_PATH" ]]; then
        ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
        log_info "  $toolchain: $ARCHIVE_SIZE"
    fi
done

echo ""

# Cleanup artifacts if requested
if [[ "$CLEANUP" == true ]]; then
    log_info "Cleaning up artifacts folder..."
    rm -rf "$ARTIFACTS_DIR"
    log_success "Artifacts cleaned up"
    log_info "To rebuild toolchains, run: make toolchain"
else
    log_info "Artifacts retained (skipped cleanup)"
fi

echo ""
log_success "Toolchain release v$VERSION complete!"
log_info "Share this URL: https://github.com/$REPO_URL/releases/tag/v$VERSION"

exit 0
