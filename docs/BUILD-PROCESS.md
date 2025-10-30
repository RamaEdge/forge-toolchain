# ForgeOS Toolchain Build Process

## Architecture

### Single Unified Script

forge-toolchain uses **one build script** for all toolchains:

```
scripts/build_toolchain.sh → handles musl AND glibc builds
```

**Benefits:**
- Single entry point
- Consistent build logic
- Easier to maintain
- Matches forge-os approach

## Build Script

```bash
# Usage
./scripts/build_toolchain.sh [ARCH] [LIBC]

# Examples
./scripts/build_toolchain.sh aarch64 musl
./scripts/build_toolchain.sh aarch64 gnu
```

## Build Stages

All toolchains follow these stages:

1. **Package Discovery** - Find packages in `packages/extracted/`
2. **Package Extraction** - Extract source tarballs  
3. **Binutils Build** - Cross-assembler and linker
4. **GCC Bootstrap** - Initial compiler
5. **Libc Build** - musl or glibc headers and libraries
6. **GCC Final** - Complete cross-compiler
7. **Verification** - Test compilation

## Dynamic Package Discovery

The build script finds packages dynamically:

```bash
# No hardcoded versions
BINUTILS_TAR=$(find_package "binutils-*.tar.*")
GCC_TAR=$(find_package "gcc-*.tar.*")
MUSL_TAR=$(find_package "musl-*.tar.*")
GLIBC_TAR=$(find_package "glibc-*.tar.*")
LINUX_TAR=$(find_package "linux-*.tar.*")
```

This allows version changes without script updates.

## Toolchain Configuration

### musl Toolchain
- **Target**: `aarch64-linux-musl`
- **Libc**: musl (static linking)
- **Output**: `artifacts/aarch64-musl/`

### glibc Toolchain
- **Target**: `aarch64-linux-gnu`
- **Libc**: glibc (dynamic linking)
- **Output**: `artifacts/aarch64-gnu/`

## Directory Structure

```
forge-toolchain/
├── packages/
│   ├── downloads/              # Downloaded tarballs
│   └── extracted/              # Extracted sources
│       ├── binutils-2.45/
│       ├── gcc-15.2.0/
│       ├── musl-1.2.5/
│       ├── glibc-2.42/
│       └── linux-6.12.49/
├── build/
│   └── {libc}-toolchain/       # Build workspace
└── artifacts/
    └── {arch}-{libc}/          # Final toolchain
        ├── bin/                # Toolchain binaries
        └── {arch}-linux-{libc}/  # Target sysroot
```

## Helper Scripts

### common.sh
Provides shared utilities:
- Logging functions
- Project root detection  
- Toolchain configuration

### load_config.sh
Loads configuration from `build.json`:
- Directory paths
- Architecture settings
- Repository information

## Build Flags

### Reproducible Builds
```bash
export SOURCE_DATE_EPOCH=$(date +%s)
```

### Optimization
```bash
# Parallel builds
export MAKE_JOBS=$(nproc)  # Linux
export MAKE_JOBS=$(sysctl -n hw.ncpu)  # macOS
```

## Verification

After build, `verify_toolchain.sh`:
- Checks all binaries exist
- Tests C/C++ compilation
- Verifies static linking (musl)
- Checks target architecture

## Troubleshooting

### Build Fails

```bash
# Clean and retry
make clean
make toolchain
```

### Missing Packages

```bash
# Download again
rm -rf packages/downloads/*
make download-packages
```

### Check Logs

Build logs are in `build/{libc}-toolchain/`.

