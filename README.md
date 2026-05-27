# Vault Setup Wizard

Install the Claude Code vault-rules system on any machine. Creates a structured knowledge base (LLM Wiki) with agent-enforced rules, or adds it alongside existing vaults.

## What This Is — In Plain English

The **vault** is a personal knowledge base for AI/ML concepts, tools, and topics. You feed it articles, notes, transcripts (raw sources), then Claude Code compiles them into structured wiki entries with proper tags and cross-links.

The **hooks** are invisible — they make Claude Code aware of your wiki rules whenever it reads a file in the vault, and prevent accidental edits to managed files.

Think of it as: you feed sources → Claude Code organizes them into a searchable wiki, with rules enforced automatically.

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

## How You'll Use It (Daily Workflow)

### Ingesting a new article or note
1. **Save the raw source** — paste cleaned Markdown into `Wiki/Raw/Sources/`
2. **Ask Claude Code to compile it** — e.g., "I have a source on Graph RAG, please add the key concepts to my wiki"
3. Claude Code will use `wiki_tool.py build && lint` automatically when needed (via the SKILL.md)

### Querying your knowledge base
- **Ask Claude Code** — it knows to search `Wiki/index.md` and the catalog first
- **Search from CLI** — `python3 scripts/wiki_tool.py search-catalog --query "your topic"`

### Running the tool directly
```bash
cd ~/.vault/{name}

# Validate everything is consistent (run after any changes)
python3 scripts/wiki_tool.py doctor && build && lint

# Scan raw sources and update manifest
python3 scripts/wiki_tool.py source-scan --update --accept-covered

# Search the compiled catalog
python3 scripts/wiki_tool.py search-catalog --query "neural networks"

# Log a change
python3 scripts/wiki_tool.py log -m "Added Graph RAG concept note"

# Check for sources not yet in manifest
python3 scripts/wiki_tool.py source-delta
```

## Manual Parts — What Requires Human Attention

The system is mostly automatic, but these things need your input:

| Task | How Often | What You Do |
|------|-----------|-------------|
| **Add raw sources** (`Raw/Sources/`) | As you find interesting content | Paste or save cleaned Markdown files. Keep them source-faithful — don't rewrite them in your own words. |
| **Compile sources into wiki notes** | After adding new raw sources | Ask Claude Code to compile, or do it yourself using the templates in `_templates/` |
| **Run `wiki_tool.py build && lint`** | After every change to wiki notes | Ensures the catalog and manifest stay in sync. The SKILL.md tells agents this, but you may need to run it manually if working outside Claude Code. |
| **Review agent-generated notes** | Periodically | Agents are good at following rules but can miss nuance. Check important entries for accuracy and completeness. |
| **Update the source manifest** (`Schema/source-manifest.jsonl`) | After ingesting new sources | Run `source-scan --update` to register raw files and accept any that are already processed. |
| **Maintain cross-references** (`[[wikilinks]]`) | When connecting related concepts | Links between notes should be intentional, not auto-generated. Review them as you add new wiki entries. |

**Not automated:**
- **Source cleaning** — stripping ads, navigation, and boilerplate from scraped articles. You (or an agent) need to produce clean Markdown before saving to `Raw/Sources/`.
- **Curation** — deciding what's worth compiling into the wiki. The system won't add notes automatically; something has to trigger it.
- **Schema changes** — if you modify note templates or frontmatter rules, the SKILL.md and AGENTS.md need updating too.

## Customization — Making It Yours

### Adding new note types
Create a template in `_templates/` (use an existing one as reference), then add the folder and allowed tags to `AGENTS.md`.

### Customizing hook behavior
Hooks live in `~/.claude/hooks/` and are **copies** of the bundle — they're not symlinked. To customize:
- Edit `~/.claude/hooks/vault-rules-inject.js` to change what gets injected
- Edit `~/.claude/hooks/vault-rules-validate.js` to change what gets blocked
- After changes, restart Claude Code (hooks are read on tool invocation)

### Adding more vaults
Run the installer again with a different name:
```bash
./install.sh --vault-name Work    # Second vault, same machine
```

Each vault gets its own hooks and settings.json entries. The validate hook applies to all registered paths.

### Using with Obsidian Desktop
If you use the Obsidian app, the installer can register your vault in `obsidian.json`. After installation:
1. Open Obsidian Desktop → "Open folder as vault" → select `~/.vault/{name}/`
2. Your wiki will appear in the sidebar alongside any other vaults

### Disabling parts of the system
- **No hooks:** Skip step 6 of installation (decline when prompted). Hooks are optional — the SKILL.md and AGENTS.md work without them.
- **No Obsidian registration:** Decline when prompted during install, or remove entries from `obsidian.json` manually.

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
