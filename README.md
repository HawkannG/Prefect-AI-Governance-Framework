# Claude Warden

> AI governance framework for Claude Code

## Status: Under Construction

This plugin is being rebuilt from the ground up as a native Claude Code plugin. The old curl-install version has been retired.

A new release will be published here when ready. Until then, development continues locally.

## What It Will Do

- Self-protecting governance hooks (PreToolUse / PostToolUse / Stop)
- Protected file enforcement (CLAUDE.md, settings.json, config files)
- Bash command guard (blocks writes to governance files via shell)
- Root file lockdown, forbidden directory names, depth limits
- Drift scoring and audit trails
- Session-end checks and handoff reminders
- Native deny entry seeding for defense-in-depth

## License

MIT
