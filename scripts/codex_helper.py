#!/usr/bin/env python3
"""
💻 TERMUX CODEX HELPER - Code Generation pe Telefon
Ruleaza: python ~/ai-workspace/scripts/codex_helper.py
"""

import os
import openai
from pathlib import Path

API_KEY = os.getenv('OPENAI_API_KEY')
CODE_DIR = Path.home() / 'ai-workspace' / 'generated_code'

if not API_KEY or API_KEY == "sk-your-api-key-here":
    print("❌ API_KEY not set!")
    print("📝 Run: nano ~/ai-workspace/config/ai.conf")
    exit(1)

openai.api_key = API_KEY

class CodexHelper:
    def __init__(self):
        CODE_DIR.mkdir(parents=True, exist_ok=True)

    def generate_code(self, prompt, language='python'):
        """Genereaza cod din descriere"""
        try:
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": f"You are an expert {language} developer. Generate clean, well-documented code."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=2000
            )

            return response['choices'][0]['message']['content']
        except Exception as e:
            return f"❌ Error: {e}"

    def save_code(self, filename, code, language='python'):
        """Salveaza cod in fisier"""
        filepath = CODE_DIR / f"{filename}.{self._get_extension(language)}"
        filepath.write_text(code, encoding='utf-8')
        print(f"✅ Cod salvat: {filepath}")
        return filepath

    def _get_extension(self, language):
        ext_map = {
            'python': 'py',
            'javascript': 'js',
            'bash': 'sh',
            'java': 'java',
            'cpp': 'cpp',
            'c': 'c'
        }
        return ext_map.get(language, 'txt')

    def interactive_generation(self):
        """Chat interactiv pentru code generation"""
        print("""
╔═══════════════════════════════════════════╗
║   💻 CODEX HELPER - Code Generation        ║
║   Descrie ce cod vrei sa genereze          ║
╚═══════════════════════════════════════════╝
        """)

        while True:
            print("""
1. Generate code
2. Save code to file
3. Exit
            """)

            choice = input("👀 Choose (1-3): ").strip()

            if choice == '1':
                language = input("Language (python/javascript/bash): ").strip() or 'python'
                prompt = input("\n📝 Describe code to generate: ").strip()

                if prompt:
                    print("\n⏳ Generating...")
                    code = self.generate_code(prompt, language)
                    print(f"\n✅ Generated Code:\n")
                    print("─" * 50)
                    print(code)
                    print("─" * 50)

                    save = input("\nSave code? (y/n): ").lower()
                    if save == 'y':
                        filename = input("Filename (without extension): ").strip()
                        if filename:
                            self.save_code(filename, code, language)

            elif choice == '2':
                print("\n💾 Manual save feature coming soon...")

            elif choice == '3':
                print("👋 Goodbye!")
                break

            input("\n⏳ Press Enter...")

if __name__ == "__main__":
    codex = CodexHelper()
    codex.interactive_generation()
