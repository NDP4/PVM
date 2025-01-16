#!/bin/bash

PVM_DIR="$HOME/.pvm"

# Download and install PVM
install_pvm() {
    # Create PVM directory
    mkdir -p "$PVM_DIR"

    # Copy PVM script
    cp pvm.sh "$PVM_DIR/pvm"

    # Make PVM executable
    chmod +x "$PVM_DIR/pvm"

    # Create symlink
    sudo ln -sf "$PVM_DIR/pvm" /usr/local/bin/pvm

    # Add PVM to PATH if not already present
    if ! grep -q 'export PATH="$HOME/.pvm:$PATH"' "$HOME/.bashrc"; then
        echo 'export PATH="$HOME/.pvm:$PATH"' >> "$HOME/.bashrc"
    fi

    echo "PVM has been installed successfully!"
    echo "Please restart your terminal or run 'source ~/.bashrc' to start using PVM."
}

# Run the installation
install_pvm
