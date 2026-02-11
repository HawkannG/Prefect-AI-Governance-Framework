#!/usr/bin/env bash
set -euo pipefail
# test-bash-guard.sh — Tests for prefect-bash-guard.sh hook
# Tests bash command filtering and protection bypass prevention
# Usage: bash tests/test-bash-guard.sh [project-dir]

PROJECT_DIR="${1:-.}"
HOOK="$PROJECT_DIR/.claude/hooks/prefect-bash-guard.sh"

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
echo "🛡️  PREFECT-BASH-GUARD.SH HOOK TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ══════════════════════════════════════════════════════════════
# RULE 1: PROTECT GOVERNANCE FILES FROM BASH WRITES
# ══════════════════════════════════════════════════════════════
echo ""
echo "Rule 1: Protect Governance Files from Bash Writes"
echo "────────────────────────────────────────"

# Redirect attacks
run_test '{"tool_name":"Bash","tool_input":{"command":"echo hacked > CLAUDE.md"}}' 1 \
  "B1.1: Block echo redirect to CLAUDE.md"

run_test '{"tool_name":"Bash","tool_input":{"command":"echo hacked >> CLAUDE.md"}}' 1 \
  "B1.2: Block echo append to CLAUDE.md"

run_test '{"tool_name":"Bash","tool_input":{"command":"cat evil.txt > PREFECT-POLICY.md"}}' 1 \
  "B1.3: Block cat redirect to PREFECT-POLICY.md"

run_test '{"tool_name":"Bash","tool_input":{"command":"printf 'bad' > CLAUDE.md"}}' 1 \
  "B1.4: Block printf redirect to CLAUDE.md"

# tee attacks
run_test '{"tool_name":"Bash","tool_input":{"command":"echo hacked | tee CLAUDE.md"}}' 1 \
  "B1.5: Block tee to CLAUDE.md"

run_test '{"tool_name":"Bash","tool_input":{"command":"cat bad.txt | tee PREFECT-POLICY.md"}}' 1 \
  "B1.6: Block tee to PREFECT-POLICY.md"

run_test '{"tool_name":"Bash","tool_input":{"command":"echo bad | tee -a CLAUDE.md"}}' 1 \
  "B1.7: Block tee append to CLAUDE.md"

# sed -i attacks
run_test '{"tool_name":"Bash","tool_input":{"command":"sed -i \"s/NEVER/ALWAYS/\" CLAUDE.md"}}' 1 \
  "B1.8: Block sed -i on CLAUDE.md"

run_test '{"tool_name":"Bash","tool_input":{"command":"sed -i \"/RULE 0/d\" PREFECT-POLICY.md"}}' 1 \
  "B1.9: Block sed -i delete on PREFECT-POLICY.md"

# mv attacks (overwrite protected file)
run_test '{"tool_name":"Bash","tool_input":{"command":"mv /tmp/evil.md CLAUDE.md"}}' 1 \
  "B1.10: Block mv to overwrite CLAUDE.md"

run_test '{"tool_name":"Bash","tool_input":{"command":"mv temp.txt PREFECT-POLICY.md"}}' 1 \
  "B1.11: Block mv to overwrite PREFECT-POLICY.md"

# cp attacks (overwrite protected file)
run_test '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/evil.md CLAUDE.md"}}' 1 \
  "B1.12: Block cp to overwrite CLAUDE.md"

run_test '{"tool_name":"Bash","tool_input":{"command":"cp -f bad.txt PREFECT-POLICY.md"}}' 1 \
  "B1.13: Block cp -f to overwrite PREFECT-POLICY.md"

# rm attacks
run_test '{"tool_name":"Bash","tool_input":{"command":"rm CLAUDE.md"}}' 1 \
  "B1.14: Block rm CLAUDE.md"

run_test '{"tool_name":"Bash","tool_input":{"command":"rm -f PREFECT-POLICY.md"}}' 1 \
  "B1.15: Block rm -f PREFECT-POLICY.md"

# chmod/chown attacks
run_test '{"tool_name":"Bash","tool_input":{"command":"chmod 777 CLAUDE.md"}}' 1 \
  "B1.16: Block chmod on CLAUDE.md"

run_test '{"tool_name":"Bash","tool_input":{"command":"chown user:group PREFECT-POLICY.md"}}' 1 \
  "B1.17: Block chown on PREFECT-POLICY.md"

# ══════════════════════════════════════════════════════════════
# RULE 2: BLOCK HOOK SELF-MODIFICATION
# ══════════════════════════════════════════════════════════════
echo ""
echo "Rule 2: Block Hook Self-Modification"
echo "────────────────────────────────────────"

# Direct modification attacks
run_test '{"tool_name":"Bash","tool_input":{"command":"echo \"exit 0\" > .claude/hooks/prefect-guard.sh"}}' 1 \
  "B2.1: Block redirect to prefect-guard.sh"

run_test '{"tool_name":"Bash","tool_input":{"command":"sed -i \"s/exit 1/exit 0/\" .claude/hooks/prefect-bash-guard.sh"}}' 1 \
  "B2.2: Block sed -i on prefect-bash-guard.sh"

