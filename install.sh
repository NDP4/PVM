#!/bin/bash

PVM_DIR="$HOME/.pvm"

pvm_source() {
    local PVM_GITHUB_REPO
    PVM_GITHUB_REPO="${PVM_INSTALL_GITHUB_REPO:-NDP4/PVM}"
    if [ "${PVM_GITHUB_REPO}" != 'NDP4/PVM' ]; then
        { echo >&2 "$(cat)" ; } << EOF
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE REPO IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!

The default repository for this install is \`NDP4/PVM\`,
but the environment variables \`\$PVM_INSTALL_GITHUB_REPO\` is
currently set to \`${PVM_GITHUB_REPO}\`.

If this is not intentional, interrupt this installation and
verify your environment variables.
EOF
    fi

    local PVM_VERSION
    PVM_VERSION="${PVM_INSTALL_VERSION:-main}"
    local PVM_METHOD
    PVM_METHOD="$1"
    local PVM_SOURCE_URL

    if [ "_$PVM_METHOD" = "_script" ]; then
        PVM_SOURCE_URL="https://raw.githubusercontent.com/${PVM_GITHUB_REPO}/${PVM_VERSION}/pvm.sh"
    elif [ "_$PVM_METHOD" = "_git" ] || [ -z "$PVM_METHOD" ]; then
        PVM_SOURCE_URL="https://github.com/${PVM_GITHUB_REPO}.git"
    else
        echo >&2 "Unexpected value \"$PVM_METHOD\" for \$PVM_METHOD"
        return 1
    fi

    echo "$PVM_SOURCE_URL"
}

# Download and install PVM
install_pvm() {
    # Create PVM directory
    mkdir -p "$PVM_DIR"

    # Get the source URL
    local SOURCE_URL
    SOURCE_URL=$(pvm_source "script")

    # Download PVM script
    curl -o "$PVM_DIR/pvm" "$SOURCE_URL"

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
