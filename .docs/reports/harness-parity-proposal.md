# LogicLoom Harness-Machinery Parity Proposal

**Status:** PROPOSED — nothing in this document is applied. Every item is an edit to an *existing* LogicLoom system and requires explicit approval before implementation, per the standing principle: **propose before editing existing framework systems** (and Principle VI: no autonomous mutation of the governance/orchestration surface). Items that touch a protected governance file are flagged; those will additionally trip `protect-governance-files.sh` and force a main-agent approval prompt even after this proposal is accepted.

**Author:** LogicLoom lead architect
**Scope:** harness machinery only (LogicLoom v6.2.0 / constitution v3.2.0)
**Source:** kept + ranked candidates from the harness-parity mining effort (11 kept, 9 killed)

---

## Framing: machinery, not tools

LogicLoom is a **Claude-Code-native, governed multi-agent *development* harness**. This proposal improves the **harness machinery itself** — the orchestration skills, governance/preflight hooks, context/memory behavior, the plan-as-DAG contract, and the domain-brief registry — so the harness BEHAVES better for development work *automatically, for every relevant task*. It does **not** add anything a user invokes.

Each proposal passed the **harness-machinery test**:

- **VALID** — an edit to an existing harness system that changes how the harness behaves for dev work (understanding / editing / fixing / testing code, or the quality / speed / reliability of the dev workflow), automatically, with no new user surface.
- **INVALID** — any new user-invokable skill / command / plugin / tool, reimplementing native orchestration, or any refuse-list item.

Every item below carries an explicit *"why this is machinery, not a user tool"* line. Identity invariants are preserved throughout: orchestration stays Anthropic-native and rides ON native primitives (Task tool, `/workflow`, `/loop`, `/goal`) — **no custom engine, runner, process-manager, session-multiplexer, or swarm-state file** is introduced; constitutional governance (16 hook-enforced principles, approval-gated git) is untouched except where an item explicitly proposes a hook-schema change for approval.

---

## Ranked proposals

| # | Proposal | Target system | Effort | Priority | Pattern mined |
|---|---|---|---|---|---|
| 1 | Align memory search paths with where dev/learning artifacts live | loom-memory keyword + BM25 backends, memory.conf | M | **High** | Hermes (retrieval half) |
| 2 | Real LSP/diagnostics grader for the review-evaluator non-UI branch | review-evaluator SKILL.md | M | **High** | Crush/Cursor LSP-as-context; Bugbot verify-the-fix |
| 3 | "Prove the rubric green in-context" as a worker-completion contract | swarm-implement SKILL.md (+ team-orchestration) | S | **High** | Cursor Bugbot prove-green |
| 4 | Kahn wave-parallel dispatch in swarm-implement | swarm-implement SKILL.md | L | Medium | Crush/Cursor build-in-parallel |
| 5 | Ranked repo-map grounding in brief.md / slice charters | swarm-implement + swarm-explore SKILL.md | M | Medium | Aider repo-map; Crush codebase-index |
| 6 | context-cap-warn → dependency-preserving compaction handoff | .claude/hooks/context-cap-warn.sh *(protected)* | M | Medium | ace-fca; Hermes head/tail |
| 7 | Living "Field Notes" in domain briefs, fed by /retro | domain-briefs/, common.sh get_domain_brief, retro SKILL.md | S | Medium | Hermes loop; OpenHands microagents |
| 8 | Failure-mode / fix-recipe in the worker-completion contract | swarm-implement + retro SKILL.md | S | Low | Bugbot fix capture; Hermes (input half) |
| 9 | Per-task typed produces/consumes artifact edges | plan-template.md, swarm-implement SKILL.md | M | Low | Aider repo-map; Principle III Contract-First |
| 10 | Symbol-neighborhood injection in governance-preflight | .claude/hooks/user-prompt-submit/governance-preflight.sh *(protected)* | M | Low | Crush/Cursor LSP-as-context; OpenHands |
| 11 | Generalize domains.conf into a microagent trigger table | domains.conf, governance-preflight.sh *(protected)*, domain-briefs/ | M | Low | OpenHands microagents |

