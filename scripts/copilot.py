#!/usr/bin/env python3
"""
🤖 TERMUX COPILOT - AI Code Generator
Ruleaza: copilot 'describe your code'
"""

import os
import sys
import openai
import click

API_KEY = os.getenv('OPENAI_API_KEY')

if not API_KEY or API_KEY == "sk-your-api-key-here":
    print("❌ OPENAI_API_KEY not set!")
    print("📝 Run: nano ~/ai-workspace/config/ai.conf")
    exit(1)

openai.api_key = API_KEY

@click.command()
@click.argument('prompt', nargs=-1)
def copilot(prompt):
    """Termux Copilot - Generate code snippets"""
    
    if not prompt:
        click.echo("📝 Usage: copilot 'describe what you need'")
        click.echo("\nExamples:")
        click.echo("  copilot 'write a function to read JSON'")
        click.echo("  copilot 'bash script to backup files'")
        click.echo("  copilot 'python async function'")
        return
    
    user_input = ' '.join(prompt)
    
    click.secho("\n🤖 Copilot thinking...\n", fg='yellow')
    
    try:
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[
                {
                    "role": "system",
                    "content": "You are GitHub Copilot running on Termux. Generate concise, production-ready code with comments."
                },
                {
                    "role": "user",
                    "content": user_input
                }
            ],
            temperature=0.7,
            max_tokens=1500
        )
        
        code = response['choices'][0]['message']['content']
        
        click.secho("✅ Generated Code:\n", fg='green', bold=True)
        click.echo("─" * 50)
        click.echo(code)
        click.echo("─" * 50)
        
        save = input("\n💾 Save to file? (y/n): ").strip().lower()
        if save == 'y':
            filename = input("Filename (with extension): ").strip()
            if filename:
                with open(filename, 'w') as f:
                    f.write(code)
                click.secho(f"\n✅ Saved: {filename}", fg='green')
    
    except Exception as e:
        click.secho(f"❌ Error: {e}", fg='red')

if __name__ == '__main__':
    copilot()
