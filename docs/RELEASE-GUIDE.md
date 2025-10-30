# ForgeOS Toolchain Release Guide

## Overview

Create and publish toolchain releases to GitHub with package version information.

## Prerequisites

- `gh` CLI tool authenticated
- Built toolchain in `artifacts/`
- Updated version in `build.json`

## Release Workflow

### 1. Update Version

Edit `build.json`:
```json
{
  "metadata": {
    "version": "0.1.1"
  }
}
```

### 2. Build Toolchains

```bash
# Build both toolchains
make download-packages
make toolchain TOOLCHAIN=musl
make toolchain TOOLCHAIN=gnu
make verify
```

### 3. Create Release

```bash
# Create release (reads version from build.json)
./scripts/create_release.sh
```

This will:
- Read version from `build.json`
- Check if release tag already exists
- Extract package versions from `packages/extracted/`
- Create release archives (`bin/` and `sysroot/` only)
- Generate release notes with package versions
- Create GitHub release
- Upload all artifacts

### 4. Verify Release

```bash
# Check release on GitHub
gh release view v0.1.1

# Or visit
# https://github.com/ramaedge/forge-toolchain/releases/tag/v0.1.1
```

## Release Contents

Each release includes:
- `aarch64-musl-v0.1.1.tar.gz` - musl toolchain
- `aarch64-gnu-v0.1.1.tar.gz` - glibc toolchain  
- `TOOLCHAIN_RELEASE_NOTES.md` - Release documentation

Archives contain only:
- `bin/` - Toolchain binaries
- `aarch64-linux-{musl,gnu}/` - Target sysroot

## Release Notes

Auto-generated notes include:
- Toolchain version
- Package versions (binutils, gcc, glibc, musl, linux)
- Build date
- Architecture info
- Installation instructions

## Troubleshooting

### Release Already Exists

Delete the existing release:
```bash
gh release delete v0.1.1
git tag -d v0.1.1
git push origin :refs/tags/v0.1.1
```

Then recreate it.

### Missing Toolchain

Build it first:
```bash
make toolchain TOOLCHAIN=musl
./scripts/create_release.sh
```

### GitHub CLI Not Authenticated

```bash
gh auth login
gh auth status
```

## Version Management

- Manually update `build.json` → `metadata.version` field
- Script checks for existing tags before creating release
- Use semantic versioning: `v0.1.0`, `v0.2.0`, etc.
