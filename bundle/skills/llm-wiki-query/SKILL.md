# Name: llm-wiki-query

## When to use
The user asks a question that could be answered from the Wiki knowledge base, or wants you to look up something in the wiki.

## Reference
- `.vault/Core/AGENTS.md` — Query Workflow section, Core Rules
- `Wiki/index.md` — compiled knowledge base overview (always check first)
- `scripts/wiki_tool.py` — search-catalog command

## Workflow
1. Start with `Wiki/index.md` for an overview of the knowledge base.
2. Search the catalog: `python3 scripts/wiki_tool.py search-catalog --query "user topic"`
3. Open the most relevant Wiki notes from Step 2 results — not all Raw context.
4. Synthesize an answer from the compiled notes (distilled knowledge).
5. Open Raw sources only when:
   - The compiled note is insufficient, OR
   - Source-level verification is requested.
6. Cite both the compiled note and Raw source when your answer depends on source material.
