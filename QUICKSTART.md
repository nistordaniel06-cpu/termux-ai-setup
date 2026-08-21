# Claude Code Quickstart

This guide will have you using AI-powered coding assistance in a few minutes. By the end, you'll understand how to use Claude Code for common development tasks in this repository.

## Before you begin

Make sure you have:

* A terminal or command prompt open
* A [Claude subscription](https://claude.com/pricing) (Pro, Max, Team, or Enterprise), [Claude Console](https://console.anthropic.com/) account, or access through a supported cloud provider

## Step 1: Install Claude Code

**macOS, Linux, WSL:**

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows PowerShell:**

```powershell
irm https://claude.ai/install.ps1 | iex
```

**Windows CMD:**

```batch
curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
```

Or via Homebrew / WinGet:

```bash
brew install --cask claude-code
```

```powershell
winget install Anthropic.ClaudeCode
```

Confirm the installation worked:

```bash
claude --version
```

## Step 2: Log in to your account

Start an interactive session and you'll be prompted to log in on first use:

```bash
claude
```

Follow the prompts to authenticate in your browser. To switch accounts later, type `/login` inside a running session.

## Step 3: Start a session in this repo

```bash
cd termux-ai-setup
claude
```

Type `/help` for available commands or `/resume` to continue a previous conversation.

## Step 4: Ask questions about this project

```
what does this project do?
```

```
explain the folder structure
```

This repo hosts the **Heroium** game (a Godot 4 action-roguelike, under `games/heroium/`) plus the GitHub Pages redirect in `index.html` that sends visitors straight to the playable web build.

## Step 5: Make a code change

```
add a hello world function to the main file
```

Claude Code finds the appropriate file and shows you the change. Review and approve edits before they're applied (permission mode depends on your plan and settings — see `/help`).

## Step 6: Use Git with Claude Code

```
what files have I changed?
```

```
commit my changes with a descriptive message
```

```
create a new branch called feature/my-change
```

## Step 7: Common workflows

**Fix a bug**

```
there's a bug where the joystick doesn't reset after release - fix it
```

**Refactor code**

```
refactor hero_combat.gd to simplify the attack state machine
```

**Write or update tests**

```
add a test in games/heroium/tests for the new ability
```

**Update documentation**

```
update games/heroium/README.md with the new control scheme
```

**Code review**

```
review my changes and suggest improvements
```

## Essential commands

**Shell commands**

| Command             | What it does                                           |
| -------------------- | ------------------------------------------------------ |
| `claude`             | Start interactive mode                                  |
| `claude "task"`      | Run a one-time task                                     |
| `claude -p "query"`  | Run one-off query, then exit                             |
| `claude -c`          | Continue most recent conversation in current directory   |
| `claude -r`          | Resume a previous conversation                           |

**Session commands**

| Command                 | What it does               |
| ------------------------ | --------------------------- |
| `/clear`                 | Clear conversation history  |
| `/help`                  | Show available commands     |
| `/exit` or Ctrl+D twice  | Exit Claude Code            |

## Pro tips

* Be specific: "fix the boss phase-2 trigger that fires at the wrong HP threshold" beats "fix the boss bug".
* Break complex tasks into numbered steps.
* Let Claude explore the codebase (`analyze the ability system`) before asking for changes.
* Press `Shift+Tab` to cycle permission modes; press `Tab` for command completion.

## Learn more

* [Claude Code documentation](https://code.claude.com/docs)
* [Best practices](https://code.claude.com/docs/en/best-practices)
* [Common workflows](https://code.claude.com/docs/en/common-workflows)
