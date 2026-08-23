#!/data/data/com.termux/files/usr/bin/bash
# Instalare automată GitHub CLI (gh) în Termux

set -e

if ! command -v pkg >/dev/null 2>&1; then
    echo "Acest script trebuie rulat din Termux (lipseste comanda 'pkg')." >&2
    exit 1
fi

echo "==> Actualizare pachete Termux..."
pkg update -y && pkg upgrade -y

echo "==> Instalare GitHub CLI..."
if pkg install gh -y 2>/dev/null; then
    echo "==> GitHub CLI instalat cu succes via pkg."
else
    echo "==> pkg install gh a eșuat. Se încearcă instalarea via Go..."
    pkg install golang git -y
    go install github.com/cli/cli/v2/cmd/gh@latest

    GH_BIN="$HOME/go/bin/gh"
    PROFILE="$HOME/.bashrc"

    if ! grep -q 'go/bin' "$PROFILE" 2>/dev/null; then
        echo "export PATH=\$PATH:\$HOME/go/bin" >> "$PROFILE"
    fi
    export PATH=$PATH:$HOME/go/bin
    echo "==> GitHub CLI instalat via Go la: $GH_BIN"
fi

echo ""
echo "==> Verificare versiune:"
gh --version

echo ""
echo "==> Autentificare GitHub (rulează manual):"
echo "    gh auth login"
