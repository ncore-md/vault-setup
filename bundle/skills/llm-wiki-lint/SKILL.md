# Name: llm-wiki-lint

## When to use
The user asks to check wiki quality, before committing changes that affect Wiki notes, or after creating/editing a note.

## Reference
- `.vault/Core/AGENTS.md` — Core Rules (Non-Negotiable), Allowed Tags section
- `.vault/Core/Schema/frontmatter-schema.md` — frontmatter field requirements (referenced in AGENTS.md)
- `.vault/Core/Schema/lint-checklist.md` — lint checklist (referenced in AGENTS.md)
- `scripts/wiki_tool.py` — lint, source-lint commands

## Workflow
1. Check frontmatter on each Wiki note:
   - Title field exists and is non-empty
   - tags array contains one of {topic, concept, entity, project, log}
   - topics and sources arrays are present (even if empty)
2. Check source_count: must equal the number of entries in `sources` array (derived, not manually set)
3. Run programmatic validation: `python3 scripts/wiki_tool.py lint`
4. Report any issues found with file names and specific violations
