# PVM - PHP Version Manager

PVM adalah tools sederhana untuk mengelola multiple versi PHP di Arch Linux dan turunannya (Manjaro, EndeavourOS, dll). Tools ini dibuat untuk memudahkan developer PHP dalam mengganti versi PHP sesuai kebutuhan project.

## Fitur

- 🚀 Instalasi PHP versi tertentu dengan satu perintah
- 🔄 Switch antar versi PHP dengan mudah
- 📦 Instalasi extensions PHP secara otomatis
- 🧹 Pembersihan cache untuk menghemat ruang disk
- ⚡ Optimasi instalasi dengan parallel processing
- 🔒 Manajemen sudo yang aman dan efisien

## Keunggulan

1. **Sederhana**: Perintah yang mudah diingat dan digunakan
2. **Otomatis**: Instalasi dependencies dan extensions secara otomatis
3. **Efisien**: Menggunakan parallel processing untuk mempercepat instalasi
4. **Aman**: Manajemen sudo yang terkontrol dan timestamp-based
5. **Terintegrasi**: Bekerja seamless dengan package manager sistem (yay/pacman)

## Keterbatasan

1. Hanya berjalan di Arch Linux dan turunannya
2. Membutuhkan yay sebagai AUR helper
3. Belum mendukung custom PHP extensions
4. Tidak bisa menginstall versi PHP yang tidak tersedia di repositori

## Persyaratan Sistem

- Arch Linux atau turunannya (Manjaro, EndeavourOS, dll)
- yay (AUR helper)
- sudo privileges

## Cara Instalasi

### Metode 1: Instalasi User-level

```bash
git clone https://github.com/NDP4/PVM.git
cd pvm
./install-pvm.sh
source ~/.bashrc
```

### Metode 2: Instalasi System-wide

```bash
git clone https://github.com/NDP4/PVM.git
cd pvm
sudo ./setup-pvm.sh
```

## Cara Uninstall PVM

### Metode 1: User-level Uninstall

```bash
# Hapus binary PVM
rm -f ~/bin/pvm

# Hapus direktori PVM
rm -rf ~/.pvm

# Hapus path dari .bashrc (opsional)
sed -i '/export PATH="$HOME\/bin:\$PATH"/d' ~/.bashrc

# Reload shell
source ~/.bashrc
```

### Metode 2: System-wide Uninstall

```bash
# Hapus binary PVM dari system
sudo rm -f /usr/local/bin/pvm

# Hapus direktori PVM untuk semua user
sudo rm -rf ~/.pvm

# Hapus symlink PHP jika ada
sudo rm -f /usr/bin/php
```

### Membersihkan PHP yang Terinstall

```bash
# Hapus semua versi PHP yang terinstall (opsional sesuaikan dengan versi yang pernah di install)
sudo pacman -Rs php php74 php80 php81 php82 php83
yay -Rs php74 php80 php81 php82 php83

# Bersihkan dependencies yang tidak digunakan
sudo pacman -Rns $(pacman -Qtdq)
```

## Penggunaan Dasar

```bash
# Install PHP versi tertentu
pvm install 82    # Install PHP 8.2
pvm install 74    # Install PHP 7.4

# Switch versi PHP
pvm use 82        # Switch ke PHP 8.2
pvm use 74        # Switch ke PHP 7.4

# Lihat versi PHP terinstall
pvm list

# Uninstall PHP
pvm uninstall 74  # Hapus PHP 7.4

# Bersihkan cache
pvm clean-cache
```

## Versi PHP yang Didukung

- PHP 7.4 (74)
- PHP 8.0 (80)
- PHP 8.1 (81)
- PHP 8.2 (82)
- PHP 8.3 (83)

## Extensions yang Diinstall Otomatis

- gd
- curl
- pdo
- mysql
- zip
- bcmath
- sqlite
- intl
- mbstring
- xml
- fileinfo
- tokenizer
- openssl
- ctype

## Extensions PHP

### Mode Instalasi Extensions

