# Vault Setup Wizard — Handover

## What This Is

A setup wizard that installs the Claude Code vault-rules system (hooks, 5 skills, brief, agent rules) on any machine — creates a new vault from scratch or adds it alongside existing ones.

## Location

`/Users/bernardoresende/Core/Sandbox/vault-setup/`

## Current Status — COMPLETE, TESTED, READY TO USE

All 5 implementation steps done and verified:
1. Hooks refactored for dynamic vault path resolution (was hardcoded, now uses state file + env var + auto-detect)
2. Bundle directory assembled (hooks, skill, brief, AGENTS.md, 7 templates, scripts.tar.gz)
3. install.sh written and tested (dry-run, fresh install, idempotent re-install)
4. Step 2 refactored from hardcoded vault-rules to a loop that installs all SKILL.md files in bundle/skills/
4. README.md written
5. Interactive vault selection + Obsidian registration added

## File Layout

```
vault-setup/
├── install.sh              # Main installer (~445 lines, executable)
├── README.md               # Usage docs for end users
├── HANDOVER.md             # This file
└── bundle/                 # All installable seed files
    ├── hooks/              # vault-rules-inject.js, vault-rules-validate.js (refactored versions)
    ├── skills/             # 5 SKILL.md files: vault-rules + llm-wiki-{ingest,query,lint,maintain}
    ├── brief/              # vault-brief.md
    ├── AGENTS.md           # Agent rules (from Core vault)
    └── templates/          # 7 note templates (concept, entity, log, project, session-log, source, topic)
```

## Key Architecture Change (Already Applied System-Wide)

The hooks were refactored from hardcoded paths to dynamic resolution:
- **Before:** `vault-rules-inject.js` and `validate.js` had `/Users/bernardoresende/Core/.vault/Core` hardcoded
- **After:** They resolve vault path from: `--vault-path arg > $VAULT_PATH env > state file > auto-detect`
- **State file:** `~/.claude/hooks/vault-rules-state.json` — written by installer, read by hooks on each invocation
- **System-wide:** Already applied to the current machine (state file exists, settings.json entries updated)

## How install.sh Works

1. Parses `--vault-name NAME` (default: "Core") and `--dry-run`
2. Resolves vault root at `$HOME/.vault/$VAULT_NAME`
3. Installs hooks → `~/.claude/hooks/`, skills → loop over `bundle/skills/*/SKILL.md` into `~/.claude/skills/`, brief → `~/.claude/`
4. If vault doesn't exist: creates full directory tree, copies AGENTS.md + templates, extracts scripts
5. If vault exists: skips existing files (idempotent)
6. Writes `vault-rules-state.json` with resolved path(s)
7. Merges hook matchers into `~/.claude/settings.json` (jq with python3 fallback, skips if already present)
8. Runs dependency check + quick health check

## Important Gotcha (Already Fixed in install.sh)

In bash, `[[ $DRY_RUN ]]` where DRY_RUN=false evaluates to **true** (non-empty string). All checks now use `[[ "$DRY_RUN" == true ]]` or `[[ "$DRY_RUN" != true ]]`. If you modify install.sh, never use bare `[[ $VAR ]]` for boolean checks — always compare strings.

## How to Test in a New Session

```bash
cd /Users/bernardoresende/Core/Sandbox/vault-setup

# Preview only (no changes)
./install.sh --vault-name TestName --dry-run

# Fresh install on simulated machine (HOME override)
rm -rf /tmp/test-home && HOME=/tmp/test-home ./install.sh --vault-name TestVault

# Verify directory structure
find /tmp/test-home/.vault/TestVault -type f | sort
find /tmp/test-home/.claude -type f | sort

# Idempotency test (run again, should skip existing files)
HOME=/tmp/test-home ./install.sh --vault-name TestVault

# Clean up
rm -rf /tmp/test-home*
```

## What Could Be Added Later (Not Done)

- Test with a real `~/.claude/settings.json` to verify jq merge adds the new Read matcher entry (dry-run confirmed it detects existing entries correctly, but live merge was not tested on our actual settings.json)
- Support for custom vault paths (not just `~/.vault/`)
- Uninstall script
