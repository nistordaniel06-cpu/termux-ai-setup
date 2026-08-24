#!/data/data/com.termux/files/usr/bin/bash
# start.sh — One-shot setup + launch for Termux Copilot Chat
#
# Run once to install everything, then launches the chat automatically.
# After the first run you can just call:  bash termux-chat.sh

set -euo pipefail

YELLOW="\033[33m"
GREEN="\033[32m"
RESET="\033[0m"
BOLD="\033[1m"

RETRIES=3

# Retry a flaky, network-dependent command with backoff (2s, 4s, 8s).
retry() {
    local attempt=1 delay=2
    until "$@"; do
        if (( attempt >= RETRIES )); then
            echo "  Command failed after $RETRIES attempts: $*" >&2
            return 1
        fi
        echo "  Retrying in ${delay}s... (attempt $((attempt + 1))/$RETRIES)" >&2
        sleep "$delay"
        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done
}

echo -e "${BOLD}==> Termux Copilot Chat — setup & launch${RESET}"

if ! command -v pkg &>/dev/null; then
    echo "This script must be run inside Termux (missing 'pkg' command)." >&2
    exit 1
fi

# 1. Update packages (non-fatal if offline)
echo -e "${YELLOW}[1/4] Updating Termux packages…${RESET}"
retry pkg update -y || echo "  (skipped — no network or already up to date)"

# 2. Install gh CLI
echo -e "${YELLOW}[2/4] Installing GitHub CLI (gh)…${RESET}"
if ! command -v gh &>/dev/null; then
    if ! retry pkg install gh -y; then
        echo "  pkg install gh failed, trying via Go…"
        retry pkg install golang git -y
        retry go install github.com/cli/cli/v2/cmd/gh@latest
        PROFILE="$HOME/.bashrc"
        grep -q 'go/bin' "$PROFILE" 2>/dev/null || \
            echo "export PATH=\$PATH:\$HOME/go/bin" >> "$PROFILE"
        export PATH="$PATH:$HOME/go/bin"
    fi
    echo -e "${GREEN}  gh installed.${RESET}"
else
    echo -e "${GREEN}  gh already present: $(gh --version | head -1)${RESET}"
fi

# 3. Authenticate
echo -e "${YELLOW}[3/4] Checking GitHub authentication…${RESET}"
if ! gh auth status &>/dev/null; then
    echo "  Not logged in — starting interactive login…"
    gh auth login
else
    echo -e "${GREEN}  Already authenticated.${RESET}"
fi

# 4. Install gh-copilot extension
echo -e "${YELLOW}[4/4] Checking gh-copilot extension…${RESET}"
if ! gh extension list 2>/dev/null | grep -q "gh-copilot"; then
    retry gh extension install github/gh-copilot
    echo -e "${GREEN}  gh-copilot extension installed.${RESET}"
else
    echo -e "${GREEN}  gh-copilot already installed.${RESET}"
fi

# ── wire up ~/.bashrc so the chat auto-launches on every new Termux session ──
MARKER="# termux-copilot-autostart"
CHAT_SCRIPT="$(cd "$(dirname "$0")" && pwd)/termux-chat.sh"
BASHRC="$HOME/.bashrc"

if [[ ! -f "$CHAT_SCRIPT" ]]; then
    echo "termux-chat.sh not found next to start.sh ($CHAT_SCRIPT) — skipping autostart setup." >&2
    exit 1
fi

if ! grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
    {
        echo ""
        echo "$MARKER"
        echo "bash \"$CHAT_SCRIPT\""
    } >> "$BASHRC"
    echo -e "${GREEN}  Auto-start added to ~/.bashrc${RESET}"
    echo "  To remove it later, delete the marker line and the bash line that follows it in ~/.bashrc"
else
    echo -e "${GREEN}  Auto-start already configured in ~/.bashrc${RESET}"
fi

echo ""
echo -e "${BOLD}Setup complete! Launching Copilot Chat…${RESET}"
echo ""

exec bash "$CHAT_SCRIPT"
