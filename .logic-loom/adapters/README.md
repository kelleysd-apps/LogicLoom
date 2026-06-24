# LogicLoom off-host enforcement adapters (L2)

These adapters carry LogicLoom's **enforcement** floor to hosts **other than
Claude Code**. On Claude Code, governance is enforced by PreToolUse hooks. Other
hosts (Codex CLI, Cursor, Gemini CLI, Aider, plain shell, CI) have no PreToolUse
layer — so the *policy* (AGENTS.md Tier 1, the constitution) is model-followed,
and *enforcement* must be supplied by an adapter here.

Every adapter calls the **same verdict functions** as the Claude Code hooks
(`.logic-loom/lib/governance-verdicts.sh`) — one source of truth. An adapter may
only be claimed as "enforced" once it passes the shared golden-fixture
conformance test (see `.docs/architecture/governance-threat-model.md` →
*Adapter-conformance contract*).

## Shipped adapter — git-approval gate (Principle VI)

Enforces "no autonomous git mutation" off Claude Code.

| File | Role |
|------|------|
| `git-approval-gate.sh` | adapter core — `loom_git_approval_gate "<git cmd>"` → allow/block, calling the shared verdicts |
| `githooks/pre-push` | git pre-push hook (gates pushes via `core.hooksPath`) — PATH-independent, but `--no-verify`-bypassable (see Honest limits) |
| `bin/git` | PATH wrapper — **defense-in-depth nudge, NOT a boundary** (bypassable by absolute path); see Honest limits |
| `install.sh` | installs both layers into this repo |

**Behavior** (the off-host analog of Claude Code's interactive "ask"): an
autonomous (non-interactive) mutating git is **blocked**; a human approves with a
`/dev/tty` prompt or `LOOM_GIT_APPROVED=1`; read-only git and non-git pass
through. Unlike the Claude Code hooks (which fail *open* as one backstop among
several), this adapter fails **closed** — off-host it is the only backstop.

## Honest limits (read before relying on this)

A client-side, in-process gate **cannot** fully stop an autonomous agent that
controls its own process and environment. These bypasses are inherent, not bugs:

- **PATH wrapper is bypassable by absolute path.** `/usr/bin/git push` or
  `env -i git …` never consults `bin/git` — it only shadows the *name* `git` on
  `PATH`. Treat the wrapper as defense-in-depth, not enforcement. The
  **pre-push hook is the only PATH-independent layer** (git itself honors it).
- **`git push --no-verify` skips the pre-push hook** (documented git behavior).
  There is no client-side defense against this. For real enforcement, use a
  **server-side `pre-receive` hook or remote branch protection** — the client
  pre-push is advisory.
- **`LOOM_GIT_APPROVED=1` is an honor-system marker, not a secret.** The gated
  process can set it (`LOOM_GIT_APPROVED=1 git push` self-approves). It gates the
  *careless*, not the *adversarial*. For a real approval, rely on the interactive
  `/dev/tty` prompt or an out-of-band nonce the agent process cannot mint.

The honest takeaway: off-host this raises the bar (an agent must *deliberately*
route around it) and enforces against non-adversarial autonomy; it is **not** the
hard, unavoidable gate Claude Code's PreToolUse hooks provide. The threat-model
matrix reflects this — `adapter†`, not `ENFORCED`.

## Install

```bash
bash .logic-loom/adapters/install.sh          # pre-push gate (+ instructions for the PATH wrapper)
bash tests/contract/test_git_adapter.sh        # verify enforcement (conformance)
```

## Conformance status

| Guarantee | Adapter | Status |
|-----------|---------|--------|
| VI git-approval gate (mutations) | `git-approval-gate.sh` + `pre-push` | ✅ `test_git_adapter.sh` 13/13 — **with the Honest-limits bypasses above** (`--no-verify`, absolute-path) |
| VI subagent-git-deny | `bin/git` wrapper (non-interactive heuristic) | **followed-only / heuristic** — NOT equivalent. The Claude Code guarantee denies ALL subagent git (incl. read-only `git log`/`git show HEAD:secrets` — the recon/exfil surface); off-host there is no `agent_id`, and the wrapper only gates *mutations*, so read-only subagent git is **not** blocked |
| governance-file protection | _not yet shipped_ | followed-only |
| freeze-write-scope | _not yet shipped_ | followed-only |

Only the **git-mutation gate** row is conformance-proven (`test_git_adapter.sh`),
and only to the extent the Honest-limits section allows. Every other guarantee is
**followed-only** off Claude Code — never represent a host as fully governed.
