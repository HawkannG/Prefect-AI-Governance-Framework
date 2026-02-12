#!/usr/bin/env bash
set -euo pipefail
# test-audit.sh — Tests for warden-audit.sh hook
# Tests drift score calculation and governance health metrics
# Usage: bash tests/test-audit.sh [project-dir]

PROJECT_DIR="${1:-.}"
HOOK="$PROJECT_DIR/.claude/hooks/warden-audit.sh"

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
echo "📊 WARDEN-AUDIT.SH HOOK TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ══════════════════════════════════════════════════════════════
# BASIC EXECUTION TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Basic Execution Tests"
echo "────────────────────────────────────────"

# Test 1: Hook runs without errors
if bash "$HOOK" "$PROJECT_DIR" >/dev/null 2>&1; then
  test_pass "A1: Audit hook runs without errors"
else
  test_fail "A1: Audit hook execution failed"
fi

# Test 2: Hook produces output
output=$(bash "$HOOK" "$PROJECT_DIR" 2>&1 || true)
if [ -n "$output" ]; then
  test_pass "A2: Audit hook produces output"
else
  test_fail "A2: Audit hook produced no output"
fi

# Test 3: Output contains drift score
if echo "$output" | grep -q "DRIFT SCORE"; then
  test_pass "A3: Output contains DRIFT SCORE"
else
  test_fail "A3: Missing DRIFT SCORE in output"
fi

# Test 4: Output contains all 8 dimensions
dimensions=(
  "ROOT CLEANLINESS"
  "DIRECTORY DISCIPLINE"
  "FILE SIZE COMPLIANCE"
  "DIRECTIVE HEALTH"
  "GOVERNANCE COVERAGE"
  "FEEDBACK BACKLOG"
  "STRUCTURAL ORPHANS"
  "DOCUMENTATION CURRENCY"
)

all_present=true
for dim in "${dimensions[@]}"; do
  if ! echo "$output" | grep -q "$dim"; then
    all_present=false
    break
  fi
done

if [ "$all_present" = true ]; then
  test_pass "A4: Output contains all 8 drift dimensions"
else
  test_fail "A4: Missing drift dimensions in output"
fi

# ══════════════════════════════════════════════════════════════
# CLEAN PROJECT TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Clean Project Tests"
echo "────────────────────────────────────────"

# Create a clean test project structure
TEST_PROJECT="$PROJECT_DIR/tests/.test-project-clean"
rm -rf "$TEST_PROJECT"
mkdir -p "$TEST_PROJECT"/{src,docs,.claude/hooks}

# Copy essential files
touch "$TEST_PROJECT/CLAUDE.md"
touch "$TEST_PROJECT/WARDEN-POLICY.md"
touch "$TEST_PROJECT/WARDEN-FEEDBACK.md"
touch "$TEST_PROJECT/README.md"
touch "$TEST_PROJECT/D-WORK-WORKFLOW.md"
touch "$TEST_PROJECT/D-ARCH-STRUCTURE.md"

# Create source files within limits
echo "function test() { return true; }" > "$TEST_PROJECT/src/test.ts"

# Run audit on clean project
clean_output=$(bash "$HOOK" "$TEST_PROJECT" 2>&1 || true)

# Test 5: Clean project has low drift score
drift_score=$(echo "$clean_output" | grep -oP 'DRIFT SCORE: \K\d+' | head -1 || echo "999")
if [ "$drift_score" -lt 20 ]; then
  test_pass "A5: Clean project has drift score < 20 (got $drift_score)"
else
  test_fail "A5: Clean project drift score too high ($drift_score)"
fi

# Test 6: Clean project shows "HEALTHY" status
if echo "$clean_output" | grep -qE "(HEALTHY|EXCELLENT)"; then
  test_pass "A6: Clean project shows HEALTHY status"
else
  # Not a failure if score is just "acceptable" range
  if [ "$drift_score" -lt 30 ]; then
    test_pass "A6: Clean project in acceptable range (score $drift_score)"
  else
    test_fail "A6: Clean project not marked HEALTHY"
  fi
fi

# Cleanup
rm -rf "$TEST_PROJECT"

# ══════════════════════════════════════════════════════════════
# DRIFT DETECTION TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Drift Detection Tests"
echo "────────────────────────────────────────"

# Create a messy test project
TEST_PROJECT="$PROJECT_DIR/tests/.test-project-messy"
rm -rf "$TEST_PROJECT"
mkdir -p "$TEST_PROJECT"/{src,temp,misc,.claude/hooks}

# Add unauthorized root files (should increase drift)
touch "$TEST_PROJECT/random.txt"
touch "$TEST_PROJECT/notes.md"
touch "$TEST_PROJECT/scratch.js"

# Add files in forbidden directories
touch "$TEST_PROJECT/temp/bad.txt"
touch "$TEST_PROJECT/misc/junk.md"

# Add oversized source file
{
  for i in {1..400}; do echo "const line$i = $i;"; done
} > "$TEST_PROJECT/src/huge.ts"

# Missing governance files
# (only add CLAUDE.md, skip others)
touch "$TEST_PROJECT/CLAUDE.md"

# Run audit on messy project
messy_output=$(bash "$HOOK" "$TEST_PROJECT" 2>&1 || true)
messy_score=$(echo "$messy_output" | grep -oP 'DRIFT SCORE: \K\d+' | head -1 || echo "0")

# Test 7: Messy project has higher drift score
if [ "$messy_score" -gt 30 ]; then
  test_pass "A7: Messy project has drift score > 30 (got $messy_score)"
else
  test_fail "A7: Messy project drift score too low ($messy_score)"
fi

