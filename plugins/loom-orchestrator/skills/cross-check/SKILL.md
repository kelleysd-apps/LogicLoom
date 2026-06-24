---
name: cross-check
version: 0.1.0
description: |
  The canonical governed cross-provider adversarial reviewer. A non-Claude model
  (Codex/GPT by default; Gemini/others pluggable) adversarially verifies a target
  (diff, plan.md, claim set, or file scope) and returns structured findings. The
  external model is an OPINION SOURCE, never an actor: it cannot write repo
  source, run git, or orchestrate — the governed Claude agent owns all
  remediation. Every adversarial / cross-check review in LogicLoom routes here.
allowed-tools: Read, Write, Bash, Grep, Glob, Task
triggers: ["cross-check", "adversarial review", "second opinion", "codex review"]
category: orchestration
constitutional_principles: [VI, X, XIV]
---

# Cross-Check Skill — Governed Cross-Provider Adversarial Review

## Why this exists (decorrelated failure modes)

`/review-team` and `/plan-review` are powerful but, by default, **Claude reviews
Claude** — generator and graders share a training lineage and therefore share
blind spots. A second model from a *different* lineage (OpenAI Codex/GPT,
Gemini) catches the class of defects correlated reviewers structurally miss.
That decorrelation is the entire value proposition; it is why this is worth more
than spawning another Claude reviewer.

This skill is the **single machinery** every adversarial / cross-check review in
LogicLoom routes through. It is invoked three ways:

