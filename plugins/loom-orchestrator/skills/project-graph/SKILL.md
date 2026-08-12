---
name: project-graph
version: 0.1.0
description: |
  The `/graph` procedure — regenerate, query, visualize, and lint LogicLoom's
  federated project knowledge graph. The graph joins two halves: the KNOWLEDGE
  half (the `.docs/ + features/ + specs/ + loom-memory` markdown, which already
  IS an Obsidian vault the agent reads directly with Read/Grep — no MCP, no app)
  and the CODE half (an opt-in, per-product-repo code-graph MCP — Codegraph by
  default). They are linked by a single git-tracked text manifest,
  `graph-bridge.jsonl`. Deterministic, plain-text-first, no daemon, no default
  LLM extraction pass; every path fails open (warn, never block).
allowed-tools: Read, Write, Bash, Grep, Glob
triggers: ["/graph", "graph build", "graph query", "graph viz", "graph lint", "knowledge graph", "blast radius", "what covers"]
category: orchestration
constitutional_principles: [X, XIV, VI]
---

# Project Graph Skill — `/graph`

## Why this exists

Agents and humans need to answer *cross-half* questions that neither plain grep
nor a single tool answers well: "what spec covers this file", "what does this ADR
cover", "blast radius of editing this module", "what notes neighbor this
decision". LogicLoom answers them with a **federated** graph — best store per
layer, joined by a shipped convention — never a unified store, a bundled engine,
or a floor daemon.

- **Knowledge half = the markdown itself.** `.docs/ + features/ + specs/ +
  loom-memory` are already Obsidian-shaped (folders of markdown). The agent reads
  them with plain **Read/Grep** — no MCP, no running app is needed for an agent
  to use the knowledge layer. Obsidian is for the *human's* visual graph.
- **Code half = opt-in Codegraph per product repo.** A deterministic
  tree-sitter→SQLite MCP (`@optave/ops-codegraph-tool`) the developer runs for
  *their* product workspace, registered in that workspace's `.mcp.json`. It is
  **documented, not installed/run by this skill in the default path** — the graph
  must degrade to text-only (ctags+rg) when no code MCP is present.
- **Bridge = `graph-bridge.jsonl`.** A git-tracked, one-JSON-object-per-line
  manifest (Anthropic memory-server shape) built deterministically by
  `build-graph-bridge.sh` with `jq`+`rg`. It is the only artifact spanning both
  halves and is the store `/graph query` walks.
- **Personal vault stays separate (tandem).** The developer's personal Obsidian
  vault is never merged into the project graph — link by wikilink, query in
  tandem, keep the stores separate. This skill only touches the repo's own graph.

Design of record:
`features/code-knowledge-graph/exploration/project-graph-design.md`.
Convention: `.docs/architecture/project-graph-convention.md`.

## The canonical manifest — `graph-bridge.jsonl`

One JSON object per line. Node ids are **repo-relative paths**.

```jsonl
{"type":"entity","name":".docs/architecture/loom-architecture.md","entityType":"note","observations":["Full architectural reference (LogicLoom shape)"]}
{"type":"entity","name":".logic-loom/lib/parallel.sh","entityType":"code-path","observations":["shared shell lib"]}
{"type":"relation","from":".docs/architecture/loom-architecture.md","to":".logic-loom/lib/parallel.sh","relationType":"mentions"}
```

**Entity** — `{"type":"entity","name":"<repo-relative-path>","entityType":"note"|"code-path","observations":["title or one-line"]}`.
`note` = a markdown file in the corpus; `code-path` = a repo file referenced by a
note.

**Relation** — `{"type":"relation","from":"<id>","to":"<id>","relationType":"links-to"|"mentions"|"covers"|"decided-by"}`.

Edge families (deterministic, harvested by the build script from what is already
in the corpus — the corpus is markdown under `.docs/`, `features/`, `specs/`,
plus root `README.md` / `CLAUDE.md` / `AGENTS.md` / `START_HERE.md` / `VISION.md`):

