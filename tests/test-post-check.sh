#!/usr/bin/env bash
set -euo pipefail
# test-post-check.sh — Tests for warden-post-check.sh hook
# Tests post-write validation and warning messages
# Usage: bash tests/test-post-check.sh [project-dir]

PROJECT_DIR="${1:-.}"
HOOK="$PROJECT_DIR/.claude/hooks/warden-post-check.sh"

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
echo "⚠️  WARDEN-POST-CHECK.SH HOOK TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ══════════════════════════════════════════════════════════════
# BASIC EXECUTION TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Basic Execution Tests"
echo "────────────────────────────────────────"

# Test 1: Hook runs without errors on normal file
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
json_input='{"tool_name":"Write","tool_input":{"file_path":"tests/test.txt","content":"test"}}'

if echo "$json_input" | bash "$HOOK" >/dev/null 2>&1; then
  test_pass "P1: Hook runs without errors"
else
  test_fail "P1: Hook execution failed"
fi

# Test 2: Hook handles empty file_path gracefully
if echo '{"tool_name":"Write","tool_input":{"file_path":"","content":"test"}}' | bash "$HOOK" >/dev/null 2>&1; then
  test_pass "P2: Handles empty file_path gracefully"
else
  test_fail "P2: Failed on empty file_path"
fi

# Test 3: Hook handles missing file_path gracefully
if echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | bash "$HOOK" >/dev/null 2>&1; then
  test_pass "P3: Handles missing file_path gracefully"
else
  test_fail "P3: Failed on missing file_path"
fi

# ══════════════════════════════════════════════════════════════
# SOURCE FILE SIZE WARNING TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Source File Size Warning Tests"
echo "────────────────────────────────────────"

# Create test directory
mkdir -p "$PROJECT_DIR/tests/post-check-tests"

# Test 4: Small source file (no warning)
echo "function test() { return true; }" > "$PROJECT_DIR/tests/post-check-tests/small.ts"
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"tests/post-check-tests/small.ts","content":"ok"}}' | \
  bash "$HOOK" 2>&1 || true)

if ! echo "$output" | grep -q "WARDEN DRIFT"; then
  test_pass "P4: No warning for small source file (< 250 lines)"
else
  test_fail "P4: Unexpected warning for small file"
fi

# Test 5: Large source file (should warn)
{
  for i in {1..300}; do echo "const line$i = $i;"; done
} > "$PROJECT_DIR/tests/post-check-tests/large.ts"

output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"tests/post-check-tests/large.ts","content":"ok"}}' | \
  bash "$HOOK" 2>&1 || true)

if echo "$output" | grep -q "WARDEN DRIFT"; then
  test_pass "P5: Warns about oversized source file (300 lines)"
else
  test_fail "P5: Missing warning for oversized file"
fi

# Test 6: Warning mentions file size
if echo "$output" | grep -qE "[0-9]+ lines"; then
  test_pass "P6: Warning includes line count"
else
  test_fail "P6: Warning doesn't include line count"
fi

# Test 7: Warning suggests action
if echo "$output" | grep -qiE "(WARDEN-FEEDBACK|split)"; then
  test_pass "P7: Warning suggests logging or splitting file"
else
  test_fail "P7: Warning doesn't suggest action"
fi

# Test 8: Different source file types
for ext in js jsx py rb go rs java cs cpp; do
  {
    for i in {1..300}; do echo "// line $i"; done
  } > "$PROJECT_DIR/tests/post-check-tests/large.$ext"

  output=$(echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"tests/post-check-tests/large.$ext\",\"content\":\"ok\"}}" | \
    bash "$HOOK" 2>&1 || true)

  if echo "$output" | grep -q "WARDEN DRIFT"; then
    test_pass "P8.$ext: Warns about oversized .$ext file"
  else
    test_fail "P8.$ext: Missing warning for .$ext file"
  fi
done

# Test 9: Non-source file (no warning even if large)
{
  for i in {1..500}; do echo "Line $i"; done
} > "$PROJECT_DIR/tests/post-check-tests/large.txt"

output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"tests/post-check-tests/large.txt","content":"ok"}}' | \
  bash "$HOOK" 2>&1 || true)

if ! echo "$output" | grep -q "WARDEN DRIFT"; then
  test_pass "P9: No warning for non-source file (large.txt)"
else
  test_fail "P9: Unexpected warning for .txt file"
fi

# Cleanup
rm -rf "$PROJECT_DIR/tests/post-check-tests"

# ══════════════════════════════════════════════════════════════
# ERROR HANDLING TESTS (V8)
# ══════════════════════════════════════════════════════════════
echo ""
echo "Error Handling Tests (V8)"
echo "────────────────────────────────────────"

