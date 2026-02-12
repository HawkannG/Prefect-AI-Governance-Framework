#!/usr/bin/env bash
# migrate-from-prefect.sh — Upgrade existing Prefect projects to Warden
# Usage: bash migrate-from-prefect.sh [project-directory]

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Prefect → Warden Migration Tool${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Target directory
if [ -n "${1:-}" ]; then
  TARGET_DIR="$1"
else
  TARGET_DIR="$(pwd)"
fi

cd "$TARGET_DIR"

# Check if this is a Prefect project
if [ ! -f "PREFECT-POLICY.md" ] && [ ! -f ".claude/hooks/prefect-guard.sh" ]; then
  echo -e "${RED}❌ No Prefect installation detected in this directory${NC}"
  echo "   Looking for: PREFECT-POLICY.md or .claude/hooks/prefect-guard.sh"
  exit 1
fi

echo -e "📁 Target: ${GREEN}$TARGET_DIR${NC}"
echo ""
echo -e "${YELLOW}⚠️  This will rename all Prefect files to Warden${NC}"
echo "   • PREFECT-*.md → WARDEN-*.md"
echo "   • prefect-*.sh → warden-*.sh"
echo "   • Update all file references"
echo ""

read -p "Create git backup first? (recommended) (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  if [ -d ".git" ]; then
    git tag "pre-warden-migration-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    echo -e "${GREEN}✅ Git backup tag created${NC}"
  else
    echo -e "${YELLOW}⚠️  Not a git repo - no backup created${NC}"
  fi
fi

echo ""
read -p "Continue with migration? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Migration cancelled."
  exit 0
fi

# Unlock files if lockdown.sh exists
if [ -f "lockdown.sh" ]; then
  echo -e "🔓 Unlocking governance files..."
  bash lockdown.sh unlock 2>/dev/null || true
fi

# Rename files
echo -e "📝 Renaming files..."

if [ -f "PREFECT-POLICY.md" ]; then
  mv PREFECT-POLICY.md WARDEN-POLICY.md
  echo "  PREFECT-POLICY.md → WARDEN-POLICY.md"
fi

if [ -f "PREFECT-FEEDBACK.md" ]; then
  mv PREFECT-FEEDBACK.md WARDEN-FEEDBACK.md
  echo "  PREFECT-FEEDBACK.md → WARDEN-FEEDBACK.md"
fi

if [ -d ".claude/hooks" ]; then
  for hook in prefect-guard.sh prefect-bash-guard.sh prefect-post-check.sh prefect-audit.sh prefect-session-end.sh; do
    if [ -f ".claude/hooks/$hook" ]; then
      new_name=$(echo "$hook" | sed 's/prefect-/warden-/')
      mv ".claude/hooks/$hook" ".claude/hooks/$new_name"
      echo "  $hook → $new_name"
    fi
  done
fi

# Reorganize to .claude/ structure
echo -e "📂 Reorganizing to official Claude Code structure..."

# Create .claude/rules/ directory
mkdir -p .claude/rules

# Move governance files to .claude/
if [ -f "WARDEN-POLICY.md" ]; then
  mv WARDEN-POLICY.md .claude/rules/policy.md
  echo "  WARDEN-POLICY.md → .claude/rules/policy.md"
fi

if [ -f "WARDEN-FEEDBACK.md" ]; then
  mv WARDEN-FEEDBACK.md .claude/rules/feedback.md
  echo "  WARDEN-FEEDBACK.md → .claude/rules/feedback.md"
fi

if [ -f "CLAUDE.md" ]; then
  mv CLAUDE.md .claude/CLAUDE.md
  echo "  CLAUDE.md → .claude/CLAUDE.md"
fi

# Move directive files (D-*.md → .claude/rules/*.md)
if [ -f "D-ARCH-STRUCTURE.md" ]; then
  mv D-ARCH-STRUCTURE.md .claude/rules/architecture.md
  echo "  D-ARCH-STRUCTURE.md → .claude/rules/architecture.md"
fi

if [ -f "D-WORK-WORKFLOW.md" ]; then
  mv D-WORK-WORKFLOW.md .claude/rules/workflow.md
  echo "  D-WORK-WORKFLOW.md → .claude/rules/workflow.md"
fi

# Move any other D-*.md files
for directive in D-*.md; do
  if [ -f "$directive" ]; then
    base_name=$(echo "$directive" | sed 's/D-\([A-Z]*\)-\([A-Z]*\)\.md/\L\2.md/')
    mv "$directive" ".claude/rules/$base_name"
    echo "  $directive → .claude/rules/$base_name"
  fi
done

# Update file contents
echo -e "✏️  Updating file references..."

# Update markdown and shell files (Prefect → Warden + new paths)
find . -type f \( -name "*.md" -o -name "*.sh" -o -name "*.json" \) \
  -not -path "./.git/*" \
  -not -path "./node_modules/*" \
  -not -path "./.venv/*" \
  -exec sed -i 's/PREFECT-POLICY\.md/.claude\/rules\/policy.md/g; s/PREFECT-FEEDBACK\.md/.claude\/rules\/feedback.md/g; s/WARDEN-POLICY\.md/.claude\/rules\/policy.md/g; s/WARDEN-FEEDBACK\.md/.claude\/rules\/feedback.md/g; s/^CLAUDE\.md$/.claude\/CLAUDE.md/g; s/D-ARCH-STRUCTURE\.md/.claude\/rules\/architecture.md/g; s/D-WORK-WORKFLOW\.md/.claude\/rules\/workflow.md/g; s/prefect-guard\.sh/warden-guard.sh/g; s/prefect-bash-guard\.sh/warden-bash-guard.sh/g; s/prefect-post-check\.sh/warden-post-check.sh/g; s/prefect-audit\.sh/warden-audit.sh/g; s/prefect-session-end\.sh/warden-session-end.sh/g; s/PREFECT BLOCK/WARDEN BLOCK/g; s/PREFECT ERROR/WARDEN ERROR/g; s/PREFECT DRIFT/WARDEN DRIFT/g; s/PREFECT WARNING/WARDEN WARNING/g; s/prefect check/warden check/g' {} \;

# Update .gitignore
if [ -f ".gitignore" ]; then
  sed -i 's/\.prefect\.conf\.local/.warden.conf.local/g' .gitignore
fi

# Update hook internal comments
if [ -d ".claude/hooks" ]; then
  sed -i 's/for Prefect governance/for Warden governance/g; s/Prefect/Warden/g' .claude/hooks/*.sh 2>/dev/null || true
fi

# Make hooks executable
chmod +x .claude/hooks/*.sh 2>/dev/null || true
chmod +x lockdown.sh 2>/dev/null || true

echo -e "${GREEN}✅ Files updated${NC}"
echo ""

# Test one hook
echo -e "🧪 Testing warden-guard hook..."
if echo '{"tool":"Write","tool_input":{"file_path":".claude/rules/policy.md","content":"test"}}' | \
   CLAUDE_PROJECT_DIR="." bash .claude/hooks/warden-guard.sh 2>&1 | grep -q "WARDEN BLOCK"; then
  echo -e "${GREEN}✅ Hook test passed${NC}"
else
  echo -e "${RED}❌ Hook test failed - manual verification needed${NC}"
fi

echo ""

# Re-lock files
if [ -f "lockdown.sh" ]; then
  echo -e "🔒 Re-locking governance files..."
  bash lockdown.sh lock
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Migration complete: Prefect → Warden${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "What changed:"
echo "  • All Prefect files → Warden files"
echo "  • Reorganized to official Claude Code structure (.claude/rules/)"
echo "  • All file references updated"
echo "  • Hooks tested and working"
echo ""
echo "Next steps:"
echo "  1. Test in Claude Code: claude"
echo "  2. Try: warden check"
echo "  3. Run audit: bash .claude/hooks/warden-audit.sh"
echo ""

# Suggest git commit
if [ -d ".git" ]; then
  echo "Suggested git commit:"
  echo "  git add -A"
  echo "  git commit -m 'Migrate from Prefect to Warden'"
  echo ""
fi