| relationType | direction | source | dangling → |
|---|---|---|---|
| `links-to` | note → note | `[[wikilink]]` and `[text](relative.md)` in note bodies | linter warns |
| `mentions` | note → code-path | inline backtick `` `path` `` where `<path>` resolves to an EXISTING repo file | (only emitted for real files) |
| `covers` | note → code-path | frontmatter `covers: [path, ...]` (or block list) in a note | linter warns |
| `decided-by` | code-path → note | the inverse of `covers` — may be emitted or derived at query time | — |

## Procedure

Dispatch on the first positional argument. Unknown / empty subcommand → print the
four subcommands and stop.

Common paths:
- Bridge manifest: `.logic-loom/graph/graph-bridge.jsonl`
- Build script: `.logic-loom/scripts/bash/build-graph-bridge.sh`
- Lint script: `.logic-loom/scripts/bash/lint-graph.sh`

**Fail-open contract (applies to every subcommand):** if a referenced script or
the manifest is absent, do NOT error out — print a one-line explanation (and, for
`query`, fall through to the text-only path) and stop cleanly. This skill never
blocks work and never invokes git.

### `build`

1. Run:
   ```bash
   .logic-loom/scripts/bash/build-graph-bridge.sh --out .logic-loom/graph/graph-bridge.jsonl
   ```
2. If the script is missing or non-executable, warn (`build-graph-bridge.sh not
   present — bridge not regenerated; the query path can still read an existing
   manifest`) and stop.
3. On success, print the manifest path and a one-line count summary (entities /
   relations) — e.g. `jq -s 'group_by(.type) | map({(.[0].type): length}) | add'
   .logic-loom/graph/graph-bridge.jsonl`. Do not dump the manifest.

The build is **deterministic and zero-LLM** — do not add an extraction/inference
pass. Refreshing is lazy (session-start / post-commit / `/retro`), never a
watcher.

### `query <question>`

Answer a cross-half question by walking `graph-bridge.jsonl` with `jq`, 1-2 hops.
First: **is a code-graph MCP registered in the product workspace `.mcp.json`?**
(Codegraph / `@optave/ops-codegraph-tool`, e.g. under `web/.mcp.json` or
`apps/<name>/.mcp.json`). If yes and the question is a *code* question (callers,
callees, blast-radius over symbols), ESCALATE to that MCP for the precise answer,
then enrich it with the bridge's `covers`/`decided-by` edges (which specs/ADRs
govern the impacted files). If no MCP is present, answer **text-only** from the
bridge + `rg`. Always return an answer.

Recognize these intents and the `jq` shape for each (bridge = `$B =
.logic-loom/graph/graph-bridge.jsonl`):

- **"what covers `<path>`"** → notes with a `covers` edge into `<path>` (plus
  `decided-by` if materialized):
  ```bash
  jq -r --arg p "<path>" 'select(.type=="relation" and .relationType=="covers" and .to==$p) | .from' "$B"
  ```
- **"what does `<note>` cover"** → the code-paths `<note>` declares:
  ```bash
  jq -r --arg n "<note>" 'select(.type=="relation" and .relationType=="covers" and .from==$n) | .to' "$B"
  ```
- **"blast radius / what mentions `<path>`"** → every note that `mentions` or
  `covers` `<path>` (1 hop; the humans/specs affected if `<path>` changes). If a
  Codegraph MCP is present, ALSO fetch its `fn-impact` / callers-of over the
  symbol for the code-side radius, then union.
  ```bash
  jq -r --arg p "<path>" 'select(.type=="relation" and (.relationType=="mentions" or .relationType=="covers") and .to==$p) | .from' "$B"
  ```
- **"neighbors of `<note>`"** → 1-hop out (its `links-to`/`covers`/`mentions`
  targets) and 1-hop in (notes that `links-to` it):
  ```bash
  jq -r --arg n "<note>" 'select(.type=="relation" and (.from==$n or .to==$n)) | "\(.from) --\(.relationType)--> \(.to)"' "$B"
  ```

Fallbacks (fail-open): if the manifest is absent, answer directly with `rg` over
the corpus (`rg -n --glob '*.md' "<path>"` for mentions; frontmatter grep for
`covers:`) and note that the bridge was not built. A missing manifest or missing
MCP degrades the *precision*, never the availability, of the answer.