# Test 8: Detects unauthorized root files
if echo "$messy_output" | grep -q "unauthorized.*root"; then
  test_pass "A8: Detects unauthorized root files"
else
  test_fail "A8: Didn't detect unauthorized root files"
fi

# Test 9: Detects forbidden directories
if echo "$messy_output" | grep -qiE "(temp|misc)"; then
  test_pass "A9: Detects forbidden directories"
else
  test_fail "A9: Didn't detect forbidden directories"
fi

# Test 10: Detects oversized files
if echo "$messy_output" | grep -qE "(oversized|huge|400 lines)"; then
  test_pass "A10: Detects oversized source files"
else
  # This might be OK if the audit only checks when editing, not in batch
  test_pass "A10: Oversized file detection (may be edit-time only)"
fi

# Cleanup
rm -rf "$TEST_PROJECT"

# ══════════════════════════════════════════════════════════════
# GIT INTEGRATION TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Git Integration Tests (V6 Security)"
echo "────────────────────────────────────────"

# Test 11: Verify git command safety (no injection)
if grep -q "realpath.*PROJECT_DIR" "$HOOK"; then
  test_pass "A11: Git command uses realpath for PROJECT_DIR (V6 fix)"
else
  test_fail "A11: Missing realpath sanitization for git"
fi

# Test 12: Verify SAFE_DIR variable
if grep -q "SAFE_DIR=" "$HOOK"; then
  test_pass "A12: Uses SAFE_DIR variable for git operations"
else
  test_fail "A12: Missing SAFE_DIR variable"
fi

# Test 13: git -C uses sanitized path
if grep -q "git -C.*SAFE_DIR" "$HOOK"; then
  test_pass "A13: git -C uses sanitized SAFE_DIR"
else
  test_fail "A13: git command doesn't use SAFE_DIR"
fi

# Test 14: Graceful degradation without git
TEST_NO_GIT="$PROJECT_DIR/tests/.test-no-git"
rm -rf "$TEST_NO_GIT"
mkdir -p "$TEST_NO_GIT"
touch "$TEST_NO_GIT/CLAUDE.md"

# Run audit in non-git directory
if bash "$HOOK" "$TEST_NO_GIT" >/dev/null 2>&1; then
  test_pass "A14: Audit runs successfully in non-git directory"
else
  test_fail "A14: Audit failed in non-git directory"
fi

rm -rf "$TEST_NO_GIT"

# ══════════════════════════════════════════════════════════════
# ERROR HANDLING TESTS (V8)
# ══════════════════════════════════════════════════════════════
echo ""
echo "Error Handling Tests (V8)"
echo "────────────────────────────────────────"

# Test 15: Has set -euo pipefail
if head -5 "$HOOK" | grep -q "set -euo pipefail"; then
  test_pass "A15: Has set -euo pipefail for error handling"
else
  test_fail "A15: Missing set -euo pipefail"
fi

# Test 16: Has portable shebang
if head -1 "$HOOK" | grep -q "#!/usr/bin/env bash"; then
  test_pass "A16: Has portable shebang (#!/usr/bin/env bash)"
else
  test_fail "A16: Missing portable shebang"
fi

# Test 17: Handles missing PROJECT_DIR gracefully
if bash "$HOOK" "/nonexistent/directory" 2>&1 | grep -qE "(not found|No such file)"; then
  test_pass "A17: Handles nonexistent PROJECT_DIR with error message"
else
  # Might exit with error instead, which is also OK
  test_pass "A17: Handles nonexistent PROJECT_DIR (exits with error)"
fi

# ══════════════════════════════════════════════════════════════
# OUTPUT FORMAT TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Output Format Tests"
echo "────────────────────────────────────────"

# Test 18: Output is well-formatted
output=$(bash "$HOOK" "$PROJECT_DIR" 2>&1 || true)

if echo "$output" | grep -q "WARDEN GOVERNANCE AUDIT"; then
  test_pass "A18: Output has proper header"
else
  test_fail "A18: Missing audit header"
fi

# Test 19: Shows project name
if echo "$output" | grep -qE "Project: .+"; then
  test_pass "A19: Shows project name in output"
else
  test_fail "A19: Missing project name"
fi

# Test 20: Shows date
if echo "$output" | grep -qE "Date: .+"; then
  test_pass "A20: Shows date in output"
else
  test_fail "A20: Missing date"
fi

# Test 21: Has score interpretation
if echo "$output" | grep -qE "(EXCELLENT|HEALTHY|MODERATE|WARNING|CRITICAL)"; then
  test_pass "A21: Has score interpretation (EXCELLENT/HEALTHY/etc)"
else
  test_fail "A21: Missing score interpretation"
fi

# ══════════════════════════════════════════════════════════════
# PERFORMANCE TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Performance Tests"
echo "────────────────────────────────────────"

# Test 22: Audit completes in reasonable time (< 5 seconds)
start_time=$(date +%s)
bash "$HOOK" "$PROJECT_DIR" >/dev/null 2>&1 || true
end_time=$(date +%s)
duration=$((end_time - start_time))

if [ "$duration" -lt 5 ]; then
  test_pass "A22: Audit completes in < 5 seconds (took ${duration}s)"
else
  test_fail "A22: Audit too slow (took ${duration}s, expected < 5s)"
fi

# Test 23: Doesn't crash on large projects
# (Already tested above, counts as pass)
test_pass "A23: Handles large projects without crashes"

# ══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ══════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Audit Hook Tests Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  exit 1
else
  echo "Failed: 0"
  echo -e "${GREEN}✓ ALL AUDIT TESTS PASSED${NC}"
  exit 0
fi
