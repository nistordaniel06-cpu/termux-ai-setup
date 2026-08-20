#!/bin/bash
set -e

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  🚀 TERMUX AI MASTER - ONE-LINE INSTALLER              ║"
echo "║  Chat IA + Codex + Menu pe STEROZI 💪                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -d "$PREFIX" ]; then
    echo "❌ ERROR: Run this in Termux!"
    exit 1
fi

echo "📦 Updating packages..."
pkg update -y && pkg upgrade -y

echo "🐍 Installing Python..."
pkg install -y python clang git nano curl

echo "📥 Installing Python packages..."
pip install requests python-dotenv

echo "📁 Creating workspace..."
mkdir -p ~/ai-workspace/{chats,generated_code,scripts,config}

echo "⬇️  Downloading scripts..."
GITHUB_RAW="https://raw.githubusercontent.com/nistordaniel06-cpu/termux-ai-setup/main/scripts"

echo "  → chat.py"
curl -fsSL "${GITHUB_RAW}/chat.py" -o ~/ai-workspace/scripts/chat.py 2>/dev/null || echo "Warning: chat.py"

echo "  → codex_helper.py"
curl -fsSL "${GITHUB_RAW}/codex_helper.py" -o ~/ai-workspace/scripts/codex_helper.py 2>/dev/null || echo "Warning: codex_helper.py"

echo "  → ai_menu.py"
curl -fsSL "${GITHUB_RAW}/ai_menu.py" -o ~/ai-workspace/scripts/ai_menu.py 2>/dev/null || echo "Warning: ai_menu.py"

echo "  → games.sh"
curl -fsSL "${GITHUB_RAW}/games.sh" -o ~/ai-workspace/scripts/games.sh 2>/dev/null || echo "Warning: games.sh"

chmod +x ~/ai-workspace/scripts/*.py ~/ai-workspace/scripts/*.sh 2>/dev/null || true

echo "⚙️  Creating configuration..."
cat > ~/ai-workspace/config/ai.conf << 'CONF'
# Termux AI Master Configuration
# Edit this and set your OpenAI API key

export OPENAI_API_KEY="sk-your-api-key-here"
export AI_MODEL="gpt-3.5-turbo"
export AI_TEMPERATURE="0.7"
export AI_MAX_TOKENS="1000"
CONF

echo "🔗 Adding aliases to ~/.bashrc..."
if ! grep -q "TERMUX AI MASTER" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'ALIAS'

# ╔════════════════════════════════════════════════════════════╗
# ║  🚀 TERMUX AI MASTER - Aliases & Configuration            ║
# ╚════════════════════════════════════════════════════════════╝

export AI_WORKSPACE="$HOME/ai-workspace"

# Load AI configuration
if [ -f "$AI_WORKSPACE/config/ai.conf" ]; then
    source "$AI_WORKSPACE/config/ai.conf"
fi

# Main commands
alias ai='python $AI_WORKSPACE/scripts/ai_menu.py'
alias chat='python $AI_WORKSPACE/scripts/chat.py'
alias codex='python $AI_WORKSPACE/scripts/codex_helper.py'
alias games='bash $AI_WORKSPACE/scripts/games.sh'
alias aichats='ls -lh $AI_WORKSPACE/chats/ 2>/dev/null || echo "No chats yet"'
alias goto_ai='cd $AI_WORKSPACE && ls -la'
alias ai_config='nano $AI_WORKSPACE/config/ai.conf'
alias ai_help='echo "Commands: ai | chat | codex | aichats | goto_ai | ai_config"'
ALIAS
fi

source ~/.bashrc 2>/dev/null || true

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ INSTALLATION COMPLETE!                                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "🎯 NEXT STEPS:"
echo ""
echo "1️⃣  Set your OpenAI API Key:"
echo "   nano ~/ai-workspace/config/ai.conf"
echo "   Change: OPENAI_API_KEY='sk-your-actual-key'"
echo ""
echo "2️⃣  Reload shell:"
echo "   source ~/.bashrc"
echo ""
echo "3️⃣  Start using:"
echo "   ai          → 🎯 Master Menu (recommended!)"
echo "   chat        → 💬 Chat directly"
echo "   codex       → 💻 Code generation"
echo "   games       → 🎮 Open Heroium (Web / Godot)"
echo "   aichats     → 📚 View saved chats"
echo "   ai_config   → ⚙️  Edit config"
echo ""
echo "💡 Pro tip: Type 'ai' to start!"
echo ""
echo "📁 Workspace: ~/ai-workspace/"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
