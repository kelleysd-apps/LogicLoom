---
type: capture
title: "LOOM-0071: can Claude Code's built-in Bash sandbox replace the string-parsing governance guard?"
date: 2026-09-17
source: "research task (LOOM-0071) — live doc review of code.claude.com/docs sandboxing + settings, empirical probes with nested `claude -p` on macOS Seatbelt (Claude Code 2.1.252), plus two decorrelated external CLI reviewers (Codex GPT, Antigravity)"
status: unprocessed
---

# LOOM-0071 — Bash sandbox as the structural answer to string-parsing bypasses

## Bottom line

Claude Code's built-in Bash sandbox is a **real OS-level enforcement layer** that
closes every documented residual-#8 bypass by construction: on macOS Seatbelt,
`python3 -c open(...)`, `eval "rm"`, `$VAR` expansion, `xargs rm`, `find -delete`,
`bash -c` redirection, parent-directory rename, and hard-linking a protected file
were **all denied at the mutating syscall** in live probes — because the sandbox
enforces on the running process, not on the command string, so it is blind to the
evasions that beat a token matcher. But it is **not a drop-in replacement**: it is
Bash-only (the `Edit`/`Write` tools bypass it entirely, so the hook must stay), a
project-shipped `sandbox` block is a *default a developer can override*, not a
floor, and it fails open on unsupported hosts — so the honest recommendation is
**adopt it as a second, structural layer under the existing hook, made into a
floor via a CLI-settings launcher, not as the hook's retirement.**

## What the sandbox is and what it enforces

- **OS layer.** macOS uses Seatbelt (`sandbox-exec`); Linux/WSL2 use bubblewrap +
  socat (optional seccomp filter). Native Windows and WSL1 are **unsupported**.
  Enforcement covers every `Bash`/`PowerShell`/`Monitor` command **and all child
  processes**. Source: https://code.claude.com/docs/en/sandboxing#os-level-enforcement
- **Filesystem model.** Writes allowed only in cwd + session `$TMPDIR` + `--add-dir`
  paths; reads wide open by default. Configurable via `sandbox.filesystem.denyWrite`
  / `allowWrite` / `denyRead` / `allowRead`. Source: https://code.claude.com/docs/en/sandboxing#filesystem-isolation
- **Built-in immutable protected paths** — inside the writable cwd the sandbox
  *still* denies writes to the config/code Claude Code loads: the `.claude`
  settings files, `.claude/hooks`, `.claude/skills`, `.claude/agents`,
  `.claude/commands`, `.mcp.json` (in cwd and every ancestor); `.git/hooks` and
  `.git/config`; and `~/.claude`. "There is no way to exempt one of these paths"
  — only `filesystem.disabled` (user/managed scope only) lifts them. Source:
  https://code.claude.com/docs/en/sandboxing#protected-paths
- **Subagents inherit the parent session's sandbox config** — same enforcement for
  subagent Bash as main-agent Bash. Source: https://code.claude.com/docs/en/sandboxing#scope

### The answer to the five LOOM-0071 questions, in one place

1. **Does it close residual #8 by construction?** For Bash and its children, yes.
   Seatbelt/bubblewrap deny the write syscall regardless of how the path is
   spelled, so interpreter indirection, `$VAR`, `xargs`, `find -delete`, and `eval`
   are all irrelevant — the OS never sees the string. **Verified by probe** (below).
2. **Subagents + a main-agent approval path?** It applies to subagents too, but it
   denies *everyone equally* — it cannot express "subagent DENY / main-agent ASK".
   That asymmetry is exactly what the existing hook provides and the sandbox does
   not, so the two are complementary, not substitutes. When it blocks, the command
   fails with a violation; the **model may retry with `dangerouslyDisableSandbox`**
   (drops to the normal permission flow — prompt in manual, classifier in auto),
   unless `allowUnsandboxedCommands:false` ("strict sandbox mode") makes Claude
   Code ignore that parameter. Who controls it: it is a boolean the model can set
   on a call, disabled only by a setting the human controls. Source:
   https://code.claude.com/docs/en/sandboxing#the-unsandboxed-retry-escape-hatch
3. **Platform coverage / unsupported hosts?** macOS, Linux, WSL2 only. Default on
   an unsupported host or missing dependency is **fail-open** (warning + unsandboxed
   run); `sandbox.failIfUnavailable:true` makes it a hard failure (Claude Code
   refuses to start). Source: https://code.claude.com/docs/en/sandboxing#get-started
