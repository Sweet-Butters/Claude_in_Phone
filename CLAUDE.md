# Claude Code Context — Claude_in_Phone

This repo is the SSOT for a multi-device personal dev workflow. The user guide and setup steps live in [README.md](README.md) (English) / [README.ko.md](README.ko.md) (한국어).

## Behavior rules for Claude Code in this repo

- **Mobile sessions dominate.** Keep responses short. Summarize long logs and diffs.
- **Absolute paths.** The Bash tool resets cwd between calls — always pass absolute paths or chain with `&&` in one invocation.
- **Permission mode.** `bypassPermissions` is the default. The `permissions.deny` patterns in `~/.claude/settings.json` are still hard-enforced — destructive commands listed there are blocked even in bypass mode.
- **Auto-yes vs explicit confirmation** is a global rule defined in `~/.claude/CLAUDE.md`. Not duplicated per repo.

## Working on this repo

- Content is the setup guide (READMEs) + infrastructure (`infra/`, `scripts/`). New artifacts go in one of those directories. Keep the "Repository Layout" section of both READMEs in sync.
- `README.md` (English) and `README.ko.md` (Korean) must stay in sync. When changing one, update the other in the same commit.
- When recording a successful multi-device sync verification, put commit SHAs in the commit message, not in the README — they age fast and clutter the doc.
