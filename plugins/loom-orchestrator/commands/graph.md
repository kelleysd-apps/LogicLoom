---
name: graph
description: Project-wide knowledge graph — regenerate + query the code+docs bridge, emit a visual export, and lint. Walks the git-tracked graph-bridge.jsonl (text-first, deterministic, no daemon); escalates code questions to an opt-in code-graph MCP (Codegraph) when the product workspace has one, else degrades to text-only (ctags+rg) so an agent always gets an answer.
model: opus
---

# /graph Command — Project Knowledge Graph

**Subcommand dispatch**: the first positional argument selects the operation.

**SKILL ACTIVATION**: Read and execute
`plugins/loom-orchestrator/skills/project-graph/SKILL.md` and follow its
Procedure for the selected subcommand.

`/graph` is the single entry point to LogicLoom's federated project graph — the
join between the **knowledge half** (the `.docs/ + features/ + specs/ +
loom-memory` markdown that *is* an Obsidian vault, read directly with Read/Grep)
and the **code half** (an opt-in, per-product-repo code-graph MCP). The two are
linked by a git-tracked text manifest, `graph-bridge.jsonl`. There is no daemon,
no server, and no default LLM extraction pass — the graph is plain text the agent
reads, and everything **fails open** (warn, never block).

Design of record: `features/code-knowledge-graph/exploration/project-graph-design.md`.
Convention: `.docs/architecture/project-graph-convention.md`.

## Subcommands

### `/graph build`
Regenerate the bridge manifest. Runs
`.logic-loom/scripts/bash/build-graph-bridge.sh --out .logic-loom/graph/graph-bridge.jsonl`,
which deterministically harvests corpus edges (`links-to` from wikilinks/relative
md links, `mentions` from backtick path references that resolve to real files,
`covers` from frontmatter, `decided-by` as the inverse) with `jq`+`rg`. No LLM,
no new clone-time dependency. Fail-open: if the script is absent, say so and stop.

### `/graph query <question>`
Answer a cross-half question by walking `graph-bridge.jsonl` with `jq` (1-2 hops):
"what covers `<path>`", "what does `<note>` cover", "blast radius / what mentions
`<path>`", "neighbors of `<note>`". If a code-graph MCP (Codegraph,
`@optave/ops-codegraph-tool`) is registered in the **product workspace**
`.mcp.json`, escalate code questions to it; otherwise answer text-only from the
bridge + `rg`. Always degrade gracefully — an agent must always get an answer.

### `/graph viz`
Emit a visual export for the human: (a) the Obsidian-openable view (the corpus
IS a vault — "open the repo / `.docs` as an Obsidian vault"; optionally emit code
nodes as stub notes so they appear in the same graph), and (b) a **Mermaid**
graph of the bridge (renders natively in Obsidian / GitHub / VS Code — not
Graphviz, which is absent on this machine). Point at the shipped HTML viewer if
one is present under `.logic-loom/graph/`.

### `/graph lint`
Run `.logic-loom/scripts/bash/lint-graph.sh` — warns on dangling `links-to`,
dangling `covers:` (path missing), and orphan notes. **Warn-only**, never blocks
(fail-open, like the rest of the governance floor).

## Usage

```
/graph build                              # regenerate graph-bridge.jsonl
/graph query "what covers .logic-loom/lib/parallel.sh"
/graph query "blast radius of plugins/loom-governance/hooks/scripts/git-safety-gate.sh"
/graph query "what does .docs/architecture/loom-architecture.md cover"
/graph query "neighbors of .docs/architecture/governance-threat-model.md"
/graph viz                                # Obsidian view + Mermaid export
/graph lint                               # warn-only dangling/orphan check
```

## Constitutional Compliance

- **Principle X (Agent Delegation)**: the code half is delegated to an opt-in
  code-graph MCP for context isolation; the knowledge half stays in-context
  plain-text the agent reads directly. `/graph` coordinates; it does not
  re-implement a graph engine.
- **Principle XIV (Provider Boundary)**: the code-graph MCP is a deterministic
  tree-sitter tool (no LLM edges) held **advisory** at the verification layer —
  it answers code questions, it never orchestrates or writes repo source.
- **Fail-open, no daemon**: every path degrades (MCP → text-only; missing script
  → warn and stop; lint warns, never blocks). No mandatory floor daemon,
  file-watcher, or server — the canonical store is git-tracked text.
- **Principle VI (Git Approval)**: `/graph` never invokes git.
