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

    # Add PVM to PATH for both Bash and Zsh
    add_to_shell_config "$HOME/.bashrc"
    add_to_shell_config "$HOME/.zshrc"

    echo "PVM has been installed successfully!"
    echo "Please restart your terminal or run 'source ~/.bashrc' (for Bash) or 'source ~/.zshrc' (for Zsh) to start using PVM."
}

# Function to add PVM to shell configuration
add_to_shell_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        if ! grep -q 'export PATH="$HOME/.pvm:$PATH"' "$config_file"; then
            echo 'export PATH="$HOME/.pvm:$PATH"' >> "$config_file"
            echo "PVM added to $config_file"
        fi
    else
        echo 'export PATH="$HOME/.pvm:$PATH"' > "$config_file"
        echo "Created $config_file with PVM configuration"
    fi
}

# Run the installation
install_pvm
