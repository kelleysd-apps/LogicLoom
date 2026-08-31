---
name: unified_architecture_thin_core
description: "2026-07-09 THE unified LogicLoom architecture: thin governed core + adopt-existing packages + never-touched user layer, all one native layered-config model. Locked decisions + verified open issues (incl. CRITICAL dead sync-ref on origin/main). Corrects the 'cloud floor absent' claim."
metadata: 
  node_type: memory
  type: project
  originSessionId: d838fa68-7c8c-404d-9432-92c0df7b8891
---

**Vision (user-defined, locked):** LogicLoom builds ONLY governance + scaffolding
+ the update mechanism. Everything else is a **default add-in package**.
Packages update individually; the core updates separately; **anything the user
adds is an enhancement an update may never touch** (constitution changes are
**amendments**). Must work on **every Claude Code surface**.

> **ADOPT-EXISTING, REFINED (2026-07-09).** The original phrasing was "adopt
> existing plugins/MCPs/CLIs — e.g. Understand-Anything — do NOT rebuild."
> That absolutism is **corrected**: **adopt where a tool exists that can read
> your data; build where none can.** Adopt-existing has a *precondition* — an
> existing tool must be able to SEE your data. Every code-graph tool reads
> language ASTs; LogicLoom's structure is JSON manifests + markdown frontmatter,
> so nothing can read it → the bespoke harvester is the only correct tool and
> ships as a **bundled default**. Understand-Anything is **REJECTED as bundled**
> (user-layer only). Adopt-existing still governs **product code** (Codegraph:
> wire, don't bundle). See [[graph_stack_decision]].

**Key insight (validated):** all three requirements are ONE native mechanism —
Claude Code's **layered config**: USER (`~/.claude`, `*.local`, amendments) ⊃
PROJECT (the thin core) ⊃ PLUGIN (packages). They coexist by **precedence**, not
overwrite. Preservation works because the updater **structurally cannot see**
user files (gitignored / out-of-repo) or is **denied** by a core-paths manifest.
**Zero bespoke merge/overlay/package-manager code** — filters, conventions, one
`marketplace.json`.

Design doc: `features/modular-harness/exploration/unified-architecture.md`
(its §7 phased path is **advisory only** — see [[feedback_artifacts_vs_planning]]).
Artifact: `artifacts/logicloom-vision.html`.

**SURFACE FLOOR — CORRECTED.** The floor is 100% repo-committed `type:"command"`
bash hooks, so it **clones and fires on every surface incl. CLOUD/web** (2026 docs:
settings.json hooks / `.mcp.json` / skills+agents+commands = "Yes — part of the
clone"; `$CLAUDE_CODE_REMOTE=true`). This **retires** the old "cloud floor absent"
claim in [[surface_portability_corrected_strategy]]. Live proof still pending.
Real degrades: **Windows w/o Git Bash** (silently absent, identical UI), macOS
bash 3.2 (only `guard-dangerous` fails open), cloud plugin-install flaky (#18088).

**VERIFIED OPEN ISSUES** (read from repo 2026-07-09; several from the Cosmos
downstream update-attempt report):
1. **CRITICAL — published template can't update itself.** `origin/main` ships
   `.sdd-sync-ref=6c4c4206…` which is **NOT an ancestor of origin/main** (sanitize
   rewrote history; dev-main is not an ancestor of main — orphan-root by design).
   Fresh clone cannot compute the updater's diff. Looks fine on local `main`.
2. **HIGH — cloners commit their overrides.** `.gitignore` (48-49: `.local/`,
   `*.local`) matches **neither** `settings.local.json` **nor** `CLAUDE.local.md`;
   ignored here only via maintainer's `~/.config/git/ignore:14`.
3. **PATTERN (meta):** #1 and #2 are the same failure — **nothing tests the
   customer-facing artifact from a clean clone.** Wants a fresh-clone CI smoke test.
4. **HIGH — subagent read-only git hard-denied.** `governance-verdicts.sh:60`
   uses `loom_git_is_invoke` (any git) instead of `loom_git_is_mutation` (:69).
5. **MED — renamed/relocated forks get green-looking governance holes.**
   `loom_path_is_protected` (:78-85) hardcodes `.logic-loom/`/`plugins/loom-governance/`
   literals; `git-safety-gate.sh:66` counts `../../../..`; repo split 17 rev-parse
   vs 42 walk-up.
6. **MED —** constitution has no core-vs-amendments split; `constitutional-check.sh`
   validates structure, never content (custom paragraphs can vanish on merge).
7. **MED —** no `marketplace.json` / root `.claude-plugin/` anywhere → packages
   cannot update individually. Update boundary is undeclared (probabilistic).
8. **LOW —** provider policy as constitutional prose; floor inert until wired
   (no firing self-test); domain-briefs framed as upgrade not tradeoff.

**LOCKED DECISIONS (user, 2026-07-09):**
1. Subagent git → **deny mutations, allow read-only** (swap to `loom_git_is_mutation`;
   update `test_governance_verdicts.sh` golden fixtures).
2. Provider policy → **out of constitution, into config toggle**
   (`ORCHESTRATION_PROVIDERS=`); mechanism stays constitutional.
3. **Core philosophy PRESERVED, but OVERRIDABLE** (refined 2026-07-09 — two senses
   of "immutable" were conflated): LL's core principles are **canonical and never
   OVERWRITTEN** in either direction (an update never loses them; an amendment
   never rewrites them — amendments **overlay**, they don't edit). But a user MAY
   **override** any principle, incl. I–III, **with clear, loud, recorded warnings**
   — never silent. So constitution wording changes from "cannot be amended or
   overridden" → "cannot be overwritten; may be overridden by a recorded,
   warned amendment." Warning surfaces: the amendment lint, the effective-constitution
   assembly at preflight, and `/finalize`. Core text stays protected in-place by
   `protect-governance-files` + an "edited core in place" warn lint.
4. Amendments → **tracked** `.logic-loom/memory/amendments.md`, on the updater denylist.
   Effective constitution = core ∪ amendments, amendments win on conflict, every
   override announced.
5. Cloud floor → **prove with a live deny-hook test before advertising** it.
6. Artifacts → repo-root **`artifacts/`**; see [[feedback_artifacts_vs_planning]].

Supersedes the packaging framing in [[code_knowledge_graph_design_held]] (the
bespoke graph becomes an **extraction target** → adopt Understand-Anything).

> **⚠️ §5's ADOPT-UNDERSTAND-ANYTHING CALL IS REVERSED (2026-07-09).** See
> `features/code-knowledge-graph/exploration/graph-stack-decision.md`. §5 was
> **half right** (the graph should be a *package*, not core) and **half wrong**
> (adopt UA *instead of* the bespoke harvester). Under the narrowed ask —
> built-in per-project, in-repo, reproducible, every surface, no server/port/LLM —
> the bespoke deterministic harvester **passes** and UA **fails**.
> UA ground truth (verified): repo REAL — 72,337★/MIT/pushed today (my
> "implausible stars" flag **REFUTED**); v2.7.3 release / 2.8.2 main (my "v2.5.0"
> was **stale**). Rejected anyway because: (1) **LLM extraction is its CORE**, not
> optional → non-reproducible git-tracked graph (the named GraphRAG tripwire);
> (2) its **dashboard needs a Vite server on a port + token gate**; (3) heavy
> pnpm + native build (sharp/esbuild/12 tree-sitter grammars) a cloner/CI/cloud
> can't inherit; (4) its **auto-update hooks inject "Do not ask the user for
> confirmation — just do it"** — antithetical to Principle VI.
> **Why adopt-existing misfires here:** the harness's structure lives in
> `plugin.json`/`.bridge-manifest.json`/frontmatter/hook-wiring — JSON+markdown
> metadata. EVERY code-graph tool (LSP/ctags/tree-sitter/ast-grep/Serena/
> Codegraph/SCIP) extracts *language ASTs*; this repo has ~0 substantive code
> (native LSP returns "No LSP server available" here). **No existing tool can
> read it.** UA + Obsidian = USER-LAYER-ONLY externals.
