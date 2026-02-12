#!/usr/bin/env bash
# install.sh — One-command installer for Claude Warden
# Usage: curl -fsSL https://raw.githubusercontent.com/HawkannG/Claude-Warden/main/install.sh | bash

set -euo pipefail

WARDEN_VERSION="1.0.0"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Claude Warden AI Governance Framework v${WARDEN_VERSION}${NC}"
echo -e "${BLUE}  Installation Wizard${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Detect target directory
if [ -n "${1:-}" ]; then
  TARGET_DIR="$1"
else
  TARGET_DIR="$(pwd)"
fi

echo -e "📁 Target directory: ${GREEN}$TARGET_DIR${NC}"
echo ""

# Check if target is a git repo
if [ ! -d "$TARGET_DIR/.git" ]; then
  echo -e "${YELLOW}⚠️  Warning: Target is not a git repository${NC}"
  echo "   Warden works best with git projects"
  read -p "   Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
  fi
fi

# Check for jq
if ! command -v jq &>/dev/null; then
  echo -e "${YELLOW}⚠️  jq is required but not installed${NC}"
  echo ""
  echo "Install jq:"
  echo "  macOS:        brew install jq"
  echo "  Ubuntu/Debian: sudo apt-get install jq"
  echo "  Windows:      winget install jqlang.jq"
  echo ""
  exit 1
fi

# Check for existing .claude/settings.json
if [ -f "$TARGET_DIR/.claude/settings.json" ]; then
  echo -e "${YELLOW}⚠️  .claude/settings.json already exists${NC}"
  read -p "   Overwrite? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled. Use migrate-from-prefect.sh if upgrading."
    exit 0
  fi
fi

# Create directories
echo -e "📂 Creating directory structure..."
mkdir -p "$TARGET_DIR/.claude/hooks"
mkdir -p "$TARGET_DIR/.claude/lib"
mkdir -p "$TARGET_DIR/.claude/rules"
mkdir -p "$TARGET_DIR/docs"

# Download files from GitHub
REPO_URL="https://raw.githubusercontent.com/HawkannG/Claude-Warden/main"

echo -e "⬇️  Downloading Warden files..."

# Core governance files
curl -fsSL "$REPO_URL/.claude/CLAUDE.md" -o "$TARGET_DIR/.claude/CLAUDE.md"
curl -fsSL "$REPO_URL/.claude/rules/policy.md" -o "$TARGET_DIR/.claude/rules/policy.md"
curl -fsSL "$REPO_URL/.claude/rules/feedback.md" -o "$TARGET_DIR/.claude/rules/feedback.md"

# Rules files
curl -fsSL "$REPO_URL/.claude/rules/architecture.md" -o "$TARGET_DIR/.claude/rules/architecture.md"
curl -fsSL "$REPO_URL/.claude/rules/workflow.md" -o "$TARGET_DIR/.claude/rules/workflow.md"

# Product docs
curl -fsSL "$REPO_URL/docs/PRODUCT-SPEC.md" -o "$TARGET_DIR/docs/PRODUCT-SPEC.md"
curl -fsSL "$REPO_URL/docs/AI-UAT-CHECKLIST.md" -o "$TARGET_DIR/docs/AI-UAT-CHECKLIST.md"

# Hooks
curl -fsSL "$REPO_URL/.claude/hooks/warden-guard.sh" -o "$TARGET_DIR/.claude/hooks/warden-guard.sh"
curl -fsSL "$REPO_URL/.claude/hooks/warden-bash-guard.sh" -o "$TARGET_DIR/.claude/hooks/warden-bash-guard.sh"
curl -fsSL "$REPO_URL/.claude/hooks/warden-post-check.sh" -o "$TARGET_DIR/.claude/hooks/warden-post-check.sh"
curl -fsSL "$REPO_URL/.claude/hooks/warden-audit.sh" -o "$TARGET_DIR/.claude/hooks/warden-audit.sh"
curl -fsSL "$REPO_URL/.claude/hooks/warden-session-end.sh" -o "$TARGET_DIR/.claude/hooks/warden-session-end.sh"

# Utilities
curl -fsSL "$REPO_URL/.claude/lib/path-utils.sh" -o "$TARGET_DIR/.claude/lib/path-utils.sh"

# Settings
curl -fsSL "$REPO_URL/.claude/settings.json" -o "$TARGET_DIR/.claude/settings.json"

# Scripts
curl -fsSL "$REPO_URL/lockdown.sh" -o "$TARGET_DIR/lockdown.sh"

# Make scripts executable
chmod +x "$TARGET_DIR/.claude/hooks/"*.sh
chmod +x "$TARGET_DIR/lockdown.sh"

echo -e "${GREEN}✅ Files installed${NC}"
echo ""

# Customize .claude/CLAUDE.md
echo -e "✏️  Customizing .claude/CLAUDE.md..."
echo ""
read -p "Project name: " PROJECT_NAME
read -p "Project description: " PROJECT_DESC
read -p "Tech stack (e.g., Next.js 14, FastAPI): " TECH_STACK

sed -i "s/\[PROJECT_NAME\]/$PROJECT_NAME/g" "$TARGET_DIR/.claude/CLAUDE.md"
sed -i "s/\[Brief description of what this project does\]/$PROJECT_DESC/g" "$TARGET_DIR/.claude/CLAUDE.md"
sed -i "s/\[e.g., Next.js 14, FastAPI, PostgreSQL, S3\]/$TECH_STACK/g" "$TARGET_DIR/.claude/CLAUDE.md"

echo -e "${GREEN}✅ .claude/CLAUDE.md customized${NC}"
echo ""

# Lock governance files
echo -e "🔒 Locking governance files..."
cd "$TARGET_DIR" && bash lockdown.sh lock

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Claude Warden installed successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo "  1. Review .claude/CLAUDE.md and customize further if needed"
echo "  2. Edit docs/PRODUCT-SPEC.md to describe your project"
echo "  3. Start Claude Code: claude"
echo ""
echo "Commands:"
echo "  warden check     - Verify governance is active"
echo "  bash .claude/hooks/warden-audit.sh - Check project health"
echo "  ./lockdown.sh status - View locked files"
echo ""
echo "Documentation: https://github.com/HawkannG/Claude-Warden"
echo ""
