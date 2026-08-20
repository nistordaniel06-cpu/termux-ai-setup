#!/bin/bash
# 🎮 GAMES - Deschide jocurile publicate, direct din Termux
# Ruleaza: bash ~/ai-workspace/scripts/games.sh   (alias: games)
#
# Nu descarca si nu cloneaza nimic - jocurile ruleaza din browser, servite
# de GitHub Pages. Scriptul doar deschide link-ul corect, ca sa nu-l mai
# cauti/copiezi de fiecare data. Se actualizeaza singur la fiecare push.

TORCHBOUND_URL="https://nistordaniel06-cpu.github.io/termux-ai-setup/"
HEROIUM_URL="https://nistordaniel06-cpu.github.io/termux-ai-setup/games/heroium/play/"

open_url() {
    local url="$1"
    if command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "$url"
    else
        echo ""
        echo "📋 Copiaza link-ul (Termux:API nu e instalat, deci nu pot deschide singur browser-ul):"
        echo "   $url"
        echo ""
        echo "💡 Pentru deschidere automata data viitoare:"
        echo "   pkg install termux-api"
        echo "   (si instaleaza si aplicatia Termux:API din F-Droid)"
    fi
}

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  🎮 GAMES - Jocurile tale, direct din browser              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "1  🔥 Torchbound   (action-roguelike, browser HTML)"
echo "2  ⚔️  Heroium      (Godot, export Web)"
echo "3  🎮 Ambele"
echo "0  🚪 Iesire"
echo ""
read -p "Alege (0-3): " choice

case "$choice" in
    1) open_url "$TORCHBOUND_URL" ;;
    2) open_url "$HEROIUM_URL" ;;
    3) open_url "$TORCHBOUND_URL"; open_url "$HEROIUM_URL" ;;
    0) exit 0 ;;
    *) echo "Optiune invalida." ;;
esac

echo ""
