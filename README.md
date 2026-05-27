# Vault Setup Wizard

Install the Claude Code vault-rules system on any machine. Creates a structured knowledge base (LLM Wiki) with agent-enforced rules, or adds it alongside existing vaults.

## Quick Start

```bash
./install.sh                          # Install with default name "Core"
./install.sh --vault-name MyVault     # Install to ~/.vault/MyVault
./install.sh --dry-run                # Preview without making changes
```

## What It Installs

| Component | Destination | Purpose |
|-----------|-------------|---------|
| Hooks | `~/.claude/hooks/vault-rules-{inject,validate}.js` | Inject vault rules on Read/Bash; block direct writes to managed vaults |
| Skill definition | `~/.claude/skills/vault-rules/SKILL.md` | Agent skill with workflow rules |
| Brief | `~/.claude/vault-brief.md` | Sub-agent instructions for vault operations |
| AGENTS.md | `~/.vault/{name}/AGENTS.md` | Agent rules for the vault itself |
| Templates | `~/.vault/{name}/_templates/` | 7 note templates (concept, entity, log, project, session-log, source, topic) |
| Scripts | `~/.vault/{name}/scripts/` | wiki_tool.py, audit_public.py (stdlib-only Python) |
| State file | `~/.claude/hooks/vault-rules-state.json` | Maps vault paths for hook resolution |
| settings.json entries | `~/.claude/settings.json` | Hook matchers for PreToolUse injection/validation |

## Vault Structure Created

```
~/.vault/{name}/
├── AGENTS.md
├── Wiki/
│   ├── Topics/index.md    # Compiled topic notes
│   ├── Concepts/index.md  # Compiled concept notes
│   ├── Entities/index.md  # People, orgs, tools
│   ├── Projects/index.md  # Initiatives with scope/status
│   ├── Logs/log.md        # Activity logs
│   └── catalog.jsonl      # Searchable compiled notes index
├── Raw/
│   ├── Sources/           # Unprocessed source material (immutable)
│   └── Files/             # Binary attachments
├── Schema/                # Rules, schemas, manifests
└── _templates/            # Note templates for new content
```

## Multi-Vault Support

The hooks resolve vault paths from the state file (`vault-rules-state.json`), allowing multiple managed vaults on a single machine:

```bash
./install.sh --vault-name Core    # First vault
./install.sh --vault-name Work    # Second vault (merges into existing hooks)
```

Each vault gets its own `Read:${VAULT_PATH}` matcher in settings.json. The validate hook blocks writes to all registered vault paths.

## Prerequisites

- **Node.js** — required for hook execution
- **Python 3.8+** — required for wiki_tool.py and settings.json merge fallback
- **jq** (optional) — preferred over python3 for JSON manipulation
- **Obsidian CLI** (optional) — `/usr/local/bin/obsidian` for advanced features

## How It Works

1. **Hooks** (PreToolUse) — `vault-rules-inject.js` reads AGENTS.md and injects it into the agent context when relevant tools are used. `vault-rules-validate.js` blocks direct Write/Edit to managed vault paths, enforcing use of Obsidian CLI or wiki_tool.py.

2. **State file** — `vault-rules-state.json` stores vault paths for hook resolution, enabling dynamic multi-vault support without hardcoded paths.

3. **settings.json merge** — Hook matchers are added idempotently (skipped if already present). Uses jq with Python fallback.

4. **wiki_tool.py** — Self-contained (stdlib only) tool for building catalog, linting notes, scanning sources, and managing the vault.

## After Installation

```bash
cd ~/.vault/{name}
python3 scripts/wiki_tool.py doctor && build && lint
```

## Files

| File | Role |
|------|------|
| `install.sh` | Main installer script (~580 lines) |
| `bundle/hooks/` | Hook scripts for ~/.claude/hooks/ |
| `bundle/skills/vault-rules/SKILL.md` | Skill definition |
| `bundle/brief/vault-brief.md` | Sub-agent brief |
| `bundle/AGENTS.md` | Agent rules for vault root |
| `bundle/templates/` | 7 note templates |
| `bundle/scripts.tar.gz` | wiki_tool.py + audit_public.py |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `No settings.json found` | Run the installer after Claude Code is installed and has created its config. |
| `Neither jq nor python3 found` | Install either (`brew install jq` or use system Python). wiki_tool.py still works without it. |
| `node not found` — hooks won't fire | Install Node.js (brew, nvm). Hooks require a working `node` binary. |
| `obsidian CLI not found` | Install Obsidian or the CLI at `/usr/local/bin/obsidian`. Wiki tools work without it. |
| Hooks firing but no AGENTS.md injected | Verify `vault-rules-state.json` contains your vault path and the `Read:${VAULT_PATH}` matcher is in settings.json. |
| Write/Edit blocked unexpectedly | The validate hook blocks direct writes to vault paths. Use Obsidian CLI or `wiki_tool.py` instead, or edit outside the managed path. |
| Multiple vaults — hooks interfering | Each vault gets its own `Read:${VAULT_PATH}` matcher. The validate hook applies to all registered paths. |
| `scripts.tar.gz is corrupt` | Re-download or re-run installer from the repo (the tarball ships in `bundle/`). |

## Uninstall

```bash
# Remove hooks, skill, brief, and state entries for a vault (data preserved)
./install.sh --uninstall --vault-name MyVault

# Dry-run preview
./install.sh --uninstall --vault-name MyVault --dry-run
```

This preserves `~/.vault/MyVault/` for backup/restoration. To remove the vault data entirely, delete it manually:

```bash
rm -rf ~/.vault/MyVault
```

## Known Limitations

- **Moving a vault after install** — Update the state file manually: `jq '.vault_path = "new/path"' ~/.claude/hooks/vault-rules-state.json`. The old matcher in settings.json will still work for reads.
- **settings.json race condition** — Running two installs simultaneously may corrupt the file. Install vaults sequentially.
- **Obsidian config** — Registration writes to Obsidian's `obsidian.json`. If you don't use Obsidian, decline when prompted (or the write is silent).
- **pi-vault-path** — Registration appends to a third-party tool's config file. Decline when prompted if you don't use it.