> *(protected)* = edits the governance surface guarded by `protect-governance-files.sh`; requires main-agent approval at apply-time regardless of this proposal's acceptance.

---

## High priority

### 1. Align memory search paths with where dev/learning artifacts actually live

- **Target (existing):** `plugins/loom-memory/lib/keyword-backend.sh`, `plugins/loom-memory/lib/bm25-search.sh`, `plugins/loom-memory/config/memory.conf`
- **Behavior change (all dev work):** Drop the dead `.devloop/sessions/` path (dev-loop was removed in v6.2); add `features/` scoped to summary files (`retro.md` / `plan-review.md` / `prd.md` / `sprints/**/result.md`); add the home retro-memory dir `$HOME/.claude/projects/<slug>/memory/` to the searched set in **both** backends. The always-on preflight memory injection then actually surfaces past-feature lessons.
- **Justification (dev value + pattern):** **VERIFIED broken loop.** `keyword-backend.sh` lines 135/140 still search the removed `.devloop/sessions` path and line 142 searches only `.logic-loom/memory`; `bm25-search.sh` line 296 scope pattern is `^(specs/|.devloop/sessions/|.docs/)`. Meanwhile `/retro` provably writes lessons to `$HOME/.claude/projects/<slug>/memory/` (retro SKILL.md lines 101–108) and `features/` — **neither is searched by either backend.** The retrieval side of the learning loop is dead today. Brings the **Hermes** closed cross-session learning loop (retrieval half). **Why machinery, not a user tool:** a pure edit to the search backend the `governance-preflight` hook auto-invokes on every `UserPromptSubmit` — no command, no new surface, no runner. Foundational: every other learning candidate (items 7, 8) depends on retrieval working.
- **Risk:** Low. Broadening search paths cannot deny or mutate anything; worst case is slightly higher injection latency, already bounded by the 3000ms memory timeout. Scope `features/` to summary files (not raw `exploration/` dumps) to avoid noise. *Note:* `vector-search.sh` carries the same dead `.devloop` path (lines 362–365, 535–539) — flag for a consistency follow-up; out of this item's declared scope.
- **Effort:** M

### 2. Real LSP/diagnostics grader for the review-evaluator non-UI branch

- **Target (existing):** `plugins/loom-orchestrator/skills/review-evaluator/SKILL.md`
- **Behavior change:** Replace the non-UI branch's automatic pass-with-caveat with a grader that runs `mcp__ide__getDiagnostics` / native LSP over changed files and **fails the Functionality rubric item** on type/diagnostic errors, degrading to a scoped build/typecheck run when no language server is connected.
- **Justification (dev value + pattern):** **VERIFIED placeholder** (SKILL.md lines 33–37, 95–99) emits `pass-with-caveat` for any non-UI surface, giving most backend/library work a free pass through `/review-team`'s 4th, load-bearing reviewer right before `/git-push`. Brings **Crush/Cursor LSP-as-default-context** and the **Cursor Bugbot verify-the-fix** posture into the evaluator. **Why machinery, not a user tool:** the evaluator's internal grading branch is invoked automatically by `/review-team` — never by the user — over the already-present native IDE-diagnostics surface, not a new MCP server.
- **Risk:** Low–medium. Native LSP/diagnostics may be unavailable in headless contexts; the build/typecheck fallback must itself fail open to a clearly labeled caveat rather than hard-blocking when no toolchain is detected, so it never becomes a phantom gate. No identity exposure (native surface).
- **Effort:** M

### 3. "Prove the rubric green in-context" as a worker-completion contract

