# ForgeOS Toolchain Build Process

## Quick Start

### Unified Build Script

forge-toolchain uses a **single unified build script** that handles both musl and glibc toolchains:

```bash
# Build musl toolchain
./scripts/build_toolchain.sh aarch64 musl

# Build glibc toolchain
./scripts/build_toolchain.sh aarch64 gnu

# Or use make
make toolchain TOOLCHAIN=musl
make toolchain TOOLCHAIN=gnu
make all-toolchains  # Build both
```

## Architecture

### Single vs Multiple Scripts

**Previous Approach** (Complex):
```
build_musl.sh   → builds musl toolchain only
build_glibc.sh  → builds glibc toolchain only
build_all.sh    → orchestrates all builds
```

**Current Approach** (Simplified):
```
build_toolchain.sh → handles ALL toolchain builds
                   → Parameters: [ARCH] [TOOLCHAIN]
```

### Benefits of Unified Script

✅ **Simpler** - One script to maintain
✅ **Consistent** - Same build logic for all toolchains
✅ **Faster** - Direct execution, no wrapper overhead
✅ **Follows forge-os** - Same approach as main repository
✅ **Easier to debug** - Single entry point

## Build Script Parameters

```bash
Usage: ./scripts/build_toolchain.sh [ARCH] [TOOLCHAIN]

ARCH       Default: aarch64
           Options: aarch64, x86_64
           
TOOLCHAIN  Default: musl
           Options: musl, gnu, glibc
```

## Usage Examples

### 1. Build musl for aarch64
```bash
make toolchain ARCH=aarch64 TOOLCHAIN=musl
```

### 2. Build glibc for aarch64
```bash
make toolchain ARCH=aarch64 TOOLCHAIN=gnu
```

### 3. Build both toolchains
```bash
make all-toolchains ARCH=aarch64
```

### 4. Direct script invocation
```bash
./scripts/build_toolchain.sh aarch64 musl
./scripts/build_toolchain.sh aarch64 gnu
```

## Script Internals

### Configuration Selection

The script uses a case statement to set parameters based on toolchain type:

```bash
case "$TOOLCHAIN" in
    "musl")
        TARGET="aarch64-linux-musl"
        LIBC_VERSION="$MUSL_VERSION"
        LIBC_FILENAME="musl-$MUSL_VERSION.tar.gz"
        ;;
    "gnu"|"glibc")
        TARGET="aarch64-linux-gnu"
        LIBC_VERSION="$GLIBC_VERSION"
        LIBC_FILENAME="glibc-$GLIBC_VERSION.tar.xz"
        ;;
esac
```

### Build Stages

All toolchains follow this sequence:

1. **Package Validation** - Verify all required packages exist
2. **Package Extraction** - Extract binutils, gcc, libc, linux headers
3. **Binutils Build** - Build cross-compilation binutils
4. **GCC Stage 1** - Build bootstrap compiler
5. **Libc Build** - Build musl or glibc headers
6. **Verification** - Verify final toolchain

### Directory Structure

```
forge-toolchain/
├── scripts/
│   └── build_toolchain.sh    ← Unified build script
├── packages/downloads/
│   ├── binutils-2.45.tar.xz
│   ├── gcc-15.2.0.tar.xz
│   ├── musl-1.2.5.tar.gz      (for musl builds)
│   ├── glibc-2.42.tar.xz      (for glibc builds)
│   └── linux-6.12.49.tar.xz
├── build/
│   ├── musl-toolchain/        (musl build directory)
│   └── glibc-toolchain/       (glibc build directory)
└── artifacts/
    ├── aarch64-musl/          (musl output)
    └── aarch64-gnu/           (glibc output)
```

## Prerequisites
