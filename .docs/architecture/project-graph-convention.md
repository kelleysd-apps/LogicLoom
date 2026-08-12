# Project Graph Convention

**Status**: v1.0 · **Since**: 2026-07-05 · **Authority**: Constitution
Principles I (Library-First), IV (Idempotency), XV (File Organization),
XVI (Plugin-First) · **Design of record**:
`features/code-knowledge-graph/exploration/project-graph-design.md` · **Skill**:
`/graph` (Phase 1) · **Wiring**: `/initialize-project` (Phase 3)

The **portable, load-bearing convention** every templated LogicLoom project
inherits for a project-wide knowledge graph that is both **agent-queryable**
(Read/Grep + an opt-in code MCP + the `/graph` skill) and **visually
explorable** (Obsidian graph view + Codegraph exports + a shipped HTML viewer).

This is a **convention**, not an engine. LogicLoom ships text, a skill, and
wiring — **never a graph engine, never a mandatory floor daemon, never a
default LLM extraction pass**. Everything below is normative for templated
projects; every mechanism **fails open** (warn, never block).

---

## 1. The federated model (normative)

A project's graph is **FEDERATED — best-of-breed per layer, joined by a
git-tracked text convention**, with a unified merged view available **on demand
as an export**, never as the store. Four layers plus a tandem personal vault:

| Layer | Store | Access | Ships in template |
|---|---|---|---|
| **Knowledge / docs / links** | the markdown itself — `.docs/` + `features/` + `specs/` + `loom-memory` (already an Obsidian vault) | agents: plain **Read/Grep** (no MCP, no app); human: **Obsidian graph view** | yes — the folders + an `.obsidian/` config **template** (`.logic-loom/templates/obsidian/`; copy into your vault — auto-install in Phase 3) |
| **Code** | opt-in per-**product**-repo code-graph MCP → `.codegraph/graph.db` (git-ignored) | agents: the Codegraph MCP when present, else **ctags + rg** floor; human: Codegraph Mermaid/GraphML export | **documented + opt-in only** — not installed by the framework |
| **Bridge** | `.logic-loom/graph/graph-bridge.jsonl` (git-tracked, Anthropic memory-server shape) | `/graph` walks it with `jq`; resolves code paths to Codegraph node ids when present | yes — the manifest + its `build-graph-bridge.sh` generator |
| **Visualization** | rendered on demand from the layers above | Obsidian (docs) · Codegraph export (code) · shipped HTML viewer (self-authored layer) | yes — the `.obsidian/` **template** + the HTML viewer |
| **Tandem: personal vault** | the developer's own second-brain vault, **outside any repo** | opt-in Obsidian CLI / MCP, wired into the developer's own Claude Code | **no — recommended, never templated in, never merged** |

**The invariant:** each half lives in its **best** store; the two are connected
by a git-tracked **text** manifest; the merged code+docs graph is an **export**,
not a canonical store. LogicLoom's mandatory floor gains only **text** (a JSONL
manifest, a skill, an `.obsidian/` config **template**) — exactly how the memory
files already inherit with zero setup.

Two repo shapes, **same convention**, different layers populated:

- **LogicLoom-shaped repo (thin code, rich docs)** — the graph is **docs-only**.
  The knowledge half lights up in Obsidian; Codegraph is simply not wired
  because there is no product code.
- **Product repo (rich code, e.g. `web/` / `apps/<name>/`)** — **both** halves
  light up. Codegraph indexes the product source; the bridge links specs/ADRs to
  the modules they `cover`; the human sees the merged graph via export.

---

## 2. Knowledge layer — the vault *is* the folder

**The store is the markdown itself.** An Obsidian vault is "a folder and its
subfolders" of markdown plus a hidden `.obsidian/` config. A LogicLoom project's
`.docs/` + `features/` + `specs/` + `loom-memory` are already Obsidian-shaped →
they **are a vault with zero conversion**.

### 2.1 Agent access — Read/Grep, no MCP, no app

Agents read the knowledge layer with **plain Read/Grep**. This is normative:
**no Obsidian MCP is bundled as a project floor.** Every capable Obsidian MCP is
app-gated (needs the desktop app + local REST port + token); every headless one
is thinner than plain Read/Grep. The headless-read path is free and always
available, including in CI.

