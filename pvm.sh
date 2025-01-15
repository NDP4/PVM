#!/bin/bash

# Konfigurasi
PVM_DIR="$HOME/.pvm"
PVM_CACHE_DIR="$PVM_DIR/cache"
CURRENT_VERSION_FILE="$PVM_DIR/current"
SUDO_TIMESTAMP_FILE="/tmp/pvm-sudo-timestamp"
YAY_FLAGS="--noconfirm --needed --noprogressbar --norebuild"

# Inisialisasi sudo sekali di awal
init_sudo() {
    if [ ! -f "$SUDO_TIMESTAMP_FILE" ] || [ $(( $(date +%s) - $(stat -c %Y "$SUDO_TIMESTAMP_FILE") )) -gt 3600 ]; then
        echo "Meminta akses sudo (akan berlaku selama 1 jam)..."
        sudo -v
        sudo touch "$SUDO_TIMESTAMP_FILE"
    fi
}

# Extend fungsi init_pvm
init_pvm() {
    if [ ! -d "$PVM_DIR" ]; then
        mkdir -p "$PVM_DIR"
        mkdir -p "$PVM_CACHE_DIR"
        echo "PVM initialized at $PVM_DIR"
    fi

    # Set yay config untuk non-interaktif
    echo "Configuring yay for non-interactive use..."
    yay --save --answerdiff None --answerclean None --answeredit None --answerupgrade None --noconfirm

    # Save yay config sekali saja jika belum ada
    if [ ! -f "$HOME/.config/yay/config.json" ]; then
        mkdir -p "$HOME/.config/yay"
        echo '{
            "answerdiff": "None",
            "answerclean": "None",
            "answeredit": "None",
            "answerupgrade": "None",
            "noconfirm": true,
            "combinedupgrade": true,
            "sudoloop": true
        }' > "$HOME/.config/yay/config.json"
    fi

    # Pre-cache sudo
    init_sudo
}

