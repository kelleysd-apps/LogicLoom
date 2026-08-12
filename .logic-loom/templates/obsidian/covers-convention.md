# The `covers:` frontmatter convention

`covers:` is the one authoring addition that lets a spec/ADR/decision note declare
the code it governs, so the code↔docs bridge (`graph-bridge.jsonl`) can draw a
`covers` edge from the doc node to the file(s)/dir(s) it describes. It is
**optional and soft** — omitting it costs nothing; a stale entry only warns.

## Shape

Add a `covers:` list to the YAML frontmatter of any spec, ADR, or decision note:

```yaml
---
title: Auth cookie rotation
status: accepted
covers:
  - src/auth/login.ts
  - src/auth/session.ts
  - plugins/loom-git/
---
```

Inline-list form is equivalent:

```yaml
---
covers: [src/auth/login.ts, plugins/loom-git/]
---
```

## Rules

- **Repo-relative paths.** No leading `/`. `plugins/loom-git/` (trailing slash) =
  the whole directory; `src/auth/login.ts` = one file.
- **Resolution is progressive.** With a code-graph MCP present, each path resolves
  to a graph node id (enabling blast-radius / "what governs this file" queries);
  with no MCP, it stays a path-string anchor. The convention works text-only on
  any clone and *upgrades* when the MCP is wired.
- **Fail-open linter.** A `covers:` entry pointing at a path that no longer exists
  (deleted/moved) is a **dangling edge** → the linter emits a warning and moves
  on. It **never blocks** `/finalize`, commits, or CI. Likewise, a code file that
  *no* spec covers is a soft "uncovered" note, not an error.
- **Direction.** `covers:` reads doc → code. The reverse `decided-by` edge
  (code → the ADR that governs it) is derived by the bridge generator; you do not
  hand-author it.

## Why declare it

- `/graph` can answer "what spec covers `src/auth/*`" and "what does editing this
  file impact" by walking the bridge.
- The merged export (Obsidian vault / Mermaid / GraphML) shows spec nodes and code
  nodes in one graph.
- It mirrors the 2026 ADR-as-knowledge-graph practice without an LLM extraction
  pass — the edge is author-written, deterministic, and git-tracked.