4. **Can LogicLoom ship it in the (protected) project `.claude/settings.json`?**
   Yes — the `sandbox` keys are "Any file" scope, so the committed project settings
   can set them and every cloner inherits them. **But** precedence is managed >
   CLI `--settings` > `.claude/settings.local.json` > `.claude/settings.json` >
   user, so an untracked developer `settings.local.json` outranks the committed
   file for booleans, and `excludedCommands` merges additively across scopes with
   no managed-only lock. So a project-shipped block is a **default, not a floor**.
   What it breaks: per-domain network prompts (package installs), tools writing
   outside cwd (need `allowWrite`), `docker` (incompatible), Go CLIs `gh`/`gcloud`/
   `terraform` (TLS failures on macOS), `jest` (needs `--no-watchman`), and — the
   LogicLoom-specific one — `git checkout`/`merge` fail with `unable to unlink old`
   when they must replace a file under a protected path, and this repo **git-tracks
   `.claude/commands/` and `.claude/hooks/`** and regenerates `.claude/commands/`
   from plugins. Source: https://code.claude.com/docs/en/sandboxing#configure-sandboxing
   and #troubleshooting
5. **Recommendation:** adopt narrowly as the structural layer, keep the string
   guard as the intent layer. Details in *Recommendation* below.

## Empirical probes (macOS, Seatbelt, Claude Code 2.1.252)

Nested `claude -p --allowedTools Bash` runs in throwaway fixtures outside the repo,
each command issued as a separate Bash call, no retries, no override. Config on the
project `.claude/settings.json`: `enabled:true, allowUnsandboxedCommands:false,
autoAllowBashIfSandboxed:true`, plus `filesystem.denyWrite` for the two custom paths.

| Attempt | Result |
|---|---|
| `python3 -c "open('.claude/settings.json','a')..."` | **DENIED** — `PermissionError: Operation not permitted` (built-in protected path) |
| `eval "rm .claude/settings.json"` | **DENIED** — `Operation not permitted` |
| `D=.claude; echo x >> $D/hooks/h.sh` | **DENIED** — `operation not permitted` |
| `echo .claude/hooks/h.sh | xargs rm -f` | **DENIED** — `Operation not permitted` |
| `find .claude -name h.sh -delete` | **not deleted**, but process **exit 0** (find swallowed the error) |
| `echo x >> ./constitution.md` (custom denyWrite, **project scope**) | **DENIED** |
| `python3 -c open('constitution.md','a')` | **DENIED** |
| `bash -c "echo x >> plugins/gov/hooks/g.sh"` (custom denyWrite, project scope) | **DENIED** |
| `mv locked locked2` where `locked/inner` is denied (parent-rename evasion) | **DENIED** at the `mv` — `rename ... Operation not permitted` |
| `ln leaf.txt alias.txt` then write (hard-link evasion) | **link creation DENIED** — `Operation not permitted` |
| control write to a new unprotected file | succeeded (as intended) |

**Two nuances that change the design:**

- **`./`-path scope gotcha (verified).** A `filesystem.denyWrite` of `./constitution.md`
  passed via **`--settings`/user scope silently did nothing** — a relative `./` path
  resolves to the *project root only in project settings*; in user/CLI settings it
  resolves to `~/.claude`. The same rule placed in the project `.claude/settings.json`
  worked. So the custom denies must live in the committed project file, and a floor
  enforced via a CLI launcher (below) must use **absolute** paths.
- **`find -delete` returns exit 0 even when the delete is denied.** Any acceptance
  test must assert **file state**, not command exit codes.

**Escape-hatch probe (verified).** With project `allowUnsandboxedCommands:false`
but a developer `.claude/settings.local.json` setting it back to `true`, the model's
`dangerouslyDisableSandbox` retry **succeeded** and wrote the denied file with no
prompt. This is the concrete proof that a project block is a default, not a floor:
local settings outrank it.

## External second opinions (decorrelated, non-Claude, read-only)