run_test '{"tool_name":"Bash","tool_input":{"command":"rm .claude/hooks/prefect-guard.sh"}}' 1 \
  "B2.3: Block rm of prefect-guard.sh"

run_test '{"tool_name":"Bash","tool_input":{"command":"mv /tmp/evil.sh .claude/hooks/prefect-guard.sh"}}' 1 \
  "B2.4: Block mv to replace prefect-guard.sh"

run_test '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/evil.sh .claude/hooks/prefect-audit.sh"}}' 1 \
  "B2.5: Block cp to replace prefect-audit.sh"

run_test '{"tool_name":"Bash","tool_input":{"command":"chmod +x .claude/hooks/prefect-session-end.sh"}}' 1 \
  "B2.6: Block chmod on prefect-session-end.sh"

# Editor attacks
run_test '{"tool_name":"Bash","tool_input":{"command":"vim .claude/hooks/prefect-guard.sh"}}' 1 \
  "B2.7: Block vim on prefect-guard.sh"

run_test '{"tool_name":"Bash","tool_input":{"command":"nano .claude/hooks/prefect-bash-guard.sh"}}' 1 \
  "B2.8: Block nano on prefect-bash-guard.sh"

run_test '{"tool_name":"Bash","tool_input":{"command":"vi .claude/hooks/prefect-audit.sh"}}' 1 \
  "B2.9: Block vi on prefect-audit.sh"

run_test '{"tool_name":"Bash","tool_input":{"command":"emacs .claude/hooks/prefect-post-check.sh"}}' 1 \
  "B2.10: Block emacs on prefect-post-check.sh (via edit pattern)"

# ══════════════════════════════════════════════════════════════
# RULE 3: BLOCK SETTINGS.JSON MODIFICATION
# ══════════════════════════════════════════════════════════════
echo ""
echo "Rule 3: Block settings.json Modification"
echo "────────────────────────────────────────"

run_test '{"tool_name":"Bash","tool_input":{"command":"echo {} > .claude/settings.json"}}' 1 \
  "B3.1: Block redirect to settings.json"

run_test '{"tool_name":"Bash","tool_input":{"command":"cat new.json > .claude/settings.json"}}' 1 \
  "B3.2: Block cat redirect to settings.json"

run_test '{"tool_name":"Bash","tool_input":{"command":"echo bad | tee .claude/settings.json"}}' 1 \
  "B3.3: Block tee to settings.json"

run_test '{"tool_name":"Bash","tool_input":{"command":"sed -i \"s/hooks/none/\" .claude/settings.json"}}' 1 \
  "B3.4: Block sed -i on settings.json"

run_test '{"tool_name":"Bash","tool_input":{"command":"mv new.json .claude/settings.json"}}' 1 \
  "B3.5: Block mv to replace settings.json"

run_test '{"tool_name":"Bash","tool_input":{"command":"cp backup.json .claude/settings.json"}}' 1 \
  "B3.6: Block cp to replace settings.json"

run_test '{"tool_name":"Bash","tool_input":{"command":"rm .claude/settings.json"}}' 1 \
  "B3.7: Block rm settings.json"

# ══════════════════════════════════════════════════════════════
# RULE 4: BLOCK FORBIDDEN DIRECTORIES VIA BASH
# ══════════════════════════════════════════════════════════════
echo ""
echo "Rule 4: Block Forbidden Directories via Bash"
echo "────────────────────────────────────────"

# mkdir in forbidden directories
run_test '{"tool_name":"Bash","tool_input":{"command":"mkdir temp"}}' 1 \
  "B4.1: Block mkdir temp"

run_test '{"tool_name":"Bash","tool_input":{"command":"mkdir -p tmp/files"}}' 1 \
  "B4.2: Block mkdir -p tmp/"

run_test '{"tool_name":"Bash","tool_input":{"command":"mkdir misc"}}' 1 \
  "B4.3: Block mkdir misc"

run_test '{"tool_name":"Bash","tool_input":{"command":"mkdir backup"}}' 1 \
  "B4.4: Block mkdir backup"

# touch in forbidden directories
run_test '{"tool_name":"Bash","tool_input":{"command":"touch temp/file.txt"}}' 1 \
  "B4.5: Block touch in temp/"

run_test '{"tool_name":"Bash","tool_input":{"command":"touch old/file.md"}}' 1 \
  "B4.6: Block touch in old/"

# echo/cat to forbidden directories
run_test '{"tool_name":"Bash","tool_input":{"command":"echo test > scratch/file.txt"}}' 1 \
  "B4.7: Block echo redirect to scratch/"

run_test '{"tool_name":"Bash","tool_input":{"command":"cat file.txt > junk/output.txt"}}' 1 \
  "B4.8: Block cat redirect to junk/"

# cp/mv to forbidden directories
run_test '{"tool_name":"Bash","tool_input":{"command":"cp file.txt temp/"}}' 1 \
  "B4.9: Block cp to temp/"

