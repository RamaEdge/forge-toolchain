# ForgeOS Toolchain Build System
# Cross-compilation toolchain building for ForgeOS
# Independent repository for toolchain management
#
# Configuration Source: build.json
# - All package URLs are defined in build.json pointing to forge-packages releases
# - All package versions are centralized in build.json
# - Single source of truth for all dependencies
#
# Package Management Strategy:
# - forge-packages releases contain all pre-built packages
# - Packages are downloaded via GitHub releases (faster, no cloning needed)
# - Local copies used during build (offline-capable after download)
# - All URLs point to forge-packages GitHub releases (forge-packages repo)

# =============================================================================
# CONFIGURATION
# =============================================================================

# Load build.json configuration
# Note: Configuration is loaded via scripts/load_config.sh when needed

# Default configuration (can be overridden)
ARCH ?= aarch64
TOOLCHAIN ?= musl
BUILD_DIR ?= build
ARTIFACTS_DIR ?= artifacts
SOURCE_DATE_EPOCH ?= $(shell date +%s)

# Toolchain-specific settings
ifeq ($(TOOLCHAIN),musl)
    TARGET := $(ARCH)-linux-musl
    CROSS_COMPILE := $(TARGET)-
    OUTPUT_DIR := $(ARTIFACTS_DIR)/$(ARCH)-musl
else ifeq ($(TOOLCHAIN),gnu)
    TARGET := $(ARCH)-linux-gnu
    CROSS_COMPILE := $(TARGET)-
    OUTPUT_DIR := $(ARTIFACTS_DIR)/$(ARCH)-gnu
else
    $(error Unknown toolchain: $(TOOLCHAIN). Supported: musl, gnu)
endif

# Build configuration
export ARCH
export TOOLCHAIN
export TARGET
export CROSS_COMPILE
export OUTPUT_DIR
export SOURCE_DATE_EPOCH

# Color output
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m

# =============================================================================
# MAIN TARGETS
# =============================================================================

# Default target: download packages and build toolchain
all: download-packages toolchain

# Build specific toolchain
toolchain: check-dependencies
	@echo "Building $(TOOLCHAIN) toolchain for $(ARCH)..."
	@./scripts/build_toolchain.sh $(ARCH) $(TOOLCHAIN)
	@if [ -f "$(OUTPUT_DIR)/bin/$(TARGET)-gcc" ]; then \
		echo "$(GREEN)[✓]$(NC) Toolchain build complete: $(OUTPUT_DIR)"; \
	else \
		echo "$(RED)[✗]$(NC) ERROR: Toolchain not found at $(OUTPUT_DIR)"; \
		exit 1; \
	fi

# Build all toolchains (musl and gnu for both architectures)
all-toolchains: check-dependencies
	@echo "Building all toolchains..."
	@echo "$(BLUE)[1/2]$(NC) Building musl toolchain..."
	./scripts/build_toolchain.sh $(ARCH) musl
	@if [ -f "$(ARTIFACTS_DIR)/$(ARCH)-musl/bin/$(ARCH)-linux-musl-gcc" ]; then \
		echo "$(GREEN)[✓]$(NC) musl toolchain built successfully"; \
	else \
		echo "$(RED)[✗]$(NC) ERROR: musl toolchain not found"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(BLUE)[2/2]$(NC) Building glibc toolchain..."
	./scripts/build_toolchain.sh $(ARCH) gnu
	@if [ -f "$(ARTIFACTS_DIR)/$(ARCH)-gnu/bin/$(ARCH)-linux-gnu-gcc" ]; then \
		echo "$(GREEN)[✓]$(NC) glibc toolchain built successfully"; \
	else \
		echo "$(RED)[✗]$(NC) ERROR: glibc toolchain not found"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(GREEN)[✓]$(NC) All toolchains built successfully"
	@echo ""
	@echo "$(BLUE)[Summary]$(NC)"
	@echo "  musl:  $(ARTIFACTS_DIR)/$(ARCH)-musl/bin/$(ARCH)-linux-musl-gcc"
	@echo "  glibc: $(ARTIFACTS_DIR)/$(ARCH)-gnu/bin/$(ARCH)-linux-gnu-gcc"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf packages/downloads
	@echo "Build artifacts and packages cleaned"

# Clean all artifacts including built toolchains
clean-all: clean
	@echo "Cleaning all artifacts..."
	@rm -rf $(ARTIFACTS_DIR)
	@echo "All artifacts cleaned"

# =============================================================================
# TOOLCHAIN VERIFICATION AND TESTING
# =============================================================================

# Verify toolchain build
verify: toolchain
	@echo "Verifying $(TOOLCHAIN) toolchain..."
	@./scripts/verify_toolchain.sh $(ARCH) $(TOOLCHAIN) $(ARTIFACTS_DIR)
	@echo "Toolchain verification complete"

# Test toolchain
test: toolchain
	@echo "Testing $(TOOLCHAIN) toolchain..."
	@./scripts/test_toolchain.sh $(ARCH) $(TOOLCHAIN) $(ARTIFACTS_DIR)
	@echo "Toolchain test complete"

# =============================================================================
# PACKAGE MANAGEMENT
# =============================================================================

# Download packages from forge-packages
download-packages:
	@echo "Downloading packages from forge-packages..."
	@./scripts/download_packages.sh
	@echo "Package download complete"

# Download packages from specific release version
# Usage: make download-packages-release VERSION=v1.0.1
download-packages-release:
	@if [ -z "$(VERSION)" ]; then \
		echo "VERSION is required: make download-packages-release VERSION=v1.0.1"; \
		exit 1; \
	fi
	@echo "Downloading packages from forge-packages release $(VERSION)..."
	@./scripts/download_packages.sh "" "$(VERSION)"
	@echo "Package download complete for release $(VERSION)"

