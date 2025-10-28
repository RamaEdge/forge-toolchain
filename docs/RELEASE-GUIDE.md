# ForgeOS Toolchain Release Guide

## Overview

This guide covers creating and uploading ForgeOS toolchain releases to GitHub.

## Scripts

### 1. `scripts/create_release.sh`

Creates a GitHub release with a built toolchain archive.

**Usage:**
```bash
./scripts/create_release.sh VERSION [--arch ARCH] [--toolchain TOOLCHAIN] [--no-cleanup]
```

**Parameters:**
- `VERSION` (required): Release version (e.g., v0.1.0)
- `--arch ARCH`: Target architecture (default: aarch64)
- `--toolchain TOOLCHAIN`: Toolchain type: musl or gnu (default: musl)
- `--no-cleanup`: Keep release files after upload

**What it does:**
1. ✅ Verifies toolchain exists at `artifacts/{arch}-{toolchain}`
2. ✅ Generates SHA256 checksums
3. ✅ Creates release archive: `releases/{toolchain}-{arch}-{version}.tar.gz`
4. ✅ Generates release notes
5. ✅ Creates GitHub release
6. ✅ Uploads archive and checksums
7. ✅ Outputs release URL

**Example:**
```bash
./scripts/create_release.sh v0.1.0 --arch aarch64 --toolchain musl
```

**Output:**
```
[INFO] Creating toolchain release: v0.1.0
[INFO] Architecture: aarch64
[INFO] Toolchain: musl
[INFO] Toolchain found: artifacts/aarch64-musl
[✓] Checksums generated
[✓] Release archive created
[✓] Release notes generated
[✓] GitHub release created successfully
[INFO] Release URL: https://github.com/ramaedge/forge-toolchain/releases/tag/v0.1.0
```

### 2. `scripts/upload_release.sh`

Uploads existing toolchain archives to a GitHub release.

**Usage:**
```bash
./scripts/upload_release.sh VERSION [--arch ARCH] [--toolchain TOOLCHAIN]
```

**Parameters:**
- `VERSION` (required): Release version (e.g., v0.1.0)
- `--arch ARCH`: Target architecture (default: aarch64)
- `--toolchain TOOLCHAIN`: Toolchain type: musl or gnu (default: musl)

**What it does:**
1. ✅ Verifies release exists on GitHub
2. ✅ Finds release archive locally
3. ✅ Generates checksums if needed
4. ✅ Uploads archive to GitHub release
5. ✅ Uploads checksums to GitHub release
6. ✅ Outputs release URL

**Example:**
```bash
./scripts/upload_release.sh v0.1.0 --arch aarch64 --toolchain musl
```

**Output:**
```
[INFO] Uploading toolchain release: v0.1.0
[INFO] Architecture: aarch64
[INFO] Toolchain: musl
[✓] Release found: v0.1.0
[INFO] Checking for release artifacts...
[✓] Found: musl-aarch64-v0.1.0.tar.gz (2.3G)
[✓] Found: musl-aarch64-v0.1.0-SHA256SUMS.txt
[INFO] Uploading to GitHub release...
[✓] Uploaded: musl-aarch64-v0.1.0.tar.gz
[✓] Uploaded: musl-aarch64-v0.1.0-SHA256SUMS.txt
[✓] Release upload complete!
```

## Makefile Targets

### `make release-toolchain VERSION=v0.1.0`

Calls `scripts/create_release.sh` with configured architecture and toolchain.

**Example:**
```bash
make release-toolchain VERSION=v0.1.0 ARCH=aarch64 TOOLCHAIN=musl
```

### `make upload-toolchain VERSION=v0.1.0`

Calls `scripts/upload_release.sh` with configured architecture and toolchain.

**Example:**
```bash
make upload-toolchain VERSION=v0.1.0 ARCH=aarch64 TOOLCHAIN=musl
```

## Complete Workflow

### Step 1: Download Packages

```bash
make download-packages
```

### Step 2: Build Toolchain

```bash
make toolchain ARCH=aarch64 TOOLCHAIN=musl
```

### Step 3: Create Release

```bash
make release-toolchain VERSION=v0.1.0 ARCH=aarch64 TOOLCHAIN=musl
```

This will:
- ✅ Verify toolchain exists
- ✅ Generate checksums
- ✅ Create archive: `releases/musl-aarch64-v0.1.0.tar.gz`
- ✅ Generate release notes
- ✅ Create GitHub release
- ✅ Upload all artifacts

### Step 4: Verify Release

Check GitHub:
```bash
gh release view v0.1.0
```

Or visit: `https://github.com/ramaedge/forge-toolchain/releases/tag/v0.1.0`

## Release Archives

Built toolchain archives are stored in `releases/`:

```
releases/
├── musl-aarch64-v0.1.0.tar.gz           # Compressed toolchain (2-3 GB)
├── musl-aarch64-v0.1.0-SHA256SUMS.txt   # Checksums
├── musl-x86_64-v0.1.0.tar.gz            # Another arch/toolchain
├── musl-x86_64-v0.1.0-SHA256SUMS.txt
├── gnu-aarch64-v0.1.0.tar.gz
└── gnu-aarch64-v0.1.0-SHA256SUMS.txt
```

## Release Notes

Automatically generated release notes include:

- Release version
- Architecture and toolchain info
- Build date
- Archive contents
- Installation instructions
- Verification steps
- Usage examples

## Verification

Users can verify downloaded toolchains:

```bash
# Extract
tar -xzf musl-aarch64-v0.1.0.tar.gz

# Verify checksums
sha256sum -c musl-aarch64-v0.1.0-SHA256SUMS.txt

# Set up toolchain
export PATH=$(pwd)/bin:$PATH
export LD_LIBRARY_PATH=$(pwd)/lib:$LD_LIBRARY_PATH

# Test
aarch64-linux-musl-gcc --version
```

## Multi-Architecture Releases

To create releases for multiple architectures:

```bash
# Build and release musl/aarch64
make download-packages
make toolchain ARCH=aarch64 TOOLCHAIN=musl
make release-toolchain VERSION=v0.1.0 ARCH=aarch64 TOOLCHAIN=musl

# Build and release gnu/x86_64
make toolchain ARCH=x86_64 TOOLCHAIN=gnu
make release-toolchain VERSION=v0.1.0 ARCH=x86_64 TOOLCHAIN=gnu
```

All archives will be uploaded to the same `v0.1.0` release.

## Troubleshooting

### Release Already Exists

If release already exists, you can upload additional architectures:

```bash
make upload-toolchain VERSION=v0.1.0 ARCH=x86_64 TOOLCHAIN=gnu
```

### Missing Toolchain

If toolchain not found:
```bash
make toolchain ARCH=aarch64 TOOLCHAIN=musl
make release-toolchain VERSION=v0.1.0 ARCH=aarch64 TOOLCHAIN=musl
```

### Upload Failed

Check GitHub CLI authentication:
```bash
gh auth login
gh auth status
```

Then retry upload:
```bash
make upload-toolchain VERSION=v0.1.0 ARCH=aarch64 TOOLCHAIN=musl
```

## Environment Variables

Scripts use:
- `ARCH` - Target architecture (default: aarch64)
- `TOOLCHAIN` - Toolchain type (default: musl)
- `VERSION` - Release version (required)

## See Also

- [Toolchain Build Process](toolchain-build-process.md)
- [Package Management](package-management.md)
- [Integration Guide](integration-guide.md)
