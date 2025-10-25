# ForgeOS glibc Toolchain Configuration
# Configuration file for glibc-based cross-compilation toolchain

# Toolchain type
TOOLCHAIN_TYPE := gnu

# Default architecture
ARCH ?= aarch64

# Target configuration
TARGET := $(ARCH)-linux-gnu
CROSS_COMPILE := $(TARGET)-

# Build configuration
BUILD_DIR ?= build
ARTIFACTS_DIR ?= artifacts
OUTPUT_DIR := $(ARTIFACTS_DIR)/$(ARCH)-gnu

# Version information
BINUTILS_VERSION := 2.42
GCC_VERSION := 13.2.0
GLIBC_VERSION := 2.38
LINUX_HEADERS_VERSION := 6.6

# Download URLs
BINUTILS_URL := https://ftp.gnu.org/gnu/binutils/binutils-$(BINUTILS_VERSION).tar.xz
GCC_URL := https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/gcc-$(GCC_VERSION).tar.xz
GLIBC_URL := https://ftp.gnu.org/gnu/glibc/glibc-$(GLIBC_VERSION).tar.xz
LINUX_HEADERS_URL := https://www.kernel.org/pub/linux/kernel/v6.x/linux-$(LINUX_HEADERS_VERSION).tar.xz

# Build flags for reproducible builds
COMMON_CFLAGS := -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables -Os
COMMON_CXXFLAGS := -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables -Os
COMMON_LDFLAGS := -Wl,--build-id=sha1

# binutils configuration
BINUTILS_CONFIG := --disable-multilib --disable-werror --enable-shared --enable-static

# glibc configuration
GLIBC_CONFIG := --disable-multilib --enable-shared --enable-static --disable-werror

# GCC configuration
GCC_CONFIG := --enable-languages=c,c++
GCC_CONFIG += --disable-libssp
GCC_CONFIG += --disable-libgomp
GCC_CONFIG += --disable-libmudflap
GCC_CONFIG += --disable-libsanitizer
GCC_CONFIG += --disable-libatomic
GCC_CONFIG += --disable-libquadmath
GCC_CONFIG += --disable-multilib
GCC_CONFIG += --with-sysroot=$(OUTPUT_DIR)
GCC_CONFIG += --with-newlib
GCC_CONFIG += --disable-shared
GCC_CONFIG += --disable-threads
GCC_CONFIG += --disable-libstdcxx-pch

# Linux headers configuration
LINUX_HEADERS_CONFIG := --with-headers=$(LINUX_HEADERS_DIR)/usr/include

# Build environment
export ARCH
export TOOLCHAIN_TYPE
export TARGET
export CROSS_COMPILE
export OUTPUT_DIR
export BINUTILS_VERSION
export GCC_VERSION
export GLIBC_VERSION
export LINUX_HEADERS_VERSION
export BINUTILS_URL
export GCC_URL
export GLIBC_URL
export LINUX_HEADERS_URL
export COMMON_CFLAGS
export COMMON_CXXFLAGS
export COMMON_LDFLAGS
export BINUTILS_CONFIG
export GLIBC_CONFIG
export GCC_CONFIG
export LINUX_HEADERS_CONFIG