# Download specific package
# Usage: make download-package PACKAGE=binutils
download-package:
	@if [ -z "$(PACKAGE)" ]; then \
		echo "PACKAGE is required: make download-package PACKAGE=binutils"; \
		exit 1; \
	fi
	@echo "Downloading package: $(PACKAGE)..."
	@./scripts/download_packages.sh "$(PACKAGE)"
	@echo "Package download complete: $(PACKAGE)"

# List available packages
list-packages:
	@echo "Available packages from build.json:"
	@jq -r '.build.packages | keys[]' build.json | sort
	@echo ""
	@echo "Total packages: $$(jq '.build.packages | length' build.json)"

# Clean downloaded packages
clean-packages:
	@echo "Cleaning downloaded packages..."
	@rm -rf packages/downloads
	@echo "Downloaded packages cleaned"

# =============================================================================
# RELEASE AND DISTRIBUTION
# =============================================================================

# Create a release archive of built toolchains (both musl and gnu)
# Creates minimal archives with only essential files and uploads to GitHub
# After release, artifacts folder is cleaned up
# Usage: make release-toolchain VERSION=v0.1.0 [ARCH=aarch64] [--no-cleanup] [--no-build]
release-toolchain:
	@if [ -z "$(VERSION)" ]; then \
		echo "$(RED)[✗]$(NC) VERSION is required: make release-toolchain VERSION=v0.1.0"; \
		exit 1; \
	fi
	@./scripts/create_release.sh "$(VERSION)" --arch "$(ARCH)"

# Upload existing toolchain release to GitHub
# Usage: make upload-toolchain VERSION=v0.1.0
upload-toolchain:
	@if [ -z "$(VERSION)" ]; then \
		echo "$(RED)[✗]$(NC) VERSION is required: make upload-toolchain VERSION=v0.1.0"; \
		exit 1; \
	fi
	@./scripts/upload_release.sh "$(VERSION)" --arch "$(ARCH)"

# =============================================================================
# DEPENDENCY CHECKS
# =============================================================================

check-dependencies:
	@echo "Checking build dependencies..."
	@./scripts/check_dependencies.sh || { echo "$(RED)[✗]$(NC) Dependency check failed"; exit 1; }
	@echo "$(GREEN)[✓]$(NC) All dependencies check complete"

# =============================================================================
# HELP AND INFO
# =============================================================================

help:
	@echo "$(BLUE)ForgeOS Toolchain Build System$(NC)"
	@echo ""
	@echo "Usage: make [target] [options]"
	@echo ""
	@echo "$(BLUE)Build Targets:$(NC)"
	@echo "  toolchain            Build specific toolchain (default: musl)"
	@echo "  all-toolchains       Build all toolchains (musl and gnu)"
	@echo "  verify               Build and verify toolchain"
	@echo "  test                 Build and test toolchain"
	@echo ""
	@echo "$(BLUE)Package Management:$(NC)"
	@echo "  download-packages              Download all packages (default version)"
	@echo "  download-packages-release      Download packages from release VERSION=v1.0.1"
	@echo "  download-package PACKAGE=name  Download specific package"
	@echo "  list-packages                  List available packages"
	@echo "  clean-packages                 Clean downloaded packages"
	@echo ""
	@echo "$(BLUE)Release and Distribution:$(NC)"
	@echo "  release-toolchain VERSION=v0.1.0      Create toolchain release archive"
	@echo "  upload-toolchain VERSION=v0.1.0  Upload release to GitHub"
	@echo ""
	@echo "$(BLUE)Cleanup:$(NC)"
	@echo "  clean                Clean build artifacts and packages"
	@echo "  clean-all            Clean all artifacts including toolchains"
	@echo ""
	@echo "$(BLUE)Information:$(NC)"
	@echo "  config               Show current build configuration"
	@echo "  check-dependencies   Check build dependencies"
	@echo "  help                 Show this help"
	@echo ""
	@echo "$(BLUE)Options:$(NC)"
	@echo "  ARCH=arch       Target architecture (default: aarch64)"
	@echo "  TOOLCHAIN=type  Toolchain type: musl, gnu (default: musl)"
	@echo "  BUILD_DIR=dir   Build directory (default: build)"
	@echo "  ARTIFACTS_DIR=dir  Artifacts directory (default: artifacts)"
	@echo "  VERSION=tag     Release/package version"
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  make toolchain                     # Build musl/aarch64"
	@echo "  make toolchain ARCH=x86_64 TOOLCHAIN=gnu  # Build gnu/x86_64"
	@echo "  make download-packages             # Download all packages"
	@echo "  make verify                        # Build and verify"
	@echo "  make release-toolchain VERSION=v0.1.0     # Create release"
	@echo "  make upload-toolchain VERSION=v0.1.0  # Upload release"

# Show current configuration
config:
	@echo "$(BLUE)ForgeOS Toolchain Configuration:$(NC)"
	@echo "  Architecture: $(ARCH)"
	@echo "  Toolchain: $(TOOLCHAIN)"
	@echo "  Target: $(TARGET)"
	@echo "  Cross-compile: $(CROSS_COMPILE)"
	@echo "  Build directory: $(BUILD_DIR)"
	@echo "  Artifacts directory: $(ARTIFACTS_DIR)"
	@echo "  Output directory: $(OUTPUT_DIR)"
	@echo "  Source date epoch: $(SOURCE_DATE_EPOCH)"
	@echo ""
	@echo "$(BLUE)Package Configuration:$(NC)"
	@jq '.build.repository' build.json

.PHONY: all toolchain all-toolchains clean clean-all verify test download-packages download-packages-release download-package list-packages clean-packages release-toolchain upload-toolchain check-dependencies config help
