#!/bin/bash

# 🚀 TERMUX PRO - Complete Setup
set -e

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  🚀 TERMUX PRO - Ultimate Developer Environment           ║"
echo "║  Copilot + GitHub + Chat IA + Beautiful UI                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -d "$PREFIX" ]; then
    echo "❌ Run this in Termux!"
    exit 1
fi

echo "📦 Updating packages..."
pkg update -y && pkg upgrade -y

echo "🐍 Installing Python & tools..."
pkg install -y python clang git nano curl wget openssh

echo "📥 Installing Python packages..."
pip install --upgrade pip
pip install openai==0.27.8 anthropic requests python-dotenv rich click

echo "📁 Creating workspace..."
mkdir -p ~/ai-workspace/{chats,generated_code,scripts,config,github}

echo "⬇️  Downloading scripts..."
GITHUB_RAW="https://raw.githubusercontent.com/nistordaniel06-cpu/termux-ai-setup/main/scripts"

for script in chat.py copilot.py codex_helper.py termux_pro_hub.py ai_menu.py; do
    echo "  → $script"
    curl -fsSL "${GITHUB_RAW}/$script" -o ~/ai-workspace/scripts/$script 2>/dev/null || true
done

chmod +x ~/ai-workspace/scripts/*.py 2>/dev/null || true

echo "⚙️  Creating config..."
cat > ~/ai-workspace/config/ai.conf << 'CONF'
# 🚀 TERMUX PRO Configuration
export OPENAI_API_KEY="sk-your-api-key-here"
export GITHUB_TOKEN="ghp_your-token-here"
export GITHUB_USER="your-username"
export AI_MODEL="gpt-3.5-turbo"
CONF

echo "🔗 Adding aliases..."
if ! grep -q "TERMUX PRO" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'ALIAS'

# 🚀 TERMUX PRO
export AI_WORKSPACE="$HOME/ai-workspace"
[ -f "$AI_WORKSPACE/config/ai.conf" ] && source "$AI_WORKSPACE/config/ai.conf"
alias tp='python $AI_WORKSPACE/scripts/termux_pro_hub.py'
alias ai='python $AI_WORKSPACE/scripts/termux_pro_hub.py'
alias chat='python $AI_WORKSPACE/scripts/chat.py'
alias copilot='python $AI_WORKSPACE/scripts/copilot.py'
alias cop='python $AI_WORKSPACE/scripts/copilot.py'
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias goto_ai='cd $AI_WORKSPACE && ls -la'
alias ai_config='nano $AI_WORKSPACE/config/ai.conf'

ALIAS
fi

source ~/.bashrc 2>/dev/null || true

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ INSTALLATION COMPLETE!                                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "🎯 SETUP:"
echo "  1. nano ~/ai-workspace/config/ai.conf"
echo "  2. Set your OPENAI_API_KEY"
echo "  3. source ~/.bashrc"
echo ""
echo "🚀 START:"
echo "  tp  or  ai      → Main Hub"
echo "  chat             → Chat AI"
echo "  copilot/cop      → Code Generator"
echo "  gs, ga, gp       → Git commands"
echo ""