Obsidian the **app** is the **human** visual graph — never a dependency of the
agent path. The optional official **Obsidian CLI** (structured backlinks /
orphans / deadends that grep can't cheaply compute) remote-controls a running
app, so it is a per-machine convenience only: `/graph` **may** call it if
present, **never** requires it.

### 2.2 The `covers:` frontmatter convention (the one authoring addition)

A spec / ADR / decision note declares the code paths it governs via a YAML
frontmatter `covers:` key. This is the single new authoring convention and the
primary source of **spec → code** edges in the bridge:

```yaml
---
covers:
  - src/auth/session.ts
  - src/auth/rotation.ts
  - plugins/loom-git/skills/git-push/SKILL.md
---
```

- Each listed path is a repo-relative path to an **existing** file → a
  `code-path` node, joined by a **covers** edge (note → code-path).
- The **inverse** (code-path → note) is the **decided-by** edge — the note that
  governs a given file. It may be emitted into the bridge or derived at query
  time by `/graph`.
- A **dangling `covers:`** (the path no longer exists) is a **warn** from the
  linter — never a block (fail-open). It mirrors 2026 "ADR-as-knowledge-graph"
  practice, where decision records point at the code they constrain.

### 2.3 Prefer `[[wikilinks]]` in new docs

New docs **should prefer `[[wikilinks]]`** over bare prose references so the
Obsidian graph view is meaningful. Both `[[wikilink]]` and `[text](relative.md)`
markdown links are harvested as **links-to** edges; an inline backtick `` `path` ``
whose target resolves to an existing repo file becomes a **mentions** edge to a
`code-path` node. Authoring for the graph is soft and fail-open: unresolved links
are surfaced by the linter as **dangling**, never rejected.

> **Slug hygiene.** Keep wikilink slugs stable — do not mix hyphen and
> underscore forms of the same target (`[[architecture-v6-1…]]` vs
> `[[architecture_v6_1…]]`), which produces phantom dangling nodes in the graph
> view.

---

## 3. Code layer — opt-in, per-product-repo, degrades to text

The code graph is **opt-in per product repo**, launched **on demand**, and
**NOT installed by the framework**. It is documented here so every project knows
the default and the degradation path; it is wired only at `/initialize-project`
on explicit opt-in (Phase 3).

### 3.1 Default engine — Codegraph (documented, not vendored)

**Default: Codegraph (`@optave/ops-codegraph-tool`).**

| Property | Value |
|---|---|
| License | Apache-2.0 (safe for a cloner's private repos) |
| Mechanism | **tree-sitter → SQLite**, built on demand (`codegraph build` → `.codegraph/graph.db`) |
| Daemon | **none** — no resident server, no file-watcher required |
| LLM | **none** — deterministic tree-sitter, so **no hallucinated edges** |
| Interface | MCP (callers/callees, blast-radius / `fn-impact`, boundaries, communities, diff-impact) |
| Export | Mermaid / GraphML / JSON / DOT / GraphSON / Neo4j-CSV |

Codegraph is chosen because it is the only no-daemon option delivering **both**
first-class agent queries (what `freeze` plan-as-DAG and `/review-team` consume)
**and** a human-visual path via export. **Mermaid** and **GraphML** are the
load-bearing exports because **Graphviz (`dot`) is absent** on the reference
machine — do not lean on DOT rendering.

**Rules:**

- **Wired, not vendored.** The framework does **not** vendor, install, or run
  Codegraph. The `/graph` skill's backend is **swappable** and the export
  formats are standard. **Pin the version** when a project opts in.
- `.codegraph/` (the on-demand SQLite build) is **git-ignored** — it is a
  derived cache, never committed.
- Registered in the **product workspace's** `.mcp.json` **only on opt-in** — the
  same npx-stdio pattern product repos already use for their MCP servers. Never
  in the framework-root config.

### 3.2 Degradation floor — ctags + rg (always present)

When **no code MCP is present**, the graph **degrades to text-only**: the
`ctags + rg` ranked repo-map (the swarm-explore grep loop) that ships **in** the
template with zero clone-time binary dependency. An agent therefore **always**
has *some* graph — the code half simply resolves to path-string anchors instead
of Codegraph node ids. This degradation is normative and must never regress into
a hard dependency on Codegraph.

---

## 4. Bridge — `graph-bridge.jsonl`, the only thing spanning both halves

The bridge is the single git-tracked artifact that joins code and docs.

- **Location:** `.logic-loom/graph/graph-bridge.jsonl` (git-tracked, beside the
  memory files).
- **Format:** one JSON object per line, **Anthropic memory-server shape**.
- **Builder:** `build-graph-bridge.sh` — a deterministic `jq` + `rg` generator.
  **Zero LLM.** Idempotent (Principle IV): re-running over an unchanged corpus
  produces byte-identical output.
- **Refresh:** via **`/graph build`**, hung off **session-start / post-commit /
  `/retro`**. **NO watcher, NO daemon** — freshness is lazy regeneration, never
  a resident process.

### 4.1 Canonical schema

Node ids are **repo-relative paths** (e.g. `.docs/architecture/loom-architecture.md`,
`.logic-loom/lib/parallel.sh`).

```jsonc
// entity
{"type":"entity","name":"<repo-relative-path>","entityType":"note"|"code-path","observations":["title or one-line"]}

// relation
{"type":"relation","from":"<id>","to":"<id>","relationType":"links-to"|"mentions"|"covers"|"decided-by"}
```

### 4.2 Edge harvest rules (deterministic, from the corpus)

The corpus is markdown under `.docs/`, `features/`, `specs/`, plus root
`README.md` / `CLAUDE.md` / `AGENTS.md` / `START_HERE.md` / `VISION.md`.

| Edge | Source | Node it points at | Dangling → |
|---|---|---|---|
| **links-to** | `[[wikilink]]` and `[text](relative.md)` in note bodies | a real **note** path | linter **warns** |
| **mentions** | inline backtick `` `path` `` where `<path>` resolves to an **existing** repo file | a **code-path** node | (only emitted when resolvable) |
| **covers** | frontmatter `covers: [path, …]` (or block list) in a note | a **code-path** node per path | linter **warns** |
| **decided-by** | the **inverse** of `covers` (code-path → note) | the governing **note** | derived / may be emitted |

Resolution: each code path resolves to a **Codegraph node id when the MCP is
present**, or a **path-string anchor** when not — so the bridge works text-only
on any clone and upgrades in place when Codegraph is wired.

---

## 5. Visualization — three self-contained paths, no server

No single native pane shows code AND docs unless code is represented as nodes
alongside docs. All three shipped paths render **without Graphviz and without
Docker** (both absent on the reference machine):

1. **Docs — Obsidian graph view.** Natively visualizes `.docs/` + `features/` +
   `specs/` + `loom-memory` with zero conversion. An `.obsidian/` config **template**
   (`.logic-loom/templates/obsidian/`) provides sane graph filters/colors + wikilink-preferred
   defaults — copy it into your vault's `.obsidian/` (Phase 1); auto-install lands in Phase 3.
2. **Code — Codegraph export.** `codegraph export -f mermaid` (renders in
   Obsidian / GitHub / VS Code natively) or `-f graphml` (→ Gephi / Cytoscape /
   yEd for interactive force-directed exploration). `/graph` can also emit code
   nodes as **Obsidian stub-notes** so they appear in the *same* Obsidian graph
   as the docs.
3. **Self-authored layer — a shipped HTML viewer.** One committed,
   inline-JS, CSP-safe single-file HTML viewer over `.logic-loom/graph/*.json`.
   Commit-one-file, opens offline, **no server, regenerated on demand**.

**Graphviz and Docker are NOT required and NOT assumed.** Any visualization the
convention leans on must render without them.

---

## 6. Tandem — personal vault beside the project graph, never merged

The developer's **personal vault** and the **project vault/graph** are **two
vaults side by side, NEVER merged**. Obsidian runs multiple vaults
simultaneously and internal links do not cross vaults — that isolation is a
feature, and it is what keeps the project graph portable.

| | Personal vault | Project vault/graph |
|---|---|---|
| Scope | per-**user** second brain (saved links, bookmarks, personal context) | per-**repo** docs/features/specs/loom-memory + opt-in Codegraph |
| Location | **outside** any repo | in-repo, git-tracked, templated |
| Templated in | **never** | yes |
| Access | opt-in Obsidian **CLI / MCP**, wired into the developer's own Claude Code once | Read/Grep + `/graph` + opt-in Codegraph MCP |

**Tandem model = two independent queries, one synthesis — no store merge.** For
any task the agent consults the **project** graph (repo context) **and** queries
the **personal** vault (saved-links / personal context) via its CLI/MCP, then
synthesizes. The stores are **never** co-mingled — that separation is the
portability guarantee. A personal-vault MCP (e.g. an Apache-2.0 Obsidian MCP
server) is **recommended, never bundled**; the developer wires it into their own
Claude Code, not into the templated project.

---

## 7. What LogicLoom ships (and never ships)

**Ships (portable to every templated project):**

1. **This convention** — the shipped policy doc every project inherits.
2. **An `.obsidian/` config template** (`.logic-loom/templates/obsidian/`) — sane graph
   view + wikilink-preferred defaults; the human copies it into their vault (Phase 1).
   Auto-install via `/initialize-project` lands in Phase 3.
3. **The bridge** — `graph-bridge.jsonl` + `build-graph-bridge.sh` (deterministic
   `jq` + `rg`, zero LLM, git-tracked).
4. **A `/graph` skill** (bridged via `.claude/commands/` like every command) that:
   (a) regenerates the bridge; (b) answers cross-half queries ("what governs
   `src/auth/*`", "what does spec Y cover", "blast radius of editing Z") by
   walking the manifest with `jq`, **escalating to the Codegraph MCP when
   present** (else text-only); (c) emits the Obsidian-vault / Mermaid / GraphML /
   HTML export for human viewing; (d) runs a **fail-open** orphan/dangling linter.
5. **`/initialize-project` wiring (Phase 3)** — writes the convention +
   `.obsidian/` stub; **detects project shape** and, on opt-in, registers
   Codegraph in the *product* workspace's `.mcp.json` and adds `.codegraph/` to
   `.gitignore`; hangs manifest refresh off session-start / post-commit /
   `/retro`.

**Never ships:** a graph **engine** or **daemon**; a mandatory floor
file-watcher or server; a **default LLM extraction pass**; a merged unified store
as the canonical store; a bundled Codegraph install; a bundled Obsidian MCP as a
project floor.

---

## 8. Anti-overbuild guardrails + tripwires

**Allowed** (the reconciled scope): a per-project **opt-in** MCP a developer
starts for *their* repo (Codegraph, a personal-vault Obsidian MCP); a git-tracked
graph JSON/JSONL; a committed self-contained HTML viewer; Mermaid/GraphML exports
rendered in tools already installed.

**Forbidden — must NOT happen:**

1. **No mandatory harness-floor daemon / file-watcher / server** every clone must
   keep alive (a graph DB as a *required* store; an always-on watcher; Docker —
   not even installed). The canonical store stays **git-tracked text**; MCP/HTML
   are on-demand lenses.
2. **No LLM extraction pass in the default path.** It re-derives author-written
   edges — worse and expensively. loom-memory already **hand-writes** the
   temporal `SUPERSEDES`/`CORRECTS` edges an extraction pipeline would approximate.
3. **No hard-depending the template on a low-maturity tool.** Codegraph is
   **wired, not vendored** — swappable backend, standard export formats, **pinned
   version**, and it **degrades cleanly to the ctags + rg floor** when absent.
4. **No unified store as the canonical store.** The merged code+docs view is an
   **export**, never the source of truth.
5. **No co-mingling** the personal vault into the project graph. Link by
   convention; **never merge stores**.

**Tripwires** (each signals the graph capability is drifting toward the next cut
subsystem):

- (i) a proposal adds a **running process / port / Docker** a cloner must keep
  alive;
- (ii) an **LLM call enters the default** extraction path;
- (iii) the linter **blocks** instead of **warns**;
- (iv) a **new clone-time binary** requirement appears (Graphviz, Docker, a
  native graph-DB wheel);
- (v) the personal and project vaults get **merged** into one store;
- (vi) freshness needs a **watcher** instead of lazy regen on session-start /
  post-commit / `/retro`;
- (vii) the template **requires** Codegraph rather than **degrading** to the
  ctags + rg floor.

---

## See also

- `features/code-knowledge-graph/exploration/project-graph-design.md` — the
  design of record this convention normalizes (§3–§4 stack, §6 guardrails).
- `.docs/architecture/freeze-scope-protocol.md` — the plan-as-DAG file-ownership
  contract the code-graph blast-radius queries feed.
- `.docs/architecture/loom-architecture.md` — full architectural reference.
- `.logic-loom/graph/graph-bridge.jsonl` — the bridge artifact (Phase 1).
