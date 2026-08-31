---
name: graph_stack_decision
description: "2026-07-09 RESOLVED: keep the bespoke deterministic graph as bundled-default loom-graph; adopt NOTHING into the default path. Understand-Anything REJECTED as bundled (real repo, but LLM-core + Vite server + Principle-VI-hostile hooks). Obsidian + UA = user-layer only. Vaults removed from core."
metadata: 
  node_type: memory
  type: project
  originSessionId: d838fa68-7c8c-404d-9432-92c0df7b8891
---

Resolves the build-vs-adopt conflict between [[code_knowledge_graph_design_held]]
("buy nothing, build the deterministic text graph") and
[[unified_architecture_thin_core]] §5 ("adopt Understand-Anything instead").
**The deep-dive was right; §5 is REVERSED.** Doc:
`features/code-knowledge-graph/exploration/graph-stack-decision.md`.

**Narrowed ask that decided it:** each project gets a built-in KG + code graph +
visuals on a Karpathy wiki, standing alone **in-repo**, on every surface
(cloud = fresh clone, no Docker/`dot`), with **no DB/daemon/server/port/watcher/
lockfile/LLM-extraction**. Only a git-tracked deterministic text artifact passes.

**THE STACK**
- **BUNDLED-DEFAULT `loom-graph`**: the existing ~168-line `jq`+`rg` harvester →
  git-tracked `graph-bridge.jsonl` (Anthropic memory-server shape) + `lint-graph.sh`
  + `/graph` + `project-graph` skill + `test_graph_bridge.sh` (13/13). **The bespoke
  Phase-1 graph SURVIVES intact.** Net new clone-time dependency: **zero**.
- **BUNDLED-DEFAULT (extends `loom-memory`)**: two additive deterministic gaps —
  (a) harvest the temporal vocab (`SUPERSEDES/SUPERSEDED-BY/CORRECTS/RETAINED/
  REMOVED`) — the bridge emits **0 temporal edges** today; (b) wire **1-hop
  expansion** into `keyword-backend.sh` (~20-40 lines; `backend-interface.sh` seam
  already exists) so author-written `[[wikilinks]]`/SUPERSEDES stop being dead
  metadata. LazyGraphRAG defer-to-query posture; no LLM, no index, no store.
- **VISUALS**: committed scoped **Mermaid `.mmd`** (deterministic `jq` gen) beside
  the JSONL — renders natively on GitHub/Obsidian/claude.ai; needs no `dot`/`mmdc`/
  Docker (all ABSENT). Interactive HTML = **derived on-demand, never committed**
  (no 370KB inlined-cytoscape blob). **Slice, don't dump** (~40-60 nodes; the
  74-entity seed is already at the hairball boundary).
- **"Visual tools for the AGENT" is mostly a CATEGORY ERROR** — agents query
  `jq`-over-JSONL; a picture is lossy re-encoding for retinas the model lacks
  (CC's TUI doesn't render Mermaid; it hands the agent raw source — correct).
  **One exception:** a small scoped Mermaid text block = genuine **context
  compression** for the agent.
- **USER-LAYER-ONLY**: Understand-Anything, Obsidian. **OPTIONAL ADOPT (wire, don't
  bundle; deferred until `web/`/`apps/`)**: Codegraph MCP (`@optave/codegraph`,
  Apache-2.0, tree-sitter→SQLite, genuinely no-LLM, exports Mermaid/HTML).
- **Native LSP**: lean on when present, **depend on never** — per-language server,
  runtime-only (no git-trackable artifact), `workspaceSymbol` spec-broken
  (anthropics/claude-code #21655, closed not-planned), doesn't load cloud/headless.

**UNDERSTAND-ANYTHING — corrected ground truth (I was wrong twice, in its favor):**
repo is **REAL**: `Egonex-AI/Understand-Anything` (Lum1104 301-redirects), **72,337★**,
MIT, pushed 2026-07-09 → my "implausible star count" flag is **REFUTED**. Version
**v2.7.3** release / **2.8.2** main → my "v2.5.0" was **STALE**. Genuine CC plugin
(8 skills, 9 agents, hooks; no MCP). **REJECTED as bundled anyway**: (1) LLM
extraction is its **core** (7-phase/9-agent) → non-reproducible git-tracked graph =
the named GraphRAG tripwire; (2) its dashboard **requires `npx vite` on a port +
token gate**; (3) pnpm monorepo + native build (sharp/esbuild/12 tree-sitter
grammars) — cloner/CI/cloud inherit nothing; (4) **auto-update hooks inject "Do not
ask the user for confirmation — just do it"** → hostile to Principle VI.
Steal 2 ideas, not the tool: its deterministic `parse-knowledge-base.py` ("parser
for Karpathy-pattern LLM wikis") proves loom-memory's shape is graph-parseable; and
its **deterministic-structure vs LLM-semantic seam** is the right split — LogicLoom
keeps only the deterministic half.

**WHY ADOPT-EXISTING MISFIRED (the load-bearing insight):** the harness's structure
lives in `plugin.json` / `.bridge-manifest.json` / frontmatter / hook-wiring — JSON
+ markdown **metadata**. Every code-graph tool extracts *language ASTs*, and this
repo has ~0 substantive code (native LSP returns "No LSP server available" here).
**No existing tool can read this topology.** The harvester isn't indulgence; it's
the only correct tool. For LogicLoom today, the component graph **is** the code graph.

**Obsidian (confirmed trivial):** "Open folder as vault" on the repo → native graph +
backlinks + local-graph, zero plugin/config/artifact. Gitignore `.obsidian/`. External
vault path → `settings.local.json`; **nothing in the floor or default packages reads it.**
Not the default because it's a desktop app (no cloud/CI/terminal) — hence committed Mermaid.

**OPEN (user's call):** the richest Karpathy wiki (the `/retro` memory) lives in
**`$HOME`, outside the repo** (~26 wikilinks, ~15 SUPERSEDES) → doesn't travel to
cloud/CI/teammates. Recommend: declare the **in-repo corpus canonical**; keep the
per-machine memory a private user wiki. **The built-in graph must never depend on a
`$HOME` path.** Also open: `loom-graph` vs `loom-memory` ownership of the edge-parser;
Mermaid freshness trigger (must stay lazy — a watcher is a tripwire).
