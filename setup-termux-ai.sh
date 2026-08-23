#!/data/data/com.termux/files/usr/bin/bash
# Instalare Claude Code in Termux + comanda directa termux-ai

set -euo pipefail

TMP_ROOT="${TMPDIR:-$PREFIX/tmp}"
LAUNCHER="$PREFIX/bin/termux-ai"
AUTO_LAUNCHER="$PREFIX/bin/termux-ai-auto"

mkdir -p "$TMP_ROOT"

echo "==> Actualizare pachete Termux..."
pkg update -y && pkg upgrade -y

echo "==> Instalare dependinte necesare..."
pkg install nodejs-lts git proot -y

echo "==> Instalare Claude Code..."
npm install -g @anthropic-ai/claude-code

echo "==> Creare comanda directa termux-ai..."
cat > "$LAUNCHER" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
set -e
TMP_ROOT="\${TMPDIR:-\$PREFIX/tmp}"
mkdir -p "\$TMP_ROOT"
exec proot -b "\$TMP_ROOT:/tmp" claude "\$@"
EOF2
chmod 755 "$LAUNCHER"
ln -sf "$LAUNCHER" "$AUTO_LAUNCHER"

echo ""
echo "==> Gata. Ruleaza direct:"
echo "    termux-ai"
echo "sau"
echo "    termux-ai-auto"
echo ""
echo "Pentru verificare:"
echo "    termux-ai --version"
