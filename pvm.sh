#!/usr/bin/env bash

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

    # Setup extensions config
    load_extensions_config

    # Add support for Zsh
    if [ -n "$ZSH_VERSION" ]; then
        autoload -U +X bashcompinit && bashcompinit
    fi
}

# Enhanced PHP detection function
detect_installed_php() {
    local versions=()
    
    # Check AUR installed versions
    for php in $(pacman -Qq | grep '^php[0-9][0-9]$' 2>/dev/null); do
        if [[ $php =~ php([0-9][0-9]) ]]; then
            versions+=("${BASH_REMATCH[1]}")
        fi
    done
    
    # Check source installed versions
    for php_dir in /opt/php??; do
        if [[ -x "$php_dir/bin/php" && $php_dir =~ php([0-9][0-9])$ ]]; then
            versions+=("${BASH_REMATCH[1]}")
        fi
    done
    
    # Remove duplicates and sort
    printf "%s\n" "${versions[@]}" | sort -u
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

# Download and build PHP from source
build_php_from_source() {
    local version=$1
    local major_version="${version:0:1}.${version:1:1}"
    local build_dir="$PVM_CACHE_DIR/php-$major_version"
    local thread_count=$(nproc)
    
    echo "Building PHP $major_version from source..."
    
    # Install build dependencies
    echo "Installing build dependencies..."
    sudo pacman -S --needed --noconfirm \
        base-devel libxml2 libzip oniguruma libxslt libpng \
        libjpeg-turbo aspell enchant libmcrypt libtool pcre2 bzip2 \
        gmp tidyhtml openssl-1.1 sqlite autoconf automake curl re2c bison \
        libxslt icu gcc make pkg-config argon2 libsodium zlib

    # Version-specific configurations
    local extra_cflags=""
    if [[ "${version:0:1}" -ge "8" && "${version:1:1}" -ge "2" ]]; then
        # PHP 8.2+ needs special flags for atomic operations
        extra_cflags="-DUSE_GCC_ATOMIC_BUILTINS -std=gnu11"
    fi

    # Create build directory
    rm -rf "$build_dir"
    mkdir -p "$build_dir/patches"
    cd "$build_dir" || return 1

    # Determine latest patch version based on major version
    local latest_version
    case "$major_version" in
        "7.4")
            latest_version="33"
            ;;
        "8.0")
            latest_version="30"
            ;;
        "8.1")
            latest_version="27"
            ;;
        "8.2")
            latest_version="15"
            ;;
        "8.3")
            latest_version="1"
            ;;
        *)
            echo "Unsupported PHP version: $major_version"
            return 1
            ;;
    esac

    # Download source with correct version number
    echo "Downloading PHP ${major_version}.${latest_version}..."
    wget "https://www.php.net/distributions/php-${major_version}.${latest_version}.tar.xz" || return 1
    tar xf "php-${major_version}.${latest_version}.tar.xz" || return 1
    cd "php-${major_version}.${latest_version}" || return 1

    # Create patches
    echo "Creating patches..."
    cat > patches/001-libxml.patch << 'EOL'
diff --git a/ext/libxml/libxml.c b/ext/libxml/libxml.c
index 93c21a3..a806153 100644
--- a/ext/libxml/libxml.c
+++ b/ext/libxml/libxml.c
@@ -826,7 +826,9 @@ PHP_MSHUTDOWN_FUNCTION(libxml)
 #ifdef HAVE_TIDYLIB
                 tidySetLanguage(NULL);
 #endif
+#if !defined(LIBXML_VERSION) || LIBXML_VERSION < 20900
                 xmlRelaxNGCleanupTypes();
+#endif
                 xmlCleanupParser();
                 xmlCleanupThreads();
         }
@@ -1032,7 +1034,7 @@ PHP_FUNCTION(libxml_use_internal_errors)
                xmlSetStructuredErrorFunc(NULL, NULL);
                handler = NULL;
             } else {
-                xmlSetStructuredErrorFunc(NULL, php_libxml_structured_error_handler);
+                xmlSetStructuredErrorFunc(NULL, (xmlStructuredErrorFunc) php_libxml_structured_error_handler);
                handler = php_libxml_structured_error_handler;
             }
             current_handler = handler;
