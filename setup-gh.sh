#!/data/data/com.termux/files/usr/bin/bash
# Automatic GitHub CLI (gh) installer for Termux

set -e

if ! command -v pkg >/dev/null 2>&1; then
    echo "This script must be run inside Termux (missing 'pkg' command)." >&2
    exit 1
fi

echo "==> Updating Termux packages..."
pkg update -y && pkg upgrade -y

echo "==> Installing GitHub CLI..."
if pkg install gh -y 2>/dev/null; then
    echo "==> GitHub CLI installed successfully via pkg."
else
    echo "==> pkg install gh failed. Trying installation via Go..."
    pkg install golang git -y
    go install github.com/cli/cli/v2/cmd/gh@latest

    GH_BIN="$HOME/go/bin/gh"
    PROFILE="$HOME/.bashrc"

    if ! grep -q 'go/bin' "$PROFILE" 2>/dev/null; then
        echo "export PATH=\$PATH:\$HOME/go/bin" >> "$PROFILE"
    fi
    export PATH=$PATH:$HOME/go/bin
    echo "==> GitHub CLI installed via Go at: $GH_BIN"
fi

echo ""
echo "==> Version check:"
gh --version

echo ""
echo "==> To authenticate with GitHub, run:"
echo "    gh auth login"