# Deteksi versi PHP yang terinstall di sistem
detect_installed_php() {
    # Cek dari binary yang ada
    for php in /usr/bin/php*[0-9]*; do
        if [[ -f "$php" && "$php" =~ php([0-9]+) ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done | sort -u
}

# Fungsi untuk install package secara parallel
install_package() {
    local pkg=$1
    if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
        yay -S $YAY_FLAGS "$pkg" >/dev/null 2>&1 &
    fi
}

# Fungsi untuk memverifikasi package terinstall
verify_package() {
    local pkg=$1
    local max_attempts=3
    local attempt=1

    echo "Installing $pkg..."
    while [ $attempt -le $max_attempts ]; do
        if yay -S --noconfirm --needed "$pkg"; then
            return 0
        fi
        echo "Attempt $attempt failed, retrying..."
        attempt=$((attempt + 1))
        sleep 1
    done
    return 1
}

# Install PHP versi tertentu dengan optimasi
install_php() {
    local version=$1
    if [ -z "$version" ]; then
        echo "Please specify PHP version (e.g., pvm install 74)"
        return 1
    fi

    echo "Installing PHP $version..."
    
    # Install base packages
    local base_packages=(
        "php${version}-cli"
        "php${version}"
        "php${version}-fpm"
    )

    for pkg in "${base_packages[@]}"; do
        echo "Installing base package: $pkg"
        if ! verify_package "$pkg"; then
            echo "Failed to install $pkg"
            return 1
        fi
    done

    # Verify CLI binary exists and is executable
    local cli_paths=(
        "/usr/bin/php${version}"
        "/usr/bin/php${version}-cli"
        "/usr/local/bin/php${version}"
    )

    local cli_found=0
    for cli_path in "${cli_paths[@]}"; do
        if [ -x "$cli_path" ]; then
            cli_found=1
            echo "Found PHP CLI at: $cli_path"
            break
        fi
    done

    if [ $cli_found -eq 0 ]; then
        echo "PHP CLI binary not found in expected locations"
        echo "Available PHP files:"
        ls -l /usr/bin/php* || true
        return 1
    fi

    # Install extensions
    echo "Installing PHP extensions..."
    install_extensions_parallel "$version"

    # Create symlinks and switch version
    echo "Setting up PHP $version..."
    if use_php "$version"; then
        echo "PHP $version installed and configured successfully"
        php -v
        return 0
    else
        echo "Failed to configure PHP $version"
        return 1
    fi
}

# Install extensions secara parallel
install_extensions_parallel() {
    local version=$1
    local extensions=(
        "gd" "curl" "pdo" "mysql" "zip"
        "bcmath" "sqlite" "intl" "mbstring" "xml"
        "fileinfo" "tokenizer" "openssl" "ctype"
    )
    
    echo "Installing extensions for PHP $version..."
    
    # Install extensions satu per satu untuk stabilitas
    for ext in "${extensions[@]}"; do
        echo "Installing php$version-$ext..."
        verify_package "php$version-$ext"
    done
}

# Get PHP binary path with better detection
get_php_binary() {
    local version=$1
    local paths=(
        "/usr/bin/php${version}"
        "/usr/bin/php${version}-cli"
        "/usr/local/bin/php${version}"
        "$(/usr/bin/php-config${version} --php-binary 2>/dev/null)"
    )
    
    for path in "${paths[@]}"; do
        if [ -x "$path" ] && "$path" --version 2>/dev/null | grep -q "^PHP"; then
            echo "$path"
            return 0
        fi
    done

    # Fallback: try to find any PHP binary for this version
    for binary in /usr/bin/php*${version}*; do
        if [ -x "$binary" ] && "$binary" --version 2>/dev/null | grep -q "^PHP"; then
            echo "$binary"
            return 0
        fi
    done

    return 1
}

# Switch PHP version
use_php() {
    local version=$1
    if [ -z "$version" ]; then
        echo "Please specify PHP version to use"
        return 1
    fi

    # Debug info
    echo "Checking PHP $version installation..."
    
    # Verify PHP CLI package is installed
    if ! pacman -Qi "php${version}" >/dev/null 2>&1; then
        echo "PHP $version is not installed. Installing..."
        if ! verify_package "php${version}"; then
            echo "Failed to install PHP $version"
            return 1
        fi
    fi
    
    # Get PHP binary path
    local php_binary=$(get_php_binary "$version")
    echo "Found PHP binary: $php_binary"

    if [ -z "$php_binary" ]; then
        echo "PHP $version CLI binary not found"
        return 1
    fi

    # Update system PHP symlink
    echo "Creating symlink from $php_binary to /usr/bin/php"
    sudo ln -sf "$php_binary" /usr/bin/php
    echo "$version" > "$CURRENT_VERSION_FILE"

    # Verify installation
    if php -v | grep -q "PHP ${version:0:1}\.${version:1:1}"; then
        echo "Successfully switched to PHP $version"
        php -v
        return 0
    else
        echo "Failed to switch PHP version"
        return 1
    fi
}

# List semua versi PHP yang terinstall
list_versions() {
    echo "Installed PHP versions:"
    current_version=$(cat "$CURRENT_VERSION_FILE" 2>/dev/null)
    
    if ! detected_versions=$(detect_installed_php); then
        echo "No PHP versions detected"
        return 1
    fi

    for version in $detected_versions; do
        if [ "$version" = "$current_version" ]; then
            echo "* $version (current)"
        else
            echo "  $version"
        fi
    done
}

# Uninstall versi PHP
uninstall_php() {
    local version=$1
    if [ -z "$version" ]; then
        echo "Please specify PHP version to uninstall"
        return 1
    fi

    yay -R "php$version" "php$version-fpm"
    rm -f "$PVM_DIR/php$version"
    echo "PHP $version uninstalled"
}

# Main command handler
init_pvm

case "$1" in
    "install")
        time {
            install_php "$2"
            echo "Total installation time:"
        }
        ;;
    "use")
        use_php "$2"
        ;;
    "list")
        list_versions
        ;;
    "uninstall")
        uninstall_php "$2"
        ;;
    "clean-cache")
        echo "Cleaning PVM cache..."
        rm -rf "$PVM_CACHE_DIR"/*
        yay -Scc --noconfirm
        echo "Cache cleaned"
        ;;
    *)
        echo "PVM - PHP Version Manager"
        echo "Usage:"
        echo "  pvm install <version>  : Install PHP version"
        echo "  pvm use <version>      : Switch PHP version"
        echo "  pvm list              : List installed versions"
        echo "  pvm uninstall <version>: Uninstall PHP version"
        echo "  pvm clean-cache       : Clean package cache"
        ;;
esac