- **Target (existing):** `plugins/loom-orchestrator/skills/swarm-implement/SKILL.md` (and the `team-orchestration` quality-gates section)
- **Behavior change:** Add a completion precondition to every task worker's `brief.md`: the worker MUST run its rubric's tests/build in its own context and paste the green evidence into `result.md` before it may set `status:passed`; a red result forces a **bounded** in-worker fix loop. `/review-team` remains the independent second gate.
- **Justification (dev value + pattern):** **VERIFIED gap** — swarm-implement verifies the rubric only AFTER the worker returns (step 7, lines 143–153), and `result.md` status can be set with nothing actually run. This is the **Cursor Bugbot prove-green** pattern framed as a worker contract, not a command. **Why machinery, not a user tool:** a completion contract embedded in the `brief.md` the orchestrator already writes, plus a gating rule on the existing `result.md` artifact — not a user-invokable verifier. Operationalizes **Principle II (Test-First)** at the worker boundary automatically, for every dispatched task.
- **Risk:** Low. A text gate, consistent with the harness's "floor not sandbox" stance — a worker could paste false evidence, but item 2's LSP grader and `/review-team` are the independent second gate. The in-worker fix loop must be bounded (max attempts) to avoid runaway context spend.
- **Effort:** S

---

## Medium priority

### 4. Kahn wave-parallel dispatch in swarm-implement

- **Target (existing):** `plugins/loom-orchestrator/skills/swarm-implement/SKILL.md`
- **Behavior change:** Replace step 5's "execute sequentially" with Kahn-style wave scheduling: group tasks whose `depends_on` are satisfied into a wave, dispatch the wave as multiple Task calls in ONE message (native parallel-subagent primitive), barrier on all returns before the next wave. Applies automatically to every sprint with independent tasks.
- **Justification (dev value + pattern):** **VERIFIED** as the explicit v0.2 deferred item (SKILL.md lines 90–91, 212–218); the DAG parse, one-task-one-owner check, and freeze hook were built to support it. Brings **Crush/Cursor build-in-parallel** (auto-fan independent work). **Why machinery, not a user tool:** the scheduler step of an existing skill, driven by existing `depends_on` edges, riding on native parallel Task calls — no runner, process-manager, or swarm-state file. Completes designed-in machinery; large sprint wall-clock win.
- **Risk:** Medium. **CAVEAT:** the freeze hook reads a single `.loom-active-feature` marker, so wave parallelism loosens enforcement from per-task to per-wave — disjointness is guaranteed at plan-parse, not re-checked at the hook. The marker schema must either carry **per-task `owns` scopes** or the change must explicitly document the looser per-wave guarantee. Pairs naturally with item 9. Glob overlap detection is still literal-string (`src/**` vs `src/auth/**` pass the conflict check), so wave grouping inherits that gap — call it out at apply-time.
- **Effort:** L

### 5. Ranked repo-map grounding in brief.md / slice charters

- **Target (existing):** `plugins/loom-orchestrator/skills/swarm-implement/SKILL.md` and `plugins/loom-orchestrator/skills/swarm-explore/SKILL.md`
- **Behavior change:** Before dispatch, compute a compact ranked file/symbol skeleton over the task's touch-set (`owns` scope for implement; entry-point area for explore) using native Grep/Read plus ctags/tree-sitter via Bash, and embed it in `brief.md` / the slice charter. Auto-generated for every dispatched worker. (Absorbs the swarm-explore-only and worker-brief duplicate variants.)
- **Justification (dev value + pattern):** **VERIFIED** — `brief.md` carries only description/owns/freeze/rubric and swarm-explore hands free-form "suggested entry points," so workers rediscover structure by blind grep. Brings **Aider's tree-sitter+PageRank repo-map** as default grounding and **Crush's codebase-index**. **Why machinery, not a user tool:** an auto-generated artifact folded into the brief/charter the orchestrator already writes — not a command. Rides on native Grep/Read (+ctags via Bash) for the actual reads, adding only ranking. Raises first-try correctness on unfamiliar code.
- **Risk:** Medium. Keep it a **LIGHT** ranked skeleton (signatures, size-capped, graceful fallback when ctags/tree-sitter absent), **NOT** a full PageRank index, to stay clear of reimplementing native codebase search. Cap to avoid brief-prompt bloat.
- **Effort:** M