EOL

    # Apply patches
    echo "Applying patches..."
    patch -p1 < patches/001-libxml.patch || {
        echo "Warning: libxml patch application failed, continuing anyway..."
    }

    # Directly edit zend_atomic.h for PHP 8.2+
    if [[ "${version:0:1}" -ge "8" && "${version:1:1}" -ge "2" ]]; then
        echo "Modifying zend_atomic.h for PHP 8.2+..."
        sed -i 's/__c11_atomic_exchange/__atomic_exchange_n/g' Zend/zend_atomic.h
        sed -i 's/__c11_atomic_load/__atomic_load_n/g' Zend/zend_atomic.h
        sed -i 's/__c11_atomic_store/__atomic_store_n/g' Zend/zend_atomic.h
        sed -i 's/__c11_atomic_init(/__atomic_store_n(/g' Zend/zend_atomic.h
        sed -i 's/ZEND_ATOMIC_BOOL_INIT(obj, desired) __atomic_store_n(&(obj)->value, (desired))/ZEND_ATOMIC_BOOL_INIT(obj, desired) __atomic_store_n(\&(obj)->value, (desired), __ATOMIC_RELAXED)/' Zend/zend_atomic.h
    fi

    # Configure build with specific settings for PHP 7.4
    echo "Configuring build..."
    PKG_CONFIG_PATH="/usr/lib/openssl-1.1/pkgconfig" \
    ./configure \
        --prefix="/opt/php$version" \
        --with-config-file-path="/opt/php$version/etc" \
        --with-config-file-scan-dir="/opt/php$version/etc/conf.d" \
        --enable-bcmath \
        --enable-fpm \
        --enable-mbstring \
        --enable-mysqlnd \
        --enable-opcache \
        --enable-pcntl \
        --enable-sockets \
        --with-curl \
        --with-openssl=/usr/lib/openssl-1.1 \
        --with-openssl-dir=/usr/lib/openssl-1.1 \
        --with-pdo-mysql \
        --with-pdo-sqlite \
        --with-sqlite3 \
        --with-zlib \
        --with-zip \
        --without-libxml \
        --disable-dom \
        --disable-xml \
        --disable-xmlreader \
        --disable-xmlwriter \
        --disable-simplexml \
        --with-sodium \
        || {
            echo "Configure failed"
            cat config.log
            return 1
        }

    # Build using all cores
    echo "Building PHP (using $thread_count threads)..."
    MAKE_OPTS="-j$thread_count" make || {
        echo "Make failed"
        return 1
    }

    # Install
    echo "Installing PHP..."
    sudo make install || {
        echo "Make install failed"
        return 1
    }

    # Create configuration directories
    sudo mkdir -p "/opt/php$version/etc/conf.d"
    sudo cp php.ini-production "/opt/php$version/etc/php.ini"

    # Create PHP-FPM configuration
    sudo mkdir -p "/opt/php$version/etc/php-fpm.d"
    sudo cp sapi/fpm/php-fpm.conf.in "/opt/php$version/etc/php-fpm.conf"
    sudo cp sapi/fpm/www.conf.in "/opt/php$version/etc/php-fpm.d/www.conf"

    # Create symlinks
    sudo ln -sf "/opt/php$version/bin/php" "/usr/bin/php$version"
    sudo ln -sf "/opt/php$version/sbin/php-fpm" "/usr/bin/php$version-fpm"

    # Create systemd service
    create_phpfpm_service "$version"

    echo "PHP $version built and installed successfully from source"
    return 0
}

# Create PHP-FPM systemd service
create_phpfpm_service() {
    local version=$1
    local service_file="/etc/systemd/system/php${version}-fpm.service"

    echo "Creating PHP-FPM service..."
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=PHP ${version:0:1}.${version:1:1} FastCGI Process Manager
After=network.target

[Service]
Type=notify
ExecStart=/opt/php${version}/sbin/php-fpm --nodaemonize
ExecReload=/bin/kill -USR2 \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "php${version}-fpm"
}

# Install PHP versi tertentu dengan optimasi
install_php() {
    local version=$1
    if [ -z "$version" ]; then
        echo "Please specify PHP version (e.g., pvm install 74)"
        return 1
    fi

    # Check if already installed
    if get_php_binary "$version" > /dev/null; then
        echo "PHP $version is already installed"
        read -p "Would you like to switch to it? [Y/n] " -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            use_php "$version"
        fi
        return 0
    fi

    echo "=== PHP Installation Method ==="
    echo "1) AUR (Arch User Repository)"
    echo "2) Source (Build from official source)"
    read -p "Choose installation method [1/2]: " -r install_method

    local install_success=0

    case "$install_method" in
        "1")
            install_php_from_aur "$version" && install_success=1
            ;;
        "2")
            build_php_from_source "$version" && install_success=1
            ;;
        *)
            echo "Invalid choice."
            return 1
            ;;
    esac

    # Only proceed with extensions and switching if installation was successful
    if [ $install_success -eq 1 ]; then
        # Ask for extensions only if using AUR method
        if [ "$install_method" = "1" ]; then
            echo "=== PHP Extensions ==="
            read -p "Do you want to install PHP extensions? [y/N]: " -r install_extensions
            if [[ "$install_extensions" =~ ^[Yy]$ ]]; then
                install_extensions_parallel "$version"
            fi
        fi

        # Switch to newly installed version
        use_php "$version"
    else
        echo "Installation failed."
        return 1
    fi
}

