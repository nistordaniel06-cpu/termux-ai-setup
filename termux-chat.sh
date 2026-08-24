#!/data/data/com.termux/files/usr/bin/bash
# termux-chat.sh — GitHub Copilot chat UI for Termux
# Launches `gh copilot suggest` / `gh copilot explain` in a readline-friendly
# loop so cursor movement, history (↑/↓), and editing work out of the box.
#
# Usage:  bash termux-chat.sh
# Quit:   type  exit  or press Ctrl-D

set -uo pipefail

if [[ ! -t 0 || ! -t 1 ]]; then
    echo "This chat UI must be run in an interactive terminal."
    exit 1
fi

# Ignore Ctrl-C at the shell level so it interrupts a running
# `gh copilot` call instead of killing the whole chat session.
trap '' INT

# ── colour helpers ──────────────────────────────────────────────────────────
BOLD="\033[1m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# ── ensure gh CLI is available ───────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
    echo -e "${RED}Error:${RESET} 'gh' (GitHub CLI) not found."
    echo "Install it with:  bash setup-gh.sh"
    exit 1
fi

# ── ensure gh copilot extension is installed ─────────────────────────────────
if ! gh extension list 2>/dev/null | grep -q "gh-copilot"; then
    echo -e "${YELLOW}Installing gh-copilot extension…${RESET}"
    gh extension install github/gh-copilot || {
        echo -e "${RED}Failed to install gh-copilot.${RESET}"
        echo "Make sure you are authenticated: gh auth login"
        exit 1
    }
fi

# ── ensure authenticated ─────────────────────────────────────────────────────
if ! gh auth status &>/dev/null; then
    echo -e "${YELLOW}You are not logged in to GitHub.${RESET}"
    echo "Running: gh auth login"
    gh auth login || exit 1
fi

# ── history file for readline ─────────────────────────────────────────────────
HISTFILE_CHAT="${HOME}/.termux_chat_history"
touch "$HISTFILE_CHAT"

# ── banner ───────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║   GitHub Copilot — Termux Chat UI    ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${GREEN}suggest${RESET}  Ask Copilot to suggest a shell command"
echo -e "  ${GREEN}explain${RESET}  Ask Copilot to explain a command"
echo -e "  ${GREEN}help${RESET}     Show this help"
echo -e "  ${GREEN}exit${RESET}     Quit"
echo ""

# ── main loop ────────────────────────────────────────────────────────────────
while true; do
    # readline-based prompt: history, cursor movement, editing all work
    if ! IFS= read -re -p "$(echo -e "${BOLD}${CYAN}you>${RESET} ")" input; then
        # Ctrl-D / EOF
        echo ""
        echo -e "${YELLOW}Goodbye!${RESET}"
        break
    fi

    # skip blank lines
    [[ -z "${input// }" ]] && continue

    # save to history
    history -s "$input"
    history -w "$HISTFILE_CHAT"

    # parse command prefix
    cmd="${input%% *}"
    rest="${input#* }"
    [[ "$rest" == "$input" ]] && rest=""

    case "$cmd" in
        exit|quit|q)
            echo -e "${YELLOW}Goodbye!${RESET}"
            break
            ;;
        help|h|\?)
            echo ""
            echo -e "  ${GREEN}suggest <question>${RESET}  e.g. suggest list all files modified today"
            echo -e "  ${GREEN}explain <command>${RESET}   e.g. explain find . -mtime -1"
            echo -e "  ${GREEN}exit${RESET}                quit the chat"
            echo ""
            ;;
        suggest|s)
            if [[ -z "$rest" ]]; then
                echo -e "${YELLOW}Usage:${RESET} suggest <what you want to do>"
            else
                echo ""
                gh copilot suggest -t shell "$rest"
                echo ""
            fi
            ;;
        explain|e)
            if [[ -z "$rest" ]]; then
                echo -e "${YELLOW}Usage:${RESET} explain <command>"
            else
                echo ""
                gh copilot explain "$rest"
                echo ""
            fi
            ;;
        *)
            # treat bare input as a suggest query for convenience
            echo ""
            gh copilot suggest -t shell "$input"
            echo ""
            ;;
    esac
done
