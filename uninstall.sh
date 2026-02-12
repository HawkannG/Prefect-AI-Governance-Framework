#!/usr/bin/env bash
# uninstall.sh - Remove Claude Warden from your project
# Usage: bash uninstall.sh

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}=================================================${NC}"
echo -e "${RED}  Claude Warden - Uninstall${NC}"
echo -e "${RED}=================================================${NC}"
echo ""
echo -e "${YELLOW}WARNING  This will remove ALL Warden governance from this project.${NC}"
echo ""
echo "Files that will be deleted:"
echo "  - .claude/ directory (CLAUDE.md, rules/, hooks/, settings.json)"
echo "  - docs/PRODUCT-SPEC.md, docs/AI-UAT-CHECKLIST.md, docs/SESSION-LOG.md"
echo "  - lockdown.sh"
echo ""
read -p "Continue with uninstall? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Uninstall cancelled."
  exit 0
fi

# Unlock files first
if [ -f "lockdown.sh" ]; then
  echo -e "Unlocking Unlocking governance files..."
  bash lockdown.sh unlock 2>/dev/null || true
fi

# Remove .claude directory (contains all governance)
echo -e "Removing  Removing .claude/ directory..."
rm -rf .claude/

# Remove lockdown script
echo -e "Removing  Removing lockdown.sh..."
rm -f lockdown.sh

# Remove docs (optional - ask first)
if [ -d "docs" ]; then
  echo ""
  read -p "Remove docs/ directory? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f docs/PRODUCT-SPEC.md
    rm -f docs/AI-UAT-CHECKLIST.md
    rm -f docs/SESSION-LOG.md
    # Only remove docs/ if it's empty
    rmdir docs 2>/dev/null || echo "  (kept docs/ - not empty)"
  fi
fi

# Verify removal
echo ""
echo -e "Verifying Verifying removal..."
REMAINING=$(ls -la 2>/dev/null | grep -iE "(warden|claude)" | wc -l || echo 0)

if [ "$REMAINING" -eq 0 ]; then
  echo -e "${GREEN}OK Claude Warden completely removed${NC}"
else
  echo -e "${YELLOW}WARNING  Some files may remain:${NC}"
  ls -la | grep -iE "(warden|claude)" || true
fi

echo ""
echo -e "${GREEN}=================================================${NC}"
echo -e "Uninstall complete."
echo ""
echo "Your project is no longer governed by Warden."
echo "Claude Code will operate without governance hooks."
echo ""
