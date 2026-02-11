# Security Policy

## Supported Versions

| Version | Supported          | Status |
| ------- | ------------------ | ------ |
| 6.0.x   | :white_check_mark: | Secure |
| < 6.0   | :x:                | Upgrade required |

## Reporting a Vulnerability

**DO NOT** open public GitHub issues for security vulnerabilities.

### How to Report

Use GitHub's private security advisory:
- https://github.com/HawkannG/Prefect-AI-Governance-Framework/security/advisories/new

Or contact the maintainer directly (see README).

### What to Include

- Clear description of the vulnerability
- Steps to reproduce
- Impact and affected versions
- Suggested fix (optional)

### Response Timeline

- Initial response: Within 48 hours
- Fix timeline: 2-4 weeks depending on severity
- Public disclosure: After fix is released

## Security Fixes in v6.0

Version 6.0 addresses 9 security vulnerabilities:

1. **Symlink Attack Protection** - Hooks now resolve symlinks before path validation
2. **Path Traversal Prevention** - Canonical path validation prevents `../` bypasses
3. **Command Injection Hardening** - Removed unsafe grep fallback, jq now required
4. **Exit Code Standardization** - Correct exit codes (0=allow, 1=block, 2=error)
5. **Dependency Validation** - jq is required, no unsafe fallbacks
6. **Git Command Injection Fix** - Sanitized paths before git operations
7. **Hook Tampering Protection** - Hooks protected from modification
8. **Error Handling** - All hooks have `set -euo pipefail`
9. **Log Injection Mitigation** - Resilient log format with error handling

## Security Testing

Run the comprehensive test suite:
```bash
bash tests/run-tests.sh
```

Includes 400+ tests covering all vulnerability types with regression testing.

## Best Practices

- Don't run Claude Code as root
- Review `.claude/audit.log` periodically
- Use version 6.0 or later
- Keep hooks executable and unmodified

---

**Last Updated:** February 2026
**Security Version:** 6.0
