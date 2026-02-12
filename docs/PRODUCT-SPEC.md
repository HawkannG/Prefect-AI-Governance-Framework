# Product Specification — Claude Warden

> **Version:** 1.0
> **Last Updated:** 2026-02-12
> **Status:** Production Release

---

## 1. Overview

**What:** AI governance framework that prevents Claude Code from breaking its own rules

**For whom:** Developers using Claude Code who want:
- Self-protecting governance files (Claude can't edit its own rules)
- Drift tracking and health scoring
- Project structure enforcement
- Security hardening against AI mistakes

**Core problem:** AI assistants are stateless and forget rules. Without mechanical enforcement, they create drift, break patterns, and accumulate entropy over long sessions.

## 2. Tech Stack

| Layer | Technology |
|---|---|
| Runtime | Bash 4.0+ (macOS, Linux, WSL) |
| Hooks | Claude Code hooks system |
| Config | JSON (settings.json) + Markdown (governance files) |
| Testing | Bash test suite (300+ test cases) |
| Distribution | GitHub + curl installer |

## 3. Core Features

### 3.1 Self-Protecting Hooks
- **Description:** Hooks that block Claude from modifying governance files
- **Acceptance Criteria:**
  - [x] Block Write/Edit to .claude/CLAUDE.md
  - [x] Block Write/Edit to .claude/rules/*.md
  - [x] Block Write/Edit to .claude/hooks/*.sh
  - [x] Block Write/Edit to .claude/settings.json
  - [x] Block Bash commands that write to protected files
- **Priority:** Must-have
- **Status:** Implemented

### 3.2 Drift Tracking
- **Description:** Health score (0-100) measuring governance compliance
- **Acceptance Criteria:**
  - [x] Detect unauthorized root files
  - [x] Detect forbidden directories (temp/, misc/, old/)
  - [x] Detect files exceeding 250-line limit
  - [x] Report drift score with component breakdown
- **Priority:** Must-have
- **Status:** Implemented

### 3.3 Project Structure Enforcement
- **Description:** Prevent creation of unauthorized files/directories
- **Acceptance Criteria:**
  - [x] Allow only registered root files
  - [x] Block forbidden directory names
  - [x] Enforce 5-level depth limit
  - [x] Enforce 250-line file size limit
- **Priority:** Must-have
- **Status:** Implemented

### 3.4 Security Hardening
- **Description:** Protection against path traversal, symlink attacks, command injection
- **Acceptance Criteria:**
  - [x] Block symlink attacks on governance files
  - [x] Block path traversal (../ escapes)
  - [x] Block command injection via Bash tool
  - [x] 100% test coverage on security vectors
- **Priority:** Must-have
- **Status:** Implemented (17/17 security tests passing)

### 3.5 Installation & Migration Tools
- **Description:** One-command installer and migration from Prefect
- **Acceptance Criteria:**
  - [x] install.sh downloads and configures framework
  - [x] migrate-from-prefect.sh upgrades existing projects
  - [x] uninstall.sh cleanly removes all files
  - [x] Works on macOS, Linux, WSL
- **Priority:** Should-have
- **Status:** Implemented

## 4. Architecture

### 4.1 Hook Chain
```
Claude calls Write → preToolUse hook → warden-guard.sh
                                     ↓
                                   Block or Allow
                                     ↓
                         postToolUse hook → warden-post-check.sh
                                     ↓
                              Drift warnings
```

### 4.2 Protection Layers
1. **Layer 1:** permissions.deny in settings.json (native Claude Code)
2. **Layer 2:** Rules files (.claude/rules/*.md auto-discovered)
3. **Layer 3:** Pre-tool hooks (block before action)
4. **Layer 4:** Post-tool hooks (warn after action)
5. **Layer 5:** File permissions (chmod -w via lockdown.sh)

### 4.3 File Structure
```
.claude/
├── CLAUDE.md              # Project instructions
├── settings.json          # Hooks + permissions config
├── hooks/                 # Enforcement hooks
│   ├── warden-guard.sh           # Pre-tool protection
│   ├── warden-bash-guard.sh      # Bash command filtering
│   ├── warden-post-check.sh      # Post-tool warnings
│   ├── warden-audit.sh           # Drift scoring
│   └── warden-session-end.sh     # Session cleanup
└── rules/                 # Governance rules
    ├── policy.md          # Constitution
    ├── workflow.md        # Development process
    ├── architecture.md    # Directory structure
    └── feedback.md        # Feedback loop
```

## 5. API Design

### 5.1 Hook Inputs (stdin JSON)
```json
{
  "tool": "Write",
  "tool_input": {
    "file_path": ".claude/rules/policy.md",
    "content": "..."
  }
}
```

### 5.2 Hook Outputs (exit codes)
- `0` - Allow
- `1` - Block (WARDEN BLOCK message to stderr)

### 5.3 Environment Variables
- `CLAUDE_PROJECT_DIR` - Project root path
- `CLAUDE_TOOL_NAME` - Current tool being called

## 6. Success Metrics

- [x] Zero governance file modifications by AI (hard enforcement)
- [x] Drift score < 20 for well-governed projects
- [x] 100% security test pass rate
- [x] < 5 minute installation time
- [x] Works on macOS + Linux + WSL without dependencies (except jq)

## 7. Roadmap

### v1.0 (Current)
- Self-protecting hooks
- Drift tracking
- Security hardening
- Installation tools

### v1.1 (Future)
- Visual drift dashboard
- Auto-fix suggestions
- IDE integration warnings
- Multi-project governance sync

### v2.0 (Future)
- Plugin marketplace
- Custom rule DSL
- LLM-agnostic (support other AI assistants)

---

*This is the product spec for the Warden framework itself. Users can copy this as a template for their own projects.*
