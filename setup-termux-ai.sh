#!/data/data/com.termux/files/usr/bin/bash
# Install Claude Code in Termux and add a direct termux-ai launcher.

set -euo pipefail

TMP_ROOT="${TMPDIR:-$PREFIX/tmp}"
LAUNCHER="$PREFIX/bin/termux-ai"

mkdir -p "$TMP_ROOT"

echo "==> Updating Termux packages..."
pkg update -y && pkg upgrade -y

echo "==> Installing required dependencies..."
pkg install nodejs-lts git proot -y

echo "==> Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

echo "==> Creating the direct termux-ai command..."
cat > "$LAUNCHER" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
set -e
TMP_ROOT="\${TMPDIR:-\$PREFIX/tmp}"
mkdir -p "\$TMP_ROOT"
exec proot -b "\$TMP_ROOT:/tmp" claude "\$@"
EOF2
chmod 755 "$LAUNCHER"

echo ""
echo "==> Done. Run directly with:"
echo "    termux-ai"
echo ""
echo "For verification:"
echo "    termux-ai --version"
