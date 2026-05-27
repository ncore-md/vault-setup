# Name: llm-wiki-maintain

## When to use
Before a meaningful commit that touches Wiki content, or when the user asks you to run maintenance on the wiki.

## Reference
- `.vault/Core/AGENTS.md` — Maintenance Gate section, Ingest Workflow step 7
- `scripts/wiki_tool.py` — all commands

## Workflow
1. Run health check: `python3 scripts/wiki_tool.py doctor`
2. Rebuild catalog and index: `python3 scripts/wiki_tool.py build`
3. Validate compiled notes: `python3 scripts/wiki_tool.py lint`
4. Check Raw source coverage: `python3 scripts/wiki_tool.py source-lint`
5. Log changes if the maintenance cycle modified Wiki content: `python3 scripts/wiki_tool.py log --title "..." --details "..."`
