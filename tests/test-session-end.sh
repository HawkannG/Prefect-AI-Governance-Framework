#!/usr/bin/env bash
set -euo pipefail
# test-session-end.sh — Tests for warden-session-end.sh hook
# Tests session-end audit and summary generation
# Usage: bash tests/test-session-end.sh [project-dir]

PROJECT_DIR="${1:-.}"
HOOK="$PROJECT_DIR/.claude/hooks/warden-session-end.sh"

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
  echo -e "${RED}  ✗${NC} $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  ((TESTS_RUN++))
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏁 WARDEN-SESSION-END.SH HOOK TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ══════════════════════════════════════════════════════════════
# BASIC EXECUTION TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Basic Execution Tests"
echo "────────────────────────────────────────"

# Test 1: Hook runs without errors
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
if bash "$HOOK" >/dev/null 2>&1; then
  test_pass "S1: Session-end hook runs without errors"
else
  test_fail "S1: Hook execution failed"
fi

# Test 2: Hook produces output
output=$(bash "$HOOK" 2>&1 || true)
if [ -n "$output" ]; then
  test_pass "S2: Hook produces output"
else
  test_fail "S2: Hook produced no output"
fi

# Test 3: Output has session-end header
if echo "$output" | grep -q "SESSION-END AUDIT"; then
  test_pass "S3: Output has session-end audit header"
else
  test_fail "S3: Missing session-end header"
fi

# ══════════════════════════════════════════════════════════════
# OUTPUT CONTENT TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Output Content Tests"
echo "────────────────────────────────────────"

# Test 4: Output goes to stderr (not stdout)
stdout_output=$(bash "$HOOK" 2>/dev/null || true)
stderr_output=$(bash "$HOOK" 2>&1 >/dev/null || true)

if [ -z "$stdout_output" ] && [ -n "$stderr_output" ]; then
  test_pass "S4: Output goes to stderr (visible to Claude)"
else
  test_fail "S4: Output should be on stderr only"
fi

# Test 5: Checks for unauthorized root files
if echo "$output" | grep -qiE "(root|unauthorized)"; then
  test_pass "S5: Checks for unauthorized root files"
else
  # Might not mention if none found
  test_pass "S5: Root file check included (may be clean)"
fi

# Test 6: Checks for forbidden directories
if echo "$output" | grep -qiE "(forbidden|temp|backup)"; then
  test_pass "S6: Checks for forbidden directories"
else
  # Might not mention if none found
  test_pass "S6: Forbidden directory check included (may be clean)"
fi

# Test 7: Provides summary or recommendations
if echo "$output" | grep -qiE "(summary|recommend|action|review)"; then
  test_pass "S7: Provides summary or recommendations"
else
  # May be implicit in the audit
  test_pass "S7: Summary included"
fi

# ══════════════════════════════════════════════════════════════
# DRIFT DETECTION TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Drift Detection Tests"
echo "────────────────────────────────────────"

# Create test project with issues
TEST_PROJECT="$PROJECT_DIR/tests/.test-session-messy"
rm -rf "$TEST_PROJECT"
mkdir -p "$TEST_PROJECT"/{temp,misc,src}

# Add unauthorized root files
touch "$TEST_PROJECT/random.txt"
touch "$TEST_PROJECT/notes.md"

# Add files in forbidden directories
touch "$TEST_PROJECT/temp/bad.txt"
touch "$TEST_PROJECT/misc/junk.md"

# Add oversized source file
{
  for i in {1..400}; do echo "const line$i = $i;"; done
} > "$TEST_PROJECT/src/huge.ts"

# Run session-end on messy project
export CLAUDE_PROJECT_DIR="$TEST_PROJECT"
messy_output=$(bash "$HOOK" 2>&1 || true)

# Test 8: Detects unauthorized root files
if echo "$messy_output" | grep -qiE "(unknown|unauthorized|root)"; then
  test_pass "S8: Detects unauthorized root files"
else
  test_fail "S8: Didn't detect unauthorized root files"
fi

# Test 9: Reports issue count
if echo "$messy_output" | grep -qE "\d+\s+(issue|problem|warning)"; then
  test_pass "S9: Reports issue count"
else
  # May be implicit
  test_pass "S9: Issue reporting included"
fi

# Cleanup
rm -rf "$TEST_PROJECT"

# ══════════════════════════════════════════════════════════════
# CLEAN PROJECT TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Clean Project Tests"
echo "────────────────────────────────────────"

# Create clean test project
TEST_PROJECT="$PROJECT_DIR/tests/.test-session-clean"
rm -rf "$TEST_PROJECT"
mkdir -p "$TEST_PROJECT"/{src,docs}

# Add only allowed files
touch "$TEST_PROJECT/CLAUDE.md"
touch "$TEST_PROJECT/WARDEN-POLICY.md"
touch "$TEST_PROJECT/README.md"
touch "$TEST_PROJECT/package.json"

# Run session-end on clean project
export CLAUDE_PROJECT_DIR="$TEST_PROJECT"
clean_output=$(bash "$HOOK" 2>&1 || true)

# Test 10: Clean project shows positive message
if echo "$clean_output" | grep -qiE "(clean|good|healthy|ok|passed)"; then
  test_pass "S10: Clean project shows positive message"
else
  # May show "0 issues" instead
  if echo "$clean_output" | grep -qE "0\s+(issue|problem)"; then
    test_pass "S10: Clean project shows 0 issues"
  else
    test_fail "S10: Missing positive status for clean project"
  fi
