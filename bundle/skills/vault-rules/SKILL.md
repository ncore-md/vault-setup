# Core — Structured Knowledge Base

**Location:** `~/.vault/{name}` (set at install time)
**Full rules + command reference:** AGENTS.md (loaded automatically when working with this Vault)

## When to use
The LLM Wiki stores compiled knowledge about AI/ML concepts, tools, and topics. Use it to research, ingest sources, maintain knowledge notes.

## Required Tools
- **Obsidian CLI** — for reading/writing notes with correct formatting (wikilinks, frontmatter)
- **wiki_tool.py** — for building catalog, linting, managing sources

Never edit core files directly with raw reads/writes. These tools enforce Obsidian's strict formatting requirements — wikilinks, frontmatter schema, naming conventions.

## Core Rules (Non-Negotiable)
1. **Sources are immutable** — never overwrite `Raw/Sources/` files during compilation.
2. **One concept per note** — keep Wiki notes short (3-5 key points).
3. **Wikilinks use Title Case** — `[[Graph RAG]]` not `[[graph-rag]].
4. **Always include topics and sources** — even if empty (`topics: [], sources: []`).
5. **Always run `wiki_tool.py build` after changes** — source_count is derived, not manual.

## Ingest Workflow
1. Clean Markdown → `Raw/Sources/` (remove nav, ads; preserve all facts).
2. Search catalog for related topics before creating new notes.
3. Open only the most relevant existing Wiki notes — not all context.
4. Create/update focused note in correct folder (`Wiki/Topics/`, `Wiki/Concepts/`, etc.).
5. Add source links to `sources` array, keep `source_count` accurate.
6. Validate: `wiki_tool.py build && lint`. Update manifest: `source-scan --update --accept-covered`.
7. Log changes, commit.

## Query Workflow
1. Start with `Wiki/index.md` for overview.
2. Search catalog: `wiki_tool.py search-catalog --query "topic"`.
3. Open relevant notes from step 2 results (not all Raw context).
4. Synthesize answer; open Raw sources only when compiled notes are insufficient.

## Maintenance Gate
Before committing: `wiki_tool.py doctor && build && lint`. After source ingestion, also run `source-scan --update --accept-covered` and `source-lint`.
