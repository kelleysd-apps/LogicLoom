# Governance Threat Model & Enforcement Posture

**Status:** v6.3.0 · **Scope:** the hook-enforced governance core.

LogicLoom's governance is **hook-enforced** (model-independent), but hooks are a
**porous floor, not a sandbox**. This document states honestly what the
enforcement layer does and does **not** cover, so governance is never
mis-marketed as airtight (cf. Claude Code RFC #45427, which documents PreToolUse
bypass modes that Anthropic declined to close in-CLI — the hardening burden is
the harness author's).

## Defense-in-depth layers

Governance is one layer among several; rely on the stack, not any single gate:

1. **Permissions** (allow/deny/ask in settings) — coarse daily policy.
2. **PreToolUse hooks** (this layer) — deterministic, model-independent policy at the tool boundary.
3. **MCP allowlists** — tool-surface governance.
4. **Sandboxing** (NOT yet a LogicLoom layer — see Residual #4) — blast-radius limit.
5. **Audit/observability** — evidence (`governance-preflight` audit log).
6. **PR / CI review** — the human release boundary.

## The hooks (what each enforces)

| Hook | Matcher | Enforces |
|---|---|---|
| `subagent-git-guard.sh` | PreToolUse·Bash | Denies ANY git from a subagent (`agent_id` present). |
| `git-safety-gate.sh` | PreToolUse·Bash | Main-agent git mutations → `ask`. |
| `protect-governance-files.sh` | PreToolUse·Write/Edit + Bash | Edits to the governance surface (`.claude/hooks/`, `settings.json`, `constitution.md`, `governance.conf`, `loom-governance/hooks/`) → subagent `deny` / main `ask`. Stops the model softening its own rules. |
| `guard-dangerous-commands.sh` | PreToolUse·Bash | Policy-based dangerous-command blocking (bash 4+; fails open on 3.2). |
| `freeze-write-scope.sh` | PreToolUse·Write/Edit | Plan-as-DAG file-ownership; paths canonicalized (`realpath`) so `..`/symlink/`//` cannot escape the `owns:` scope. |
| `governance-preflight.sh` | UserPromptSubmit | Domain briefs + memory; strict-mode recitation. |

## Detection model

A subagent's tool call carries an `agent_id` (and `agent_type`) in the
PreToolUse payload; the main agent's does not. This is the basis for
"subagent → deny, main → ask" and is **empirically verified** (not documented
contract) — re-verify if a future Claude Code version changes the field.

## Residual bypass surface (KNOWN — not closed)

These are inherent to string-level gating over a shell. They are documented, not
hidden; close them with the defense-in-depth stack above, not by trusting hooks.

1. **Interpreter / eval indirection.** `python -c "subprocess git…"`,
   `bash some-script.sh` (git/write inside the script), `eval "$cmd"`, variable
   indirection (`G=git; $G push`) are invisible to a string gate. Out of scope by
   design for all Bash hooks.
2. **Bash write-path escape of the freeze DAG.** `freeze-write-scope` gates the
   `Write`/`Edit` tools. A worker can still write *outside its `owns:` scope* via
   Bash redirects (`cat > f`, `tee`, heredoc, `dd of=`). **Mitigation today:**
   `protect-governance-files` *does* cover Bash mutations for the protected
   governance paths specifically; and the freeze DAG is only active during
   `/swarm implement`. **Not yet closed** for arbitrary DAG-owned paths — a
   focused follow-up (extend freeze to a Bash matcher + redirect-target parsing).
3. **Silent hook failure.** A non-zero hook exit does not always block a tool
   call (esp. batched calls). Hooks here fail *open* on infra gaps deliberately
   (never block on a broken policy lib); that is a safety/availability trade.
4. **No execution sandbox.** `worktree-port-namespace` is *collision avoidance*,
   not isolation. For untrusted / auto-approved execution, add an opt-in
   container/VM boundary (e.g. the OpenHands swap-the-workspace pattern). This is
   a deliberate non-goal for the Claude-Code-native, human-approved default
   posture; revisit if auto-approval is enabled.
5. **Cross-check CLI mode trusts the provider sandbox, not our hooks.** The
   `cross-check` skill's opt-in Mode B (`--deep`) shells an external provider CLI
   (`codex exec --sandbox read-only --ask-for-approval never …`) so a non-Claude
   model can explore the repo read-only. That CLI runs as a **subprocess** — the
   same blind spot as residual #1 — so its read-only-ness is enforced by the
   *provider's* `--sandbox read-only` flag, NOT by LogicLoom's Bash hooks.
   **Mitigations:** Mode A (API, artifact-scoped, no agentic surface) is the
   default and has no such assumption; Mode B is opt-in and the skill forbids
   invoking the provider CLI in any write-capable sandbox
   (`workspace-write`/`danger-full-access`); the external model is advisory-only
   regardless of mode (it returns findings, never edits). Acceptable for an
   advisory read-only adversary; revisit if the provider CLI is ever granted
   write or auto-approval from this slot.

## Bottom line

Governance is a real, model-independent **floor** — it makes the common,
high-impact failures (autonomous git, a subagent's `git clean`, the model
rewriting its own hooks, writing outside an owned scope) *hard*. It is not a
jail. Market it as defense-in-depth; keep the residuals above documented and
revisited.

## Provider portability (policy travels; enforcement does not)

LogicLoom is being made **provider-portable at the policy layer**. The honest
through-line: **policy** travels to any host as model-followed rules;
**enforcement** is host-specific and **binary present/absent** — a host either
has a conformant adapter or it degrades to followed-trust; **tooling/diagnostics**
run anywhere with a shell but VALIDATE, they do not ENFORCE.

**L1 — provider-neutral POLICY (travels to any host, model-followed).** The
constitution (16 principles as prose), AGENTS.md Tier 1 (operating principles +
the Cross-Check Disposition + neutral capability catalog + the in-band
"Enforcement reality" banner), the cross-check advisory/read-only contract, and
the `models.conf` role→tier *convention* (read as "most-capable / cheaper-faster").
Off Claude Code this is the ONLY layer left, and it is **unenforced**.

**L2 — host ENFORCEMENT ADAPTERS (host-specific; Claude Code = reference).** Four
guarantees need real enforcement: (VI) git-mutation approval gate, (VI)
subagent-git-deny, (governance) governance-file self-protection, (DAG)
freeze-write-scope. Today each is a Claude Code `PreToolUse` script emitting
`permissionDecision` JSON wired only in `.claude/settings.json` — invisible to
every other host. The portable move factors each guarantee's **decision logic**
into a pure-bash **verdict function** (`is-mutating-git?`, `is-protected-path?`,
`is-outside-owns?`) returning `allow|ask|deny`; the thin Claude Code JSON wrapper
is the reference adapter. Other hosts implement their own adapter (a repo git
pre-push/pre-commit hook; a PATH `git` wrapper that refuses non-interactive git
as the subagent-deny substitute, since `agent_id` is a Claude-internal signal no
other host emits; a CI gate; or the host's native pre-tool-use hook) **calling
the same verdict functions**.

> **Adapter-conformance contract.** A host's matrix cell may NOT be labeled
> "enforced" until its adapter passes a shared **golden-fixture test** (golden
> inputs → expected `allow|ask|deny` for each verdict function). Until an adapter
> passes, the cell reads **"followed-only"** — never an optimistic
> "adapter-able" dressed up as near-enforcement. **Shipping an unconformant
> adapter that claims compliance is itself a governance-integrity violation** —
> the same discipline as the cross-check Mode B rule (never pretend the bash gate
> still applies when it doesn't).

**L3 — host-agnostic TOOLING / DIAGNOSTICS (runs anywhere; VALIDATES, not
ENFORCES).** `constitutional-check.sh` (a validator — it reports compliance, it
does not gate it), the plugin command `.md` procedures (plain-English readable on
any host; only the generated `/slash` UX + frontmatter `model:` keyword are
Claude-only), the cross-check API/CLI calls the SKILL.md procedure makes, and the
`common.sh`/`load-context.sh` helpers. Pure bash, any shell — but **diagnostics,
not portable governance**. Note: cross-check ships as `SKILL.md` (a
model-executed procedure), NOT a standalone entrypoint — a foreign agent cannot
"shell out to the cross-check script"; it re-creates the curl/CLI calls from the
procedure.

### Honest enforced-vs-followed matrix

| Host         | L1 policy | git-gate (VI)    | subagent-deny       | gov-file protect | freeze-scope (DAG) |
|--------------|-----------|------------------|---------------------|------------------|--------------------|
| Claude Code  | followed  | ENFORCED (hook)  | ENFORCED (agent_id) | ENFORCED (hook)  | ENFORCED (hook)    |
| Codex CLI    | followed  | adapter†         | followed            | followed-only\*  | followed-only\*    |
| Cursor       | followed  | adapter†         | followed            | followed-only\*  | followed-only\*    |
| Gemini CLI   | followed  | adapter†         | followed            | followed-only\*  | followed-only\*    |
| Copilot      | followed  | adapter†         | followed            | followed-only\*  | followed-only\*    |
| Aider        | followed  | adapter† (git-hook) | followed (no subagents) | followed-only\* | followed-only\* |

\* the host HAS a pre-tool-use mechanism that COULD host an adapter, but **no
conformant adapter ships today**, so the cell is "followed-only" until one passes
the golden fixture. `subagent-deny` is "followed" everywhere but Claude Code
because `agent_id` is a Claude-internal signal no other host emits.

**Blunt truth.** Governance does NOT "degrade gracefully" onto other hosts —
enforcement is **binary present/absent by host**. Off Claude Code it is the
model-followed policy plus whatever conformant adapter someone writes. What is
portable is the POLICY and the Cross-Check Disposition, not the enforcement
floor. This is a **considered supersession** of the prior absolute "not
provider-portable" stance (recorded in CHANGELOG + project memory), mirroring the
v6.1/v6.2 supersession-note pattern.

> **Status of L2 adapters.** The adapter *contract* (verdict functions +
> golden-fixture conformance gate) is defined here. **Shipped (Phase 1–2):**
> (1) the verdict-function refactor — `.logic-loom/lib/governance-verdicts.sh`,
> the single source the four Claude Code hooks now call (golden fixtures:
> `tests/contract/test_governance_verdicts.sh`, 36/36); and (2) the first
> reference NON-Claude adapter — the off-host **git-approval gate**
> (`.logic-loom/adapters/`: a `pre-push` hook + a PATH `git` wrapper) which calls
> those same verdicts and passes `tests/contract/test_git_adapter.sh` (18/18).
> So the **git-gate (VI)** guarantee is now *conformance-enforced on any
> POSIX-shell host that installs the adapter* (`bash .logic-loom/adapters/install.sh`),
> marked `adapter†` in the matrix — subject to the inherent client-side bypasses
> documented in `.logic-loom/adapters/README.md` → *Honest limits* (absolute-path
> `git`, `git push --no-verify`, the honor-system `LOOM_GIT_APPROVED` token). The
> **governance-file protection** and **freeze-write-scope** adapters are NOT yet
> shipped, so those cells stay "followed-only" on non-Claude hosts.
>
> **Floor-integrity hardening (post-gate-review).** Because the verdict lib is now
> load-bearing, it is itself in the protected set (`loom_path_is_protected` covers
> `.logic-loom/lib/governance-verdicts.sh` + `policy.sh`) — a subagent cannot blank
> it to disarm the git gates. And the two git hooks **fail SAFE, not open**, if the
> lib is ever absent: `subagent-git-guard` still denies any subagent git inline and
> `git-safety-gate` still asks on a mutating git inline (verified). The off-host
> adapter likewise fails CLOSED (refuses all git when it cannot classify).
>
> `adapter†` = a conformant adapter ships and passes the golden fixtures;
> enforcement is real **once the host installs it** (opt-in), versus Claude
> Code where it is always-on via hooks.