### 6. context-cap-warn → dependency-preserving compaction handoff *(protected file)*

- **Target (existing):** `.claude/hooks/context-cap-warn.sh`
- **Behavior change:** Turn the emitted free-text advice into a **structured handoff**: head (active goal + constitution pointer) and tail (recent turns) flagged preserve-verbatim, plus the active plan-as-DAG `depends_on`/`owns`/completed-vs-pending edges read from `.loom-active-feature` + `plan.md`, so a post-reset agent still knows what blocks what and which scope it owns. Middle-summary directed to the cheap MEMORY/haiku tier.
- **Justification (dev value + pattern):** **VERIFIED free-text today** (lines 100–106; reads no DAG state). Brings **humanlayer ace-fca** dependency-preserving compaction (keeps "A blocks B" edges across summary boundaries) + **Hermes** head/tail protection. **Why machinery, not a user tool:** the existing context-boundary hook's emitted schema, fired automatically at the cap — not a command. Augments (does not replace) native compaction by guaranteeing DAG structure that native compaction would flatten, reading state files the harness already maintains.
- **Risk:** Medium. **Edits a protected governance file** — must be PROPOSED for main-agent approval, not silent. Only changes WHAT fires; the pre-existing, unreliable token trigger (lines 100–106) is out of scope and not improved here.
- **Effort:** M

### 7. Living "Field Notes" in domain briefs, fed by /retro

- **Target (existing):** `plugins/loom-governance/domain-briefs/` (the 7 briefs), `.logic-loom/scripts/bash/common.sh` (`get_domain_brief`), `plugins/loom-orchestrator/skills/retro/SKILL.md`
- **Behavior change:** Add a bounded `## Field Notes` section to each domain brief and have `/retro` append domain-scoped, dated lessons there (capped at N, oldest pruned). Every future swarm/team worker in that domain inherits the gotcha automatically through the brief channel it already reads.
- **Justification (dev value + pattern):** **VERIFIED zero-parser-change** — `get_domain_brief` (common.sh lines 589–590, `awk '/^## Task Brief/{f=1;next} f'`) emits everything from `## Task Brief` to EOF, so a trailing section is auto-included with no parser edit. This is the **only** learning channel that reaches subagents (workers do not receive the main-agent preflight memory injection). Brings **Hermes** cross-session learning + **OpenHands microagents** at the worker channel. **Why machinery, not a user tool:** enriches an existing registry payload an existing function already injects; `/retro` (existing skill) is the writer. `domain-briefs/` is NOT in the protected surface (only `loom-governance/hooks/` is), so `/retro` writes are unblocked.
- **Risk:** Low. **Mandatory hard cap (N, oldest-pruned)** to avoid bloating every worker prompt. Identity-safe.
- **Effort:** S

---

## Low priority

### 8. Failure-mode / fix-recipe in the worker-completion contract

- **Target (existing):** `plugins/loom-orchestrator/skills/swarm-implement/SKILL.md`, `plugins/loom-orchestrator/skills/retro/SKILL.md`
- **Behavior change:** Extend the `result.md` contract so a worker records a lightweight `## Fix recipes` block (symptom → root cause → fix) for any rubric predicate that started red, and have `/retro` read those directly to produce tagged lessons instead of reconstructing from git/directory-name archaeology.
- **Justification (dev value + pattern):** **VERIFIED** — `result.md` captures only status/rubric/diff (lines 152–153, 183) and `/retro` reconstructs attempts from directory-name heuristics. Brings **Cursor Bugbot** fix capture + the **Hermes** learning loop (the input-quality half that feeds item 7). **Why machinery, not a user tool:** extends the `result.md` completion contract embedded in every worker brief plus an existing skill's input list — rides the existing per-task `sprints/<NN>/<id>/` artifact channel, explicitly **NOT** a new shared swarm-state file.
- **Risk:** Low. Must stay **QUALITATIVE** (symptom/cause/fix) — never metrics/dashboards — to respect the removed-RL-telemetry boundary. Emit **only-on-red** to limit verbosity.
- **Effort:** S

