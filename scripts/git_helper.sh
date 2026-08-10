#!/bin/bash
# GitHub Setup Helper for Termux Pro

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  🐙 GitHub Configuration Helper                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

read -p "GitHub username: " github_user
read -p "GitHub email: " github_email

git config --global user.name "$github_user"
git config --global user.email "$github_email"

echo ""
echo "✅ Git configured!"
echo ""
echo "Next time you clone, use:"
echo "  git clone https://github.com/username/repo.git"
echo ""
echo "For SSH setup, run:"
echo "  ssh-keygen -t ed25519 -C \"$github_email\""
echo ""