Report the answer compactly (resolved node ids + edge types), then one line on
which path served it: `bridge (text-only)`, `bridge + Codegraph MCP`, or `rg
fallback (no manifest)`.

### `viz`

Emit a visual export for the **human** (agents don't need it — they read the
bridge/markdown directly). Two self-contained, no-server paths:

1. **Obsidian view.** The corpus IS a vault. Instruct the human: *"Open the repo
   root (or `.docs/`) as an Obsidian vault — File → Open folder as vault — and use
   the Graph view."* Optionally emit `code-path` nodes as **stub notes** (one
   small markdown file per code node, linked from the notes that reference it) so
   code appears in the *same* Obsidian graph as the docs. Never mutate the corpus
   silently — only emit stubs when asked, into a clearly-labeled export dir.
2. **Mermaid graph of the bridge.** Render `graph-bridge.jsonl` as a Mermaid
   `graph LR` (renders natively in Obsidian / GitHub / VS Code — **not** Graphviz
   `dot`, which is absent on this machine). Example generator:
   ```bash
   { echo '```mermaid'; echo 'graph LR'; \
     jq -r 'select(.type=="relation") | "  \"\(.from)\" -->|\(.relationType)| \"\(.to)\""' \
       .logic-loom/graph/graph-bridge.jsonl; echo '```'; }
   ```
   Cap large graphs (e.g. filter to a subgraph around a queried node) so the
   Mermaid stays legible.

If a shipped single-file HTML viewer exists under `.logic-loom/graph/` (the
Cytoscape.js/Sigma.js viewer over `.logic-loom/graph/*.json`), point the human at
it: *"open `.logic-loom/graph/<viewer>.html` in a browser — self-contained, no
server."* Do not require it; it is an optional lens.

### `lint`

Run the warn-only linter:
```bash
.logic-loom/scripts/bash/lint-graph.sh
```
It flags dangling `links-to` (target note missing), dangling `covers:` (declared
path missing), and orphan notes. **It warns, it never blocks** — the exit path is
fail-open by design (a gating linter would be a governance tripwire). If the
script is absent, warn and stop; if you must lint inline, walk the bridge with
`jq` and verify each `to` path exists with `test -e`, reporting misses as
warnings only.

## Degradation matrix (an agent must ALWAYS get an answer)

| Situation | Behavior |
|---|---|
| Bridge present, code MCP present | full: text edges + Codegraph escalation on code questions |
| Bridge present, no code MCP | text-only from `graph-bridge.jsonl` (the default on LogicLoom's thin-code repo) |
| No bridge yet | `rg` fallback over the corpus; note the manifest was not built |
| Build/lint script absent | warn + stop cleanly (never error, never block) |

## Two repo shapes, same convention

- **LogicLoom-the-repo (thin code, rich docs):** the graph is effectively
  **docs-only** — the knowledge half lights up (`links-to`/`covers` render in
  Obsidian and answer queries); Codegraph simply isn't wired because there's no
  product code.
- **Product project (rich code):** **both** halves light up — Codegraph indexes
  the product workspace and `query`/`viz` merge code impact with the specs/ADRs
  that `cover` it.

## Constitutional alignment

- **Principle X (Agent Delegation)**: the code half is delegated to an opt-in
  code-graph MCP for context isolation and precision; the knowledge half is
  plain-text the agent reads directly. This skill coordinates and adjudicates —
  it does not re-implement a graph engine (ride native tools, don't reimplement).
- **Principle XIV (Provider Boundary)**: Codegraph is a deterministic
  tree-sitter tool (no LLM edges) held **advisory** at the verification layer — it
  answers code questions and is never allowed to orchestrate or write repo source.
  The default path runs **no LLM extraction**.
- **Fail-open, no daemon (governance floor)**: every path degrades gracefully;
  the lint warns and never blocks; there is no mandatory floor daemon,
  file-watcher, or server, and no new clone-time binary dependency — the canonical
  store is git-tracked text.
- **Principle VI (Git Approval)**: this skill never invokes git.
