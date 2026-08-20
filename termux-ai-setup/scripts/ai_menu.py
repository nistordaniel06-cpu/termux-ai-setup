#!/usr/bin/env python3
"""
🎯 TERMUX AI MASTER - Meniu principal
Ruleaza: python ~/ai-workspace/scripts/ai_menu.py  (alias: ai)
"""

import os
from pathlib import Path

WORKSPACE = Path.home() / 'ai-workspace'


def clear():
    os.system('clear')


def banner():
    print("""
╔════════════════════════════════════════════════════════════╗
║        🎯 TERMUX AI MASTER - Meniu principal                ║
║        Chat IA + Codex + Statistici, direct pe telefon      ║
╚════════════════════════════════════════════════════════════╝
    """)


def menu():
    print("""
┌─────────────────────────────────────────────────────────────┐
│  1  💬  AI Chat                                              │
│  2  💻  Codex (Code Generator)                                │
│  3  📚  Vezi conversatii salvate                              │
│  4  📊  Statistici                                            │
│  5  ⚙️   Editeaza configuratia (API key)                       │
│  0  🚪  Iesire                                                │
└─────────────────────────────────────────────────────────────┘
    """)


def option_chat():
    os.system(f'python "{WORKSPACE}/scripts/chat.py"')


def option_codex():
    os.system(f'python "{WORKSPACE}/scripts/codex_helper.py"')


def option_history():
    chats_dir = WORKSPACE / 'chats'
    files = sorted(chats_dir.glob('*.json')) if chats_dir.exists() else []
    if not files:
        print("📭 Nu exista conversatii salvate inca.")
    else:
        print(f"\n📚 {len(files)} conversatii salvate:\n")
        for f in files:
            print(f"  - {f.name}")
    input("\nApasa Enter...")


def option_stats():
    chats = len(list((WORKSPACE / 'chats').glob('*.json'))) if (WORKSPACE / 'chats').exists() else 0
    code = len(list((WORKSPACE / 'generated_code').glob('*'))) if (WORKSPACE / 'generated_code').exists() else 0
    print(f"""
📊 Statistici:
  Conversatii chat: {chats}
  Fisiere de cod generate: {code}
    """)
    input("Apasa Enter...")


def option_config():
    os.system(f'nano "{WORKSPACE}/config/ai.conf"')


def run():
    while True:
        clear()
        banner()
        menu()

        choice = input("Alege (0-5): ").strip()

        if choice == '1':
            option_chat()
        elif choice == '2':
            option_codex()
        elif choice == '3':
            option_history()
        elif choice == '4':
            option_stats()
        elif choice == '5':
            option_config()
        elif choice == '0':
            print("\n👋 Pa! Spor la treaba!\n")
            break
        else:
            input("Optiune invalida. Apasa Enter...")


if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        print("\n👋 Intrerupt.\n")
