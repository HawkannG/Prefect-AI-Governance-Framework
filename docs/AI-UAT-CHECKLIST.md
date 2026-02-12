# AI-UAT-CHECKLIST — Testing Conventions for AI-Assisted Development

> How Claude should handle testing within this project.
> This is a product doc, not a governance doc.

---

## 1. Core Principles

1. **Tests ship with the feature.** No "we'll add tests later."
2. **Acceptance criteria define what "done" means.** Not the developer's opinion.
3. **Every user-facing feature has acceptance criteria BEFORE code is written.**
4. **Edge cases and error states are mandatory**, not optional extras.
5. **Test what the user sees**, not just what the code does.

## 2. Test Structure

### Unit Tests
- Test individual functions and methods in isolation
- Mock external dependencies
- Cover happy path, edge cases, and error states
- Naming: `test_[function]_[scenario]_[expected_result]`

### Integration Tests
- Test service interactions (DB, API, external services)
- Use real database (test instance) where practical
- Test the full request→response cycle for API endpoints

### UAT / Acceptance Tests
- Verify acceptance criteria from PRODUCT-SPEC or user stories
- Written in business language, mapped to test code
- Include: happy path, at least one edge case, expected error states

## 3. Pre-Build Checklist

Before writing any feature code:
- [ ] Acceptance criteria defined?
- [ ] Edge cases identified?
- [ ] Error states documented?
- [ ] Test file locations planned?

## 4. Post-Build Checklist

Before marking a feature as VERIFY:
- [ ] All acceptance criteria have corresponding tests?
- [ ] All tests pass?
- [ ] Edge cases tested?
- [ ] Error states tested?
- [ ] No skipped or commented-out tests?

## 5. Commit Convention

Reference acceptance criteria in commit messages:

```
feat: Add user login (UAT: login-happy-path, login-invalid-creds, login-empty-fields)
fix: Handle expired tokens (UAT: auth-token-expiry)
test: Add integration tests for payment flow (UAT: payment-success, payment-declined)
```

## 6. Test File Conventions

| Project Type | Test Location | Naming |
|---|---|---|
| Python (pytest) | `tests/` mirror of `src/` | `test_[module].py` |
| JavaScript (Jest) | `__tests__/` or `*.test.ts` | `[module].test.ts` |
| Go | Same package | `[module]_test.go` |

## 7. When No Acceptance Criteria Exist

**STOP.** Do not write code.

Ask the human to define acceptance criteria first. Claude can help draft them:
- "What should the user see when this works?"
- "What happens if the input is empty/invalid/too large?"
- "What error message should appear?"

---

*Update this file as testing conventions evolve. This is a living document.*