Both ran with the same brief (problem, constraints, my leaning, "what am I
missing"), framed as a defensive configuration review. Codex (GPT, `codex exec
-s read-only`) returned 17 findings; Antigravity (`agy -p --sandbox --mode plan`)
returned 10. They **converged independently** on five points — which is the signal
to treat those as real:

1. **A project sandbox is a default, not a floor** (both, Blocker). `settings.local.json`
   and `--settings` outrank project settings for booleans; `excludedCommands` merges
   additively; only a CLI-settings launcher or managed settings approaches a floor —
   and even managed settings cannot lock `excludedCommands`. *I agree — probe D2
   confirmed it directly.*
2. **The sandbox does not cover `Edit`/`Write`/MCP** (both, Blocker). Custom
   `denyWrite` protects only Bash + children; the hook remains the sole enforcement
   for the file-edit tools. *I agree — this is why the hook cannot be retired, only
   demoted to a second layer.*
3. **`git checkout`/`merge` on tracked `.claude/` breaks inside the sandbox** (both,
   Blocker). And do **not** fix it by excluding git — that hands an unsandboxed
   process exactly the capability to replace governance files. Keep regeneration/
   checkout an explicit human step. *I agree; this is the biggest daily-workflow cost.*
4. **`autoAllowBashIfSandboxed:false` is the wrong call** (both, Should-fix). A
   PreToolUse hook returning `"ask"` still prompts even under auto-allow, so leaving
   it at the default `true` keeps the governance ASK prompts **and** the sandbox's
   usability benefit; setting it false throws the benefit away for no security gain.
   *This corrects my initial leaning — I had proposed `false`. Adopting their
   correction: leave it at default `true`.*
5. **Fail-open default vs `failIfUnavailable`** (both, Should-fix). Shipping
   `false` silently reopens every parser bypass on an unsupported host and leaves
   the flawed string guard as the only defense. Codex/Antigravity lean toward
   `true` with an explicit degraded opt-out. *Partial disagreement: `true` locks
   every Windows/WSL1 cloner out of the template entirely, which is too blunt for a
   cloneable harness. My call: ship `false` + a loud startup advisory naming the
   unsandboxed state, and document `true` as the setting a security-sensitive fork
   flips. This keeps it the maintainer's call, consistent with LOOM-0071's framing.*

**Points only one raised, worth keeping:**

- **Git object-DB plumbing is an unprotected semantic bypass** (Codex, Blocker):
  `hash-object`/`update-index`/`commit-tree`/`update-ref` can stage governance
  content without ever writing the protected working-tree path, to be materialized
  by a later checkout. *Partly mitigated here:* `subagent-git-guard.sh` allowlists
  only read-only git, so a subagent is already denied these; `git-safety-gate.sh`
  recognizes `update-ref`/`symbolic-ref`/`filter-branch`/`fast-import` but **not**
  `hash-object`/`update-index`/`commit-tree`/`write-tree` — a real gap for the main
  agent. Record as a follow-up, not a blocker to adoption.
- **Parent-directory rename defeats leaf denies** (Antigravity, Blocker): *refuted
  on macOS by probe* — Seatbelt denied the `mv` of the protected directory itself.
  Still worth testing on Linux bubblewrap before relying on it, and denying the
  containing directory (not the leaf) is the robust choice regardless.
- **Hooks are privileged confused deputies / protect the hook dependency closure**
  (Codex, Should-fix): any writable script a hook sources or execs is unsandboxed
  code execution even if the hook entrypoint is protected. Good hardening note.
- **Human `!` shell-mode commands run outside strict sandbox** (Codex, Note):
  acceptable only if "human action" is explicitly outside the threat model.

## Recommendation

**Adopt as the structural second layer under the existing hook — not as its
replacement.** The string guard keeps the one thing the sandbox cannot express
(subagent DENY vs main-agent ASK, and coverage of `Edit`/`Write`); the sandbox
adds the one thing the guard cannot achieve (OS enforcement immune to string
evasion). Neither alone is sufficient; together they cover each other's blind spot.

Shipped `sandbox` block (in the committed project `.claude/settings.json`):
`enabled:true`, `allowUnsandboxedCommands:false`, `autoAllowBashIfSandboxed:true`
(default — keep the hook's ASK prompts working), `failIfUnavailable:false` + a loud
unsandboxed-state startup advisory, and `filesystem.denyWrite` (absolute or
project-`./` paths) for the three governance paths the built-in list does **not**
already cover: `.logic-loom/memory/constitution.md`, `.logic-loom/config/governance.conf`,
`plugins/loom-governance/hooks`. (The `.claude/*` surface is already built-in-protected.)

To make it a **floor** rather than a default, the strict keys
(`allowUnsandboxedCommands:false`, and the governance `denyWrite` paths) should be
delivered through a **CLI `--settings` launcher** the harness documents, because
CLI settings outrank a developer's `settings.local.json`; managed settings are the
only strictly-higher option and are out of scope for a cloneable template.

### First step and what must be tested before adoption

First step: a **spike branch** that adds the `sandbox` block to a *copy* of the
project settings and runs a new contract test — do not touch live governance config
(this task changed none). The test must, before adoption, prove:

1. State, not exit codes — assert the governed files' **bytes and inode** are
   unchanged after each attempt (the `find -delete` exit-0 case makes this mandatory).
2. Every residual-#8 bypass form is denied **and** the `Edit`/`Write` tools are
   still caught by the hook (the sandbox does not cover them).
3. The main-agent ASK / subagent DENY asymmetry still holds with the sandbox on.
4. Normal development still works: a non-governance edit, `npm test`, and a
   `git checkout` that does **not** touch tracked `.claude/` — and a documented,
   human-run path for the checkout/commands-regeneration case that does.
5. Both implementations (macOS Seatbelt and Linux bubblewrap), and a pinned minimum
   Claude Code version, since sandbox/hook behavior has moved across releases.

This stays a rewrite-of-the-floor decision the maintainer owns (LOOM-0071's own
framing); this capture is the evidence that the structural layer is real, bounded,
and safe to pilot behind a test — not a change to ship blind.
