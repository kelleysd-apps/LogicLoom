# Governance Threat Model & Enforcement Posture

**Status:** v6.2.0 · **Scope:** the hook-enforced governance core.

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

## Bottom line

Governance is a real, model-independent **floor** — it makes the common,
high-impact failures (autonomous git, a subagent's `git clean`, the model
rewriting its own hooks, writing outside an owned scope) *hard*. It is not a
jail. Market it as defense-in-depth; keep the residuals above documented and
revisited.
