#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up dotfiles..."

create_symlink() {
    local source="$1"
    local target="$2"

    echo "Creating symlink: $target -> $source"
    ln -sf "$source" "$target"
}

# .gitconfig
create_symlink "$SCRIPT_DIR/shared/.gitconfig" "$HOME/.gitconfig"
create_symlink "$SCRIPT_DIR/shared/.mcp.json" "$HOME/.mcp.json"

echo "Dotfiles setup complete!"