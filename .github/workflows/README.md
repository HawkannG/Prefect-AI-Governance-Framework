# GitHub Actions Workflows

## Security Tests

**File:** `security-tests.yml`

Runs comprehensive security validation on every push and pull request.

### What It Does

1. **Quick Validation** (Job 1)
   - Runs `quick-test.sh` (6 critical tests)
   - Fast feedback (<30 seconds)
   - Blocks merge if critical vulnerabilities detected

2. **Comprehensive Tests** (Job 2)
   - Only runs if quick validation passes
   - Tests all 4 vulnerability categories individually
   - Detailed output for each test suite

### Triggers

- Push to `main`, `develop`, or `security-*` branches
- Pull requests to `main`
- Manual trigger via Actions UI

### Requirements

- Ubuntu latest
- jq (installed automatically)
- Bash 4.0+

### Viewing Results

1. Go to repository → Actions tab
2. Click on latest workflow run
3. Expand job steps to see test output

### Status Badge

Add to README.md:

```markdown
[![Security Tests](https://github.com/HawkannG/Claude-Warden/actions/workflows/security-tests.yml/badge.svg)](https://github.com/HawkannG/Claude-Warden/actions/workflows/security-tests.yml)
```

### Local Testing

Run the same tests locally:

```bash
# Quick validation (same as CI)
bash tests/security/quick-test.sh

# Comprehensive (same as CI)
bash tests/security/test-symlink-attack.sh
bash tests/security/test-path-traversal.sh
bash tests/security/test-exit-codes.sh
bash tests/security/test-command-injection.sh
```

### Troubleshooting

**Tests fail locally but pass in CI:**
- Check jq version: `jq --version` (need 1.5+)
- Verify hooks are executable: `ls -l .claude/hooks/*.sh`

**Tests pass locally but fail in CI:**
- Check GitHub Actions logs for specific error
- Verify `.claude/hooks/` directory is committed
- Check file permissions in git: `git ls-files -s .claude/hooks/`

### Adding New Tests

1. Add test script to `tests/security/`
2. Make it executable: `chmod +x tests/security/new-test.sh`
3. Add to workflow (optional - tests in `quick-test.sh` run automatically)
4. Commit and push

---

**Last Updated:** February 2026