### 9. Per-task typed produces/consumes artifact edges

- **Target (existing):** `.logic-loom/templates/plan-template.md`, `plugins/loom-orchestrator/skills/swarm-implement/SKILL.md`
- **Behavior change:** Tasks gain optional typed `produces:` (artifacts/interfaces a task emits, e.g. `api-contract: src/auth/types.ts#LoginRequest`) and `consumes:` (refs to upstream `produces`). swarm-implement step 6 resolves each `consumes` ref against the completed upstream task's `produces` and embeds the concrete interface in `brief.md`; unresolved refs **warn, not block**.
- **Justification (dev value + pattern):** **VERIFIED** — plan-template has only `depends_on`/`owns`/`freeze`/`rubric` (no typed payload); `depends_on` merely orders tasks, so a dependent re-derives the upstream API by grepping. Brings **Aider's repo-map** to cross-task interface handoff; in-grain with **Principle III (Contract-First)**. **Why machinery, not a user tool:** extends the existing DAG schema and the existing `brief.md` construction — automatic per dependent dispatch, no command, no runner. Distinct from item 5 (cross-task *interface* handoff vs existing-code *structure*).
- **Risk:** Low. Optional + warn-not-block keeps legacy plans parsing unchanged. Synergy with item 4: typed `produces` could supply the per-task scope the wave scheduler's marker needs.
- **Effort:** M

### 10. Symbol-neighborhood injection in governance-preflight *(protected file)*

- **Target (existing):** `.claude/hooks/user-prompt-submit/governance-preflight.sh`
- **Behavior change:** Add a step that scans the prompt for explicit file paths and resolvable symbol identifiers and injects a compact symbol-neighborhood (definition location, signature, top references via ctags/Grep, LSP when available) into the same `additionalContext` channel, gated behind the existing min-query-length + timeout guards.
- **Justification (dev value + pattern):** **VERIFIED distinct consumer** — preflight fires on every `UserPromptSubmit` including plan mode, so this is the **only** way to ground the MAIN agent and the native planner before any Task is dispatched (plan mode has no skill to edit). Brings **Crush/Cursor LSP-as-context** + **OpenHands keyword-injection**, generalized to path/symbol. **Why machinery, not a user tool:** extends an existing automatic hook reusing its existing `additionalContext`/timeout/min-length machinery — no command, no plugin.
- **Risk:** Medium. **CAVEATS:** protected governance file (propose, not silent); require path-like/CamelCase tokens that resolve to a real definition before injecting, to avoid false positives and interactive latency on every prompt.
- **Effort:** M

### 11. Generalize domains.conf into a microagent trigger table *(protected file)*

- **Target (existing):** `plugins/loom-orchestrator-hook/config/domains.conf`, `.claude/hooks/user-prompt-submit/governance-preflight.sh`, `plugins/loom-governance/domain-briefs/`
- **Behavior change:** Extend the `keyword=domain` format (and the `detect_domains` parser) to also map a trigger → an arbitrary project-knowledge brief in the same registry (e.g. `migration=migration-runbook`, `freeze=freeze-marker-gotchas`), via the same injection path and registry. Project-specific landmines surface exactly when the relevant topic is engaged.
- **Justification (dev value + pattern):** **VERIFIED** — `domains.conf` is strictly `keyword=one-of-7-domains` and `get_domain_brief` already forms a keyword→brief pipeline (common.sh line 589). This is the **OpenHands microagent** pattern = that pipeline with the value side generalized — additional rows + brief files in an existing automatic injection. **Why machinery, not a user tool:** no command, no plugin; rides the existing preflight injection. Distinct from item 7 (curated mechanism vs retro-fed content).
- **Risk:** Medium. **CAVEATS:** protected preflight file (propose); keyword triggers need specificity to avoid over-firing; v1 keyword-only (path-glob triggering is a follow-on). Lowest rank — real but speculative, with a manual curation burden.
- **Effort:** M

