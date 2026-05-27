# Name: llm-wiki-ingest

## When to use
The user adds a new source, wants to process raw content into wiki notes, or asks you to create/update compiled Wiki notes.

## Reference
- `.vault/Core/AGENTS.md` — Ingest Workflow section, Core Rules, directory structure
- `_templates/*.md` — frontmatter schemas for each note type (concept-note.md, topic-note.md, entity-note.md, project-note.md)
- `scripts/wiki_tool.py` — build, search-catalog commands

## Workflow
1. Put cleaned Markdown in `Raw/Sources/`. Remove navigation, ads, clutter — preserve all factual claims and context.
2. Search the catalog for related topics: `python3 scripts/wiki_tool.py search-catalog --query "key topic"`
3. Open only the most relevant compiled Wiki notes from Step 2 — not all Raw context. Understand what already exists before creating new notes.
4. Create or update focused Wiki notes in the correct folder per tag routing rule:
   - Topic → `Wiki/Topics/` — broad subject areas
   - Concept → `Wiki/Concepts/` — discrete ideas, definitions, mechanisms
   - Entity → `Wiki/Entities/` — people, organizations, tools, places
   - Project → `Wiki/Projects/` — initiatives with scope and status
5. Add Raw source links to `sources`. Ensure `source_count` equals the number of entries in `sources`.
6. Run validation: `python3 scripts/wiki_tool.py build && python3 scripts/wiki_tool.py lint`
7. Update manifest: `python3 scripts/wiki_tool.py source-scan --update --accept-covered`
8. Add a log entry if the ingest meaningfully changed the Wiki: `python3 scripts/wiki_tool.py log --title "..." --details "..."`
9. Commit