- **Standalone** via `/cross-check <target>` (ad-hoc "have an outside model tear
  this apart").
- **As a reviewer slot in `/review-team`** (the external adversary, peer to
  security / quality / performance / behavioral-evaluator).
- **As an optional lens in `/plan-review`** (external-eng adversary on the plan
  DAG).

## Provider boundary (READ — this is what keeps it legal)

Cross-provider models are permitted in LogicLoom **only at the delegated
research / verification layer, never for orchestration** (see
`.logic-loom/config/models.conf`). Adversarial code review *is* verification, so
this slot is inside the boundary — **but only because the external model is held
strictly advisory and read-only.** The instant an external model writes repo
source, runs git, or makes a control-flow decision, it has crossed into
orchestration and violated the boundary (and Principle VI). The hard constraints
below are not optional polish; they are the boundary.

## Hard constraints (non-negotiable)

1. **Advisory only.** The external model emits findings. The **governed Claude
   main agent** triages and decides what (if anything) to change. The external
   model never edits code.
2. **No git, ever.** This slot never invokes git and never asks the external
   model to. (Principle VI.)
3. **Read-only.** In API mode the model only sees the artifact text you send it.
   In CLI mode it runs under the provider's read-only sandbox (see Mode B) and
   may NOT write or mutate the workspace.
4. **Writes only its own report.** The only filesystem write this skill performs
   is the findings artifact (`.docs/cross-check/.../` or the caller-supplied
   `--out` path). It never writes into repo source.
5. **Fail-open, never phantom-gate.** If the chosen provider's key is missing or
   its CLI is absent, do NOT hard-fail the review. Emit `overall_verdict:
   unavailable` with a labeled caveat and let the pipeline continue. An external
   adversary that cannot run must not block work (mirrors the evaluator's
   non-UI fail-open).

## Two invocation modes

### Mode A — API (default): artifact-scoped, zero agentic surface

Reuses the exact pattern `/research` uses for OpenAI/Gemini. A governed Claude
subagent reads `.env`, POSTs the **target artifact as text** to the provider's
API with an adversarial system prompt, and parses structured findings back. The
external model has no repo access, no tools, no hands — it sees only what you
hand it. This is the cleanest governance story and the default.

Use Mode A when the review target is a bounded artifact: a diff, a `plan.md`, a
`claims.json`, or a small file set you can include inline.

### Mode B — CLI (opt-in via `--deep`): read-only agentic exploration

For reviews that genuinely need repo-wide exploration (trace a call graph, read
neighbouring modules, reason about cross-file invariants), a governed Claude
subagent shells the provider CLI in a **read-only sandbox**:

```bash
codex exec --sandbox read-only --ask-for-approval never "<adversarial prompt>"
```

`--sandbox read-only` lets Codex navigate and reason over the repo but blocks all
writes and command side effects; `--ask-for-approval never` keeps it
non-interactive. The subagent captures stdout and converts it to the findings
schema.

> **New trust assumption (documented in
> `.docs/architecture/governance-threat-model.md`).** In Mode B the external CLI
> runs as a *subprocess*, which LogicLoom's Bash hooks cannot see into
> (interpreter/subprocess indirection is a known residual bypass). You are
> therefore trusting **the provider's `--sandbox read-only` flag**, not
> LogicLoom's hooks, to keep the run read-only. This is acceptable for an
> advisory read-only adversary and is why Mode B is opt-in, not default. Never
> run the provider CLI in a write-capable sandbox (`workspace-write`,
> `danger-full-access`) from this slot.

If the CLI is not installed, degrade to Mode A automatically (and note it).

## Generalized provider selection

Default provider is **Codex/OpenAI** (`--provider codex`). The slot is
provider-pluggable, mirroring the existing OpenAI+Gemini research posture:

| `--provider` | Mode A endpoint | Mode B CLI | Key (`.env`) |
|---|---|---|---|
| `codex` / `openai` (default) | `https://api.openai.com/v1/chat/completions` | `codex exec --sandbox read-only` | `OPENAI_API_KEY` |
| `gemini` | `https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent` | `gemini` CLI read-only (if installed; else Mode A) | `GEMINI_API_KEY` |

Model is a tier-style indirection, not a pinned string (Principle XIV): default
to a current coding-grade model for the provider, overridable via
`CROSS_CHECK_OPENAI_MODEL` / `CROSS_CHECK_GEMINI_MODEL` in `.env`. Pick the
provider whose lineage is *most decorrelated* from the generator — for
Claude-authored code, Codex/GPT is the strong default.

## Procedure

1. **Parse arguments** (see Configuration). Resolve `target`, `--provider`,
   `--mode`/`--deep`, `--out`, `--focus`.
2. **Resolve the target artifact.**
   - Diff (default): `git diff --name-only main...HEAD` for scope, plus the
     unified diff via `git diff main...HEAD` (read-only — *reading* git state is
     fine; this slot never mutates git).
   - Plan: the path passed (e.g. `features/<x>/plan.md`).
   - Claims: a `claims.json` path.
   - Files: an explicit glob/path list.
3. **Key/CLI gate (fail-open).** Confirm the provider's key exists in `.env`
   (Mode A) or its CLI is installed (Mode B). If neither is available, write an
   `unavailable` report per Hard Constraint 5 and STOP without error.
4. **Spawn one governed subagent** via the Task tool to run the external model:
   - **Mode A**: subagent sources the key from `.env`, POSTs the artifact with
     the adversarial system prompt below, parses the JSON findings.
   - **Mode B**: subagent runs the read-only CLI with the adversarial prompt,
     captures stdout, converts it to the findings schema.
   (Delegating via Task keeps key handling and the external call out of the main
   agent's context — Principle X.)
5. **Adjudicate (Claude, main agent).** Read the returned findings. The external
   model is fallible: for each finding, the governed agent assigns a
   `triage` of `accept | reject | needs-investigation` with a one-line reason.
   This is the decorrelation payoff *and* the false-positive filter — an external
   opinion never auto-becomes truth.
6. **Write the report** to the resolved output path (Principle XV: ensure the
   parent dir exists first). Print the verdict + path; do not echo the full
   report.

### Adversarial system prompt (the external model's instructions)

> You are an adversarial code reviewer from a different model lineage than the
> author. Your job is to find what is WRONG — correctness bugs, security holes,
> race conditions, unhandled edge cases, spec deviations, and design traps the
> original author likely rationalized. Be specific and skeptical; default to
> flagging when uncertain rather than rubber-stamping. For every issue give:
> severity, a precise `file:line` location, the concrete failure it causes, your
> confidence (0.50–0.99), and a suggested fix. Do NOT praise. Do NOT propose to
> edit the code yourself — you are advisory. Return ONLY the JSON findings
> object described below.

## Findings schema

The subagent returns, and the report embeds, this object (mirrors the tribunal /
evaluator shapes so `/review-team` and `/plan-review` can ingest it):

```json
{
  "reviewer_id": "cross-check-<provider>",
  "provider": "codex | openai | gemini",
  "mode": "api | cli",
  "target": "<diff main...HEAD | path | claims.json>",
  "review_date": "<YYYY-MM-DD>",
  "overall_verdict": "pass | concern | fail | unavailable",
  "findings": [
    {
      "id": "X01",
      "severity": "critical | high | medium | low | nit",
      "category": "correctness | security | performance | design | maintainability | spec-deviation",
      "location": "path/to/file.ext:line",
      "claim": "Specific thing that is wrong",
      "rationale": "Why it fails / the concrete failure mode",
      "confidence": 0.85,
      "suggested_fix": "Advisory remediation (Claude decides whether to apply)",
      "triage": "accept | reject | needs-investigation (filled by the governed Claude agent in step 5)"
    }
  ]
}
```

**`overall_verdict` derivation** (before Claude triage): any `critical`/`high`
finding → `fail`; else any `medium` → `concern`; else `pass`; provider couldn't
run → `unavailable`.

**The cross-check verdict is a peer signal, NOT a hard gate.** Unlike the
behavioral evaluator's Functionality item (deterministic behavioral truth), a
cross-provider opinion is probabilistic and can false-positive. It therefore does
**not** unilaterally block a `/review-team` verdict — it feeds synthesis, and the
governed Claude agent's post-triage `accept`ed criticals are what carry weight.
This keeps decision authority with the governed runtime (the orchestration
boundary) and stops an external model's false positive from halting the pipeline.

## Output format

Write `<out>/cross-check-report.md` (and `<out>/findings.json` with the raw
object). Default `<out>` is `.docs/cross-check/YYYYMMDD-HHMMSS-<scope-slug>/`.

```markdown
# Cross-Check Report — <target>

- Date: <YYYY-MM-DD>
- Provider: codex | openai | gemini   (mode: api | cli)
- Lineage decorrelation: <generator model> vs <reviewer model>
- Overall verdict: pass | concern | fail | unavailable

## Summary

<2-4 sentences. If unavailable, state the labeled caveat and why.>

## Findings (post-triage)

| ID | Sev | Category | Location | Claim | Conf | Triage (Claude) |
|----|-----|----------|----------|-------|------|-----------------|
| X01 | high | correctness | foo.ts:42 | ... | 0.86 | accept — real off-by-one |

## Accepted criticals (require action)

- [ ] <accepted critical/high finding, with file:line>

## Rejected / investigate (rationale)

- X0n rejected — <why the governed agent disagrees with the external model>
```

## Configuration

**Arguments:**

- `<target>` (positional, default `diff`): `diff` (current branch vs `main`), a
  file/glob path, a `plan.md` path, or a `claims.json` path.
- `--provider {codex|openai|gemini}` (default `codex`): which external lineage.
- `--mode {api|cli}` (default `api`) or `--deep` (alias for `--mode cli`):
  artifact-scoped API vs read-only agentic CLI.
- `--focus <area>` (optional): bias the adversary (e.g. `security`,
  `concurrency`, `spec-deviation`).
- `--out <path>` (optional): write the report here instead of the default
  `.docs/cross-check/...` dir. Callers (`/review-team`, `/plan-review`) pass this
  to fold the slot into their own artifact tree.

**Keys (`.env`, gitignored):** `OPENAI_API_KEY` for `codex`/`openai`;
`GEMINI_API_KEY` for `gemini`. Optional model overrides:
`CROSS_CHECK_OPENAI_MODEL`, `CROSS_CHECK_GEMINI_MODEL`.

**Data-governance note:** Mode A sends the target artifact (your diff/plan) to
the external provider's API. For private code, treat enabling a provider as an
explicit data-sharing decision — it is key-gated and off by default for exactly
this reason. Downstream/customer copies inherit this opt-in posture.

## Constitutional alignment

- **Principle VI (Git Approval):** this slot never invokes git and the external
  model is structurally barred from it (advisory + read-only).
- **Principle X (Agent Delegation):** the external call is delegated to a Task
  subagent for context isolation and key hygiene; the main agent only
  coordinates and adjudicates.
- **Principle XIV (AI Model Selection / Provider Boundary):** cross-provider use
  is confined to the verification layer and held advisory — never orchestration;
  models are tier/override indirection, not pinned strings.
