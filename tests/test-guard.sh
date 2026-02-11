#!/usr/bin/env bash
set -euo pipefail
# test-guard.sh — Tests for prefect-guard.sh hook
# Tests file protection, structure enforcement, and governance rules
# Usage: bash tests/test-guard.sh [project-dir]

PROJECT_DIR="${1:-.}"
HOOK="$PROJECT_DIR/.claude/hooks/prefect-guard.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
  echo -e "${GREEN}  ✓${NC} $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
}

test_fail() {
  echo -e "${RED}  ✗${NC} $1 - Expected: $2, Got: $3"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
}

run_test() {
  local json_input="$1"
  local expected_exit="$2"
  local description="$3"

  export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
  local actual_exit=0
  echo "$json_input" | bash "$HOOK" >/dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    test_pass "$description"
  else
    test_fail "$description" "exit $expected_exit" "exit $actual_exit"
  fi
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️  PREFECT-GUARD.SH HOOK TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ══════════════════════════════════════════════════════════════
# RULE 0: SELF-PROTECTION TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Rule 0: Self-Protection (Human-Only Files)"
echo "────────────────────────────────────────"

# CLAUDE.md protection
run_test '{"tool_name":"Write","tool_input":{"file_path":"CLAUDE.md","content":"hacked"}}' 1 \
  "R0.1: Block Write to CLAUDE.md"

run_test '{"tool_name":"Edit","tool_input":{"file_path":"CLAUDE.md","old_string":"old","new_string":"new"}}' 1 \
  "R0.2: Block Edit to CLAUDE.md"

run_test '{"tool_name":"Write","tool_input":{"file_path":"./CLAUDE.md","content":"hacked"}}' 1 \
  "R0.3: Block Write to CLAUDE.md (with ./)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"docs/../CLAUDE.md","content":"hacked"}}' 1 \
  "R0.4: Block Write to CLAUDE.md (via path traversal)"

# PREFECT-POLICY.md protection
run_test '{"tool_name":"Write","tool_input":{"file_path":"PREFECT-POLICY.md","content":"hacked"}}' 1 \
  "R0.5: Block Write to PREFECT-POLICY.md"

run_test '{"tool_name":"Edit","tool_input":{"file_path":"PREFECT-POLICY.md","old_string":"§1","new_string":"§2"}}' 1 \
  "R0.6: Block Edit to PREFECT-POLICY.md"

# Hook scripts protection
run_test '{"tool_name":"Write","tool_input":{"file_path":".claude/hooks/prefect-guard.sh","content":"#!/bin/bash"}}' 1 \
  "R0.7: Block Write to prefect-guard.sh"

run_test '{"tool_name":"Write","tool_input":{"file_path":".claude/hooks/prefect-bash-guard.sh","content":"#!/bin/bash"}}' 1 \
  "R0.8: Block Write to prefect-bash-guard.sh"

run_test '{"tool_name":"Write","tool_input":{"file_path":".claude/hooks/prefect-audit.sh","content":"#!/bin/bash"}}' 1 \
  "R0.9: Block Write to prefect-audit.sh"

run_test '{"tool_name":"Write","tool_input":{"file_path":".claude/hooks/prefect-post-check.sh","content":"#!/bin/bash"}}' 1 \
  "R0.10: Block Write to prefect-post-check.sh"

run_test '{"tool_name":"Write","tool_input":{"file_path":".claude/hooks/prefect-session-end.sh","content":"#!/bin/bash"}}' 1 \
  "R0.11: Block Write to prefect-session-end.sh"

# New hook creation should also be blocked
run_test '{"tool_name":"Write","tool_input":{"file_path":".claude/hooks/custom-hook.sh","content":"#!/bin/bash"}}' 1 \
  "R0.12: Block creation of new hook in .claude/hooks/"

# settings.json protection
run_test '{"tool_name":"Write","tool_input":{"file_path":".claude/settings.json","content":"{}"}}' 1 \
  "R0.13: Block Write to settings.json"

run_test '{"tool_name":"Edit","tool_input":{"file_path":".claude/settings.json","old_string":"hooks","new_string":"none"}}' 1 \
  "R0.14: Block Edit to settings.json"

# ══════════════════════════════════════════════════════════════
# RULE 1: ROOT LOCKDOWN TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Rule 1: Root Directory Lockdown"
echo "────────────────────────────────────────"

# Allowed root files (should pass)
run_test '{"tool_name":"Write","tool_input":{"file_path":"README.md","content":"# Project"}}' 0 \
  "R1.1: Allow Write to README.md (allowed root file)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"LICENSE","content":"MIT License"}}' 0 \
  "R1.2: Allow Write to LICENSE (allowed root file)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"package.json","content":"{}"}}' 0 \
  "R1.3: Allow Write to package.json (allowed root file)"

