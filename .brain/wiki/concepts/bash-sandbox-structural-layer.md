---
type: concept
title: "Claude Code's Bash sandbox as a structural layer under the governance guard (LOOM-0071)"
date-updated: 2026-09-21
sources:
  - .brain/raw/research/2026-09-17-loom-0071-bash-sandbox.md  # LOOM-0071 research task, 2026-09-17 — doc review + live macOS Seatbelt probes (Claude Code 2.1.252) + two decorrelated external CLI reviewers (Codex GPT, Antigravity)
---

# Bash sandbox as a structural layer, not a replacement for the guard

**Status: evidence, not a decision.** LOOM-0071 (backlog, `status:open`) is a
rewrite-of-the-floor call the maintainer owns. This page records what the
research established; nothing here has been adopted into
`.claude/settings.json`.

## What it is

Claude Code's built-in Bash sandbox enforces at the OS layer — Seatbelt on
macOS, bubblewrap (+ socat, optional seccomp) on Linux/WSL2 — on every
`Bash`/`PowerShell`/`Monitor` command **and all child processes**. Because it
denies the mutating syscall rather than matching a command string, it is blind
to the evasions that beat a token matcher (governance threat model residual
#8: interpreter indirection, `eval`, `$VAR` expansion, `xargs`, `find -delete`).

- Writes allowed only in cwd, the session `$TMPDIR`, and `--add-dir` paths;
  configurable via `sandbox.filesystem.denyWrite` / `allowWrite`.
- A **built-in, non-exemptible protected list** already covers `.claude`
  settings, `.claude/{hooks,skills,agents,commands}`, `.mcp.json`,
  `.git/hooks`, `.git/config`, and `~/.claude`.
- Subagents inherit the parent session's sandbox config.

## What the probes showed (macOS Seatbelt only)

Every residual-#8 form was **denied at the syscall** — `python3 -c open(...)`,
`eval "rm ..."`, `$VAR` redirection, `xargs rm`, `bash -c` redirection,
parent-directory rename, and hard-link creation. Custom `denyWrite` paths in
the **project** settings file held the same way.

Two design-changing nuances:

- **`./` paths only resolve to the project root in project settings.** In
  user/CLI `--settings` scope they resolve to `~/.claude` and silently protect
  nothing — a CLI-delivered floor must use absolute paths.
- **`find -delete` exits 0 when the delete is denied.** Any acceptance test
  must assert file state (bytes + inode), never exit codes.

## Why it cannot replace the hook

1. **Bash-only.** `Edit`/`Write`/MCP tools bypass the sandbox entirely; the
   hook stays the only enforcement for them.
2. **No asymmetry.** It denies everyone equally — it cannot express
   "subagent DENY / main-agent ASK", which is what `protect-governance-files.sh`
   provides.
3. **A project block is a default, not a floor.** Precedence is managed > CLI
   `--settings` > `settings.local.json` > project `settings.json` > user. A
   probe confirmed a developer `settings.local.json` re-enabling
   `allowUnsandboxedCommands` let the model's `dangerouslyDisableSandbox` retry
   write a denied file with no prompt. `excludedCommands` merges additively
   with no lock at any scope.
4. **Fails open** on unsupported hosts (native Windows, WSL1) unless
   `failIfUnavailable: true`.

## Recommended shape (per the research)

Adopt as a **second, structural layer under the existing hook**: the guard
keeps intent + asymmetry + `Edit`/`Write` coverage; the sandbox adds
string-evasion-proof enforcement for Bash.

- Project block: `enabled: true`, `allowUnsandboxedCommands: false`,
  `autoAllowBashIfSandboxed: true` (default — a hook `"ask"` still prompts
  under auto-allow), `failIfUnavailable: false` plus a loud unsandboxed-state
  startup advisory, and `denyWrite` for the three governance paths the
  built-in list does not cover: `.logic-loom/memory/constitution.md`,
  `.logic-loom/config/governance.conf`, `plugins/loom-governance/hooks`.
- To make it a floor rather than a default, deliver the strict keys via a
  documented **CLI `--settings` launcher** with absolute paths.
- First step: a spike branch against a *copy* of the settings plus a contract
  test proving state-unchanged, Edit/Write still hook-caught, the ASK/DENY
  asymmetry intact, normal dev (non-governance edit, `npm test`, a checkout not
  touching `.claude/`) still working, on both Seatbelt and bubblewrap, with a
  pinned minimum Claude Code version.

## Known costs and open points

- **Daily-workflow cost:** `git checkout`/`merge` fail (`unable to unlink old`)
  when replacing tracked files under protected paths — and this repo tracks
  `.claude/commands/` and `.claude/hooks/` and regenerates commands from
  plugins. Both external reviewers warned **not** to fix this by excluding
  git; keep regeneration/checkout as an explicit human step.
- Also breaks: `docker`, Go CLIs (`gh`, `gcloud`, `terraform` — TLS on macOS),
  `jest` without `--no-watchman`, per-domain network prompts for installs,
  tools writing outside cwd.
- **Unresolved disagreement — `failIfUnavailable`.** Both external reviewers
  leaned `true` (fail-closed); the research author chose `false` + advisory
  because `true` locks every Windows/WSL1 cloner out of the template, and
  framed `true` as the flip a security-sensitive fork makes. Carried here
  unresolved: the maintainer decides.
- **Main-agent git plumbing gap** (Codex): `git-safety-gate.sh` gates
  `update-ref`/`symbolic-ref`/`filter-branch`/`fast-import` but not
  `hash-object`/`update-index`/`commit-tree`/`write-tree`, which can stage
  governance content without writing the protected path. Subagents are already
  denied by `subagent-git-guard.sh`'s read-only allowlist. Recorded as a
  follow-up, not an adoption blocker.
- **Linux untested.** Antigravity's parent-rename bypass was refuted on
  Seatbelt only; deny the containing directory, not the leaf, and re-probe on
  bubblewrap.
- **Hook dependency closure** (Codex): any writable script a hook sources or
  execs is unsandboxed code execution even if the hook entrypoint is protected.
- Human `!` shell-mode commands run outside strict sandbox — acceptable only
  if human action is explicitly out of the threat model.

## Related

- [Governance threat model](../../../.docs/architecture/governance-threat-model.md) — residual #8 and LOOM-0071
- [[memory-backend-default]] — the other governance-adjacent decision in this wiki
