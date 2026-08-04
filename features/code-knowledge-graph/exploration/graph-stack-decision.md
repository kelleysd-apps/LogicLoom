# Graph Stack — The Decision

**Feature:** `features/code-knowledge-graph/`
**Status:** exploration synthesis — resolves the build-vs-adopt tension for the narrowed ask
**Date:** 2026-07-09
**Builds on (do not restate mechanics):** `features/code-knowledge-graph/exploration/graph-design.md` (the 6-agent build-vs-buy deep dive) and `features/modular-harness/exploration/unified-architecture.md` §5 (the extract/adopt plan). This doc **resolves the conflict between them** and assigns every piece to a layer under the *narrowed* ask.
**Ground truth (verified 2026-07-09):** all four research landscapes; `gh api` counts stamped today; on-machine tool probe (`jq`/`rg`/`sqlite3`/`node`/`npx` present; `dot`/`docker`/`tree-sitter`/`ast-grep`/`mmdc` ABSENT; `/usr/bin/ctags` = BSD, no JSON).

---

## 0. The narrowed ask (what changed the answer)

Give **each project a built-in knowledge graph + code graph**, with **visual tools for the agent and the user**, on a **Karpathy-style wiki memory structure** — and it must **stand alone, in-repo**. Obsidian/external vaults are now **OUT of the core** (a tool a user may add, nothing more). Every surface (terminal/Desktop/VS Code/JetBrains/cloud-web) must get it; cloud = fresh clone on an Anthropic VM where only repo-committed `.claude/` config travels and plugin-install is flaky (#18088); `dot` and Docker are absent. Anti-overbuild doctrine (already 3× exercised: marketplace-MCP, RL telemetry, dev-loop all cut): **no database, daemon, server, port, file-watcher, lockfile, or LLM-based extraction**; GraphRAG-style LLM extraction is a **named tripwire**.

That last clause is decisive. "Built-in per project + in-repo + reproducible + every surface + no server/port/LLM-extraction" is a spec that a **git-tracked deterministic text artifact passes and every heavyweight tool fails** — including the one the later doc proposed to adopt.

---

## 1. Topline

**Keep the bespoke deterministic graph. Ship it as the bundled-default `loom-graph` package — it is the built-in per-project graph the ask demands. Adopt nothing into the default path.** Concretely: the existing ~168-line `jq`+`rg` harvester emits a git-tracked `graph-bridge.jsonl` (Anthropic memory-server shape) that covers **both** halves — the harness **component graph** (from `plugin.json` + `.bridge-manifest.json` + frontmatter + hook wiring, which no AST tool can even read) and the loom-memory **knowledge layer** (from author-written `[[wikilink]]` + `SUPERSEDES` edges). Two additive, deterministic, zero-LLM changes make it whole: (a) harvest the temporal `SUPERSEDES/SUPERSEDED-BY/CORRECTS/RETAINED/REMOVED` vocabulary the bridge currently ignores; (b) wire a **1-hop expansion** into loom-memory's `keyword-backend.sh` so those author-written edges stop being dead metadata. **Humans** get a committed, scoped, `jq`-generated **Mermaid `.mmd`** that GitHub / Obsidian / claude.ai render natively with zero setup, plus an *optional on-demand* self-contained HTML export for big graphs. **Agents** get a `jq`-over-JSONL **query interface** (plus a scoped Mermaid text block as context-compression) — not rendered pictures. **Understand-Anything, Codegraph, and Obsidian are all non-bundled:** Understand-Anything and Obsidian are user-layer-only externals; Codegraph is an opt-in MCP deferred until a product workspace exists. Net new clone-time dependency: **zero**. No daemon, port, DB, watcher, or LLM extraction anywhere.

---

## 2. Layer assignment

Architecture buckets: **CORE** (governance floor + constitution + scaffolding) · **BUNDLED-DEFAULT PACKAGE** (ships enabled; every project inherits it) · **OPTIONAL ADOPT** (a package/MCP a user *may* wire, `defaultEnabled:false` or documented) · **USER-LAYER-ONLY** (an external the user self-installs; the harness depends on nothing) · **REJECT** (do not bundle, adopt, or recommend as a default path).

| Piece | Layer | Why |
|---|---|---|
| **Deterministic bridge** — `build-graph-bridge.sh` + `graph-bridge.jsonl` + `lint-graph.sh` + `/graph` command + `project-graph` skill + `test_graph_bridge.sh` (13/13 green) | **BUNDLED-DEFAULT PACKAGE** (`loom-graph`) | This *is* the built-in per-project graph. Deterministic `jq`+`rg`, zero-dep, git-tracked text, reproducible byte-for-byte on every surface **including cloud**, no daemon/port/DB/LLM. It is the only candidate that passes the whole narrowed spec. |
| **Memory wiki + edge parser** — loom-memory's Karpathy wiki + temporal-edge harvest + 1-hop expansion in `keyword-backend.sh` | **BUNDLED-DEFAULT PACKAGE** (extends the existing `loom-memory` pack) | The edges are **already author-written** (`[[wikilink]]` + `SUPERSEDES`); formalize in place. Wiring 1-hop into the keyword backend revives edges the search side currently parses as *nothing* (BM25/grep only). Zero LLM. |
| **Mermaid viz** — committed scoped `.mmd`, `jq`-generated from the JSONL | **BUNDLED-DEFAULT PACKAGE** (part of `loom-graph`) | Tiny, diff-stable text; renders where the human already is (GitHub PR/README, Obsidian, claude.ai) with **no** plugin (`dot` absent is irrelevant — Mermaid needs no `dot`). Doubles as the agent's context-compression summary. Zero new dep. |
| **Interactive self-contained HTML** | **OPTIONAL on-demand derived export** (a *mode* of `loom-graph`, never committed) | Regenerate from the JSONL on demand — a hand-rolled ~150-line vanilla-canvas renderer (few KB, CSP-clean, git-trackable if ever needed) or publish as a Claude Artifact. Never commit a ~370 KB inlined-library blob (the "binary a cloner must carry" smell the project cut 3×). |
| **Native LSP** (Claude Code's built-in tool) | **USER-LAYER-ONLY / native lean-on** (opt-in, per-language, per-machine) | Precise *1-hop local* answers (def/refs/hover/impl/callers on a pointable symbol), but runtime-only, **not** a git-trackable artifact, needs a per-language server binary + plugin, `workspaceSymbol` is spec-broken (#21655, closed not-planned), and it effectively doesn't load in cloud/headless (same trust-dialog root cause as #18088). The harness **leans on it when present**; bundles and depends on **nothing**. |
| **Codegraph MCP** (`@optave/codegraph`, Apache-2.0) | **OPTIONAL ADOPT** (wire-not-bundle; **deferred** until a product workspace exists) | Genuinely no-LLM (tree-sitter→SQLite core), exports Mermaid/HTML (matters — `dot` absent), gives transitive blast-radius/diff-impact. But it is an opt-in MCP **process** with a gitignored `.codegraph/graph.db`, and cloud can't install it. Wire into the *product workspace's* `.mcp.json`; `/graph` escalates to it when present and degrades to the `ctags`+`rg` floor when not. |
| **Understand-Anything** (Egonex-AI, MIT) | **USER-LAYER-ONLY** (optional external) · **REJECT as bundled/adopted-default** | LLM extraction is its **core**, not optional (the named GraphRAG tripwire); its git-tracked graph is therefore **non-reproducible + token-costly** to regenerate; its visual tool **requires a Vite server on a port with a token gate** (crosses "no server/no port"); heavy `pnpm`+native-build install (sharp/esbuild/12 tree-sitter grammars) a cloner/CI/cloud can't inherit; poor cloud viability (#18088 + native build + localhost dashboard); auto-update hooks inject *"do it without confirmation"* against **Principle VI**. Same slot as Obsidian: a thing a user *may* self-install on real product code, never a dependency. |
| **Obsidian** | **USER-LAYER-ONLY** (pure add-on) | The repo folder **already is** a wikilinked vault; "Open folder as vault" gives native graph + backlinks with no plugin. Gitignore `.obsidian/`. Zero integration; **nothing in the harness depends on it** (see §8). |

---

## 3. Understand-Anything verdict — REJECT as bundled; USER-LAYER-ONLY external; "in conjunction with," never "instead of"

**Verdict: REJECT as a bundled or adopted default; permit as a USER-LAYER-ONLY external, in the exact slot the ask reserves for Obsidian.** Relationship to the bespoke graph: **"in conjunction with" (optional, additive, user-installed on real product code) — never "instead of."**

**The earlier `unified-architecture.md` §5 claims were partly stale, and its central call is reversed under the narrowed ask.** Ground truth verified today:

- **The repo is real, MIT, and thriving — the "71.3k implausible, verify" flag is REFUTED.** `gh api` reports **72,337 stars / 6,034 forks**, MIT, created 2026-03-15, **pushed today**. `Lum1104/Understand-Anything` 301-redirects to the canonical `Egonex-AI/Understand-Anything` (a transfer, not two projects). [CONFIRMED]
- **§5's "v2.5.0 (May 2026)" is STALE.** Latest release **v2.7.3** (2026-05-19); `plugin.json` on main declares **2.8.2** — two minors ahead. It is a genuine Claude Code plugin (8 skills, 9 agents, hooks; **no** MCP server). [CONFIRMED]
- **LLM extraction is its CORE, not optional** — a 7-phase, 9-agent pipeline whose *product* (summaries, architectural-layer/business-domain tags, tours, Q&A) is LLM-generated; tree-sitter alone yields only a skeleton, and `--review` adds *more* LLM. This is precisely the GraphRAG tripwire. Consequence: its git-tracked graph is **non-deterministic** — a teammate/CI/cloud regenerating it gets a different graph and burns tokens, **failing the reproducible+git-tracked bar**. [CONFIRMED]
- **Its visual requires a server + port + token** (`npx vite --host 127.0.0.1` → `http://127.0.0.1:<PORT>?token=<TOKEN>`) — the whole point of the ask ("visual tools"), delivered exactly across the "no port, no persistent server" line. The "no persistent server" framing is true only for the *build* step, misleading for the dashboard. [CONFIRMED]
- **Heavy install a cloner can't inherit** (`pnpm` monorepo; `onlyBuiltDependencies`: sharp/esbuild/12 tree-sitter grammars) + **auto-update hooks** that fire on git commit/merge and inject *"Do not ask the user for confirmation — just do it"* — antithetical to Principle VI. [CONFIRMED]

**Two ideas worth STEALING (not the tool):** (1) its **deterministic** `parse-knowledge-base.py` is literally described as a "parser for Karpathy-pattern LLM wikis" (frontmatter + `[[target|display]]` resolution) — independent proof that loom-memory's shape is directly graph-parseable, validating our knowledge-layer plan. (2) Its clean **deterministic-structure vs LLM-semantic** seam is the right conceptual split — **LogicLoom keeps only the deterministic half.**

So Understand-Anything is neither a replacement for, nor a bundled companion to, the bespoke graph. It is a user-layer escalation for someone who wants rich LLM-semantic graphs + an interactive dashboard on a real product codebase and accepts the cost, server, and non-reproducibility.

---

## 4. Does the bespoke Phase-1 graph survive? — YES

**Yes. It is the load-bearing default and it survives intact.** The 6-agent deep dive ("buy nothing; build a lightweight deterministic git-tracked text graph") is **correct under the narrowed ask** and stands. The later `unified-architecture.md` §5 was **half right and half wrong**:

- **RIGHT:** the graph should live as a **package**, not scattered core — extracting it to a `loom-graph` pack is consistent with the light-core + composable-packages model.
- **WRONG (reversed here):** "point it at Understand-Anything + Codegraph *instead of* the bespoke harvester." Under a built-in, in-repo, reproducible, every-surface, no-server/no-LLM spec, the bespoke deterministic harvester is the thing that *passes* and Understand-Anything is the thing that *fails*. §5's "adopt-existing-first" instinct is sound in general but mis-fires here because there is **no existing tool** that is deterministic, git-tracked, serverless, and reads *manifests+frontmatter* — the harness-component structure lives in JSON/markdown metadata no AST/LSP/tree-sitter tool can see.

**What changes** (all additive, deterministic, zero-LLM — no phased plan implied):
1. Package the working harvester + `lint-graph.sh` + `/graph` + `project-graph` skill + tests as the bundled-default **`loom-graph`** pack.
2. Extend the harvester to harvest the **temporal edge vocabulary** (`SUPERSEDES/SUPERSEDED-BY/CORRECTS/RETAINED/REMOVED`) it currently emits **zero** of (the seed has 0 temporal edges).
3. Wire a **1-hop expansion** into loom-memory's `keyword-backend.sh` so a keyword hit also surfaces linked + superseding notes and demotes superseded ones (~20–40 lines, no index, no DB — the `backend-interface.sh` seam already exists for this).
4. Add a scoped **Mermaid emitter** (`jq`, deterministic) committing `graph.mmd` beside the JSONL.
5. Declare the wiki **schema in CLAUDE.md/AGENTS.md** and nudge the Karpathy ≥2-wikilinks/page density (corpus is ~1.3/page today).
6. Extend the fail-open lint with **dangling-link + contradiction** checks.

**What does NOT change:** no Understand-Anything substitution, no LLM extraction step, no DB/daemon/port/watcher.

---

## 5. Knowledge graph — the wiki + edge-parser story (adopt the DATA MODEL, nothing else)

**Build option (i): the existing loom-memory Karpathy wiki + a deterministic edge-parser. Adopt no tool; adopt only the Anthropic memory-server DATA MODEL — which the harvester already emits.** [CONFIRMED across landscapes 1 & 3]

- loom-memory **already is** a Karpathy LLM wiki (per-fact frontmatter files + `[[wikilinks]]` + `SUPERSEDES` edges + a `MEMORY.md` index). The single real gap is that its **search backend parses none of those edges** (keyword/BM25 only) — dead metadata. The fix is deterministic 1-hop expansion at query time (LazyGraphRAG's defer-to-query posture, **no LLM**), not a new store.
- The harvester **already** parses `[[wikilink]]` + markdown links into the exact memory-server JSONL shape. Only the **temporal edges** and the **1-hop wiring** are net-new — both small regex/`jq` passes.
- **Do NOT bundle** the Anthropic memory MCP or basic-memory: both require a running **MCP process** (a "daemon" by doctrine, install-flaky in cloud per #18088); basic-memory additionally adds a **SQLite index**, an **optional file-watcher** (a named tripwire), and an **AGPL-3.0** license. Keep both as user-layer externals — parallel to Obsidian.

**One genuine open question to resolve (§9):** the *richest* Karpathy wiki (the `/retro` memory at `~/.claude/projects/<slug>/memory/`, ~26 wikilinks + ~15 SUPERSEDES) lives in **$HOME, outside the repo**, so it does **not** travel to cloud/CI/teammate. The built-in, reproducible graph therefore harvests the **in-repo corpus** (`.docs` + `features` + `specs` + root docs + in-repo plugin files — already git-tracked, ~25 wikilinks + ~23 SUPERSEDE mentions). **Recommendation:** declare the in-repo corpus the canonical graphed wiki; the per-machine `/retro` memory stays a private USER-layer wiki a user *may* choose to mirror in-repo if they want it graphed/shared. Nothing about the built-in graph should depend on a $HOME path.

---

## 6. Code graph — native LSP floor · harness-component graph adds what no tool can read · product-code deferred

**What native LSP already covers** [CONFIRMED]: precise *local* answers on a symbol you can point at — `goToDefinition`, `findReferences`, `hover`, `documentSymbol`, `goToImplementation`, and **1-hop** `incomingCalls`/`outgoingCalls`. But it is **per-language** (needs a server binary + plugin per language), **runtime-only** (ephemeral queries against a live server — **not** a git-trackable artifact that travels), its whole-repo op `workspaceSymbol` is **spec-broken** (#21655, closed not-planned), it gives **no** cross-file map or transitive impact, and it **effectively doesn't load in cloud/headless** (the trust-dialog root cause behind #18088). So LSP is a per-machine opt-in the harness leans on, **not a portable floor**.

**What the harness-component graph adds** (and *why it must be bespoke*): the harness's real structure — `command → plugin → skill → agent → hook → principle` — lives in `plugin.json`, `.bridge-manifest.json`, `SKILL.md`/agent frontmatter, and hook→matcher wiring. **No** code-graph tool (LSP, ctags, tree-sitter, ast-grep, Serena, Codegraph, SCIP) can read it — they all extract *language ASTs*, and this repo has **0 `.ts/.js/.py` of substance** (native LSP empirically returns "No LSP server available" here). The 168-line `jq`+`rg` harvester is the **only** correct tool, and it already exists. For this repo *today*, the component graph **is** the code graph.

**What is deferred to a product workspace** [CONFIRMED]: the product-code AST/topology graph stays on paper until `web/`/`apps/` exists. When it does, the floor is **native LSP** (opt-in local precision) + **ripgrep** (lexical), with swarm-explore's `ctags`+`rg` ranked repo-map promoted into a git-trackable **topology sketch** (grep-fallback, since the on-machine `ctags` is BSD/no-JSON and universal-ctags can't be assumed). The heavier escalation is **Codegraph MCP** — **wired, not bundled**, into the product workspace's `.mcp.json`, `.codegraph/graph.db` gitignored, `/graph` escalating when present and degrading to the `ctags`+`rg` floor when not. **Marginal-value verdict:** a heavier code graph buys the **agent** efficiency (~10× fewer tokens / ~2× fewer tool-calls on transitive/architectural questions LSP answers only 1-hop) and the **human** the only no-`dot` visual path (Mermaid/HTML) — **efficiency, not correctness**, and never enough to justify a template floor. Wire, don't bundle. [efficiency figures: single-benchmark/vendor-adjacent — direction robust, exact % UNCERTAIN]

**Reject as floor:** `colbymchenry/codegraph` (file-watcher = tripwire, no viz); Sourcegraph cloud (code egress on private cloner repos); any graph-DB daemon; Serena as a default (it *is* LSP-over-MCP — duplicates native LSP + adds a process).

---

## 7. Visuals — agent (query) vs human (picture); the exact zero-dep path

**"Visual tools for the agent" is mostly a category error — with one real exception.** [CONFIRMED]

- **Agent = query interface.** An agent consumes `graph-bridge.jsonl` losslessly via `jq`/`rg` 1–2-hop walks; a rendered PNG/canvas is a *lossy* re-encoding for human retinas the model doesn't perceive. Evidence: Claude Code's TUI does **not** render Mermaid — it hands the agent the raw fenced source, which is exactly right. **The exception:** a small, **scoped** Mermaid text block placed in context is a genuine agent aid as **context-compression** (~20 lines of `A -->|covers| B` packs a neighborhood for fewer tokens than 100 JSONL lines, and Mermaid is text the model both emits and reads). A rendered raster/interactive canvas *for the agent* is pure waste.
- **Human = picture, delivered where they already are.** Ship **one** deterministic `jq` generator that turns the committed JSONL into a **scoped** Mermaid block (`graph.mmd` / a fenced ```mermaid), and **commit that text** beside the JSONL. That single artifact is the whole default viz stack: diff-stable text that survives cloud/CI/teammate and renders natively on **GitHub** (README/PR/issue/wiki — the highest-value surface for a git-tracked template), **Obsidian**, **claude.ai web**, GitLab/Notion, and in **VS Code/JetBrains with the one Mermaid extension**. Add **no** new binary — `dot`/`mmdc`/`docker` stay unused (Mermaid needs none of them). [CONFIRMED]
- **Scope, don't dump.** Generate a node's 1–2-hop neighborhood, or top-N-by-degree, or a per-sprint/per-plugin slice — keep each diagram under ~40–60 nodes for readability (also comfortably inside Mermaid's 500-edge / 50 000-char technical caps). The current seed (74 entities / 36 relations) is right at the readability boundary, so a full-graph dump would be a hairball — always slice.
- **The committed artifact is the tiny text pair (`graph-bridge.jsonl` + `graph.mmd`), NOT a 370 KB inlined-library HTML blob.** Interactive self-contained HTML is a **derived, on-demand** export (a hand-rolled ~150-line vanilla-canvas force renderer with the graph JSON inlined — few KB, CSP-clean, git-trackable if ever required; or inline cytoscape.js only past a few hundred nodes and publish as a **Claude Artifact**, not a committed blob). CSP note: inline `<script>`/`<style>` and `data:` URIs are allowed; only external hosts are blocked — so a fully self-contained viewer is feasible when wanted. [CONFIRMED]
- **Do NOT bundle a terminal/ASCII renderer** — the agent uses `jq`; `mermaid-ascii`/`graph-easy` are optional user-added externals, shipped as nothing.

---

## 8. Obsidian as a pure USER-LAYER add-on — the exact, easy path

**Obsidian is a user-layer-only add-on. Nothing in the harness — no floor hook, no default package, no query path — depends on it, and the harness ships nothing for it.** [CONFIRMED]

The exact, zero-integration path:

1. **Open the repo folder as a vault.** An Obsidian vault is just a folder of `.md` files; the loom-memory + `.docs` + `features` + `specs` corpus **already is** exactly that, with `[[wikilinks]]` and relative md links the JSONL already harvests. In Obsidian: **File → Open folder as vault** → the repo root. You immediately get the native force-directed **global graph**, **backlinks**, and **"Open local graph"** (neighbors of the active note) — **no plugin, no config, no committed artifact.**
2. **Gitignore the app's scratch dir.** Obsidian auto-creates a `.obsidian/` folder (per-vault UI state). Add `.obsidian/` to `.gitignore` so it never enters the repo. This is the only footprint, and it is USER-layer by construction.
3. **If a user wants the *harness* to reference an external vault path** (not required for anything above): put it in **`.claude/settings.local.json`** — a gitignored, Local-over-Project, USER-layer file. **Nothing in the floor or the default `loom-graph`/`loom-memory` packages reads it**; it exists purely for a user's own convenience commands. (Prerequisite noted in `unified-architecture.md` §3d: the committed `.gitignore` must actually ignore `settings.local.json` — today it doesn't, an independent portability bug.)

Obsidian is the strongest *human* explorer available and costs the framework nothing to offer — **document it, ship nothing.** Caveat (why it's a bonus, not the default): it is a desktop app, so it does **not** satisfy cloud/CI/terminal surfaces — which is exactly why the committed Mermaid `.mmd` remains the portable default and Obsidian is the "if you have it" extra.

---

## 9. Anti-overbuild tripwires + open questions

**Tripwires — any of these means the graph is becoming the next cut subsystem:**
1. A **running process, port, daemon, file-watcher, or lockfile** enters the default path (the on-demand SQLite tier, if ever built, must be rebuilt-not-distributed and gitignored). Understand-Anything's Vite dashboard and basic-memory's watch mode both trip this — hence user-layer-only.
2. An **LLM call enters the extraction path** (cost + hallucinated edges = the GraphRAG anti-pattern; the whole reason Understand-Anything can't be the default).
3. A **new clone-time binary dependency** (tree-sitter, universal-ctags, duckdb, sharp/esbuild) appears in the template's requirements — the default must degrade to `jq`/`rg`/grep.
4. The generator grows a **schema-enforcer that blocks** rather than a fail-open lens (it must tolerate the ~40% of skills lacking `constitutional_principles`/`triggers`).
5. The graph is built for a consumer that **doesn't consume it** (domain detection routes off prompt text, not code; context loaders are subsumed — build for neither).
6. A **370 KB inlined-library HTML blob** gets committed — the committed artifact is the tiny `jsonl`+`mmd` text pair; interactive HTML is derived-on-demand only.

**Open questions (need the user's call — no work implied):**
1. **Canonical wiki location (§5):** declare the in-repo corpus canonical (recommended) vs git-track an in-repo mirror of the per-machine `/retro` memory wiki. The built-in graph must not depend on a $HOME path.
2. **`loom-graph` packaging boundary:** does the harness-component graph + memory edge-parser ship as **one** `loom-graph` pack, or does the memory-edge work stay inside the existing `loom-memory` pack (since it extends `keyword-backend.sh`)? Both are bundled-default; only the file ownership differs.
3. **Mermaid freshness trigger:** regenerate `graph.mmd` on the existing `sync-plugin-commands` bridge step / session-start / `/retro`, or only on explicit `/graph viz`? (Must stay lazy — a watcher is a tripwire.)
4. **Codegraph escalation contract:** confirm `/graph` should auto-detect a product-workspace `.mcp.json` Codegraph entry and escalate, vs require an explicit `--code` flag — deferred until `web/`/`apps/` exists regardless.
5. **Wikilink-density nudge:** is ≥2-wikilinks/page enforced by the fail-open lint (warn) only, given the corpus is ~1.3/page today?

---

## Sources

**Understand-Anything (verified 2026-07-09):** `gh api repos/Egonex-AI/Understand-Anything` → 72,337★ / 6,034 forks / MIT / created 2026-03-15 / pushed 2026-07-09; `Lum1104/Understand-Anything` 301→ canonical; releases/latest v2.7.3 (2026-05-19), `plugin.json` main 2.8.2; `skills/understand-dashboard/SKILL.md` (Vite localhost + `?token=`); `skills/understand-knowledge/parse-knowledge-base.py` ("Deterministic parser for Karpathy-pattern LLM wikis"); `packages/core/src/analyzer/llm-analyzer.ts` + `embedding-search.ts`; `hooks/hooks.json` (PostToolUse/SessionStart auto-update "Do not ask the user for confirmation — just do it"); root `package.json` (`pnpm`, `onlyBuiltDependencies`: sharp/esbuild/12× tree-sitter); augmentcode.com/learn (~71.7k corroboration); trendshift.io/repositories/23482.

**Code graph:** native LSP v2.0.74 (scottspence.com/posts/enable-lsp-in-claude-code; circleci.com/blog/claude-code-lsp; claudelog.com); `anthropics/claude-code` #21655 (workspaceSymbol spec-broken, closed not-planned), #18088 (cloud plugin-install), #38011 (empty-query); `@optave/codegraph` (github.com/optave/codegraph; npm — Apache-2.0, v3.15.0 2026-06-23, tree-sitter→SQLite no-LLM core, 6 exports+HTML, gitignored `.db`); `oraios/serena` (LSP-over-MCP); `colbymchenry/codegraph` (auto-sync watcher, no viz); SCIP (sourcegraph.com/blog/announcing-scip; scip-code.org); graph-vs-grep efficiency (aibuilderclub.com; agentconn.com; zzet.org/gortex/grep-replacement-for-ai-agents — direction robust, exact % vendor-adjacent).

**Knowledge graph / Karpathy wiki:** `@modelcontextprotocol/server-memory` (github.com/modelcontextprotocol/servers/tree/main/src/memory — JSONL entity/relation shape); `basicmachines-co/basic-memory` (docs.basicmemory.com — AGPL-3.0, SQLite secondary index, watch mode); aaif.io/blog/karpathys-llm-wiki-as-agent-memory; askglitch.com/blog/build-a-second-brain (3-layer); gist rohitg00 (LLM Wiki v2: confidence + supersession + contradiction).

**Visualization:** Mermaid maxEdges 500 / maxTextSize 50 000 (mermaid-js/mermaid PR #5086, issue #5042); GitHub/Obsidian/claude.ai native render; VS Code needs `bierner.markdown-mermaid` (microsoft/vscode #251616); CC TUI no-render (anthropics/claude-code #14375, #52517); Mermaid-as-context-compression (mindstudio.ai/blog); cytoscape ~350–371 KB min / ~109–112 KB gz zero-dep (cytoscape.js size-snapshot); Obsidian "open folder as vault" (obsidian.md/help/plugins/graph).

**Repo + prior designs (ground truth):** `.logic-loom/scripts/bash/build-graph-bridge.sh` (168-line jq+rg harvester, 0 temporal edges), `.logic-loom/graph/graph-bridge.jsonl` (110 lines / 74 entities / 36 relations), `plugins/loom-memory/lib/{keyword-backend,backend-interface}.sh` (grep-only, no-op index; seam live); `features/code-knowledge-graph/exploration/graph-design.md`; `features/modular-harness/exploration/unified-architecture.md` §5 (the "adopt Understand-Anything instead" call — corrected here). On-machine probe: `dot`/`docker`/`tree-sitter`/`ast-grep`/`mmdc` ABSENT; `ctags` = BSD/no-JSON; `jq`/`rg`/`sqlite3`/`node`/`npx` present.