run_test '{"tool_name":"Write","tool_input":{"file_path":".gitignore","content":"node_modules/"}}' 0 \
  "R1.4: Allow Write to .gitignore (allowed root file)"

# Directive files (D-*.md pattern should be allowed at root)
run_test '{"tool_name":"Write","tool_input":{"file_path":"D-ARCH-STRUCTURE.md","content":"# Architecture"}}' 0 \
  "R1.5: Allow Write to D-ARCH-STRUCTURE.md (directive)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"D-DATA-MODELS.md","content":"# Models"}}' 0 \
  "R1.6: Allow Write to D-DATA-MODELS.md (directive)"

# Unauthorized root files (should block)
run_test '{"tool_name":"Write","tool_input":{"file_path":"random-file.txt","content":"bad"}}' 1 \
  "R1.7: Block Write to unauthorized root file (random-file.txt)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"notes.md","content":"notes"}}' 1 \
  "R1.8: Block Write to unauthorized root file (notes.md)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"temp.js","content":"console.log()"}}' 1 \
  "R1.9: Block Write to unauthorized root file (temp.js)"

# Subdirectory files (should allow)
run_test '{"tool_name":"Write","tool_input":{"file_path":"src/index.ts","content":"export {}"}}' 0 \
  "R1.10: Allow Write to subdirectory file (src/index.ts)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"docs/guide.md","content":"# Guide"}}' 0 \
  "R1.11: Allow Write to subdirectory file (docs/guide.md)"

# ══════════════════════════════════════════════════════════════
# RULE 2: DIRECTORY DEPTH LIMIT TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Rule 2: Directory Depth Limit (Max 5 Levels)"
echo "────────────────────────────────────────"

# Depth 1-5 (should allow)
run_test '{"tool_name":"Write","tool_input":{"file_path":"level1/file.txt","content":"ok"}}' 0 \
  "R2.1: Allow depth 1 (level1/file.txt)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"level1/level2/file.txt","content":"ok"}}' 0 \
  "R2.2: Allow depth 2 (level1/level2/file.txt)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"level1/level2/level3/file.txt","content":"ok"}}' 0 \
  "R2.3: Allow depth 3 (level1/level2/level3/file.txt)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"level1/level2/level3/level4/file.txt","content":"ok"}}' 0 \
  "R2.4: Allow depth 4 (level1/.../level4/file.txt)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"level1/level2/level3/level4/level5/file.txt","content":"ok"}}' 0 \
  "R2.5: Allow depth 5 (level1/.../level5/file.txt)"

# Depth 6+ (should block)
run_test '{"tool_name":"Write","tool_input":{"file_path":"a/b/c/d/e/f/file.txt","content":"bad"}}' 1 \
  "R2.6: Block depth 6 (a/b/c/d/e/f/file.txt)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"a/b/c/d/e/f/g/file.txt","content":"bad"}}' 1 \
  "R2.7: Block depth 7 (a/.../g/file.txt)"

# ══════════════════════════════════════════════════════════════
# RULE 3: FORBIDDEN DIRECTORY NAMES TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Rule 3: Forbidden Directory Names"
echo "────────────────────────────────────────"

# Forbidden directory names (should block)
run_test '{"tool_name":"Write","tool_input":{"file_path":"temp/file.txt","content":"bad"}}' 1 \
  "R3.1: Block temp/ directory"

run_test '{"tool_name":"Write","tool_input":{"file_path":"tmp/file.txt","content":"bad"}}' 1 \
  "R3.2: Block tmp/ directory"

run_test '{"tool_name":"Write","tool_input":{"file_path":"misc/file.txt","content":"bad"}}' 1 \
  "R3.3: Block misc/ directory"

run_test '{"tool_name":"Write","tool_input":{"file_path":"old/file.txt","content":"bad"}}' 1 \
  "R3.4: Block old/ directory"

run_test '{"tool_name":"Write","tool_input":{"file_path":"backup/file.txt","content":"bad"}}' 1 \
  "R3.5: Block backup/ directory"

run_test '{"tool_name":"Write","tool_input":{"file_path":"scratch/file.txt","content":"bad"}}' 1 \
  "R3.6: Block scratch/ directory"

run_test '{"tool_name":"Write","tool_input":{"file_path":"junk/file.txt","content":"bad"}}' 1 \
  "R3.7: Block junk/ directory"

# Case-insensitive (should block TEMP, Temp, etc.)
run_test '{"tool_name":"Write","tool_input":{"file_path":"TEMP/file.txt","content":"bad"}}' 1 \
  "R3.8: Block TEMP/ (uppercase)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"Temp/file.txt","content":"bad"}}' 1 \
  "R3.9: Block Temp/ (mixed case)"

