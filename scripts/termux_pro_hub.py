#!/usr/bin/env python3
"""
🚀 TERMUX PRO HUB - Developer Interface
Integrated: GitHub + Copilot + Chat AI + Beautiful UI
"""

import os
import sys
import json
import subprocess
from pathlib import Path

try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.text import Text
except ImportError:
    subprocess.run([sys.executable, "-m", "pip", "install", "rich"], capture_output=True)
    from rich.console import Console
    from rich.panel import Panel

console = Console()
WORKSPACE = Path.home() / 'ai-workspace'

class TermuxProHub:
    def __init__(self):
        self.api_key = os.getenv('OPENAI_API_KEY')
    
    def clear(self):
        os.system('clear')
    
    def banner(self):
        b = """
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║        🚀 TERMUX PRO - Developer Hub                          ║
║        GitHub + Copilot + Chat AI                            ║
║        Beautiful Interface for Phone Development             ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
        """
        console.print(b, style="cyan bold")
    
    def menu(self):
        m = """
[bold cyan]┌─────────────────────────────────────────────────────────────┐[/]
[bold cyan]│[/]  [bold yellow]1[/]  💬 [bold]AI Chat[/bold]                                      [bold cyan]│[/]
[bold cyan]│[/]  [bold yellow]2[/]  💻 [bold]Copilot (Code Generator)[/bold]            [bold cyan]│[/]
[bold cyan]│[/]  [bold yellow]3[/]  🐙 [bold]GitHub Tools[/bold]                         [bold cyan]│[/]
[bold cyan]│[/]  [bold yellow]4[/]  📊 [bold]Statistics[/bold]                           [bold cyan]│[/]
[bold cyan]│[/]  [bold yellow]5[/]  🔧 [bold]Settings[/bold]                             [bold cyan]│[/]
[bold cyan]│[/]  [bold yellow]6[/]  ℹ️  [bold]Help[/bold]                                 [bold cyan]│[/]
[bold cyan]│[/]  [bold yellow]7[/]  🎮 [bold]Games (Heroium)[/bold]           [bold cyan]│[/]
[bold cyan]│[/]  [bold yellow]0[/]  🚪 [bold]Exit[/bold]                                [bold cyan]│[/]
[bold cyan]└─────────────────────────────────────────────────────────────┘[/]
        """
        console.print(m)
    
    def option_1(self):
        console.print("\n[cyan]→ Starting AI Chat...\n[/]")
        os.system('python $HOME/ai-workspace/scripts/chat.py')
    
    def option_2(self):
        console.print("\n[cyan]→ Copilot Code Generator\n[/]")
        prompt = input("[bold]📝 Describe code:[/bold] ").strip()
        if prompt:
            os.system(f'copilot "{prompt}"')
    
    def option_3(self):
        self.clear()
        console.print(Panel("[bold cyan]GitHub Tools[/]", border_style="cyan"))
        
        git_menu = """
[cyan]1[/] Clone | [cyan]2[/] Init | [cyan]3[/] Status | [cyan]4[/] Commit | [cyan]5[/] Setup | [cyan]0[/] Back
        """
        console.print(git_menu)
        
        choice = input("\n[bold]Choose:[/bold] ").strip()
        
        if choice == '1':
            url = input("[bold]Repo URL:[/bold] ").strip()
            if url:
                os.system(f'git clone {url}')
        elif choice == '2':
            name = input("[bold]Repo name:[/bold] ").strip()
            if name:
                os.makedirs(name, exist_ok=True)
                os.chdir(name)
                os.system('git init')
                console.print(f"[green]✅ Initialized: {name}[/]")
        elif choice == '3':
            os.system('git status')
        elif choice == '4':
            msg = input("[bold]Message:[/bold] ").strip()
            if msg:
                os.system('git add .')
                os.system(f'git commit -m "{msg}"')
                os.system('git push')
        elif choice == '5':
            os.system('bash $HOME/ai-workspace/scripts/git_helper.sh')
        
        input("\n[cyan]Press Enter...[/]")
    
    def option_4(self):
        chats_dir = WORKSPACE / 'chats'
        chats = len(list(chats_dir.glob('*.json'))) if chats_dir.exists() else 0
        code = len(list((WORKSPACE / 'generated_code').glob('*'))) if (WORKSPACE / 'generated_code').exists() else 0
        
        stats = f"[bold cyan]📊 Statistics\n\nChat Sessions: {chats}\nGenerated Code: {code}[/]"
        console.print(Panel(stats, border_style="cyan"))
        input("\n[cyan]Press Enter...[/]")
    
    def option_5(self):
        console.print(Panel(
            "[bold cyan]⚙️  Settings\n\nEdit: nano ~/ai-workspace/config/ai.conf[/]",
            border_style="cyan"
        ))
        edit = input("\n[bold]Edit now? (y/n):[/bold] ").strip().lower()
        if edit == 'y':
            os.system('nano $HOME/ai-workspace/config/ai.conf')
    
    def option_6(self):
        help_text = """[bold cyan]QUICK REFERENCE\n\nCommands:\n  tp/ai       Main hub\n  chat        Chat AI\n  copilot/cop Code gen\n  games       Open Heroium (Web/Godot)\n  gs, ga, gp  Git shortcuts\n\nFiles:\n  Config: ~/ai-workspace/config/ai.conf\n  Chats: ~/ai-workspace/chats/[/]"""
        console.print(Panel(help_text, border_style="cyan"))
        input("\n[cyan]Press Enter...[/]")

    def option_7(self):
        os.system('bash $HOME/ai-workspace/scripts/games.sh')

    def run(self):
        while True:
            self.clear()
            self.banner()
            self.menu()
            
            choice = input("[bold yellow]Choose (0-7):[/bold yellow] ").strip()

            if choice == '1':
                self.option_1()
            elif choice == '2':
                self.option_2()
            elif choice == '3':
                self.option_3()
            elif choice == '4':
                self.option_4()
            elif choice == '5':
                self.option_5()
            elif choice == '6':
                self.option_6()
            elif choice == '7':
                self.option_7()
            elif choice == '0':
                console.print("\n[cyan]👋 Goodbye! Happy coding!\n[/]")
                break
            
            input("\n[cyan]Press Enter...[/]")

if __name__ == "__main__":
    hub = TermuxProHub()
    try:
        hub.run()
    except KeyboardInterrupt:
        console.print("\n[red]Interrupted\n[/]")
