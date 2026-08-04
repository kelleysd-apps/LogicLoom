# Project-Wide Knowledge Graph — Design (agent-queryable + visually-explorable, portable to every templated project)

**Feature:** `features/code-knowledge-graph/`
**Status:** exploration synthesis — consolidates 5 research landscapes (Obsidian / code-graph / unified-vs-federated / bridge-layer / visualization)
**Date:** 2026-07-05
**Supersedes (scoped):** the tooling axis of `graph-design.md` — see §2. The plain-text-first / no-daemon / no-LLM-edge **principles** are preserved intact.

**Ground truth re-verified on this machine (2026-07-05):**
- `node v20.20.2`, `npm 10.8.2`, `npx`, `uv 0.11.7`, `python3 3.9.6`, `jq 1.7.1`, `rg 14.1.1`, `sqlite3 3.51.0` **present**; `dot` (Graphviz) **ABSENT**; `docker` **ABSENT**. → Any visualization we lean on must render **without Graphviz and without Docker**. Mermaid (Obsidian/GitHub/VS Code native) and self-contained HTML are the safe paths; Neo4j/Kùzu/Memgraph browsers (Docker/server) are out for the default.
- **LogicLoom repo** = markdown/bash/plugins (thin code). In-repo `.logic-loom/memory/` = **5** files, **0** `[[wikilinks]]`. The rich `[[wikilink]]` + temporal `SUPERSEDES/CORRECTS` edges live **out of repo** in `~/.claude/projects/.../memory/` (**17** files) and carry the **hyphen-vs-underscore slug drift** (`[[architecture-v6-1…]]` AND `[[architecture_v6_1…]]` for the same node → dangling nodes in Obsidian's graph).
- **COSMOS (`/Users/bkelley/kelleysd-apps/cosmos-2`)** = a real product project: **~495 Rust + ~220 tsx + ~176 ts + ~52 py** files, `src/`, `src-tauri/`, `supabase/`, `mcp-servers/`, plus its own `.docs/` and `specs/`. Its `.mcp.json` **already runs stdio MCP servers via `npx`** (chrome-devtools-mcp, an sdd-marketplace node server) → adding an opt-in code-graph MCP is *the pattern it already uses*, not a new class of thing.

---

## 1. Topline

Ship a **FEDERATED, best-of-breed-per-layer** project graph joined by a shipped **convention**, not a unified store or a bundled engine. **Code layer** = an opt-in, per-project code-graph MCP the developer runs for *their* repo — default **Codegraph (`@optave/ops-codegraph-tool`, Apache-2.0, tree-sitter→SQLite, 34-tool MCP, 6 export formats, no daemon, no LLM)**; **knowledge/docs/links layer** = the project's already-markdown `.docs/ + features/ + specs/ + loom-memory` folders, which literally **are an Obsidian vault** (agents read them with plain **Read/Grep** — no MCP, no app needed); **bridge layer** = a git-tracked **`graph-bridge.jsonl`** built by a ~150-line `jq`+`rg` generator that harvests edges *already in the corpus* (inline backtick path-mentions, `[[wikilinks]]`, a new frontmatter `covers:` key) and resolves code paths to code-graph node ids when the MCP is present; **visualization** = **Obsidian's native graph view** for the human (the stated bar), with code made visible via an **Obsidian-vault / GraphML / Mermaid export** and a shipped single-file HTML viewer for the self-authored layer. Agents access it via the opt-in code MCP + native Read/Grep + a `/graph` skill that walks the bridge; a human sees it in Obsidian (personal vault open side-by-side with the project vault). **LogicLoom ships a `/graph` skill + a convention + `/initialize-project` wiring — never a bundled graph engine, never a mandatory floor daemon, never an LLM extraction pass in the default path.**

---

## 2. Federated vs Unified — the explicit call

**Decision: FEDERATED (best-of-breed per layer, linked by convention), with a UNIFIED view available *on demand* as an export — not as the store.**

The NEW goal relaxes one constraint and keeps two hard:
- **RELAXED (now allowed):** a *per-project, opt-in* dev MCP the developer connects for their own repo (a Codegraph MCP, an Obsidian MCP). "Just connecting an MCP server" is fine.
- **STILL FORBIDDEN #1:** a **mandatory harness-floor daemon** every clone must keep alive (the class cut 3× — sdd-marketplace MCP, RL telemetry, dev-loop). Servers/Docker graph DBs (Neo4j, Memgraph, full FalkorDB) and always-on file-watchers fall here.
- **STILL FORBIDDEN #2:** an **LLM-extraction pipeline that re-derives author-written edges** (Microsoft GraphRAG, Cognee, Graphiti/Zep). Field data (2026) shows extraction is ~75% of indexing cost and "hallucinates entities/relationships → confidently-wrong edges that don't fail loudly." loom-memory *already hand-writes* the temporal `SUPERSEDES/CORRECTS` edges these tools charge tokens + a DB to approximate.

Given those, **unified loses on the merits, not on ideology:**
1. Every genuinely-unified *store* is either (a) a resident server/daemon (Neo4j/Memgraph/FalkorDB) — forbidden-#1 and Docker isn't even installed here — or (b) a GraphRAG/agent-memory pipeline (GraphRAG/Cognee/Graphiti) — forbidden-#2.
2. The one embedded, no-LLM exception — **LadybugDB** (Kùzu successor fork) — is a **store, not a builder**. It stays empty until you run the *same* code+doc ingestion the federated tools already do, and it adds a ~10-month-old single-team fork (bus-factor risk for a capability *every* clone inherits) + a native wheel + a separate Explorer server that **isn't Obsidian** and doesn't tandem with a personal vault. It buys a DB + fork-risk and removes **none** of the ingestion work.
3. **Neither Codegraph tool indexes docs** — both `optave/ops-codegraph-tool` and `colbymchenry/codegraph` are code-only SQLite/MCP. So no single tool can own both halves as its primary store; federation is *forced* by ground truth, not merely preferred.
4. The two 2026 tools that *do* span code+docs in one store — **Graphify** (safishamsi) and graphify-rs / code-review-graph — **re-derive** the doc structure LogicLoom already authored (its `[[wikilink]]/SUPERSEDES/covers` edges) and impose a foreign store a clone must maintain. Graphify's non-code (PDF/image/"semantic") pass **uses an LLM** — forbidden-#2 in its default. We **mine its export format** (its `--obsidian` writer is excellent) but **reject it as the store**. *If* a team wants one tool, Graphify is adoptable **only in split code-only mode** (deterministic tree-sitter, LLM pass off) — documented as an alternative, not the default.

**Net:** keep each half in its best store, connect by a git-tracked text manifest, and offer the merged code+docs view as an *export* (Obsidian vault / Mermaid / GraphML) rendered in tools already on the machine. LogicLoom's mandatory floor gains only **text** (a JSONL manifest + a skill) — exactly how the memory files already inherit with zero setup.

---

## 3. The recommended stack (per layer)

### 3.1 Code layer — opt-in code-graph MCP (per **product** repo)
| | Choice | Why |
|---|---|---|
| **Default** | **`@optave/ops-codegraph-tool` (Codegraph)** — Apache-2.0, ~74★, tree-sitter→SQLite on-demand (`codegraph build` → `.codegraph/graph.db`, git-ignored), **34-tool MCP**, exports **DOT / Mermaid / JSON / GraphML / GraphSON / Neo4j-CSV** | Only **no-daemon** option delivering **both** first-class agent-query (callers/callees, `fn-impact`/blast-radius, boundaries, communities, diff-impact — exactly what freeze plan-as-DAG + `/review-team` consume) **and** a human-visual path via export. Deterministic tree-sitter = **no LLM edges**. Apache-2.0 = safe for cloner private repos. Multi-repo mode fits monorepo `apps/<name>`. |
| **Lighter alt** | **`colbymchenry/codegraph`** — MIT, on-demand MCP (`CODEGRAPH_NO_DAEMON=1`), zero-config, token-efficient | Simpler default for pure agent context. **Caveat:** its watcher-per-project and **no visualization** (agent-only, no export) make it the lighter-but-blinder choice; Codegraph's 6 exports are what feed the human view. |
| **Companion (precision)** | **Serena** (LSP-over-MCP, MIT, ~25k★) | Optional symbol-nav/edit escalation. Overlaps Claude Code's **native LSP tool** — adopt only if native LSP proves insufficient. No graph/viz of its own. |
| **Escalation (live UI)** | **CodeGraphContext on Neo4j** | The *only* candidate with a true live, click-to-expand Obsidian-style graph **UI** — but it's a running DB server (forbidden-#1 as a floor). Document as an opt-in escalation for a team that *wants* Neo4j Browser and accepts the server. Its embedded (LadybugDB/FalkorDB-Lite) mode = daemon-free but drops to HTML export. |
| **Always-present floor** | **tree-sitter/Aider repo-map pattern** = swarm-explore's existing `ctags + rg` ranked map (grep fallback) | What `/graph` degrades to when no MCP is installed. Ships *in* the template, zero clone-time binary. |
| **Rejected** | **Sourcegraph MCP** | Cloud = code egress (hard no for private cloner repos); self-host = org-level deployment (not per-project). Visual is code-search, not a node graph. |

**Runs where:** per **product** repo, opt-in, launched **on demand**. `.codegraph/*.db` git-ignored. Registered in the *product workspace's* `.mcp.json` only on opt-in — exactly the pattern COSMOS's `.mcp.json` already uses for its npx stdio servers.

### 3.2 Knowledge / docs / links layer — the vault *is* the folder
- **Store = the markdown itself.** A vault is "a folder and its subfolders" of markdown + a hidden `.obsidian/` config (`docs.obsidian.md/Plugins/Vault`). LogicLoom's `.docs/ + features/ + specs/ + loom-memory` are already Obsidian-shaped → they *are* a vault with **zero conversion**.
- **Agent access = plain Read/Grep — NO MCP, NO app.** Every capable Obsidian MCP (Local REST API `/mcp/`, cyanheads) is **app-gated** (needs the desktop app running + `:27124` + token); every headless one (marcelmarais, MCPVault) is **thinner than plain Read/Grep**. So we **bundle no Obsidian MCP as a project floor** — the headless-read path is free.
- **Optional local convenience (opt-in, never required):** the **official Obsidian CLI (v1.12.4 GA, Feb 2026)** gives structured graph data grep can't cheaply compute (backlinks, orphans, deadends, tag counts) — but it **remote-controls a running app** (launches Obsidian if closed), so it's a per-machine convenience, not a CI/floor path. `/graph` may call it *if present*, never require it.

### 3.3 The CODE↔DOCS bridge — a git-tracked convention, the only thing spanning both halves
- **Artifact:** `graph-bridge.jsonl` in the Anthropic memory-server shape (`{type:entity}` / `{from,to,relationType}`), built by a **~150-line `jq`+`rg` generator**, deterministic, zero-LLM, git-tracked (lives beside loom-memory like the existing memory files).
- **Edge families, harvested from what's already in the corpus:**
  - `mentions` — any note → code path, from **inline backtick path-mentions** (pervasive already: `` `.logic-loom/lib/parallel.sh` ``, `` `.claude/settings.json` ``).
  - `covers` — spec/ADR/decision note → code file/symbol, from a **new frontmatter `covers:` key** (the one authoring addition; mirrors 2026 ADR-as-knowledge-graph `@adr`-tag practice).
  - `decided-by` — code file → the ADR/decision note that governs it.
  - `links-to` / `SUPERSEDES` — the existing intra-knowledge edges.
- **Resolution:** each code path resolves to a **code-graph node id via the Codegraph CLI when present**, or a **path-string anchor** when not. So the bridge works text-only on any clone and *upgrades* when the MCP is installed.
- **Authoring contract (soft, fail-open):** specs/ADRs declare `covers: [src/…, plugins/…]`; new docs prefer `[[wikilinks]]` so the Obsidian graph is meaningful. A dangling-`covers:` **linter warns, never blocks** (fail-open like the rest of the floor).

### 3.4 Visualization — showing the WHOLE (code+docs) graph, no server
There is no single native pane showing code AND docs unless code is represented as nodes alongside docs. Two self-contained paths, both no-server:
1. **Product projects (real code):** Codegraph exports **Mermaid** (renders in Obsidian/GitHub/VS Code natively — critical since `dot` is absent) or **GraphML** (→ Gephi/Cytoscape/yEd for interactive force-directed exploration); the `/graph` skill can emit code nodes as **Obsidian stub-notes** so they appear in the *same* Obsidian graph as the docs.
2. **LogicLoom's own thin-code repo + the self-authored layer:** Obsidian's graph view natively visualizes `.docs/ + features/ + specs/ + loom-memory` with zero conversion; for the deterministic harness-component + bridge graph, ship **one committed, inline-JS, CSP-safe HTML viewer** (**Cytoscape.js** or **Sigma.js**, MIT) reading `.logic-loom/graph/*.json` — commit-one-file, no server, regenerated on demand.

**Rejected for the shipped capability:** Neo4j Bloom / Kùzu Explorer / Memgraph Lab (all server/Docker-bound = forbidden-#1; Kùzu was archived by Apple Oct 2025 = rot warning); VS Code graph extensions (single-layer, editor-locked, no agent access).

### 3.5 Tandem with the developer's PERSONAL Obsidian vault
Two vaults, **side by side, never merged** (Obsidian runs multiple vaults simultaneously; internal links don't cross vaults — a feature, not a gap):
- **Per-USER personal vault** — the developer's second brain (saved links, bookmarks, personal context). Global, one per developer, lives **outside** any repo, **never templated in**. Reached in tandem via the **official Obsidian CLI** or, for the personal vault specifically, a recommended (not bundled) MCP — **cyanheads/obsidian-mcp-server** (Apache-2.0, 14 tools, BM25 + link extraction) or the plugin's built-in `/mcp/`. The developer wires this into *their own* Claude Code once (the reconciled per-project-opt-in rule).
- **Per-REPO project vault/graph** — the repo's own docs/features/specs/loom-memory (already wikilink-shaped) + the opt-in Codegraph output. Templated in, git-tracked.
- **Tandem model = two independent queries, no store merge:** for any task the agent consults the PROJECT graph (repo context) **and** queries the PERSONAL vault's CLI/MCP (saved-links/personal context), then synthesizes. Keeping the stores separate is what makes the project graph portable.

---

## 4. What LogicLoom ships (portable to every templated project)

**LogicLoom ships a CONVENTION + a `/graph` skill + `/initialize-project` wiring — no engine, no daemon, no default-LLM pass.**

1. **A convention (a shipped policy doc):** the knowledge vault *is* the already-Obsidian-shaped `.docs/ + features/ + specs/ + loom-memory` (agents Read/Grep it directly); the per-project code graph lives in the product workspace (`web/` / `apps/<name>/`) as opt-in Codegraph; the personal vault stays separate, reached in tandem. Ship a committed **`.obsidian/` config stub** (graph filters/colors, wikilink-preferred) so cloners inherit a sane graph view with zero setup.
2. **The bridge (`graph-bridge.jsonl`):** the ~150-line `jq`+`rg` generator that harvests corpus edges (`mentions`/`covers`/`decided-by`/`links-to`/`SUPERSEDES`) and resolves to Codegraph node ids when present — deterministic, git-tracked, the join between halves.
3. **A `/graph` skill** (bridged via `.claude/commands/` like every command) that: (a) regenerates `graph-bridge.jsonl`; (b) answers cross-half queries ("what governs `src/auth/*`", "what does spec Y cover", "blast radius of editing Z") by walking the manifest with `jq`, **escalating to the Codegraph MCP when present** (else text-only — so an agent *always* has some graph); (c) emits the Obsidian-vault / Mermaid / GraphML / HTML export for human viewing; (d) runs a **fail-open** orphan/dangling linter (spec covering a deleted file; code file no spec covers).
4. **`/initialize-project` wiring:** write the convention + `.obsidian/` stub; **detect project shape** and, on opt-in, register the Codegraph MCP in the *product* workspace's `.mcp.json` and add `.codegraph/` to `.gitignore`; hang manifest refresh off **session-start / post-commit / `/retro`** (no watcher, no floor daemon).

**Two repo shapes, same convention, different populated layers:**
- **LogicLoom-the-repo (thin code, rich docs):** graph is **docs-only** — the rich knowledge half lights up (its `[[wikilink]]`/`SUPERSEDES` edges render in Obsidian; Codegraph simply isn't wired because there's no product code). The self-authored harness-component graph + HTML viewer from `graph-design.md` still applies here.
- **COSMOS-class product project (rich code — verified ~495 Rust + ~396 TS + ~52 Py):** **both** halves light up. Codegraph indexes `src/`/`src-tauri/`/`supabase/`; the bridge links specs/ADRs to the modules they `cover`; the human sees the merged graph via export. This is where the code half is the point and Codegraph earns its keep.

---

## 5. Phased plan + hands-on trial

**Trial gate (from the tribunal "beat grep first" heuristic):** a code-graph tool ships *only if* it measurably beats the existing `ctags+rg` grep loop on a real question set. Docker/Graphviz absent → the trial uses Mermaid + HTML export only.

### Phase 0 — Hands-on trial on COSMOS (near-zero cost, no new floor)
1. **Codegraph on `cosmos-2` + A/B vs grep.** `npx @optave/codegraph build` in `cosmos-2`; register its MCP in a *scratch* `.mcp.json`; run ~8 real questions (blast radius of a Rust command, callers of a Tauri IPC handler, which TS modules import a schema type) **through the MCP** and **through the current grep/ctags loop**; score answer quality + tool-call count. **Pass = graph beats grep on ≥⅔.** Emit `codegraph export -f mermaid` and confirm it renders in Obsidian/GitHub (no Graphviz needed).
2. **Obsidian graph-view + MCP over two vaults.** Open `cosmos-2` `.docs/`+`specs/` as a **project vault**; open a throwaway **personal vault** (2-3 saved-link notes) alongside; confirm both render simultaneously and stay unmerged. Wire **cyanheads/obsidian-mcp-server** to the personal vault only; confirm an agent can pull a saved link from it while Read/Grep serves the project vault.
3. **Bridge POC.** Add `covers:` frontmatter to 2-3 COSMOS specs pointing at real modules; run the ~150-line `jq`+`rg` generator to emit `graph-bridge.jsonl`; answer "what spec covers this file / what does editing this file impact" by walking it (text-only), then again resolving via the Codegraph node ids. Confirm the merged export shows code + spec nodes in one Obsidian/Mermaid graph.

### Phase 1 — Ship the convention + `/graph` skill (docs-first, deterministic)
`/graph` skill + `graph-bridge.jsonl` generator + `.obsidian/` stub + the fail-open linter. Wire into `/finalize`/CI (warn-only). **Deterministic, zero-LLM, zero new floor dependency.** *Verify:* on LogicLoom-repo the docs graph renders; the linter flags a deliberately-dangling `covers:`.

### Phase 2 — Normalize the knowledge half so the graph view isn't broken
Normalize the **hyphen/underscore slug drift** in the auto-memory `[[wikilinks]]` (the Phase-2 lint `graph-design.md` specced); add `[[wikilinks]]`/`covers:` to new in-repo docs (currently sparse: 5 memory files, 0 wikilinks). *Verify:* Obsidian graph view over the tracked repo shows no dangling nodes.

### Phase 3 — Product-code wiring (`/initialize-project` opt-in)
Detect a product workspace; on opt-in, register Codegraph in its `.mcp.json`, gitignore `.codegraph/`, teach `/graph` to escalate to the MCP and emit the merged code+docs export. *Verify:* on a COSMOS-class repo, `/graph "blast radius of X"` returns Codegraph impact + the specs that `cover` X.

### Phase 4 — Optional escalations (documented, not bundled)
Document CodeGraphContext-on-Neo4j for a team that wants the live interactive graph UI; document Graphify code-only-split-mode as the single-tool alternative. **Neither shipped as default.**

### Phase 5 — Self-authored HTML viewer for the harness-component + bridge graph
Ship the single-file Cytoscape.js/Sigma.js viewer over `.logic-loom/graph/*.json` (the `graph-design.md` deliverable) so LogicLoom-repo's own graph is browsable without Obsidian. *Verify:* commit-one-file, opens offline, no server.

---

## 6. Anti-overbuild guardrails (updated for the relaxed constraint)

**ALLOWED now (the reconciliation):** a per-project **opt-in** MCP a developer starts for *their* repo (Codegraph MCP, an Obsidian MCP for the personal vault), a git-tracked graph JSON/JSONL, a committed self-contained HTML viewer, Mermaid/GraphML exports rendered in tools already installed.

**STILL FORBIDDEN — must NOT happen:**
1. A **mandatory harness-floor daemon / file-watcher / server** every clone must keep alive (Neo4j/Memgraph/full FalkorDB as a *required* store; an always-on watcher; Docker — not even installed). The canonical store stays git-tracked text; MCP/HTML are on-demand lenses.
2. An **LLM extraction pass in the DEFAULT path** (GraphRAG/Cognee/Graphiti; Graphify's doc-LLM pass) — re-derives author-written edges, worse and expensively. Graphify, if used at all, is **code-only split-mode**, LLM pass **off/key-gated**, and **never over loom-memory**.
3. **Hard-depending the template on a low-maturity tool.** Codegraph (~74★, single-org) is **wired, not vendored** — the `/graph` skill's backend is swappable and the export formats are standard; **pin the version**; degrade cleanly to the ctags+rg floor when absent. LadybugDB (10-month single-team fork), Kùzu (archived), graphify-rs/code-review-graph (as *stores*) are reference-only.
4. **A unified store as the canonical store.** Merged view = an *export*, never the source of truth.
5. **Co-mingling the personal vault into the project graph.** Link by wikilink; never merge stores.
6. **Graph-awareness on the write-time freeze hook / domain-detection preflight / context loaders** (hot-path risk / wrong input / subsumed) — unchanged from `graph-design.md`.

**Tripwires (this is becoming the next cut subsystem):** (i) a proposal adds a running process/port/Docker a cloner must keep alive; (ii) an LLM call enters the default extraction path; (iii) the linter *blocks* instead of warning; (iv) a new clone-time binary requirement appears (Graphviz, Docker, a native graph-DB wheel); (v) the personal and project vaults get merged into one store; (vi) freshness needs a watcher instead of lazy regen on session-start/post-commit/`/retro`; (vii) the template *requires* Codegraph rather than degrading to the ctags+rg floor.

---

## 7. Open decisions (need the user's call before building)

1. **Default code engine:** Codegraph (`@optave`, Apache-2.0, 34 tools + 6 exports — recommended) vs colbymchenry (MIT, lighter, **no viz**)? *Recommendation: Codegraph, because the human-visual requirement needs the exports.*
2. **Bridge artifact location & format:** `graph-bridge.jsonl` git-tracked **beside loom-memory** (recommended) vs feature-local vs `.logic-loom/graph/`. Confirm JSONL (Anthropic memory-server shape) over single `graph.json`.
3. **Frontmatter edge key:** `covers:` (recommended) as the spec/ADR→code declaration; and does the dangling-`covers:` linter **warn-only** (recommended, fail-open) or gate `/finalize`?
4. **Personal-vault MCP recommendation:** cyanheads/obsidian-mcp-server (Apache-2.0, richer) vs the plugin's built-in `/mcp/` — which to *document as recommended* (neither bundled)?
5. **Slug normalization now?** Fix the hyphen/underscore drift in the out-of-repo auto-memory as a prerequisite to a clean Obsidian graph (recommended) — or defer until the graph view is actually used?
6. **Trial scope:** confirm running the Phase-0 A/B on `cosmos-2` (needs `npx @optave/codegraph` + a scratch `.mcp.json`; no git, no Docker) before any Phase-1 build.
7. **HTML viewer library:** Cytoscape.js (GraphML import) vs Sigma.js (WebGL, scales) for the self-authored-layer viewer.
8. **Graphify as an offered alternative?** Ship a documented code-only-split-mode Graphify path for teams wanting one tool, or omit it entirely to keep the surface minimal?

---

## Sources

**Obsidian layer:** official CLI v1.12.4 (`obsidianmd-obsidian-help.mintlify.app/extending/obsidian-cli`, `obsidian.md/cli`, `dev.to/shimo4228/obsidians-official-cli-is-here-3123`); vault=folder (`docs.obsidian.md/Plugins/Vault`); graph view (`obsidian.md/help/plugins/graph`); links both `[[…]]`/`[](…)` (`obsidian.md/help/links`); multiple vaults (`obisian.bearblog.dev/working-with-multiple-vaults/`); Local REST API v4.1.3 built-in `/mcp/` (`github.com/coddingtonbear/obsidian-local-rest-api`); cyanheads v3.2.9 Apache-2.0 (`github.com/cyanheads/obsidian-mcp-server`); filesystem MCPs (`github.com/marcelmarais/obsidian-mcp-server`, `github.com/bitbonsai/mcpvault`); headless `github.com/nightisyang/obsidian-cli`; 2026 landscape `mcp.directory/blog/obsidian-mcp-complete-guide-2026`.

**Code-graph layer:** Codegraph `github.com/optave/ops-codegraph-tool`, `npmjs.com/package/@optave/codegraph`, `tosea.ai/blog/codegraph-claude-code-cursor-guide-2026`; colbymchenry `github.com/colbymchenry/codegraph`; CodeGraphContext `github.com/CodeGraphContext/CodeGraphContext`, `codegraphcontext.github.io`; ChrisRoyse/CodeGraph (Neo4j) `github.com/ChrisRoyse/CodeGraph`; Serena `github.com/oraios/serena`, `mcp.directory/blog/serena-mcp-complete-guide-2026`; Sourcegraph MCP `sourcegraph.com/mcp`, `sourcegraph.com/docs/api/mcp`; repo-map pattern `aider.chat/2023/10/22/repomap.html`; SCIP `sourcegraph.com/blog/announcing-scip`.

**Unified vs federated / stores:** Graphify `github.com/safishamsi/graphify`, `graphify.net`, `graphify.net/tree-sitter-ast-extraction.html`; LadybugDB `ladybugdb.com`, `thedataquarry.com/blog/from-kuzu-to-ladybug`, `github.com/LadybugDB/{explorer,mcp-server-ladybug}`; Neo4j `github.com/neo4j/mcp`, `neo4j.com/product/bloom`; Memgraph `memgraph.com/blog/introducing-memgraph-mcp-server`; FalkorDB `github.com/falkordb/falkordb`, `github.com/FalkorDB/falkordblite`; GraphRAG cost `microsoft.com/en-us/research/blog/lazygraphrag…`, `medium.com/graph-praxis/the-graphrag-cost-cliff…`; Cognee `github.com/topoteretes/cognee`; Graphiti `github.com/getzep/graphiti`.

**Bridge + viz:** ADR-as-knowledge-graph `nilus.be/blog/architecture_decision_records_as_knowledge_graph…`, `johnclick.ai/blog/adr-first-development…`; code-review-graph export `github.com/tirth8205/code-review-graph`; Cytoscape.js `js.cytoscape.org` + GraphML ext `github.com/iVis-at-Bilkent/cytoscape.js-graphml`; Sigma.js `sigmajs.org`; Kùzu archival warning `arcadedb.com/blog/neo4j-alternatives-in-2026…`.

**Repo ground-truth (this machine, 2026-07-05):** `dot`/`docker` ABSENT, `node`/`npx`/`uv`/`jq`/`rg`/`sqlite3` present; `.logic-loom/memory/` = 5 files / 0 wikilinks; `~/.claude/projects/.../memory/` = 17 files with hyphen/underscore `[[wikilink]]` drift; `cosmos-2` = ~495 rs + 220 tsx + 176 ts + 52 py, `.mcp.json` already runs npx stdio MCP servers; prior design `features/code-knowledge-graph/exploration/graph-design.md`.
