#!/data/data/com.termux/files/usr/bin/bash
# Install Claude Code in Termux and add a direct termux-ai launcher.

set -euo pipefail

if ! command -v pkg >/dev/null 2>&1; then
  echo "This script must be run inside Termux (missing 'pkg' command)." >&2
  exit 1
fi

TMP_ROOT="${TMPDIR:-$PREFIX/tmp}"
CLAUDE_VERSION="2.1.241" # Update from https://www.npmjs.com/package/@anthropic-ai/claude-code
LAUNCHER="$PREFIX/bin/termux-ai"
RETRIES=3

# Retry a flaky, network-dependent command with backoff (2s, 4s, 8s).
retry() {
  local attempt=1 delay=2
  until "$@"; do
    if (( attempt >= RETRIES )); then
      echo "Command failed after $RETRIES attempts: $*" >&2
      return 1
    fi
    echo "  Retrying in ${delay}s... (attempt $((attempt + 1))/$RETRIES)" >&2
    sleep "$delay"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}

mkdir -p "$TMP_ROOT"

echo "==> Updating Termux packages..."
retry pkg update -y

echo "==> Installing required dependencies..."
retry pkg install nodejs-lts proot -y

echo "==> Installing Claude Code..."
# Pin the version so reruns stay reproducible until the launcher is updated intentionally.
if command -v claude >/dev/null 2>&1 && claude --version 2>/dev/null | grep -qF "$CLAUDE_VERSION"; then
  echo "    claude $CLAUDE_VERSION already installed, skipping."
else
  retry npm install -g "@anthropic-ai/claude-code@$CLAUDE_VERSION"
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Claude Code was not added to PATH after installation." >&2
  case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *) echo "Note: $PREFIX/bin is not on your PATH. Add it in ~/.bashrc." >&2 ;;
  esac
  exit 1
fi

echo "==> Verifying the Claude Code native binary..."
if ! claude --version >/dev/null 2>&1; then
  # Recent npm versions require install scripts to be explicitly allowlisted,
  # so the postinstall step that downloads the native binary may get skipped.
  echo "    Native binary missing, running postinstall manually..."
  NPM_GLOBAL_ROOT="$(npm root -g)"
  POSTINSTALL="$NPM_GLOBAL_ROOT/@anthropic-ai/claude-code/install.cjs"
  if [[ -f "$POSTINSTALL" ]]; then
    node "$POSTINSTALL"
  fi
  if ! claude --version >/dev/null 2>&1; then
    echo "Claude Code installed but the native binary still isn't working." >&2
    echo "Try running it manually: node \"$POSTINSTALL\"" >&2
    exit 1
  fi
fi

echo "==> Checking proot sandbox support..."
USE_PROOT=1
if ! proot -b "$TMP_ROOT:/tmp" true >/dev/null 2>&1; then
  USE_PROOT=0
  echo "    Warning: proot is not usable on this device (common on Android 10+" >&2
  echo "    where the kernel restricts ptrace/seccomp). Falling back to running" >&2
  echo "    Claude Code directly, without the proot sandbox." >&2
fi

echo "==> Creating the direct termux-ai command..."
if [[ "$USE_PROOT" -eq 1 ]]; then
  cat > "$LAUNCHER" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
set -e
TMP_ROOT="\${TMPDIR:-\$PREFIX/tmp}"
mkdir -p "\$TMP_ROOT"
exec proot -b "\$TMP_ROOT:/tmp" claude "\$@"
EOF2
else
  cat > "$LAUNCHER" <<EOF2
#!/data/data/com.termux/files/usr/bin/bash
set -e
exec claude "\$@"
EOF2
fi
chmod 755 "$LAUNCHER"

echo ""
echo "==> Done. Run directly with:"
echo "    termux-ai"
echo ""
echo "For verification:"
echo "    termux-ai --version"