# Rename existing install function
install_php_from_aur() {
    local version=$1
    
    echo "Installing PHP $version from AUR..."
    
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

    # Install extensions if wanted
    echo "=== PHP Extensions ==="
    read -p "Do you want to install PHP extensions? [y/N]: " -r install_extensions
    if [[ "$install_extensions" =~ ^[Yy]$ ]]; then
        install_extensions_parallel "$version"
    else
        echo "Skipping extensions installation..."
    fi

    return 0
}

# Load extensions configuration
load_extensions_config() {
    local config_file="$PVM_DIR/config/extensions.conf"
    local default_config="${0%/*}/config/extensions.conf"
    
    # Create config directory if not exists
    mkdir -p "$PVM_DIR/config"
    
    # Copy default config if not exists
    if [ ! -f "$config_file" ]; then
        if [ -f "$default_config" ]; then
            cp "$default_config" "$config_file"
        else
            # Create default config if source not found
            cat > "$config_file" << 'EOL'
# Default PHP extensions
DEFAULT_EXTENSIONS=(
    "gd" "curl" "pdo" "mysql" "zip"
    "bcmath" "sqlite" "intl" "mbstring" "xml"
    "fileinfo" "tokenizer" "openssl" "ctype"
)
EOL
        fi
    fi
    
    source "$config_file"
}

# Array untuk available custom extensions
AVAILABLE_CUSTOM_EXTENSIONS=(
    "imagick:ImageMagick PHP extension"
    "redis:Redis support"
    "memcached:Memcached support"
    "xdebug:Debugging tools"
    "mongodb:MongoDB driver"
    "swoole:Async PHP framework"
    "yaml:YAML parser and emitter"
    "grpc:gRPC PHP extension"
    "protobuf:Protocol buffers support"
)

# Fungsi untuk memilih custom extensions
select_custom_extensions() {
    local version=$1
    local selected_extensions=()
    
    while true; do
        clear
        echo "=== Custom PHP Extensions ==="
        echo "Pilih extensions yang ingin diinstall (pisahkan dengan spasi, contoh: 1 3 5)"
        echo "0) Selesai dan lanjutkan instalasi"
        echo "-----------------------------------------"
        
        # Tampilkan daftar extensions
        local i=1
        for ext in "${AVAILABLE_CUSTOM_EXTENSIONS[@]}"; do
            IFS=':' read -r name desc <<< "$ext"
            printf "%2d) %-15s - %s\n" $i "$name" "$desc"
            ((i++))
        done
        echo "-----------------------------------------"
        
        read -p "Pilihan (0 untuk selesai): " -r choices
        
        # Keluar jika pilihan 0
        if [[ "$choices" == "0" ]]; then
            break
        fi
        
        # Reset selected_extensions
        selected_extensions=()
        
        # Proses pilihan
        for choice in $choices; do
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#AVAILABLE_CUSTOM_EXTENSIONS[@]}" ]; then
                local ext_name="${AVAILABLE_CUSTOM_EXTENSIONS[$((choice-1))]%%:*}"
                selected_extensions+=("$ext_name")
            fi
        done
        
        if [ ${#selected_extensions[@]} -gt 0 ]; then
            echo "Extensions yang dipilih:"
            printf '%s\n' "${selected_extensions[@]}"
            read -p "Konfirmasi pilihan? [Y/n] " -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]] || [[ -z "$confirm" ]]; then
                break
            fi
        fi
    done
    
    if [ ${#selected_extensions[@]} -gt 0 ]; then
        echo "Extensions yang akan diinstall:"
        printf '%s\n' "${selected_extensions[@]}"
        echo
    else
        echo "Tidak ada extensions yang dipilih"
    fi
    
    printf "%s " "${selected_extensions[@]}"
}

# Modifikasi fungsi install_extensions_parallel
install_extensions_parallel() {
    local version=$1
    
    clear
    echo "=== PHP Extensions Installation ==="
    echo "0) None  - Install PHP tanpa extensions"
    echo "1) Default - Install semua extensions default"
    echo "2) Custom - Pilih extensions tambahan"
    read -p "Pilihan [0/1/2]: " -r choice
    
    case "$choice" in
        "0")
            echo "Melanjutkan tanpa install extensions..."
            return 0
            ;;
        "1")
            echo "Installing default extensions..."
            for ext in "${DEFAULT_EXTENSIONS[@]}"; do
                echo "Installing php$version-$ext..."
                verify_package "php$version-$ext" || echo "Warning: Failed to install php$version-$ext"
            done
            ;;
        "2")
            echo "Installing default extensions..."
            for ext in "${DEFAULT_EXTENSIONS[@]}"; do
                echo "Installing php$version-$ext..."
                verify_package "php$version-$ext" || echo "Warning: Failed to install php$version-$ext"
            done
            
            local custom_exts=$(select_custom_extensions "$version")
            if [ -n "$custom_exts" ]; then
                echo "Installing custom extensions..."
                for ext in $custom_exts; do
                    if [ -n "$ext" ]; then
                        echo "Installing php$version-$ext..."
                        verify_package "php$version-$ext" || echo "Warning: Failed to install php$version-$ext"
                    fi
                done
            fi
            ;;
        *)
            echo "Pilihan tidak valid, melanjutkan tanpa install extensions..."
            return 0
            ;;
    esac
}