---

## Explicitly NOT doing

**Machinery, not tools — the core correction.** This effort improves how the *existing* harness behaves; it does **not** add anything a user authors and drops in. The following are refused outright and were not proposed:

- **New standalone user skills / commands / plugins** — the owner-rejected core error this proposal exists to avoid. Every item above edits an existing system; none introduces a user-invokable surface.
- **Provider-portable orchestration / multi-provider gateways / ACP multi-harness clients** — breaks the Anthropic-native identity. (Cross-provider models remain confined to the delegated `/research` layer only.)
- **Execution sandboxing** — owner-rejected: a terminal-native dev harness must not cage the model's execution.
- **Governance/workflow-OPS add-ons** — risk-tier confirmation classifier and pre-flight cost preview: owner-rejected, not development-focused.
- **Role personas, vote-until-unanimous councils, a bespoke SDK, chat-ops gateways, embedded dashboards.**
- **Reimplementing native orchestration** — no custom engine, runner, process-manager, session-multiplexer, or shared swarm-state file. Items 4, 5, 8 explicitly ride native Task fan-out and the existing per-task artifact channel instead.

**Already have (not re-proposed):** native agent loop / subagent fan-out / plan-mode / checkpoint-rewind / compaction / MCP client / permission-modes / cost-telemetry; LogicLoom's governance hooks, plan-as-DAG freeze, `/review-team`, loom-memory, `/retro`, the domain-brief registry, and worktree port-namespace.

**Killed during ranking (de-duplicated or identity-conflicting):** the architect/cheap-editor split (scaffolding-for-weak-model, against the flagship-Opus identity and Principle X); contract-gated parallel scaffolding in full-stack-feature (no freeze marker → reintroduces the collision risk the DAG ownership design prevents); plan-authored symbol "anchors" (weaker duplicate of item 5); typed machine-verifiable rubric predicates (heavier duplicate of item 3); and four other entries that duplicate items 1, 5, 7, or 11.

---

## Recommended sequence

Ordered to start with the **highest dev-value, lowest-risk** item and to respect inter-item dependencies. Nothing proceeds without approval; protected-file items carry a second main-agent gate at apply-time.

1. **Item 1 — memory search-path fix** (High, M, low-risk). Foundational: it is a pure search-path edit that cannot deny or mutate anything, and it unblocks the retrieval side of the learning loop that items 7 and 8 feed. Start here.
2. **Item 3 — prove-green worker contract** (High, S, low-risk). Establishes the `result.md` completion contract that item 8 extends; operationalizes Principle II immediately.
3. **Item 2 — evaluator LSP grader** (High, M). Closes the largest quality hole before `/git-push` and complements item 3 as the independent second gate.
4. **Item 7 — Field Notes in domain briefs** (Medium, S, zero-parser-change). With retrieval fixed (item 1), light up the only learning channel that reaches workers.
5. **Item 8 — fix-recipe capture** (Low, S). Extends item 3's `result.md` contract and supplies the input quality for item 7's Field Notes — sequence it right after both.
6. **Item 5 — repo-map grounding** (Medium, M). Independent grounding win; raises first-try correctness for every dispatched worker.
7. **Item 9 — typed produces/consumes edges** (Low, M). DAG-schema extension that also prepares the per-task scope payload item 4 needs.
8. **Item 4 — Kahn wave-parallel dispatch** (Medium, L). Largest wall-clock win, but the heaviest and the one with the freeze-marker caveat — best attempted after item 9 has enriched the marker/DAG schema.
9. **Item 6 — context-cap compaction handoff** (Medium, M, protected). Reads DAG state the prior items already maintain; protected-file approval gate.
10. **Item 10 — symbol-neighborhood preflight** (Low, M, protected). Grounds the main agent / plan mode; latency-sensitive, protected file.
11. **Item 11 — microagent trigger table** (Low, M, protected). Most speculative, manual curation burden — last.