#!/usr/bin/env bash
set -euo pipefail
# run-tests.sh — Warden Security Test Suite Runner
# Runs all security tests and reports results
# Usage: bash tests/run-tests.sh [--verbose]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VERBOSE=false
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=true
fi

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Test results storage
declare -a FAILED_TEST_NAMES
declare -a SKIPPED_TEST_NAMES

log_header() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_test_suite() {
  echo ""
  echo -e "${YELLOW}▶ $1${NC}"
}

log_pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASSED_TESTS=$((PASSED_TESTS + 1))
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

log_fail() {
  echo -e "${RED}✗${NC} $1"
  FAILED_TEST_NAMES+=("$1")
  FAILED_TESTS=$((FAILED_TESTS + 1))
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

log_skip() {
  echo -e "${YELLOW}⊘${NC} $1"
  SKIPPED_TEST_NAMES+=("$1")
  SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

log_info() {
  if [ "$VERBOSE" = true ]; then
    echo -e "  ${BLUE}ℹ${NC} $1"
  fi
}

re_enable_hooks() {
  # Re-enable hooks after testing
  if [ -f "$PROJECT_DIR/.claude/settings.json.bak" ]; then
    mv "$PROJECT_DIR/.claude/settings.json.bak" "$PROJECT_DIR/.claude/settings.json" 2>/dev/null || true
    log_info "Hooks re-enabled"
  fi
}

# Check prerequisites
check_prerequisites() {
  log_header "CHECKING PREREQUISITES"

  local all_ok=true

  # Check jq
  if command -v jq &>/dev/null; then
    log_pass "jq is installed ($(jq --version))"
  else
    log_fail "jq is NOT installed (required for hooks)"
    all_ok=false
  fi

  # Check bash version
  if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
    log_pass "bash version OK (${BASH_VERSION})"
  else
    log_fail "bash version too old (${BASH_VERSION}, need 4.0+)"
    all_ok=false
  fi

  # Check realpath
  if command -v realpath &>/dev/null; then
    log_pass "realpath is available"
  else
    log_fail "realpath is NOT available (required for path validation)"
    all_ok=false
  fi

  # Check hooks exist
  local hooks=("warden-guard.sh" "warden-bash-guard.sh" "warden-audit.sh" "warden-post-check.sh" "warden-session-end.sh")
  for hook in "${hooks[@]}"; do
    if [ -f "$PROJECT_DIR/.claude/hooks/$hook" ]; then
      log_pass "Hook exists: $hook"
    else
      log_fail "Hook missing: $hook"
      all_ok=false
    fi
  done

  if [ "$all_ok" = false ]; then
    echo ""
    echo -e "${RED}Prerequisites check failed. Fix issues before running tests.${NC}"
    exit 1
  fi
}

# Run a test script
run_test_script() {
  local script_name="$1"
  local script_path="$SCRIPT_DIR/$script_name"

  if [ ! -f "$script_path" ]; then
    log_skip "Test suite $script_name (not found)"
    return
  fi

  log_test_suite "Running $script_name"

  # Make script executable
  chmod +x "$script_path"

  # Run the test script
  if bash "$script_path" "$PROJECT_DIR"; then
    log_info "$script_name completed successfully"
  else
    log_fail "$script_name had failures"
  fi
}

# Main execution
main() {
  log_header "🔒 WARDEN SECURITY TEST SUITE"
  echo "Project: $PROJECT_DIR"
  echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"

  # Temporarily disable hooks during testing (they would block the tests)
  if [ -f "$PROJECT_DIR/.claude/settings.json" ]; then
    log_info "Temporarily disabling hooks for testing..."
    mv "$PROJECT_DIR/.claude/settings.json" "$PROJECT_DIR/.claude/settings.json.bak" 2>/dev/null || true
  fi

  # Ensure hooks are re-enabled on exit
  trap 're_enable_hooks' EXIT

  # Prerequisites check
  check_prerequisites

  # Reset counters for actual tests
  TOTAL_TESTS=0
  PASSED_TESTS=0
  FAILED_TESTS=0
  SKIPPED_TESTS=0

  # Run test suites in order
  log_header "RUNNING TEST SUITES"

  # Security tests (most critical)
  run_test_script "test-security.sh"

  # Hook-specific tests
  run_test_script "test-guard.sh"
  run_test_script "test-bash-guard.sh"
  run_test_script "test-audit.sh"
  run_test_script "test-post-check.sh"
  run_test_script "test-session-end.sh"

  # Final report
  log_header "TEST RESULTS SUMMARY"

  echo ""
  echo "Total tests run: $TOTAL_TESTS"
  echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
  if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
  else
    echo "Failed: 0"
  fi
  if [ $SKIPPED_TESTS -gt 0 ]; then
    echo -e "${YELLOW}Skipped: $SKIPPED_TESTS${NC}"
  fi

  # List failed tests
  if [ $FAILED_TESTS -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed tests:${NC}"
    for test_name in "${FAILED_TEST_NAMES[@]}"; do
      echo -e "  ${RED}✗${NC} $test_name"
    done
  fi

  # List skipped tests
  if [ $SKIPPED_TESTS -gt 0 ] && [ "$VERBOSE" = true ]; then
    echo ""
    echo -e "${YELLOW}Skipped tests:${NC}"
    for test_name in "${SKIPPED_TEST_NAMES[@]}"; do
      echo -e "  ${YELLOW}⊘${NC} $test_name"
    done
  fi

  echo ""
  if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
  else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ TESTS FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
  fi
}

main "$@"
