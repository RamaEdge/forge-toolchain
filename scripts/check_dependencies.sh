#!/bin/bash
# ForgeOS Toolchain Dependencies Check Script
# Verifies that all required dependencies are available
# Usage: check_dependencies.sh [platform]

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

# Detect project root
detect_project_root

# Parameters
PLATFORM="${1:-$(uname -s | tr '[:upper:]' '[:lower:]')}"

# Check if a command exists
check_command() {
    local cmd="$1"
    local name="$2"
    local required="${3:-true}"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        local version=""
        case "$cmd" in
            "gcc"|"g++")
                version="$($cmd --version | head -n1 | cut -d' ' -f3)"
                ;;
            "make")
                version="$($cmd --version | head -n1 | cut -d' ' -f3)"
                ;;
            "curl")
                version="$($cmd --version | head -n1 | cut -d' ' -f2)"
                ;;
            "tar")
                version="$($cmd --version | head -n1 | cut -d' ' -f2)"
                ;;
            "bash")
                version="$($cmd --version | head -n1 | cut -d' ' -f4)"
                ;;
            *)
                version="available"
                ;;
        esac
        log_success "$name: $version"
        return 0
    else
        if [[ "$required" == "true" ]]; then
            log_error "$name: not found (required)"
            return 1
        else
            log_warning "$name: not found (optional)"
            return 0
        fi
    fi
}

# Check platform-specific dependencies
check_platform_dependencies() {
    case "$PLATFORM" in
        "linux")
            log_info "Checking Linux dependencies..."
            check_command "gcc" "GCC Compiler" true
            check_command "g++" "G++ Compiler" true
            check_command "make" "Make" true
            check_command "curl" "cURL" true
            check_command "tar" "Tar" true
            check_command "bash" "Bash" true
            check_command "nproc" "nproc" false
            check_command "ld" "Linker" true
            check_command "ar" "Archiver" true
            check_command "strip" "Strip" true
            check_command "ranlib" "Ranlib" true
            check_command "nm" "NM" true
            check_command "objcopy" "Objcopy" true
            check_command "objdump" "Objdump" true
            check_command "readelf" "Readelf" true
            ;;
        "darwin"|"macos")
            log_info "Checking macOS dependencies..."
            check_command "gcc" "GCC Compiler" true
            check_command "g++" "G++ Compiler" true
            check_command "gmake" "GNU Make" true
            check_command "make" "Make" false
            check_command "curl" "cURL" true
            check_command "tar" "Tar" true
            check_command "bash" "Bash" true
            check_command "sysctl" "sysctl" false
            check_command "ld" "Linker" true
            check_command "ar" "Archiver" true
            check_command "strip" "Strip" true
            check_command "ranlib" "Ranlib" true
            check_command "nm" "NM" true
            check_command "objcopy" "Objcopy" true
            check_command "objdump" "Objdump" true
            check_command "readelf" "Readelf" true
            ;;
        *)
            log_warning "Unknown platform: $PLATFORM"
            log_info "Checking generic dependencies..."
            check_command "gcc" "GCC Compiler" true
            check_command "g++" "G++ Compiler" true
            check_command "make" "Make" true
            check_command "curl" "cURL" true
            check_command "tar" "Tar" true
            check_command "bash" "Bash" true
            ;;
    esac
}

# Check system resources
check_system_resources() {
    log_info "Checking system resources..."
    
    # Check available memory
    case "$PLATFORM" in
        "linux")
            if command -v free >/dev/null 2>&1; then
                local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
                if [[ "$mem_gb" -ge 4 ]]; then
                    log_success "Memory: ${mem_gb}GB (recommended: 4GB+)"
                else
                    log_warning "Memory: ${mem_gb}GB (recommended: 4GB+)"
                fi
            else
                log_warning "Memory: unable to check (free command not found)"
            fi
            ;;
        "darwin"|"macos")
            if command -v sysctl >/dev/null 2>&1; then
                local mem_gb=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
                if [[ "$mem_gb" -ge 4 ]]; then
                    log_success "Memory: ${mem_gb}GB (recommended: 4GB+)"
                else
                    log_warning "Memory: ${mem_gb}GB (recommended: 4GB+)"
                fi
            else
                log_warning "Memory: unable to check (sysctl command not found)"
            fi
            ;;
        *)
            log_warning "Memory: unable to check (unknown platform)"
            ;;
    esac
    
    # Check available disk space
    local disk_space=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ "$disk_space" -ge 10 ]]; then
        log_success "Disk space: ${disk_space}GB (recommended: 10GB+)"
    else
        log_warning "Disk space: ${disk_space}GB (recommended: 10GB+)"
    fi
}

# Check network connectivity
check_network() {
    log_info "Checking network connectivity..."
    
    if curl -s --connect-timeout 10 "https://ftp.gnu.org" >/dev/null 2>&1; then
        log_success "Network: GNU FTP accessible"
    else
        log_warning "Network: GNU FTP not accessible (may affect downloads)"
    fi
    
    if curl -s --connect-timeout 10 "https://github.com" >/dev/null 2>&1; then
        log_success "Network: GitHub accessible"
    else
        log_warning "Network: GitHub not accessible (may affect downloads)"
    fi
}

# Main dependency check
main() {
    log_info "Checking dependencies for $PLATFORM platform..."
    echo ""
    
    local errors=0
    
    # Check platform-specific dependencies
    if ! check_platform_dependencies; then
        ((errors++))
    fi
    
    echo ""
    
    # Check system resources
    check_system_resources
    
    echo ""
    
    # Check network connectivity
    check_network
    
    echo ""
    
    if [[ $errors -eq 0 ]]; then
        log_success "All required dependencies are available"
        log_info "You can proceed with toolchain builds"
        exit 0
    else
        log_error "Some required dependencies are missing"
        log_info "Please install the missing dependencies and try again"
        exit 1
    fi
}

# Run main function
main "$@"
