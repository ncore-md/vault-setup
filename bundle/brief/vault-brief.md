# Vault Write Rules (Core/.vault/Core)

## When to use
Only create or update wiki notes when a task explicitly produces structured knowledge about AI/ML concepts, tools, topics, or projects.

## Frontmatter Template
Copy this exact structure for every new wiki note:

```yaml
---
Title: "Note Title"           # Title Case, matches Obsidian display name
tags: [concept]               # one of: topic, concept, entity, project, log
created: YYYY-MM-DD           # lowercase "created" (not Created)
updated: YYYY-MM-DD           # same date as created on first write
topics: []                    # related topic names, e.g. ["ai-agents"]
sources: ["[[Source Title]]"] # wikilinks to Raw/Sources/ files, e.g. [[Rust Lifetimes]]
source_count: N               # must equal len(sources) exactly
---
```

## Rules
- **One concept per note** — 3–5 key points max, split if longer
- **Title Case wikilinks** — `[[Graph RAG]]` not graph-rag
- **Folder matches tag**: Wiki/Topics/, Concepts/, Entities/, Projects/, Logs/
- **Never overwrite Raw/Sources/** — source files are immutable during compilation
- Every note must include `## Related` and/or `## Sources` sections in the body

## Workflow
Produce wiki notes as deliverables with correct frontmatter. Do NOT run `build` or `lint` — the main session agent handles curation and validation before committing.