run_test '{"tool_name":"Bash","tool_input":{"command":"mv file.txt backup/"}}' 1 \
  "B4.10: Block mv to backup/"

# Case-insensitive
run_test '{"tool_name":"Bash","tool_input":{"command":"mkdir TEMP"}}' 1 \
  "B4.11: Block mkdir TEMP (uppercase)"

run_test '{"tool_name":"Bash","tool_input":{"command":"touch Temp/file.txt"}}' 1 \
  "B4.12: Block touch in Temp/ (mixed case)"

# ══════════════════════════════════════════════════════════════
# ALLOWED BASH COMMANDS (SHOULD PASS)
# ══════════════════════════════════════════════════════════════
echo ""
echo "Allowed Bash Commands (Negative Tests)"
echo "────────────────────────────────────────"

# Read-only commands
run_test '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' 0 \
  "B5.1: Allow ls command"

run_test '{"tool_name":"Bash","tool_input":{"command":"cat README.md"}}' 0 \
  "B5.2: Allow cat (read) on README.md"

run_test '{"tool_name":"Bash","tool_input":{"command":"grep pattern file.txt"}}' 0 \
  "B5.3: Allow grep command"

run_test '{"tool_name":"Bash","tool_input":{"command":"find . -name \"*.ts\""}}' 0 \
  "B5.4: Allow find command"

run_test '{"tool_name":"Bash","tool_input":{"command":"git status"}}' 0 \
  "B5.5: Allow git status"

run_test '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' 0 \
  "B5.6: Allow npm test"

# Writes to allowed files
run_test '{"tool_name":"Bash","tool_input":{"command":"echo test > src/output.txt"}}' 0 \
  "B5.7: Allow echo redirect to allowed location (src/)"

run_test '{"tool_name":"Bash","tool_input":{"command":"cat input.txt > tests/output.txt"}}' 0 \
  "B5.8: Allow cat redirect to tests/"

run_test '{"tool_name":"Bash","tool_input":{"command":"echo data | tee docs/log.txt"}}' 0 \
  "B5.9: Allow tee to docs/"

# mkdir in allowed directories
run_test '{"tool_name":"Bash","tool_input":{"command":"mkdir -p src/components"}}' 0 \
  "B5.10: Allow mkdir in allowed location (src/)"

run_test '{"tool_name":"Bash","tool_input":{"command":"mkdir tests"}}' 0 \
  "B5.11: Allow mkdir tests (not forbidden)"

# ══════════════════════════════════════════════════════════════
# EDGE CASES & BYPASS ATTEMPTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Edge Cases & Bypass Attempts"
echo "────────────────────────────────────────"

# Command chaining with protected files
run_test '{"tool_name":"Bash","tool_input":{"command":"ls -la && echo bad > CLAUDE.md"}}' 1 \
  "E1: Block command chain ending with protected file write"

run_test '{"tool_name":"Bash","tool_input":{"command":"echo bad > CLAUDE.md && ls"}}' 1 \
  "E2: Block command chain starting with protected file write"

# Subshells
run_test '{"tool_name":"Bash","tool_input":{"command":"(echo bad > CLAUDE.md)"}}' 1 \
  "E3: Block subshell with protected file write"

# Here-doc (doesn't use >, should allow unless targeting protected file)
run_test '{"tool_name":"Bash","tool_input":{"command":"cat > CLAUDE.md <<EOF\\ndata\\nEOF"}}' 1 \
  "E4: Block here-doc to CLAUDE.md"

# Quotes and escaping
run_test '{"tool_name":"Bash","tool_input":{"command":"echo \"hacked\" > \"CLAUDE.md\""}}' 1 \
  "E5: Block quoted protected filename"

run_test '{"tool_name":"Bash","tool_input":{"command":"echo hacked > ./CLAUDE.md"}}' 1 \
  "E6: Block protected file with ./ prefix"

# Path variations
run_test '{"tool_name":"Bash","tool_input":{"command":"echo bad > ../CLAUDE.md"}}' 1 \
  "E7: Block protected file via relative path"

# Multiple redirects
run_test '{"tool_name":"Bash","tool_input":{"command":"echo test > file.txt && cat file.txt > CLAUDE.md"}}' 1 \
  "E8: Block multi-step redirect to protected file"

# Background processes
run_test '{"tool_name":"Bash","tool_input":{"command":"(echo bad > CLAUDE.md) &"}}' 1 \
  "E9: Block background process writing to protected file"

# Whitespace variations
run_test '{"tool_name":"Bash","tool_input":{"command":"echo bad>CLAUDE.md"}}' 1 \
  "E10: Block redirect without spaces"

run_test '{"tool_name":"Bash","tool_input":{"command":"echo bad  >  CLAUDE.md"}}' 1 \
  "E11: Block redirect with extra spaces"

# ══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ══════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Bash Guard Tests Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  exit 1
else
  echo "Failed: 0"
  echo -e "${GREEN}✓ ALL BASH GUARD TESTS PASSED${NC}"
  exit 0
fi
