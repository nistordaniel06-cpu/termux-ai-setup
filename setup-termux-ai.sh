#!/data/data/com.termux/files/usr/bin/bash
# Install Claude Code in Termux and add a direct termux-ai launcher.

set -euo pipefail

TMP_ROOT="${TMPDIR:-$PREFIX/tmp}"
CLAUDE_VERSION="2.1.241" # Update from https://www.npmjs.com/package/@anthropic-ai/claude-code
LAUNCHER="$PREFIX/bin/termux-ai"

mkdir -p "$TMP_ROOT"

echo "==> Updating Termux packages..."
pkg update -y

echo "==> Installing required dependencies..."
pkg install nodejs-lts proot -y

echo "==> Installing Claude Code..."
# Pin the version so reruns stay reproducible until the launcher is updated intentionally.
npm install -g "@anthropic-ai/claude-code@$CLAUDE_VERSION"

if ! command -v claude >/dev/null 2>&1; then
  echo "Claude Code was not added to PATH after installation." >&2
  exit 1
fi

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
