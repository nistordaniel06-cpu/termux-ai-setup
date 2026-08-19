#!/usr/bin/env python3
"""
🤖 TERMUX AI CHAT - Interactive Chat pe Telefon
Ruleaza: python ~/ai-workspace/scripts/chat.py
"""

import os
import openai
import json
from datetime import datetime
from pathlib import Path

# Config
API_KEY = os.getenv('OPENAI_API_KEY')
CHAT_HISTORY_DIR = Path.home() / 'ai-workspace' / 'chats'
CURRENT_CHAT_FILE = CHAT_HISTORY_DIR / f"chat_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

if not API_KEY or API_KEY == "sk-your-api-key-here":
    print("❌ EROARE: OPENAI_API_KEY nu este setat!")
    print("📝 Seteaza: nano ~/ai-workspace/config/ai.conf")
    print("   OPENAI_API_KEY='sk-your-actual-key'")
    print("🔄 Reload: source ~/.bashrc")
    exit(1)

openai.api_key = API_KEY

class TermuxAIChat:
    def __init__(self):
        self.messages = []
        self.chat_file = CURRENT_CHAT_FILE
        CHAT_HISTORY_DIR.mkdir(parents=True, exist_ok=True)

    def save_chat(self):
        """Salveaza conversatia"""
        with open(self.chat_file, 'w', encoding='utf-8') as f:
            json.dump({
                'messages': self.messages,
                'created_at': datetime.now().isoformat(),
            }, f, ensure_ascii=False, indent=2)

    def get_ai_response(self, user_input):
        """Primeste raspuns de la AI"""
        try:
            self.messages.append({"role": "user", "content": user_input})

            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=self.messages,
                temperature=0.7,
                max_tokens=1000
            )

            assistant_message = response['choices'][0]['message']['content']
            self.messages.append({"role": "assistant", "content": assistant_message})

            self.save_chat()
            return assistant_message

        except Exception as e:
            return f"❌ Eroare: {str(e)}"

    def show_help(self):
        """Arata comenzi disponibile"""
        print("""
╔═══════════════════════════════════════════╗
║       TERMUX AI CHAT - COMENZI             ║
╠═══════════════════════════════════════════╣
║ /help     - Arata aceasta pagina           ║
║ /clear    - Sterge conversatia             ║
║ /save     - Salveaza manual conversatia    ║
║ /history  - Arata ultim 5 mesaje           ║
║ /exit     - Iesire din chat                ║
║ /file     - Chat file path                 ║
║ /stats    - Statistici conversatie         ║
╚═══════════════════════════════════════════╝
        """)

    def show_history(self):
        """Arata ultimele mesaje"""
        if not self.messages:
            print("📭 Niciun mesaj in istoric")
            return

        recent = self.messages[-10:]
        print(f"\n📜 Ultim(ele) {len(recent)} mesaje:")
        print("─" * 50)
        for msg in recent:
            role = "👤 Tu" if msg['role'] == 'user' else "🤖 AI"
            text = msg['content'][:100] + "..." if len(msg['content']) > 100 else msg['content']
            print(f"{role}: {text}")
        print("─" * 50 + "\n")

    def show_stats(self):
        """Arata statistici"""
        user_msgs = len([m for m in self.messages if m['role'] == 'user'])
        ai_msgs = len([m for m in self.messages if m['role'] == 'assistant'])
        total_chars = sum(len(m['content']) for m in self.messages)

        print(f"""
📊 STATISTICI CONVERSATIE:
  Mesaje utilizator: {user_msgs}
  Raspunsuri AI: {ai_msgs}
  Total caractere: {total_chars:,}
  File: {self.chat_file.name}
        """)

    def run(self):
        """Main loop - chat interactiv"""
        print("""
╔═══════════════════════════════════════════╗
║   🤖 TERMUX AI CHAT - Pe Telefon           ║
║   Scrie /help pentru comenzi               ║
║   Scrie 'exit' pentru iesire               ║
╚═══════════════════════════════════════════╝
        """)

        while True:
            try:
                user_input = input("\n📝 Tu: ").strip()

                if not user_input:
                    continue

                # Proceseaza comenzi
                if user_input.lower() == '/exit' or user_input.lower() == 'exit':
                    print("\n👋 Multumesc! Chat salvat in: " + str(self.chat_file))
                    break
                elif user_input == '/help':
                    self.show_help()
                elif user_input == '/clear':
                    self.messages = []
                    print("✅ Conversatie stearsa")
                elif user_input == '/save':
                    self.save_chat()
                    print(f"💾 Salvat: {self.chat_file}")
                elif user_input == '/history':
                    self.show_history()
                elif user_input == '/file':
                    print(f"📁 {self.chat_file}")
                elif user_input == '/stats':
                    self.show_stats()
                else:
                    print("\n⏳ AI gandeste...")
                    response = self.get_ai_response(user_input)
                    print(f"\n🤖 AI: {response}")

            except KeyboardInterrupt:
                print("\n\n👋 Chat inchis")
                break
            except Exception as e:
                print(f"❌ Eroare: {e}")

if __name__ == "__main__":
    chat = TermuxAIChat()
    chat.run()
