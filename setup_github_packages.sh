#!/bin/bash

# GitHub Packages Setup Script for LSQL
# This script helps configure your system to install gems from GitHub Packages

set -e

echo "🔧 Setting up GitHub Packages access for LSQL..."
echo ""

# Check if GitHub CLI is available
if command -v gh &> /dev/null; then
    echo "📦 GitHub CLI detected. You can use it to authenticate."
    echo "Run: gh auth login"
    echo ""
fi

echo "To install LSQL from GitHub Packages, you'll need:"
echo "1. A GitHub account with access to this repository"
echo "2. A Personal Access Token (PAT) with 'read:packages' permission"
echo ""

echo "Setup steps:"
echo "1. Create a PAT at: https://github.com/settings/tokens/new"
echo "2. Select 'read:packages' scope"
echo "3. Configure bundler:"
echo ""
echo "   bundle config set --global https://rubygems.pkg.github.com/egrif USERNAME:TOKEN"
echo ""
echo "4. Install the gem:"
echo "   gem install lsql --source \"https://rubygems.pkg.github.com/egrif\""
echo ""

echo "💡 Tip: You can also add this to your ~/.gemrc file:"
echo "---"
echo ":sources:"
echo "- https://rubygems.org"
echo "- https://rubygems.pkg.github.com/egrif"
echo ""

read -p "Would you like to open the GitHub token creation page? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v open &> /dev/null; then
        open "https://github.com/settings/tokens/new?scopes=read:packages&description=LSQL%20Gem%20Access"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "https://github.com/settings/tokens/new?scopes=read:packages&description=LSQL%20Gem%20Access"
    else
        echo "Please visit: https://github.com/settings/tokens/new?scopes=read:packages&description=LSQL%20Gem%20Access"
    fi
fi

echo ""
echo "✅ Setup information provided!"
echo "After configuring your token, you can install LSQL with:"
echo "gem install lsql --source \"https://rubygems.pkg.github.com/egrif\""
