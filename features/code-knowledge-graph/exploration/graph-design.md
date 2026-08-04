# Code Graph + Knowledge Graph — Design

**Feature:** `features/code-knowledge-graph/`
**Status:** exploration synthesis (consolidates 5 research landscapes)
**Date:** 2026-07-05
**Ground-truthed on this machine:** `jq 1.7.1`, `sqlite3 3.51.0`, `rg 14.1.1` present; `tree-sitter` NOT installed; `ast-grep` NOT installed; `/usr/bin/ctags` is Apple/BSD (no `--version`, no JSON, no real extraction). 8 plugins, bridge-manifest present, 7 domain-briefs, 16 loom-memory markdown files, `backend-interface.sh` seam (`backend_search/index/reindex_all/health_check`) confirmed live.

---

## 1. Topline

**Build both graphs as ONE generated, git-tracked, plain-text artifact — never a graph DB, never an MCP daemon.** Buy nothing. The split is by *layer, not by build-vs-buy*: (i) a **harness component/dependency graph** extracted deterministically from `plugin.json` + `.bridge-manifest.json` + frontmatter + hook wiring (this repo has no product code, so this *is* the code graph today); (ii) a **knowledge layer** that formalizes loom-memory's already-present-but-dead `[[wikilink]]` + `SUPERSEDES/CORRECTS/REMOVED` edges into working 1-hop retrieval; (iii) a **product-code layer** that stays on paper until `web//apps/` appears, then rides `ctags`/`rg` (the mechanism swarm-explore already specifies). Storage posture: canonical source is JSONL/JSON adjacency committed as text (like the 16 memory files already are); an *optional* on-demand SQLite `.db` (built from the JSONL, git-ignored) supplies recursive-CTE traversal only if 1-2-hop `jq` walks prove insufficient. It earns its keep by feeding machinery that already exists — swarm-explore's `## Repo map (ranked)`, the freeze plan-as-DAG overlap/blast-radius validator, loom-memory graph-aware recall — not as a standalone artifact.

---

## 2. Build-vs-Buy Scorecard

| Layer | adopt-tool | build | hybrid | **Winner** | Decisive reason |
|---|---|---|---|---|---|
| **Harness component graph** (this repo *today*) | — | ✅ **~150-line jq+rg generator** | — | **BUILD** | A generic code-graph tool reads *language ASTs*; the harness structure lives in **markdown frontmatter + JSON manifests** it cannot see. Every edge maps to a stable existing field (`.bridge-manifest.json`, `plugin.json dependencies[]`, `SKILL.md` frontmatter, hook→matcher wiring). Extraction is deterministic and cheap. |
| **Knowledge graph** (loom-memory) | — | ✅ **edge-parser + 1-hop expansion** | — | **BUILD (formalize in place)** | The graph already exists and is **dead metadata** — the shell BM25/vector/hybrid backend parses *none* of the `[[wikilink]]`/temporal edges. Graphiti/Zep/Cognee/Mem0/Neo4j-LLM-Builder would **re-extract (via LLM, worse) edges the author already wrote precisely** (`SUPERSEDES` on dated nodes = the exact temporal-KG feature Graphiti charges ~600K tokens/conversation + a graph DB to approximate). Neo4j needs a running server — disqualifying for a template. |
| **Product-code graph** (future, when `web//apps/` exists) | — | ✅ **thin ctags+rg repo-map helper (deferred)** | — | **BUILD-THIN, DEFER** | No product code exists → building now is premature. When it does: promote swarm-explore's on-demand `## Repo map (ranked)` (ctags+rg, grep fallback) into a reusable helper. **Do NOT buy** Codebase-Memory / CodeGraphContext / graph-sitter / Cognee — every one is a **persistent MCP daemon + file-watcher + graph DB**, the exact liability class LogicLoom already cut 3× (sdd-marketplace MCP, RL telemetry, dev-loop). Their own benchmark: 83% (graph) vs 92% (plain file-exploration) answer quality. |
| *Storage / query* | — | ✅ **JSONL + optional on-demand SQLite** | — | **BUILD (text-first)** | SQLite is the **only** embedded DB actually installed (no duckdb binary; no kuzu/networkx/rdflib). "SQLite-as-graph via recursive CTEs" is a proven 2026 pattern. LadybugDB (Kuzu fork) = right Cypher power but a **native wheel a cloner must install + a ~10-month-old single-team fork born of an abrupt archival** → reference-only. |

