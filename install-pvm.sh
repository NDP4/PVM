#!/bin/bash

# Buat direktori untuk binary user
mkdir -p "$HOME/bin"

# Copy PVM script ke bin directory
cp pvm.sh "$HOME/bin/pvm"
chmod +x "$HOME/bin/pvm"

# Tambahkan PATH ke .bashrc jika belum ada
if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
fi

# Buat direktori PVM
mkdir -p "$HOME/.pvm"

echo "PVM telah diinstall!"
echo "Silakan jalankan: source ~/.bashrc"
echo "Atau logout dan login kembali untuk menggunakan PVM"
