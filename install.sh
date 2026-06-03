#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up dotfiles..."

create_symlink() {
    local source="$1"
    local target="$2"

    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$target")"

    echo "Creating symlink: $target -> $source"
    ln -sf "$source" "$target"
}

# create symlink
create_symlink "$SCRIPT_DIR/shared/.gitconfig" "$HOME/.gitconfig"
create_symlink "$SCRIPT_DIR/shared/.mcp.json" "$HOME/.mcp.json"
create_symlink "$SCRIPT_DIR/shared/.config/mise/config.toml" "$HOME/.config/mise/config.toml"
create_symlink "$SCRIPT_DIR/shared/.config/zed/settings.json" "$HOME/.config/zed/settings.json"
create_symlink "$SCRIPT_DIR/shared/.config/zed/keymap.json" "$HOME/.config/zed/keymap.json"
create_symlink "$SCRIPT_DIR/macos/.config/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"

mise install

echo "Dotfiles setup complete!"