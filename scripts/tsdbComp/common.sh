#!/bin/bash

# Check if command exists and install it if not
function cmdInstall {
    local comd=$1
    if command -v ${comd} &> /dev/null; then
        log_info "${comd} is already installed"
    else
        if command -v apt &> /dev/null; then
            log_info "Installing ${comd} using apt"
            if apt-get install ${comd} -y 2>> ${error_install_file}; then
                log_info "${comd} installed successfully"
            else
                log_error "Failed to install ${comd} using apt"
            fi
        elif command -v yum &> /dev/null; then
            log_info "Installing ${comd} using yum"
            if yum install ${comd} -y 2>> ${error_install_file}; then
                log_info "${comd} installed successfully"
            else
                log_error "Failed to install ${comd} using yum"
            fi
        else
            log_warning "You should install ${comd} manually"
        fi
    fi
}

# Check if pip3 package exists and install it if not
# Check if pip3 packages exist and install them if not
function pip3_define_install {
    for comd in "$@"; do
        if pip3 show ${comd} &> /dev/null; then
            log_info "${comd} is already installed"
        else
            log_info "Installing ${comd} using pip3"
            if pip3 install ${comd} 2>> ${error_install_file}; then
                log_info "${comd} installed successfully"
            else
                log_error "Failed to install ${comd} using pip3"
            fi
        fi
    done
}

# Detect system type and version
function checkout_system {
    log_info "Detecting server version and hardware configuration..."

    # Detect system type
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION_ID=$VERSION_ID
        log_debug "Detected OS: $OS, Version: $VERSION_ID"
    else
        log_error "Unable to detect system type."
        exit 1
    fi

    # List of supported versions
    supported_versions=("Ubuntu 18.04" "Ubuntu 20.04" "Ubuntu 22.04")

    # Check if the current version is supported
    is_supported=false
    for version in "${supported_versions[@]}"; do
        if [[ "$OS $VERSION_ID" == "$version" ]]; then
            is_supported=true
            break
        fi
    done

    if [ "$is_supported" = false ]; then
        log_error "Unsupported system version. Current version: $OS $VERSION_ID"
        log_info "Supported versions: ${supported_versions[*]}"
        exit 1
    fi

    log_info "Detected system version: $OS $VERSION_ID"

    # Detect number of CPU cores
    cpu_cores=$(nproc)
    log_info "Number of CPU cores: $cpu_cores"

    # Detect memory size
    memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    memory_kb=$memory
    memory_mb=$((memory_kb / 1024))
    memory_gb=$(echo "scale=0; (${memory_mb} / 1024) + (${memory_mb} % 1024 > 0)" | bc)

    log_info "Memory size: $memory_gb GB"

    # Minimum hardware requirements
    min_cpu_cores=4
    min_memory_gb=8

    # Check if the minimum hardware requirements are met
    if [ "${cpu_cores}" -lt "${min_cpu_cores}" ] || [ "${memory_gb}" -lt "${min_memory_gb}" ]; then
        log_error "Server hardware configuration does not meet the minimum requirements."
        log_info "Minimum requirements: ${min_cpu_cores} CPU cores and ${min_memory_gb} GB memory"
        exit 1
    fi

    log_info "Server hardware configuration meets the minimum requirements."
    log_info "Detection completed, everything is normal."
}