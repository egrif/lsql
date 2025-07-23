#!/bin/bash

# Installation script for lsql Ruby application

set -e

echo "Installing lsql application..."

# Ensure ~/bin directory exists
HOME_BIN="$HOME/bin"
mkdir -p "$HOME_BIN"

# Create symlink to the executable
SOURCE_PATH="$(pwd)/bin/lsql"
TARGET_PATH="$HOME_BIN/lsql"

# Remove existing symlink or file if it exists
if [[ -L "$TARGET_PATH" ]] || [[ -f "$TARGET_PATH" ]]; then
    echo "Removing existing lsql installation..."
    rm "$TARGET_PATH"
fi

# Create the symlink
ln -s "$SOURCE_PATH" "$TARGET_PATH"

echo "Successfully installed lsql to $TARGET_PATH"
echo ""
echo "Make sure $HOME_BIN is in your PATH."
echo "You can add this to your shell profile:"
echo "  export PATH=\"\$HOME/bin:\$PATH\""
echo ""
echo "Usage: lsql --help"