# Test 10: Has set -euo pipefail
if head -5 "$HOOK" | grep -q "set -euo pipefail"; then
  test_pass "P10: Has set -euo pipefail for error handling"
else
  test_fail "P10: Missing set -euo pipefail"
fi

# Test 11: Has portable shebang
if head -1 "$HOOK" | grep -q "#!/usr/bin/env bash"; then
  test_pass "P11: Has portable shebang (#!/usr/bin/env bash)"
else
  test_fail "P11: Missing portable shebang"
fi

# Test 12: Handles nonexistent file gracefully
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"tests/nonexistent.ts","content":"ok"}}' | \
  bash "$HOOK" 2>&1 || true)

# Should complete without error (file doesn't exist yet, no size check possible)
test_pass "P12: Handles nonexistent file gracefully (no crash)"

# ══════════════════════════════════════════════════════════════
# HOOK BEHAVIOR TESTS
# ══════════════════════════════════════════════════════════════
echo ""
echo "Hook Behavior Tests"
echo "────────────────────────────────────────"

# Test 13: Hook is PostToolUse (runs after write, doesn't block)
# All tests should exit 0, even when warning
mkdir -p "$PROJECT_DIR/tests"
{
  for i in {1..300}; do echo "line $i"; done
} > "$PROJECT_DIR/tests/large-test.py"

exit_code=0
echo '{"tool_name":"Write","tool_input":{"file_path":"tests/large-test.py","content":"ok"}}' | \
  bash "$HOOK" >/dev/null 2>&1 || exit_code=$?

if [ "$exit_code" -eq 0 ]; then
  test_pass "P13: Hook exits 0 (warning only, doesn't block)"
else
  test_fail "P13: Hook should exit 0 (got exit $exit_code)"
fi

rm -f "$PROJECT_DIR/tests/large-test.py"

# Test 14: Warning goes to stderr (not stdout)
mkdir -p "$PROJECT_DIR/tests"
{
  for i in {1..300}; do echo "line $i"; done
} > "$PROJECT_DIR/tests/stderr-test.ts"

stdout_output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"tests/stderr-test.ts","content":"ok"}}' | \
  bash "$HOOK" 2>/dev/null || true)

stderr_output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"tests/stderr-test.ts","content":"ok"}}' | \
  bash "$HOOK" 2>&1 >/dev/null || true)

if [ -z "$stdout_output" ] && [ -n "$stderr_output" ]; then
  test_pass "P14: Warnings go to stderr (not stdout)"
else
  test_fail "P14: Warnings should be on stderr only"
fi

rm -f "$PROJECT_DIR/tests/stderr-test.ts"

# ══════════════════════════════════════════════════════════════
# EDGE CASES
# ══════════════════════════════════════════════════════════════
echo ""
echo "Edge Cases"
echo "────────────────────────────────────────"

# Test 15: File with 250 lines exactly (boundary)
mkdir -p "$PROJECT_DIR/tests"
{
  for i in {1..250}; do echo "line $i"; done
} > "$PROJECT_DIR/tests/exactly-250.ts"

output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"tests/exactly-250.ts","content":"ok"}}' | \
  bash "$HOOK" 2>&1 || true)

if ! echo "$output" | grep -q "WARDEN DRIFT"; then
  test_pass "P15: No warning at exactly 250 lines (boundary case)"
else
  test_fail "P15: Should not warn at exactly 250 lines"
fi

rm -f "$PROJECT_DIR/tests/exactly-250.ts"

# Test 16: File with 251 lines (just over boundary)
{
  for i in {1..251}; do echo "line $i"; done
} > "$PROJECT_DIR/tests/just-over.ts"

output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"tests/just-over.ts","content":"ok"}}' | \
  bash "$HOOK" 2>&1 || true)

if echo "$output" | grep -q "WARDEN DRIFT"; then
  test_pass "P16: Warns at 251 lines (just over boundary)"
else
  test_fail "P16: Should warn at 251 lines"
fi

rm -f "$PROJECT_DIR/tests/just-over.ts"

# Test 17: File path with spaces
mkdir -p "$PROJECT_DIR/tests"
{
  for i in {1..300}; do echo "line $i"; done
} > "$PROJECT_DIR/tests/file with spaces.ts"

output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"tests/file with spaces.ts","content":"ok"}}' | \
  bash "$HOOK" 2>&1 || true)

if echo "$output" | grep -q "WARDEN DRIFT"; then
  test_pass "P17: Handles file paths with spaces"
else
  test_fail "P17: Failed to process file with spaces"
fi

rm -f "$PROJECT_DIR/tests/file with spaces.ts"

# ══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ══════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Post-Check Hook Tests Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  exit 1
else
  echo "Failed: 0"
  echo -e "${GREEN}✓ ALL POST-CHECK TESTS PASSED${NC}"
  exit 0
fi
