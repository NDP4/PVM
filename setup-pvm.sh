#!/bin/bash

echo "Installing PVM to system..."

# Copy ke /usr/local/bin untuk akses sistem
sudo cp pvm.sh /usr/local/bin/pvm
sudo chmod +x /usr/local/bin/pvm

# Buat direktori PVM
mkdir -p "$HOME/.pvm"

# Test instalasi
which pvm

if [ $? -eq 0 ]; then
    echo "PVM berhasil diinstall!"
    echo "Coba jalankan: pvm list"
else
    echo "Instalasi gagal!"
fi