# Nested forbidden directories
run_test '{"tool_name":"Write","tool_input":{"file_path":"src/temp/file.txt","content":"bad"}}' 1 \
  "R3.10: Block temp/ nested in allowed directory"

run_test '{"tool_name":"Write","tool_input":{"file_path":"docs/old/guide.md","content":"bad"}}' 1 \
  "R3.11: Block old/ nested in docs/"

# Allowed directories (should pass)
run_test '{"tool_name":"Write","tool_input":{"file_path":"src/components/Button.tsx","content":"ok"}}' 0 \
  "R3.12: Allow legitimate directory (src/components/)"

run_test '{"tool_name":"Write","tool_input":{"file_path":"tests/unit/test.ts","content":"ok"}}' 0 \
  "R3.13: Allow tests/ directory (not forbidden)"

# ══════════════════════════════════════════════════════════════
# RULE 4: DIRECTIVE SIZE LIMIT TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Rule 4: Directive Size Limit (300 lines)"
echo "────────────────────────────────────────"

# Create test directive files
mkdir -p "$PROJECT_DIR"
echo "Testing directive size limits..."

# Create small directive (should allow)
{
  for i in {1..100}; do echo "Line $i"; done
} > "$PROJECT_DIR/D-TEST-SMALL.md"

run_test '{"tool_name":"Edit","tool_input":{"file_path":"D-TEST-SMALL.md","old_string":"Line 1","new_string":"Line 1 edited"}}' 0 \
  "R4.1: Allow edit to small directive (100 lines)"

# Create large directive (should block)
{
  for i in {1..350}; do echo "Line $i"; done
} > "$PROJECT_DIR/D-TEST-LARGE.md"

run_test '{"tool_name":"Edit","tool_input":{"file_path":"D-TEST-LARGE.md","old_string":"Line 1","new_string":"Line 1 edited"}}' 1 \
  "R4.2: Block edit to oversized directive (350 lines)"

# Cleanup
rm -f "$PROJECT_DIR/D-TEST-SMALL.md" "$PROJECT_DIR/D-TEST-LARGE.md"

# ══════════════════════════════════════════════════════════════
# RULE 5: SOURCE FILE SIZE WARNING TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Rule 5: Source File Size Warning (250 lines soft limit)"
echo "────────────────────────────────────────"

# Note: This rule is a warning, not a block (still exit 0)
# Create large source file
mkdir -p "$PROJECT_DIR/src"
{
  for i in {1..300}; do echo "const line$i = $i;"; done
} > "$PROJECT_DIR/src/large.ts"

# Should allow but warn
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
output=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"src/large.ts","old_string":"line1","new_string":"line1_edited"}}' | \
  bash "$HOOK" 2>&1 || true)

if echo "$output" | grep -q "PREFECT WARNING"; then
  test_pass "R5.1: Warn about oversized source file (300 lines, still allows)"
else
  test_fail "R5.1: Source file size warning" "warning message" "no warning"
fi

# Cleanup
rm -f "$PROJECT_DIR/src/large.ts"

# ══════════════════════════════════════════════════════════════
# EDGE CASES
# ══════════════════════════════════════════════════════════════
echo ""
echo "Edge Cases"
echo "────────────────────────────────────────"

# Hidden files (dotfiles)
run_test '{"tool_name":"Write","tool_input":{"file_path":"src/.config.json","content":"{}"}}' 0 \
  "E1: Allow hidden file in subdirectory (.config.json)"

# Files with multiple dots
run_test '{"tool_name":"Write","tool_input":{"file_path":"src/file.test.ts","content":"test"}}' 0 \
  "E2: Allow file with multiple dots (file.test.ts)"

# Allowed root dotfiles
run_test '{"tool_name":"Write","tool_input":{"file_path":".eslintrc.json","content":"{}"}}' 0 \
  "E3: Allow .eslintrc.json at root (in ALLOWED_ROOT)"

# Directory that starts with forbidden name but isn't exact match
run_test '{"tool_name":"Write","tool_input":{"file_path":"temporary/file.txt","content":"ok"}}' 0 \
  "E4: Allow 'temporary' directory (not exact 'temp')"

run_test '{"tool_name":"Write","tool_input":{"file_path":"templates/file.txt","content":"ok"}}' 0 \
  "E5: Allow 'templates' directory (not exact 'temp')"

# ══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ══════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Guard Hook Tests Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  exit 1
else
  echo "Failed: 0"
  echo -e "${GREEN}✓ ALL GUARD TESTS PASSED${NC}"
  exit 0
fi