# Enhanced get_php_binary function
get_php_binary() {
    local version=$1
    local paths=(
        # Source installation paths
        "/opt/php${version}/bin/php"
        # AUR installation paths
        "/usr/bin/php${version}"
        "/usr/bin/php${version}-cli"
        # Other possible paths
        "/usr/local/bin/php${version}"
        "$(/usr/bin/php-config${version} --php-binary 2>/dev/null)"
    )
    
    # Check each path
    for path in "${paths[@]}"; do
        if [ -x "$path" ] && "$path" --version 2>/dev/null | grep -q "^PHP ${version:0:1}\.${version:1:1}"; then
            echo "$path"
            return 0
        fi
    done
    
    # No valid PHP binary found
    return 1
}

# Switch PHP version
use_php() {
    local version=$1
    if [ -z "$version" ]; then
        echo "Please specify PHP version to use"
        return 1
    fi

    # Check if PHP is installed
    local php_binary
    php_binary=$(get_php_binary "$version")
    
    if [ -z "$php_binary" ]; then
        echo "PHP $version is not installed. Please install it first."
        return 1
    fi

    echo "Switching to PHP $version..."
    echo "Found PHP binary: $php_binary"

    # Update system PHP symlink
    sudo ln -sf "$php_binary" /usr/bin/php
    echo "$version" > "$CURRENT_VERSION_FILE"

    # Verify switch
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

uninstall_php() {
    local version=$1
    if [ -z "$version" ]; then
        echo "Please specify PHP version to uninstall"
        return 1
    fi

    echo "Uninstalling PHP $version..."
    
    # Check installation type
    local is_source=0
    local is_aur=0
    
    if [ -d "/opt/php${version}" ]; then
        is_source=1
    fi
    
    if pacman -Qq | grep -q "^php${version}\$"; then
        is_aur=1
    fi
    
    if [ $is_source -eq 0 ] && [ $is_aur -eq 0 ]; then
        echo "PHP $version is not installed"
        return 1
    fi

    # Source uninstallation
    if [ $is_source -eq 1 ]; then
        echo "Removing source installation..."
        sudo systemctl stop "php${version}-fpm" 2>/dev/null
        sudo systemctl disable "php${version}-fpm" 2>/dev/null
        sudo rm -f "/etc/systemd/system/php${version}-fpm.service"
        sudo systemctl daemon-reload
        sudo rm -f "/usr/bin/php${version}"
        sudo rm -f "/usr/bin/php${version}-fpm"
        sudo rm -rf "/opt/php${version}"
    fi

    # AUR uninstallation
    if [ $is_ur -eq 1 ]; then
        echo "Removing AUR packages..."
        local php_packages=($(pacman -Qq | grep "php${version}"))
        if [ ${#php_packages[@]} -gt 0 ]; then
            echo "Removing packages: ${php_packages[*]}"
            sudo pacman -Rdd "${php_packages[@]}" --noconfirm
            sudo pacman -Rns $(pacman -Qtdq) --noconfirm 2>/dev/null || true
        fi
    fi

    # Cleanup
    sudo rm -rf "/etc/php${version}" 2>/dev/null || true
    
    if [ -f "$CURRENT_VERSION_FILE" ]; then
        if [ "$(cat "$CURRENT_VERSION_FILE")" = "$version" ]; then
            rm -f "$CURRENT_VERSION_FILE"
        fi
    fi

    echo "PHP $version has been completely uninstalled"
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