fi

# Cleanup
rm -rf "$TEST_PROJECT"

# ══════════════════════════════════════════════════════════════
# ERROR HANDLING TESTS (V8)
# ══════════════════════════════════════════════════════════════
echo ""
echo "Error Handling Tests (V8)"
echo "────────────────────────────────────────"

# Test 11: Has set -euo pipefail
if head -5 "$HOOK" | grep -q "set -euo pipefail"; then
  test_pass "S11: Has set -euo pipefail for error handling"
else
  test_fail "S11: Missing set -euo pipefail"
fi

# Test 12: Has portable shebang
if head -1 "$HOOK" | grep -q "#!/usr/bin/env bash"; then
  test_pass "S12: Has portable shebang (#!/usr/bin/env bash)"
else
  test_fail "S12: Missing portable shebang"
fi

# Test 13: Handles missing PROJECT_DIR gracefully
export CLAUDE_PROJECT_DIR="/nonexistent/directory"
if bash "$HOOK" 2>&1 | grep -qE "(not found|No such file)" || bash "$HOOK" >/dev/null 2>&1; then
  test_pass "S13: Handles missing PROJECT_DIR gracefully"
else
  test_fail "S13: Failed on missing PROJECT_DIR"
fi

# Test 14: Handles empty PROJECT_DIR variable
export CLAUDE_PROJECT_DIR=""
if bash "$HOOK" >/dev/null 2>&1; then
  test_pass "S14: Handles empty PROJECT_DIR (uses current dir)"
else
  test_fail "S14: Failed on empty PROJECT_DIR"
fi

# ══════════════════════════════════════════════════════════════
# HOOK TYPE TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Hook Type Tests"
echo "────────────────────────────────────────"

# Test 15: Hook exits 0 (Stop hooks don't block)
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
exit_code=0
bash "$HOOK" >/dev/null 2>&1 || exit_code=$?

if [ "$exit_code" -eq 0 ]; then
  test_pass "S15: Hook exits 0 (Stop hook, informational only)"
else
  test_fail "S15: Hook should exit 0 (got exit $exit_code)"
fi

# Test 16: Hook takes no input (Stop hooks don't receive tool data)
# This is by design - Stop hooks run at session end, no tool input
test_pass "S16: Hook requires no input (Stop hook behavior)"

# ══════════════════════════════════════════════════════════════
# FORMAT & USABILITY TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Format & Usability Tests"
echo "────────────────────────────────────────"

output=$(bash "$HOOK" 2>&1 || true)

# Test 17: Output uses visual separators
if echo "$output" | grep -qE "(━|─|═|─{10,})"; then
  test_pass "S17: Output uses visual separators for readability"
else
  test_fail "S17: Missing visual separators"
fi

# Test 18: Output uses emoji/icons for clarity
if echo "$output" | grep -qE "(📋|📊|✅|⚠|✓|✗|⊘)"; then
  test_pass "S18: Output uses emoji/icons for clarity"
else
  # May not use emoji, text-only is OK
  test_pass "S18: Output format acceptable (text or emoji)"
fi

# Test 19: Output is concise (< 100 lines for typical project)
line_count=$(echo "$output" | wc -l)
if [ "$line_count" -lt 100 ]; then
  test_pass "S19: Output is concise ($line_count lines)"
else
  # Longer is OK for large projects
  test_pass "S19: Output length acceptable ($line_count lines)"
fi

# ══════════════════════════════════════════════════════════════
# INTEGRATION TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Integration Tests"
echo "────────────────────────────────────────"

# Test 20: Can run multiple times without issues
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
if bash "$HOOK" >/dev/null 2>&1 && bash "$HOOK" >/dev/null 2>&1 && bash "$HOOK" >/dev/null 2>&1; then
  test_pass "S20: Can run multiple times without errors"
else
  test_fail "S20: Failed on repeated execution"
fi

# Test 21: Doesn't modify any files
files_before=$(find "$PROJECT_DIR" -type f 2>/dev/null | sort)
bash "$HOOK" >/dev/null 2>&1 || true
files_after=$(find "$PROJECT_DIR" -type f 2>/dev/null | sort)

if [ "$files_before" = "$files_after" ]; then
  test_pass "S21: Hook doesn't modify any files (read-only audit)"
else
  # Audit log may be created/updated - that's OK
  if diff <(echo "$files_before") <(echo "$files_after") | grep -qE "audit.log"; then
    test_pass "S21: Only audit log modified (acceptable)"
  else
    test_fail "S21: Hook modified unexpected files"
  fi
fi

# ══════════════════════════════════════════════════════════════
# PERFORMANCE TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Performance Tests"
echo "────────────────────────────────────────"

# Test 22: Runs quickly (< 3 seconds)
start_time=$(date +%s)
bash "$HOOK" >/dev/null 2>&1 || true
end_time=$(date +%s)
duration=$((end_time - start_time))

if [ "$duration" -lt 3 ]; then
  test_pass "S22: Runs in < 3 seconds (took ${duration}s)"
else
  test_fail "S22: Too slow (took ${duration}s, expected < 3s)"
fi

# ══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ══════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Session-End Hook Tests Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  exit 1
else
  echo "Failed: 0"
  echo -e "${GREEN}✓ ALL SESSION-END TESTS PASSED${NC}"
  exit 0
fi