0. **No Extensions** - Install PHP tanpa extensions tambahan
1. **Default Extensions** - Menginstall semua extensions standar:
   - gd, curl, pdo, mysql, zip, bcmath, sqlite, intl, mbstring, xml, dll
2. **Custom Extensions** - Pilih extensions tambahan secara interaktif:
   - ImageMagick (imagick)
   - Redis (redis)
   - Memcached (memcached)
   - Xdebug (xdebug)
   - MongoDB (mongodb)
   - Swoole (swoole)
   - YAML (yaml)
   - gRPC (grpc)
   - Protocol Buffers (protobuf)

### Contoh Penggunaan

```bash
$ pvm install 82
=== PHP Extensions Installation ===
0) None  - Install PHP tanpa extensions
1) Default - Install semua extensions default
2) Custom - Pilih extensions tambahan
Pilihan [0/1/2]: 0
Melanjutkan tanpa install extensions...
```

## Konfigurasi Custom Extensions

Anda dapat menambahkan custom PHP extensions dengan mengedit file konfigurasi:

```bash
vim ~/.pvm/config/extensions.conf
```

### Contoh konfigurasi extensions:

```bash
# Default extensions tetap ada di atas
DEFAULT_EXTENSIONS=(
    # ...existing default extensions...
)

# Tambahkan custom extensions yang diinginkan
CUSTOM_EXTENSIONS=(
    "imagick"    # Image processing
    "redis"      # Redis support
    "xdebug"     # Debugging
    "memcached"  # Memcached support
)
```

Setelah mengedit konfigurasi, install ulang PHP untuk menerapkan extensions baru:

```bash
pvm install 82  # Ganti dengan versi yang diinginkan
```

## Metode Instalasi PHP

PVM menyediakan dua metode instalasi PHP:

1. **AUR (Arch User Repository)**
   - Menggunakan package yang tersedia di AUR
   - Lebih mudah dan terintegrasi dengan sistem
   - Instalasi bisa lebih lama karena proses build di AUR

2. **Source (Build from source)**
   - Download dan build dari sumber resmi PHP
   - Proses build lebih cepat (menggunakan semua core CPU)
   - Dapat dikustomisasi dengan flag compile tertentu
   - Terinstall di /opt/php[version]

### Contoh Penggunaan

```bash
$ pvm install 82
=== PHP Installation Method ===
1) AUR (Arch User Repository)
2) Source (Build from official source)
Choose installation method [1/2]: 2
Building PHP 8.2 from source...
```

### Perbandingan Metode Instalasi

| Fitur                  | AUR               | Source             |
|-----------------------|-------------------|-------------------|
| Kecepatan Install     | Lebih lambat     | Lebih cepat      |
| Integrasi Sistem      | Lebih baik       | Manual           |
| Kustomisasi           | Terbatas         | Fleksibel        |
| Maintenance           | Otomatis (pacman) | Manual           |
| Resource CPU          | Minimal          | Tinggi (saat build) |

## Troubleshooting

### 1. PHP tidak terinstall dengan benar

```bash
# Reset PVM dan coba install ulang
pvm clean-cache
pvm install 82
```

### 2. Masalah dengan sudo timestamp

```bash
# Reset sudo timestamp dan coba lagi
sudo -k
pvm install 82
```

### 3. Extensions tidak terinstall

```bash
# Cek extensions yang terinstall
php -m

# Jika ada yang kurang, coba install ulang
pvm install 82
```

## Tips Penggunaan

1. **Bersihkan Cache Secara Berkala**

   ```bash
   pvm clean-cache
   ```

2. **Switch PHP Sebelum Memulai Project**

   ```bash
   pvm use 82
   composer create-project
   ```

3. **Verifikasi Instalasi**
   ```bash
   php -v
   php -m
   ```

## Struktur Direktori

```
~/.pvm/
├── cache/         # Cache directory
├── current        # File penanda versi aktif
└── config/        # Konfigurasi tambahan
```

## Kontribusi

Silakan buat issue atau pull request jika Anda menemukan bug atau ingin menambahkan fitur baru.

## Lisensi

MIT License - Silakan gunakan dan modifikasi sesuai kebutuhan.