**Reference-only tools (document, never bundle):** tree-sitter tags + Aider repo-map PATTERN + ast-grep (all serverless — the correct primitives *if/when* product code needs them); SCIP (`scip-typescript/-python/-java` → emit `.scip` in CI, read via a skill — precise, no resident server); GitHub stack-graphs (per-language `.tsg` rule authoring = real work; **archived Sept 2025** — a rot warning); LlamaIndex `SimplePropertyGraphStore` (validates the in-memory/no-DB/networkx-export shape); LazyGraphRAG (validates rule-based, index-cheap, defer-to-query-time); the MCP knowledge-graph family (`@modelcontextprotocol/server-memory`, Obsidian-style MegaMem) → **adopt its DATA MODEL** (typed entities + directed active-voice relations + observations), not its server; universal-ctags (fallback tier only — libjansson build not guaranteed on cloner machines); LSP-via-multilspy (lean on Claude Code's *native* LSP tool instead); Claude Code native LSP tool (opt-in precision escalation on a real workspace).

**Rejected outright:** CodeQL (security engine + commercial license landmine for cloner private repos); Kythe / Glean (build-instrumented fact servers, monorepo-scale); Neo4j / Memgraph (running JVM/RAM daemon + MCP process); DuckDB+DuckPGQ (network-fetched, version-pinned, self-described "research project" extension on an uninstalled binary); Oxigraph/RDFLib (RDF/SPARQL ontology weight, uninstalled); Semgrep cross-file (paid/cloud); full Microsoft GraphRAG / Cognee / Graphiti-Zep / Mem0 / Neo4j-LLM-Builder / Sourcetrail (LLM-extraction cost, hallucinated edges, GUI, or mandatory server).

---

## 3. Recommended Architecture

### 3.1 Node/edge schema (one graph, three node families)

**Harness component graph (Layer 1 — ships now):**

| Node type | Source of truth |
|---|---|
| `plugin` | `plugins/*/.claude-plugin/plugin.json` |
| `command` | `.claude/commands/.bridge-manifest.json` (`bridged`/`static`) + command bodies |
| `skill` | `plugins/*/skills/*/SKILL.md` frontmatter |
| `agent` | `.claude/agents/*.md` (project) + plugin agents |
| `hook` | `.claude/settings.json` hook→matcher wiring |
| `domain-brief` | `plugins/loom-governance/domain-briefs/*.md` |
| `principle` | `constitution.md` (16, read-only) |

| Edge type | Extracted from |
|---|---|
| `bridges-to` (command→plugin) | `.bridge-manifest.json` |
| `depends-on` (plugin→plugin) | `plugin.json dependencies[]` |
| `invokes` (command→skill) | literal `skills/<x>/SKILL.md` refs in command bodies |
| `delegates-to` (command/agent→agent) | `agentType` / Task refs |
| `enforces` (skill/hook→principle) | `SKILL.md constitutional_principles:` + hook wiring |
| `injects` (preflight→domain-brief) | `get_domain_brief` / `domains.conf` |

**Knowledge layer (Layer 1b — ships now, same artifact):**

- Nodes: `memory-note` (16 files). Edges: `links-to` (`[[wikilink]]` + `](file.md)`), typed temporal `SUPERSEDES` / `SUPERSEDED-BY` / `CORRECTS` / `RETAINED` / `REMOVED`.
- **Component-anchor edges** bridge the two families: `memory-note ⇄ plugin|skill|hook|file it discusses` — so a query about "the freeze hook" 1-hops to every retro/decision touching it.
- Normalize the slug inconsistency found in the corpus (both `[[architecture-v6-1…]]` and `[[architecture_v6_1…]]`); lint dangling links.

**Product-code layer (Layer 2 — schema reserved, built later):** nodes `file`/`symbol`; edges `imports`/`calls`/`references`, ranked by in-degree. Populated by ctags+rg when a product workspace exists. **No tree-sitter required** (not installed; ctags/rg + grep-fallback matches swarm-explore's existing contract).

### 3.2 Storage / query posture (no-daemon, template-safe)

- **Canonical store = git-tracked JSONL/JSON adjacency** beside the markdown, in the Anthropic memory-server *shape* (`{"type":"entity",…}` / `{"from":..,"to":..,"relationType":..}`). Diff-stable, Claude reads it natively, `jq`/`rg` query it. Ships inside the template exactly like the 16 memory files → cloners inherit with **zero setup**.
- **Optional query tier = on-demand SQLite** built from the JSONL (nodes/edges tables, recursive CTEs for multi-hop reachability/shortest-path). Ship schema+seed as `.sql` text; `.gitignore` the built `.db`. Slots into loom-memory's existing `backend_search/index/reindex_all/health_check` seam as a graph-capable backend. **Build only if `jq` 1-2-hop walks prove insufficient.**
- **Derived view = DOT/GraphML export** from the JSONL for a rendered component diagram (Graphviz) — export-only, opt-in, never the store, honors "no proactive docs."

### 3.3 What each part feeds (earns its keep)

| Consumer | What the graph gives it | Store vs live |
|---|---|---|
| **swarm-explore `## Repo map (ranked)`** | cached ranked adjacency lookup+prune replaces the fresh grep-walk (same ≤40-line output contract, still read-only). For *this* repo: "which plugins/skills/commands touch capability X". | generated artifact, refreshed on session-start/post-commit |
| **freeze / plan-as-DAG** | the **deferred v0.2** cross-ownership overlap validator (does a symbol owned by task A get referenced from task B's files?) + review-time blast-radius. **Advisory, at `/plan-review` + `/review-team` time only** — NOT on the write-time hook's hot path (hook stays literal-match, fail-open). | generated, one-shot |
| **loom-memory recall** | 1-hop neighbor expansion after a BM25/vector hit surfaces linked + superseding/superseded notes (LazyGraphRAG's defer-to-query-time, **no LLM**). | sidecar the existing hybrid backend consults, refreshed on `/retro` |
| **NEW: orphan / dead-capability linter** | in-degree==0 (orphan skill/agent), dangling edge (command missing from bridge), unreachable domain-brief — the drift class the framework already polices. Runs in CI / `/finalize` / `/update-framework`. | generated, on-demand |
| **domain detection** | *nothing* — routes off prompt TEXT, not code. **Do not build for it.** | n/a |
| **context loaders** | *nothing independent* — subsumed by swarm-explore + recall. **Do not build for it.** | n/a |

---

## 4. Phased Plan (both graphs together, each phase build+verifiable)

**Phase 1 — Harness component graph + orphan linter (deterministic, ships first).**
`build-component-graph.sh` (~150-250 lines jq+rg+frontmatter parse) → JSONL adjacency for the 6 harness node families + 6 edge types. Add `lint-graph`: orphans (in-degree 0), dangling edges (command not in bridge, broken skill ref), unreachable domain-briefs. Wire into `/finalize` / CI. **Deterministic, zero LLM, zero new dependency.** *Verify:* linter flags a deliberately-orphaned test skill; every plugin/command/skill/agent/hook appears as a node.

**Phase 2 — Formalize the loom-memory knowledge layer (deterministic).**
`build-memory-graph.sh`: parse `[[wikilink]]`, `](file.md)`, typed `SUPERSEDES/CORRECTS/REMOVED` into the SAME adjacency; normalize slug hyphen/underscore; lint dangling links; add `component-anchor` edges (note ⇄ plugin/skill/hook). Add **1-hop expansion** to `backend_search` so a keyword hit also surfaces linked + superseding notes. **Deterministic, zero LLM.** *Verify:* a query on "freeze hook" returns the hook node + linked retros; dangling-link lint on the 16 files reports the known slug mismatch.

**Phase 3 — Optional SQLite query tier + DOT export (only if needed).**
Emit `schema.sql` + seed loader that builds the `.db` on demand from Phase-1/2 JSONL; recursive-CTE traversal for freeze blast-radius. Emit DOT for a Graphviz component diagram. `.gitignore` the `.db`. **Build only when `jq` walks are proven insufficient** — do not pre-build. *Verify:* a 3-hop reachability query returns the same set a hand-walk does.

**Phase 4 — Freeze overlap/blast-radius validator (advisory).**
Consume the graph at `/plan-review` + `/review-team` to warn on path-disjoint-but-symbol-coupled ownership and compute transitive dependents of a changed path. **Advisory only; never on the write-time hook.** *Verify:* a plan where task A owns a file imported by task B's file raises a warning.

**Phase 5 — DEFERRED until `web//apps/` exists: product-code layer.**
Promote swarm-explore's on-demand ctags+rg repo-map into a reusable helper populating Layer-2 `file`/`symbol` nodes ranked by in-degree. Grep-only fallback. **No tree-sitter, no daemon.** Optional opt-in `.scip` (CI-emitted) read-path documented, not bundled. *Do not start until product code exists.*

> **Deterministic vs LLM-extracted:** *everything* above is rule-based/deterministic — there is **no LLM extraction step anywhere**. That is the whole point: the edges are already author-written or mechanically present. LLM extraction is precisely what makes GraphRAG/Cognee/Graphiti overbuild for this corpus.

---

## 5. Anti-Overbuild Guardrails

**Do NOT build (covered by Claude-native + existing seeds):**
- Any **graph DATABASE** (Neo4j / Memgraph / Kuzu-Ladybug / FalkorDB) or **MCP graph daemon** — repeats the marketplace-MCP / RL-telemetry / dev-loop cut; fails the template-distribution bar (a cloner cannot inherit a running server).
- Any **LLM-extraction pipeline** (GraphRAG / Cognee / Graphiti / Mem0) — re-derives, worse and expensively, edges the author already wrote.
- A **persistent whole-repo incremental index / file-watcher** — before product code exists there is nothing to watch.
- **tree-sitter / ast-grep as a shipped dependency** — not installed; ctags+rg suffice for Layer 2's ranked sketch. Add on-demand *only* if a language ctags handles poorly becomes load-bearing.
- **A replacement for loom-memory's BM25/vector/hybrid retrieval** — it works; only add edges.
- **Graph-awareness in the write-time freeze hook, domain-detection preflight, or context loaders** — hot-path risk / wrong input / subsumed.
- **The product-code extractor now** — no product code to extract.
- **A global PageRank importance index** — swarm-explore explicitly wants a *local* ranked sketch, not a global index.
- **DOT/GraphML as the primary store** — it can't be queried in place; export-only.

**Tripwires — signals this is becoming the next cut subsystem:**
1. Any proposal introduces a **running process, port, or `.gitignore`'d state a cloner must keep alive** (beyond the on-demand `.db` that is rebuilt, never distributed).
2. An **LLM call enters the extraction path** (cost + hallucinated edges = the GraphRAG anti-pattern).
3. The generator grows a **schema-enforcer / validator that blocks** rather than a fail-open lens (it must tolerate the ~40% of skills lacking `constitutional_principles`/`triggers` keys).
4. A **new binary dependency** appears in the template's clone-time requirements (tree-sitter, duckdb, a native wheel).
5. The graph is built for a consumer that **doesn't consume it** (domain detection, context loaders) — i.e. artifact-for-its-own-sake.
6. **Freshness needs a watcher** rather than lazy regen on session-start/post-commit/`/retro`.

---

## 6. Open Decisions (need the user's call before building)

1. **Canonical serialization format:** single `graph.json` `{nodes,edges}` vs append-only `graph.jsonl` (Anthropic memory-server shape). JSONL is more git-diff-stable; JSON is simpler to `jq`. *Recommendation: JSONL.*
2. **Where the artifact lives:** beside the memory files (`…/memory/graph.jsonl`) vs a feature-local path vs `.logic-loom/`. Affects whether it ships in the template or is regenerated per-clone. *Recommendation: git-tracked beside memory, regenerated on demand.*
3. **Freshness trigger:** session-start hook vs post-commit vs manual `/`-command vs the existing `sync-plugin-commands` bridge step. *Recommendation: hang Phase-1 regen off the existing bridge; memory sidecar off `/retro`.*
4. **Phase-3 SQLite:** build it now as insurance, or strictly on-demand once `jq` walks are shown insufficient? *Recommendation: defer — start text-only.*
5. **Scope of Phase 1 first cut:** all 6 node families at once, or component graph (plugin/command/skill/agent) first and defer hook→principle `enforces` edges to a follow-up? *Recommendation: all node families, edges incrementally.*
6. **Does the orphan linter gate `/finalize` (fail the check) or only warn?** Given fail-open posture elsewhere, *recommendation: warn, don't block.*
7. **Confirm no near-term `web//apps/` plans** — if a product workspace is imminent, Phase 5's ctags+rg helper moves up; otherwise it stays deferred.

---

## Sources

**Code-graph tooling:** tree-sitter v0.26.9 + tags.scm (github.com/tree-sitter/tree-sitter/releases; tree-sitter.github.io/tree-sitter/4-code-navigation.html); Aider repo-map / PageRank (deepwiki.com/Aider-AI/aider/4.1-repository-mapping-system; github.com/pdavis68/RepoMapper); ast-grep v0.44.0 (ast-grep.github.io); universal-ctags JSON (docs.ctags.io); SCIP (github.com/sourcegraph/scip; scip-code.org; sourcegraph.com/blog/the-future-of-scip); stack-graphs **archived Sept 2025** (github.com/github/stack-graphs; github.blog/open-source/introducing-stack-graphs); CodeQL (github.com/github/codeql); Glean (github.com/facebookincubator/Glean); Kythe (kythe.io); multilspy (github.com/microsoft/multilspy); Codebase-Memory 83% vs 92% (arxiv.org/html/2603.27277v1); CodeGraphContext (github.com/CodeGraphContext/CodeGraphContext).

**Knowledge-graph / GraphRAG:** LazyGraphRAG ~0.1% index cost (microsoft.com/en-us/research/blog/lazygraphrag…); Microsoft GraphRAG (github.com/microsoft/graphrag); GraphRAG cost cliff (medium.com/graph-praxis/the-graphrag-cost-cliff…); Graphiti/Zep temporal + ~600K tokens (vectorize.io/articles/zep-vs-cognee); Cognee (github.com/topoteretes/cognee); Mem0 (github.com/mem0ai); Neo4j LLM KG Builder (neo4j.com/labs/genai-ecosystem/llm-graph-builder); LlamaIndex SimplePropertyGraphStore (developers.llamaindex.ai/…/lpg_index_guide); txtai (neuml.github.io/txtai); LightRAG/nano-GraphRAG (github.com/hkuds/lightrag; github.com/gusye1234/nano-graphrag); MCP memory server + Obsidian KG (github.com/modelcontextprotocol/servers/tree/main/src/memory; github.com/shaneholloman/mcp-knowledge-graph; github.com/C-Bjorn/MegaMem).

**Storage:** SQLite-as-graph recursive CTEs (dev.to/rohansx/sqlite-as-a-graph-database-recursive-ctes…; github.com/shwetarkadam/sqlite-graph); LadybugDB / Kuzu-fork (ladybugdb.com; thedataquarry.com/blog/from-kuzu-to-ladybug; kuzu archived Oct 2025); DuckPGQ "research project" (duckdb.org/docs/current/guides/sql_features/graph_queries; github.com/cwida/duckpgq-extension); Oxigraph (github.com/oxigraph/oxigraph); Neo4j/Memgraph MCP (neo4j.com/developer/genai-ecosystem/model-context-protocol-mcp; memgraph.com/blog/memgraph-vs-neo4j…).

**Repo (ground-truth, this machine):** `.claude/commands/.bridge-manifest.json`; `plugins/*/.claude-plugin/plugin.json`; `.claude/settings.json`; `plugins/loom-orchestrator/skills/swarm-explore/SKILL.md` (Repo-map, lines 64-92); `.docs/architecture/freeze-scope-protocol.md` (literal-match §5, deferred v0.2 validator); `plugins/loom-memory/lib/{backend-interface,hybrid-search,bm25-search,vector-search}.sh`; `.claude/hooks/user-prompt-submit/governance-preflight.sh`; `plugins/loom-governance/domain-briefs/` (7); `.docs/architecture/loom-architecture.md`.
