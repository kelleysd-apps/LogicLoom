# Design: shipping the escalation ladder, with a configurable (possibly non-Claude) worker

**Feature**: `escalation-advisor` · **Type**: exploration / design · **Date**: 2026-10-03
**Inputs**: `features/escalation-advisor/vision.md`; the maintainer's personal config
(`~/.claude/CLAUDE.md`, `~/.claude/hooks/*.sh`, `~/.claude/settings.json`); the kori-beta
hand-port; four settled maintainer decisions (restated in §0.1).

---

## Summary for the business owner (one sentence each)

- Today the harness slows down for a risky change only if the AI happens to feel cautious; this adds a fixed scorecard that decides how much checking a piece of work gets.
- The scorecard asks two questions: "if this is wrong, what does it cost to undo?" and "how many places does it touch?", and the sum picks one of four levels of review.
- The owner's personal version of this scorecard already works in his own setup and in the kori project; this design makes it a standard part of LogicLoom that every project inherits.
- LogicLoom will ship the scorecard, a built-in "devil's advocate" reviewer, and named roles for the planner, the reviewer and the worker, without forcing any particular AI brand into those roles.
- The biggest change is that a project may now choose a non-Anthropic AI (for example OpenAI's Codex) as the worker that writes code, which the current rules forbid.
- The recommended way to do that keeps the safety net: the outside AI drafts changes in a disposable copy, and a supervised Claude helper copies only the approved changes into the real project, so every real write still passes the existing guardrails.
- What is given up is that the guardrails cannot watch the outside AI while it drafts, and the outside AI never reads LogicLoom's rulebook; the helper and a review step stand in for that.
- Cost is bounded: the lowest level adds no extra AI calls, the highest adds about six, and reviews run once per phase rather than once per file.
- The first version is documents plus two small agent files and can be built in three independent packages; the outside-worker mechanism and extras come after.
- Eight decisions need the owner's answer (section H); the recommended answer is listed first for each.

---

## 0. Ground truth

### 0.1 Settled decisions (from the maintainer, restated)
1. Ships in LogicLoom and stays in the personal config ("both").
2. WORKER is a configurable role; any model including non-Claude; default stays the Sonnet tier.
3. Cadence: rung sets reviewer effort, not frequency; one review per phase on the combined diff, except packages touching hooks, auth, payment, customer data or the governance floor.
4. Research given: one provider endpoint per Claude Code session; Anthropic does not support routing Claude Code to non-Claude models through any gateway; a gateway credential replaces subscription login with per-token billing; a subagent's `model:` may be any full model name (frontmatter or `CLAUDE_CODE_SUBAGENT_MODEL`); external CLIs are `codex exec -s read-only|workspace-write --skip-git-repo-check -c model_reasoning_effort=<level>` and `agy -p ... --sandbox --mode plan --effort <level>` (headless plan mode denies its own file reads); hooks cannot see inside a CLI subprocess.

### 0.2 The personal system as it exists
- Rubric: reversibility 0/1/3 plus +3 for auth/payment/customer-data (`~/.claude/CLAUDE.md:89-97`), width 0/1/2 (`:98-101`), rungs Light 0-1 / Standard 2-3 / Heavy 4-5 / Max 6+ (`:105-112`). Effort follows cost, fan-out follows width (`:114-131`). Direct CLI invocations with sandbox flags (`:146-157`). Same brief to every advisor; two agreeing reviewers = real (`:159-166`).
- "Mutation is always a worker's job" (`~/.claude/CLAUDE.md:68`) — personal; LogicLoom's vision REJECTS it (`vision.md:89-94`) because Principle X routes trivial work to direct execution (`constitution.md:158`).
- `orchestration-policy.sh` (UserPromptSubmit, wired at `~/.claude/settings.json` hooks.UserPromptSubmit[0]): one standing reminder — run the review at the rung you selected, name the rung and trigger when escalating. No policy text; it points at CLAUDE.md.
- `delegation-nudge.sh` (PreToolUse on `Task|Edit|Write|MultiEdit|NotebookEdit|Bash`, settings.json hooks.PreToolUse[0]): a consecutive-since-last-delegation counter (`:11-19`), threshold 5 (`:21-24`), modes observe/nudge/gate/off with `observe` default that emits nothing (`:26-36`), state in `$HOME/.claude/hooks/.state` (`:76`), fails open and never denies (`:38-42`). It is taste calibration, exactly as the vision says (`vision.md:82-83`).
- `settings.json`: `modelSettings.claude-opus-5.effortLevel = medium`; `env.ANTHROPIC_DEFAULT_SONNET_MODEL = claude-sonnet-5-5`; `outputStyle = "CTO Brief"`. No gateway (`ANTHROPIC_BASE_URL`) is set.

### 0.3 LogicLoom as it exists
- Provider boundary: `CLAUDE.md:35-44` ("never writes repo source, runs git, or makes a control-flow decision"), `models.conf:8-19` and `:66` ("never workers"), `CLAUDE.md:622-623` ("the ladder adds no non-Claude workers"), ladder doc `:115-127`, `constitution.md:229-232` (Principle XIV points at the CLAUDE.md note — a protected file).
- `models.conf` is documentary, parsed by nothing (`models.conf:1-6`, `model-selection-policy.md:32-38`). A parsed `effort-policy.conf` was rejected (ladder doc `:107-113`).
- The cadence rule (decision 3) is already written into the ladder doc at `:86-89` — in the working tree, uncommitted (`git status`: `M .docs/architecture/orchestrator-worker-ladder.md`).
- Project agents: `deep-reasoner.md:8-9` (opus, high), `fast-worker.md:8-9` (sonnet, medium). Static `effort:` only (`models.conf:56-60`).
- Cross-check: boundary `SKILL.md:38-47`; hard constraints `:49-66`; Mode B forbids `workspace-write` (`:119-127`); provider table `:136-139` (codex, gemini only). Slots: `review-team.md:19,24,28`, `plan-review.md:19`.
- Preflight verification nudge `governance-preflight.sh:199-214`; strict-mode "REVIEW DEPTH" `:229-238` already names a three-level depth. `.claude/hooks/` is protected — main agent ask (`CLAUDE.md:101`).
- Threat model residual #5 (cross-check Mode B trusts the provider sandbox) `governance-threat-model.md:208-218`; matrix `:446-455`; mandates are followed in every column `:462-466`.
- Tandem contract: Disposition verbatim in AGENTS.md Tier 1 and CLAUDE.md, asserted by `tests/contract/test_disposition_tandem.sh` (`AGENTS.md:21`).
- `freeze-write-scope.sh` default-allows outside an active DAG (`:10`, `:152`) — the gap the vision's "state ownership in the brief" rule covers (`vision.md:59-62`).

### 0.4 kori-beta hand-port (read-only)
- Mandate `ESCALATION-RUNG-REQUIRED` (`amendments.md:135-187`) uses the OLD scale: auth/payment is an alternative 3 (`:148`), so Max is unreachable there. Honest-limit paragraph `:180-187` says the Heavy/Max rungs degrade without a non-Claude key.
- `.claude/agents/advisor.md`: `model: fable`, `effort: medium`, Read/Grep/Glob only (`:10-15`); lineage note says it is not a cross-check (`:46-52`).
- `models.conf:50`: `LOOM_MODEL_ADVISOR = fable  # ... never a worker`; `:45` worker = sonnet.

### 0.5 Where this design departs from the vision (explicit)
- Cost scale: vision says "roughly 0/1/3/3" (`vision.md:45-46`); shipped scale is 0/1/3 **plus** +3, so Max (6+) is reachable. Reason: the maintainer's current scale.
- Non-Claude worker: vision item 4 defines only an ADVISOR role (`:54-56`) and its constraints say "the governance floor is unchanged" (`:109-110`). This design keeps the hook floor unchanged but **rewrites the provider boundary** (decision 2). The floor's scripts do not change; the sentence describing who may hold the pen does.
- Everything else in "What ships" (`:43-64`), "What this is NOT" (`:66-85`) and "Rejected options" (`:87-94`) is honoured; see §A.

---

## A. What ships

| Path | New/changed | Purpose | Status |
|---|---|---|---|
| `.docs/policies/escalation-policy.md` | NEW | Canonical text: rubric, rung table, cadence rule, three hygiene rules, orthogonality to `governance.conf` lean/strict, re-grading mid-task, example roster marked EXAMPLE | FOLLOWED |
| `AGENTS.md` Tier 1 | changed | One short "Escalation Disposition" paragraph (score two axes, four rungs, announce at Standard+, apply twice) — host-neutral, sits beside the Cross-Check Disposition (`AGENTS.md:108-110`); plus Tier 2 registry row for `advisor` | FOLLOWED |
| `CLAUDE.md` Standing policies | changed | Same paragraph verbatim; "Model & provider boundary" (`:33-44`) and "Orchestrator + worker ladder" (`:599-626`) rewritten per §B.4 | FOLLOWED |
| `tests/contract/test_disposition_tandem.sh` | changed | Also asserts the Escalation Disposition paragraph is byte-identical in AGENTS.md, CLAUDE.md and the policy doc | ENFORCED (CI) |
| `.claude/agents/advisor.md` | NEW (project agent, not plugin — ladder doc `:143-146`) | Adversarial second opinion, Read/Grep/Glob, `effort: medium`, `model: inherit` (see H1); lineage note from kori `advisor.md:46-52` | FOLLOWED |
| `.logic-loom/config/models.conf` | changed | `LOOM_MODEL_ADVISOR = inherit`; `LOOM_MODEL_WORKER` comment gains "may name a non-Claude model via the external-worker mechanism"; line 66 and the boundary block `:8-19` rewritten; new documented env knobs `LOOM_EXTERNAL_WORKER_CLI`, `LOOM_EXTERNAL_WORKER_MODEL` (same pattern as `CROSS_CHECK_*`, `:85-96`). **Stays documentary.** | FOLLOWED |
| `.docs/architecture/orchestrator-worker-ladder.md` | changed | Ladder gains ADVISOR and external WORKER rows; "advisory boundary is unchanged" section (`:115-127`) rewritten | FOLLOWED |
| `.docs/architecture/governance-threat-model.md` | changed | New residual #6 (external worker drafts outside the hook floor) and a matrix footnote | FOLLOWED (doc) |
| `.logic-loom/memory/constitution.md:229-232` | changed (protected; main-agent ask) | Principle XIV one-sentence update; constitution v3.3.0 → v3.4.0 | FOLLOWED |
| `plugins/loom-orchestrator/skills/external-worker/SKILL.md` + `.claude/agents/external-worker.md` | NEW (v1.1) | Mechanism §B.2(ii): wrapper agent runs the external CLI in a scratch copy and applies the reviewed patch through Edit/Write | apply step ENFORCED by existing hooks; drafting step FOLLOWED |
| `plugins/loom-orchestrator/skills/cross-check/SKILL.md` + `tests/contract/test_shipped_skill_commands.sh` | changed (v1.1) | `--provider agy` row (Mode A-equivalent only: artifact inlined, no `--deep`); `--effort` passthrough to `codex -c model_reasoning_effort` / `agy --effort` | FOLLOWED |
| `.claude/hooks/user-prompt-submit/governance-preflight.sh` | changed (protected; main-agent ask; v1.1, see H4) | One lean-mode line: "Name the escalation rung before acting and re-score before done" — port of `orchestration-policy.sh` | delivered by hook, FOLLOWED by model |
| `plugins/loom-maintenance/updates/7.x/escalation-ladder.md` + `.check.sh` | NEW | The /update-loom improvement note (§D) | ENFORCED by note linter |
| delegation watcher hook | **not shipped** | Stays personal (`vision.md:82-83`); see H5 | — |

**Why models.conf stays documentation.** The rejection of `effort-policy.conf` (ladder `:107-113`) was: nothing enforces it, and an account-specific table is wrong for every cloner. Both still hold. What actually selects a model is agent frontmatter (`model:` accepts a full model name — §0.1 item 4) and, for the external worker, an env var read by a skill — the same runtime-knob pattern `/cross-check` already uses (`models.conf:94-96`). Making models.conf parsed would add a resolver nothing else needs and reopen the rejected design. It records; env and frontmatter decide.

**Rubric placement answers the vision's open question (`vision.md:114-117`).** Both AGENTS.md and CLAUDE.md, verbatim, extended tandem test — the Cross-Check Disposition precedent. Keep the Disposition paragraph short (under 12 lines); the long form lives in the policy doc.

---

## B. The non-Claude worker

### B.1 Three mechanisms

**(i) Gateway inside Claude Code** (customer runs an LLM gateway; `ANTHROPIC_BASE_URL` points at it; the gateway routes by model name so a subagent with `model: gpt-x` goes to OpenAI).
- Hooks see: everything — the harness is still Claude Code, so every Edit/Write/Bash passes PreToolUse. Hooks cannot tell which provider answered.
- Customer sets up: a gateway (LiteLLM-class), provider keys in it, an Anthropic API key (subscription login no longer applies), `ANTHROPIC_BASE_URL`.
- Billing: the **whole session** moves to per-token API billing, orchestrator included (§0.1 item 4).
- Failure modes: unsupported by Anthropic; one endpoint per session means the orchestrator rides the gateway too; a non-Claude model may not honour Claude's tool schema, so hook-visible tool calls can arrive malformed; a mis-route puts the orchestrator on a non-Claude model, which `ladder.md:42-44` forbids and this design keeps forbidding.
- Verdict: document as "possible, unsupported, not recommended"; ship nothing.

**(ii) External CLI subprocess under a Claude wrapper** (recommended).
1. Orchestrator dispatches `external-worker` (a Claude project agent, `sonnet`, tools Read/Write/Edit/Bash/Grep/Glob) with the normal brief plus `owns:` paths.
2. Wrapper builds a scratch copy of the repo in the session scratchpad with `rsync`, **excluding** `.git/`, `node_modules/`, `.env*`, and every path on `governance.conf protected_paths` (`governance.conf:23,69-70`) plus `.claude/hooks/`, `plugins/loom-governance/hooks/`, `settings.json`. No git command is run (so `subagent-git-guard` is not involved).
3. Wrapper runs `codex exec -s workspace-write --skip-git-repo-check -c model_reasoning_effort=<level> -m "${LOOM_EXTERNAL_WORKER_MODEL}" "<brief>" </dev/null` with cwd = scratch copy. The brief names the owned paths and says: write tests first, touch nothing else, emit no git.
4. Wrapper diffs scratch vs repo (`diff -ru`), **refuses** any hunk outside `owns:`, any protected path, any new file mode change, any binary, and any hunk touching a path that has changed in the real tree since the copy was made.
5. Wrapper applies accepted hunks through its own **Edit/Write** calls — so `freeze-write-scope.sh` and `protect-governance-files.sh` see every real write exactly as they would for a Claude worker.
6. Wrapper runs the owned tests, reports the diff summary, the refused hunks, and the external CLI's exit code; scratch copy deleted.
- Hooks see: steps 2, 5, 6 fully (Bash rsync/diff/test, every Edit/Write). Hooks do **not** see step 3 — same blind spot as cross-check Mode B (`threat-model.md:208-218`), with two differences: the blast radius is a disposable copy with secrets excluded, and no real write happens until step 5.
- Customer sets up: the CLI installed and logged in (its own subscription or key); `LOOM_EXTERNAL_WORKER_CLI=codex` and optional model in `.env`; nothing in `~/.claude/`.
- Billing: Claude subscription unchanged; the external provider bills the drafting tokens; the wrapper's Sonnet tokens are small (mechanical).
- Failure modes: CLI absent or non-zero exit → fail open to a Claude `fast-worker` and say so (mirrors `SKILL.md:129`); external model ignores the brief and edits outside scope → hunks refused, reported; scratch copy stale vs a concurrent worker → refused hunks; external sandbox network behaviour is provider-defined — verify before relying on it (grounding rule, `models.conf:99-119`).

**(iii) Separate session or profile per worker** (second terminal running Codex, or a second Claude Code profile pointed at a gateway, in its own worktree; the orchestrator writes a brief file; a human relays).
- Hooks see: nothing of the other session; a Codex session has no LogicLoom hooks at all (`threat-model.md:451`: followed-only).
- Customer sets up: two tools, two logins, worktree discipline; the human is the bus.
- Billing: two subscriptions or one subscription plus per-token.
- Failure modes: no automation; merge conflicts between worktrees land on the human; nothing records the rung.
- Verdict: document as the manual fallback; ship nothing.

### B.2 Recommendation
Default = **(ii)**. It is the only mechanism where every write to the real tree passes the existing PreToolUse floor, needs nothing in `~/.claude/`, leaves billing where the customer already has it, and fails open to today's Claude worker.

**Guarantee lost versus a Claude worker, stated plainly:** with a Claude worker, the model that *authors* the change is itself under the hook floor and reads the agent file's governance text (`fast-worker.md:27-30`) while authoring. With an external worker, authoring happens in an unobserved sandbox and the external model never reads LogicLoom's constitution; what the floor guarantees is only that **the result was reviewed and applied under the hooks**. Test-First (Principle II) becomes a wrapper check ("did tests arrive and pass?") rather than a worker habit. Decorrelation is also not a bonus here: the worker and a Codex cross-check would share a lineage, so a project running a Codex worker should point `/cross-check` at Gemini or Claude-reviews-external (§G).

### B.3 Rewritten boundary sentence (one text, four homes)
> **Model & provider boundary.** Three layers. **Orchestration** — the main session and every control-flow decision — is Claude-Code-native and runs Anthropic models only. **Verification** (`/research`, `/cross-check`) may use any provider, held advisory and read-only: it returns findings; a governed Claude agent triages. **Execution** — the WORKER role — may be filled by any model a project names, Claude by default; a non-Claude worker drafts in a disposable copy, and a governed Claude wrapper applies only the reviewed hunks through hook-visible tool calls. In every layer a non-Claude model never writes the real tree directly, never runs git, and never makes a control-flow decision.

Homes: `CLAUDE.md:35-44`; `models.conf:8-19` (and delete `:66` "never workers"); `constitution.md:229-232` (short pointer form); `governance-threat-model.md` residual #6 and a line under the matrix noting the external-worker apply step is ENFORCED on Claude Code only. `AGENTS.md` Tier 1 capability catalog gains an "External worker" entry mirroring the "Cross-check" entry (`AGENTS.md:117-120`).

---

## C. Reconciling with the personal config

**Identical in both (the shared block):** the two-axis rubric with the 0/1/3 (+3) and 0/1/2 scales; the four rungs and their thresholds; "score the work, not the subject"; "if the Standard advisor says the approach is wrong, move to Heavy"; "announce the rung and trigger at Standard+"; "apply twice — the second application is the one that gets skipped"; "two independent reviewers agreeing = real; disagreement surfaces both"; the cadence rule; "read the combined diff yourself"; "concurrent workers own non-overlapping files, stated in the brief". Each copy carries a first line `Escalation rubric v1.0 — canonical: LogicLoom .docs/policies/escalation-policy.md`.

**Stays personal (`~/.claude/CLAUDE.md` only):** the CTO persona and output style; "Mutation is always a worker's job" (`:68`, rejected by `vision.md:89`); the specific roster — Fable advisor, Sonnet workers (`:106-110`); the exact effort numbers per rung (`:114-131`) — LogicLoom ships them as an EXAMPLE in the ladder doc, never as a default; the raw CLI command lines with flags (`:151-152`) — inside a LogicLoom project they route through `/cross-check`, as `:146-148` already says; the delegation watcher.

**Drift detection — honest limits.** LogicLoom can test only its own three copies (AGENTS.md, CLAUDE.md, policy doc) — extend `test_disposition_tandem.sh`. It can never read or write `~/.claude/` (CLAUDE.md "Harness ↔ user boundary") and never reads another repo, so personal-vs-shipped and kori-vs-shipped drift is detected only by: (a) the version line — a mismatch is visible to any agent that reads both, and the shipped policy doc tells it to say so; (b) the maintainer's own reference-copy diff habit (CLAUDE.md "Versioning personal config"); (c) kori's `/update-loom` note (§D), which surfaces the overlap once. No automation across the three homes is proposed.

---

## D. Distribution

**Existing installs:** one `/update-loom` improvement note (`plugins/loom-maintenance/updates/7.x/escalation-ladder.md`, per `features/update-loom/exploration/design.md:24-25,55`) whose done-when is: policy doc present, `advisor.md` present, both Disposition paragraphs present, models.conf role lines present; its check greps the version line in all three in-repo copies.

**kori's hand-port.** Its mandate overlaps a shipped policy. By the composition rules (`AGENTS.md:92-105`) the effective rule is the stricter one; the shipped +3 scale is strictly tighter than kori's alternative-3 scale (`amendments.md:148`), so the mandate adds nothing once the note lands. Recommendation (H7): replace it with a true tightening — e.g. `Mandate: ESCALATION-FLOOR-STANDARD — Rule: any change under apps/mobile that reads or writes beta-tester data scores no lower than Standard` — and move the honest-limit paragraph (`:180-187`) to kori's own notes. kori's `advisor.md` (`model: fable`) and `models.conf:50` (`fable`) differ from the shipped `inherit`; the three-way engine will hold both as both-changed and the adapter will ask (update-loom design `:45`). Expected answer: keep kori's values.

---

## E. Cost per task, in agent calls

| Rung | Before starting | Before done | Agent calls added | Notes |
|---|---|---|---|---|
| Light | self-score | self-check | 0 | no advisor (`CLAUDE.md:105`) |
| Standard | 1 advisor | self-argue | 1 | advisor = one Task call |
| Heavy | 1 advisor + 1 `/cross-check` | 1 `/cross-check` | 3 (each `/cross-check` is one Task subagent + one external call, `SKILL.md:172-178`) | |
| Max | 1 advisor + 2 `/cross-check` (both providers) | 1 advisor + 2 `/cross-check` | 6, concurrent, inside workers | personal `:110-112` |

An external worker swaps one Claude worker call for one wrapper call — net zero agent calls; the drafting tokens move to the other provider's bill.

**How cadence bounds it.** Reviews are per phase on the combined diff, not per package: `N` packages in a phase cost one rung's review set, plus one extra set per sensitive package (hooks, auth, payment, customer data, governance floor). Worst case per phase = `rung_cost × (1 + sensitive_packages)`. A five-package Heavy phase with one hook package is 6 calls, not 15.

---

## F. Build order

**v1 — documents and two agent files; no hook, no skill code. Three non-overlapping packages:**
- **WP1 (policy text)** owns `.docs/policies/escalation-policy.md`, `AGENTS.md`, `CLAUDE.md`, `tests/contract/test_disposition_tandem.sh`. Writes the canonical block, both Disposition paragraphs, the Tier 2 registry row, the rewritten CLAUDE.md boundary and ladder sections, and the tandem assertion.
- **WP2 (roles)** owns `.claude/agents/advisor.md`, `.logic-loom/config/models.conf`, `.docs/architecture/orchestrator-worker-ladder.md`, `.docs/architecture/model-selection-policy.md`. Adds the advisor agent, role lines, external-worker env knobs (documented), ladder rows, EXAMPLE roster.
- **WP3 (boundary)** owns `.docs/architecture/governance-threat-model.md` and the single-sentence `constitution.md:229-232` edit (main agent applies it — protected, `CLAUDE.md:101`) plus the version bump sites for v3.4.0.

Scoring v1 itself: reversibility 1, width 1 (files move together) → Standard; WP3's constitution edit is still reversibility 1 but touches the governance surface, so give that package its own review (decision 3).

**v1.1:** external-worker skill + wrapper agent + a contract test with a planted out-of-scope hunk that must be refused; Antigravity provider row + `--effort` passthrough in `/cross-check`; the preflight reminder line (H4); the `/update-loom` note.

**Later / maybe never:** structured rung marker for counting; `/workflow` helper that maps rung → `agent()` effort; a Gemini-CLI external worker.

---

## G. Risks, ranked; and what is deliberately not built

1. **External worker ships unverified code.** The external model never reads the constitution; TDD becomes a wrapper assertion. Mitigation: wrapper refuses to apply when the owned tests are absent or fail; reviewer sees "authored by external worker" in the report.
2. **Secrets reach the external provider.** A scratch copy that includes `.env` sends keys to another vendor. Mitigation: exclusion list in §B.1(ii) step 2; wrapper fails closed if any excluded path exists in the copy.
3. **The ladder is decorative.** Followed-only (`threat-model.md:462-466` logic applies); an unannounced rung is invisible (`vision.md:34-35`). Mitigation: preflight reminder line (H4); reviewers are told to look for the rung line.
4. **Three-home drift.** Only the in-repo copies are testable (§C). Accepted.
5. **Lineage collapse.** A Codex worker plus a Codex cross-check is same-lineage review. Mitigation: policy doc says pick the adversary from a different lineage than the worker.
6. **Boundary rewrite reopens the orchestrator door.** A sloppy sentence lets "any model" leak into orchestration. Mitigation: the three-layer text in §B.3, with the orchestration sentence unchanged from `ladder.md:42-44`.
7. **Mode confusion** with `governance.conf` lean/strict (`vision.md:72-77`). Mitigation: a dedicated paragraph in the policy doc.
8. **Billing surprise.** External drafting costs appear on a second bill; the wrapper's report names the provider every time.

**Not built:** gateway routing or any `ANTHROPIC_BASE_URL` guidance beyond "unsupported"; a parsed models.conf resolver; the delegation watcher hook; a hook that auto-scores or blocks on rung; a per-rung advisor effort switch (static `effort:` only — Heavy/Max callers may use `deep-reasoner` at `high` or `/workflow agent()` effort, ladder `:61-66`); Antigravity Mode B (its headless plan mode cannot read files — §0.1); any write to `~/.claude/`; changes to any hook script other than the one reminder line.

---

## H. Decisions for the maintainer

1. **Advisor's shipped model.** (a) **Recommended:** `model: inherit` — no shipped opinion, the vision's rule (`vision.md:68-71`); the advisor runs on whatever the orchestrator runs on. (b) `opus` — a concrete default cloners can use without thinking. (c) `fable` as in kori — your roster becomes the default, which the vision forbids.
2. **Default worker mechanism for a non-Claude model.** (a) **Recommended:** external CLI under a Claude wrapper, patch applied through Edit/Write (§B.1 ii). (b) Document all three, ship no mechanism in v1.1; projects roll their own. (c) Gateway — unsupported, moves all billing; not advised.
3. **Antigravity as a third `/cross-check` provider.** (a) **Recommended:** v1.1, artifact-inlined only, no `--deep`. (b) v1 — adds skill-test work to a docs-only release. (c) Never; keep it personal.
4. **One reminder line in `governance-preflight.sh`** (protected file; you approve the edit). (a) **Recommended:** yes, lean mode, one sentence. (b) No — rely on CLAUDE.md alone.
5. **Delegation watcher hook.** (a) **Recommended:** stays personal, not shipped. (b) Ship disabled with a documented toggle (`vision.md:82-83` allows it).
6. **Constitution XIV wording** (`:229-232`). (a) **Recommended:** one-sentence update, v3.4.0, main agent edits with your approval. (b) Leave the constitution and change only CLAUDE.md — the constitution would then point at a note that contradicts it.
7. **kori's mandate.** (a) **Recommended:** replace with a tightening-only mandate (§D) when the note lands. (b) Keep as-is; accept a redundant, older-scale duplicate.
8. **Rung announcement shape** (`vision.md:125-126`). (a) **Recommended:** plain sentence with a fixed prefix, `Rung: Heavy — migration cannot be reverted`, greppable but prose. (b) Free prose. (c) Structured marker (defer until something counts it).

---

## Could not verify
- Codex `workspace-write` network behaviour and whether `--skip-git-repo-check` is accepted alongside `-s workspace-write` on the installed version — check `codex exec --help` before WP4 (grounding rule, `models.conf:99-119`).
- Whether `CLAUDE_CODE_SUBAGENT_MODEL` or frontmatter `model:` accepts a non-Anthropic model id end-to-end without a gateway — taken as given from the session's research (§0.1 item 4), not re-tested here.

---

## Addendum 2026-10-04 — Claude Code mods (not yet reflected above)

Written before mods (Claude Code >= 2.1.287) were reviewed. Per Anthropic's
docs a mod can intercept each model request, including a subagent's
(`turn.step`, `e.agentId`), send it to another model or answer it itself, hold
a tool call and ask the user, and report per-request token use. If a pending
proof holds, the non-Claude worker (section B) could run INSIDE Claude Code's
tool loop with hooks seeing every edit, replacing the external-CLI wrapper as
the default; role-to-model routing and parts of the ladder could be enforced
rather than followed. Also new: an installed mod can override a project
`PreToolUse` hook — a threat-model change. Decisions 2, 4, 5 and 8 wait on the
proof. Docs: https://code.claude.com/docs/en/plugins/mods/overview

## Addendum 2026-10-04 — Orca as an external-worker runner (deferred)

Orca (installed locally, `orca` CLI) can host the non-Claude worker pattern:
a Claude Code coordinator dispatches tasks to Codex or Claude sessions, each in
its own Orca-managed worktree, with a mailbox, blocking ask, decision gates
and supervised workers. Codex keeps its full agent loop there (edits, runs
tests, retries). Trade-off versus the mod mechanism: LogicLoom's hooks see the
work only at review and merge, not per edit. Maintainer decision 2026-10-04:
try it later, after the Codex bake-off result. Aside (an agentic web browser)
was evaluated and does not fit this use.
