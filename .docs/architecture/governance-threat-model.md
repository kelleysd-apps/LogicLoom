# Governance Threat Model & Enforcement Posture

**Status:** v6.6.2 · **Scope:** the hook-enforced governance core.

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
4. **Sandboxing** — blast-radius limit. A **host** capability (Claude Code's
   built-in Bash sandbox), opt-in and off by default; LogicLoom neither ships nor
   enables one. See Residual #4 for what it covers and what it does not.
5. **Audit/observability** — evidence (`governance-preflight` audit log).
6. **PR / CI review** — the human release boundary.

## The hooks (what each enforces)

| Hook | Matcher | Enforces |
|---|---|---|
| `subagent-git-guard.sh` | PreToolUse·Bash | Denies MUTATING git from a subagent (`agent_id` present). Explicitly allowlisted read-only git (status/log/diff/show/listing/…) is permitted; everything else — including `fetch`, code-executing globals like `-c core.fsmonitor=<cmd>`, and any command substitution — is denied. `gh` stays categorically denied. |
| `git-safety-gate.sh` | PreToolUse·Bash | Main-agent git mutations → `ask`. |
| `protect-governance-files.sh` | PreToolUse·Write/Edit + Bash | Edits to the governance surface (`.claude/hooks/`, `settings.json`, `constitution.md`, `governance.conf`, the verdict lib + `policy.sh`, `loom-governance/hooks/`) → subagent `deny` / main `ask`. Stops the model softening its own rules. That set is a **fixed floor**; `governance.conf`'s `protected_paths` key can only ADD to it — see *Protected-path floor* below. |
| `guard-dangerous-commands.sh` | PreToolUse·Bash | Policy-based dangerous-command blocking (bash 4+; fails open on 3.2). |
| `freeze-write-scope.sh` | PreToolUse·Write/Edit | Plan-as-DAG file-ownership; paths canonicalized (`realpath`) so `..`/symlink/`//` cannot escape the `owns:` scope. |
| `governance-preflight.sh` | UserPromptSubmit | Domain briefs + memory; strict-mode recitation. |

## Detection model

A subagent's tool call carries an `agent_id` (and `agent_type`) in the
PreToolUse payload; the main agent's does not. This is the basis for
"subagent → deny, main → ask" and is **empirically verified** (not documented
contract) — re-verify if a future Claude Code version changes the field.

## The subagent git guarantee (what it is, precisely)

**The guarantee is "a subagent never MUTATES git" — not "a subagent never
touches git".** It was the latter until §7.3; the blanket deny also blocked
`git status`, which bought no safety and blocked legitimate read-only worker
exploration.

The rule is an **ALLOWLIST of known-safe reads, then deny everything else**
(`loom_git_is_readonly_for_subagent` in `.logic-loom/lib/governance-verdicts.sh`).
It is deliberately NOT "classify mutations and allow the remainder", and must not
be refactored into one: with a mutation-classifier the failure mode is a false
NEGATIVE — a silent subagent mutation, the exact thing Principle VI exists to
prevent. With an allowlist the failure mode is a false POSITIVE — a worker is
loudly denied some read, someone notices, and it is fixed in a day.

A subagent git invocation is allowed only when **all** of these hold:

1. the subcommand is on the explicit read-only allowlist (`status`, `log`,
   `diff`, `show`, `rev-parse`, `rev-list`, `ls-files`, `ls-tree`,
   `cat-file`, `describe`, `blame`, `shortlog`, `whatchanged`, `grep`,
   `merge-base`, `name-rev`, `count-objects`, `verify-commit`, `verify-tag`,
   `check-ignore`, `check-attr`, `diff-tree`, `diff-index`, `for-each-ref`,
   `show-ref`);
2. for a subcommand with both read and write forms, the args are the read form —
   `branch` listing only, `tag -l`-style listing only, `stash list|show`,
   `remote` bare/`-v`/`show`/`get-url`, `worktree list`, `config
   --get|--get-all|--get-regexp|--list`, `reflog show`, `notes list|show`,
   `bisect log|view`, `symbolic-ref` with at most one operand;
3. no git global flag outside a short safe list (`-C <path>`, `--no-pager`,
   `-P`/`--paginate`, the pathspec-mode flags, `--no-optional-locks`). In
   particular `-c` / `--config-env` / `--exec-path` / `--git-dir` / `--work-tree`
   / `--namespace` are denied — `git -c core.fsmonitor=<cmd> status` *executes*
   `<cmd>`, and the dir/tree flags point git at a different repository;
4. **no environment assignment precedes the `git` word** — see "Closed vector:
   environment assignment" below;
5. no argument anywhere in the invocation is on the denied-argument list
   (`--output`, `--ext-diff`, `--textconv`, `--contents`, `--upload-pack`,
   `--receive-pack`, `--open-files-in-pager`, `--exec-path`, `--git-dir`,
   `--work-tree`, `--namespace`, `--config-env`, `--attr-source`,
   `--super-prefix`, and any short-flag cluster containing `-O`). These are the
   post-subcommand equivalents of the rule-3 globals: `git log --output=/tmp/f`
   writes a file, `git diff --ext-diff` runs the configured external diff
   program, `git blame --contents /etc/passwd` reads outside the repo, and
   `git grep -O <cmd>` executes `<cmd>`. Matched on the token's name half, so
   both `--flag=value` and `--flag value` are caught;
6. the command line contains no command or process substitution (`$(…)`,
   backticks, `<(…)`), checked against the raw command before segment splitting.

**Removed from the allowlist** (upstream cross-provider review): `ls-remote` —
unattended network I/O from a worker, and an execution primitive when paired with
a hostile `GIT_SSH_COMMAND`/`--upload-pack`; and `submodule status|summary` —
both dispatch `git-submodule--helper` and re-enter git inside each submodule, so
the args the gate validated are not the args that ultimately run.

**Closed vector: environment assignment.** `_loom_cmd_after_prefix` skips
`VAR=value` as a harmless prefix so that `env FOO=1 git push` is still recognized
as git. On the subagent *read* path that was a full bypass of rules 3 and 5 —
git's environment achieves everything the denied flags achieve without ever
looking like a flag: `GIT_EXTERNAL_DIFF` / `GIT_SSH_COMMAND` / `GIT_PAGER` /
`GIT_EDITOR` make git **execute** a named program; `GIT_DIR` / `GIT_WORK_TREE` /
`GIT_CONFIG*` / `GIT_ALTERNATE_OBJECT_DIRECTORIES` **redirect the repository**;
`LD_PRELOAD` / `DYLD_INSERT_LIBRARIES` / `PATH` / `IFS` / `BASH_ENV` hijack the
process. The gate now denies **any** leading assignment on the subagent read
path, including via `env` — categorical rather than a `GIT_*`-plus-known-bad
enumeration, because an enumeration is one new git environment variable away
from a silent hole and a worker running read-only git has no legitimate reason
to set a variable inline. Main-agent verdicts are unchanged.

`fetch` is denied for subagents (it writes remote-tracking refs and touches the
network). `gh` remains **categorically** denied for subagents, reads included —
unchanged. Main-agent behavior is unchanged in every respect.

The inline fallback in `subagent-git-guard.sh` (used only when the verdict lib is
missing) stays **categorical**: it denies all subagent git, reads included. It
deliberately does not re-implement the allowlist.

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
4. **Execution isolation is the host's, it is opt-in, and LogicLoom ships none
   of its own.** The earlier wording here — "no execution sandbox" — was wrong in
   the same way an overclaim is wrong, just pointing the other direction: it
   asserted an absence that is not real. Corrected 2026-08-24 (LOOM-0031).

   **What exists (official docs + verified in use).** Claude Code ships a
   built-in Bash sandbox: macOS Seatbelt (`/usr/bin/sandbox-exec`), Linux/WSL2
   bubblewrap + socat with an optional seccomp filter. When on, it restricts
   *writes* to the working directory plus the session `$TMPDIR`, restricts
   *network egress* to an allowlist enforced by a local proxy, and can unset or
   mask credential env vars and deny reads of credential files. Subagents inherit
   the parent session's sandbox configuration.

   **What it is NOT (this is the part that keeps the residual real).**
   - **Opt-in, not the standing posture.** It is keyed on `sandbox.enabled`,
     which defaults off. *Verified in use:* neither `~/.claude/settings.json` nor
     this repo's `.claude/settings.json` sets a `sandbox` key, and a probe from
     inside a session wrote to `$HOME` and `/tmp`, saw an unmodified `$TMPDIR`,
     and reached an unallowlisted host — i.e. no sandbox was in force. The
     presence of the Bash tool's `dangerouslyDisableSandbox` parameter is **not**
     evidence that isolation is on; the parameter sits in the static tool schema
     regardless, and is inert when the sandbox is disabled or when
     `allowUnsandboxedCommands: false`.
   - **Bash-only.** Official docs, § *Scope*: "The sandbox isolates Bash
     subprocesses." `Read`, `Edit`, and `Write` go through the permission system
     instead — so an agent writing to an allowed path, or to *any* path via the
     file tools, is not a sandbox question at all. That is exactly the gap
     `freeze-write-scope` covers, and exactly why residual #2 (Bash write-path
     escape of the freeze DAG) is not closed by turning the sandbox on.
   - **Reads are wide open by default.** The default read policy allows the whole
     machine minus a denied set; `~/.ssh` and `~/.aws/credentials` are readable
     unless `sandbox.credentials` or `denyRead` is configured.
   - **Fails open.** If the sandbox cannot start (missing dependency,
     unsupported platform — native Windows is unsupported), the default is a
     warning and unsandboxed execution, unless `sandbox.failIfUnavailable` is
     set. Same trade as residual #3, one layer down.
   - **The model can leave it.** On a sandbox-caused failure Claude may retry
     with `dangerouslyDisableSandbox: true`; the retry drops to the normal
     permission flow rather than to nothing, but the boundary is per-call and
     model-initiated unless `allowUnsandboxedCommands` is `false`.
   - **Anthropic grades it porous itself.** Documented limitations include
     domain-fronting past a proxy that allowlists on the client-supplied
     hostname without TLS inspection, Unix-socket escalation (`docker.sock`),
     `allowWrite` paths on `$PATH` or over shell rc files, `allowAppleEvents`
     removing code-execution isolation on macOS, and env vars inherited into
     sandboxed commands including credentials.

   **Where the two boundaries meet.** They are orthogonal, not stacked. The host
   sandbox bounds *what a Bash subprocess can touch* and is blind to intent;
   LogicLoom's hooks bound *which operations an agent may request* (git
   mutations, the governance surface, DAG-owned paths) and are blind to what a
   subprocess actually does once launched — residual #1. Each covers the other's
   blind spot only partially: the sandbox would catch a `python -c` git write
   *outside the allowed tree*, but not one inside the working directory, which is
   where every interesting repo mutation lives. Turning the sandbox on therefore
   narrows residuals #1 and #2 at the edges and closes neither.

   **What genuinely remains.** LogicLoom does not enable, require, configure, or
   verify the host sandbox; nothing in `.claude/settings.json`, no hook, and no
   preflight reads `sandbox.*`. So the harness's shipped posture is unsandboxed
   by default, and the honest floor statement is unchanged: hooks are a porous
   floor, and the isolation layer beneath them is a host feature the operator has
   to switch on. `worktree-port-namespace` remains *collision avoidance*, not
   isolation, and contributes nothing here. Under Pillar 2 the open work is to
   **evaluate and surface** the native boundary — a documented, opt-in
   `sandbox.enabled` posture for this repo, with the Bash-only and fail-open
   caveats stated — not to build a container/VM layer of our own. Revisit the
   priority if auto-approval is ever enabled: `autoAllowBashIfSandboxed` defaults
   to `true`, so enabling the sandbox and enabling auto-approval are the same
   decision unless it is explicitly set to `false`.
5. **Cross-check CLI mode trusts the provider sandbox, not our hooks.** The
   `cross-check` skill's opt-in Mode B (`--deep`) shells an external provider CLI
   (`codex exec --sandbox read-only -c approval_policy='"never"' …`) so a non-Claude
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
6. **The subagent read-only git allowlist is still a string gate (new in §7.3).**
   Two honest consequences of replacing the blanket subagent-git deny with an
   allowlist:
   - **Indirection is unchanged but now matters more.** Residual #1 already meant
     a subagent could reach git through `bash script.sh` / `eval` / `$G push`.
     That was true before §7.3 too — the blanket deny never saw those either — so
     this is not a new hole, but the surface is worth naming again: the allowlist
     grants nothing to an indirect invocation, and blocks nothing there either.
   - **A mis-parsed read form is now a possible false-ALLOW.** Before §7.3 a
     parsing bug in the git argument scanner could only cost a false deny. Now a
     write form that the scanner mis-reads as a read form would be *allowed* —
     bounded to the read/write subcommands listed above (`branch`, `tag`,
     `stash`, `remote`, `worktree`, `config`, `reflog`, `notes`, `bisect`,
     `symbolic-ref`), since every other subcommand must appear
     verbatim on the allowlist to pass at all. The blast radius therefore
     excludes `push`/`commit`/`reset`/`clean`/`checkout`/`rebase`/`merge`, which
     can never be reached by an arg-parsing mistake. **Mitigations:** the
     allowlist shape (unknown ⇒ deny), the golden fixtures in
     `tests/contract/test_governance_verdicts.sh`, the categorical fallback in
     the hook, and the unchanged main-agent approval gate on the same operations.
   - **ACCEPTED RESIDUAL — the policy boundary is a raw string, not argv.** The
     gate splits and tokenizes the command *text* with shell-parameter
     expansion; it never sees the argv the kernel will actually receive. So
     quoting, backslash escapes, `$IFS` games, and glob expansion can in
     principle separate what the gate reads from what git runs (e.g. a quoted
     `"--out""put=/tmp/f"`, or a pathspec that a later expansion turns into a
     flag). The cross-provider review recommended moving the boundary to
     tokenized argv, or rejecting every shell metacharacter outright.
     **Decision: not now — accepted, not closed.** Both options are a redesign of
     the gate rather than a hardening of it: real argv requires intercepting at a
     different layer than PreToolUse text, and a blanket metacharacter rejection
     would deny most legitimate worker reads (quoted `--grep` patterns, globs,
     `--` pathspecs) and push workers toward `bash -c`, i.e. residual #1, which
     is strictly worse. This is the same "floor, not sandbox" trade the rest of
     this document documents. **Mitigations:** command/process substitution is
     already rejected against the raw string; unknown ⇒ deny bounds the blast
     radius as above; the main-agent approval gate is unchanged. **Revisit if:**
     a structured-argv PreToolUse payload becomes available from the host, or
     subagent auto-approval is ever enabled.

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
subagent-git-mutation-deny, (governance) governance-file self-protection, (DAG)
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

> **Floor housing + honest residuals (Claude Code reference adapter).**
> - **"Root-anchored" describes the *wiring*, not the file location.** All four
>   PreToolUse guarantees are wired from **`.claude/settings.json` at the repo
>   root** — the single source of truth, and what makes them undisableable (a
>   plugin can be `/plugin disable`d; a root hook cannot). Three guard *scripts*
>   (`protect-governance-files.sh`, `subagent-git-guard.sh`, `git-safety-gate.sh`)
>   physically live under `plugins/loom-governance/hooks/scripts/` but run because
>   the **root** wiring invokes them by path. Consequence worth knowing:
>   **uninstalling `loom-governance` (removing the files, not merely disabling it)
>   would leave the root wiring pointing at missing scripts** — those hooks would
>   then error non-blocking and the floor would silently thin. Moving the three
>   into `.claude/hooks/` so the floor is self-contained is the durable fix
>   (deferred). A per-plugin `hooks/hooks.json` must **never** be a second wiring
>   source. `loom-governance` used to ship one, in an **undocumented flat-array
>   shape** (`{hooks:[{event,matcher,command}]}`) that Claude Code's canonical
>   schema (object keyed by event, `hooks:[{type,command}]`) does not define; it
>   has since been deleted (see *Disposition* below).
>
>   **Settled empirically 2026-08-24 (LOOM-0032) — confirmed inert, and for a
>   blunter reason than the shape.** A per-plugin `hooks/hooks.json` is never read
>   in this repo *at all*. Claude Code loads plugin hooks from
>   `~/.claude/plugins/*/hooks/hooks.json` — i.e. from **installed** plugins — and
>   LogicLoom's `plugins/` tree is not a plugin installation: the repo ships no
>   `.claude-plugin/marketplace.json`, and no `loom-*` plugin appears in
>   `~/.claude/plugins/installed_plugins.json` or in `enabledPlugins`. The tree is
>   consumed only by `sync-plugin-commands.sh`, which bridges **commands** into
>   `.claude/commands/` and has no equivalent path for hooks. The shape mismatch is
>   real but secondary — the file is never opened, so it could not fire even in the
>   canonical shape.
>
>   Observational confirmation on the `loom-orchestrator` twin: its
>   `Stop`/`SubagentStop` wiring left `.logic-loom/logs/subagent-activity.log` at a
>   single line dated 2026-06-14 across ~98 subagent completions logged in the
>   session transcripts through 2026-08-24, while the hook script itself writes
>   correctly when invoked directly. Registration, not the script, was the failure.
>
>   **Disposition.** `loom-orchestrator/hooks/` was **deleted** (nothing consumed
>   the log; a live `Stop` hook would append an `agent=unknown` line every
>   main-agent turn forever), along with its contract assertions. The floor is
>   unaffected: it holds because **root** wires the three guard scripts by path.
>   `loom-governance/hooks/hooks.json` was dead weight for the same reason and
>   **has since been removed** (commit `773d0ae`); `plugins/loom-governance/hooks/`
>   now contains only `scripts/`. No `hooks.json` remains anywhere in the tracked
>   tree. Its contract test no longer
>   asserts the file's existence; `test_plugin_lifecycle.sh` now asserts the thing
>   that is actually load-bearing — that each guard script exists **and** is wired
>   from `.claude/settings.json` — which is also the check that catches root wiring
>   left pointing at a missing script.
> - **`guard-dangerous-commands.sh` — bash<4 fail-open is CLOSED.** Previously the
>   policy lib needed bash 4+ (associative arrays, `declare -g`) while macOS ships
>   3.2, so the dangerous-command policy was silently **unenforced** on stock
>   macOS. `logging.sh` and `policy.sh` are now bash 3.2 compatible (`LOG_LEVELS`
>   is a `case`; the unused `POLICY_CACHE` was removed; `declare -g` → plain
>   top-level assignment), and the hook no longer gates on `BASH_VERSINFO`.
>   Verified on `/bin/bash 3.2.57`: `rm -rf /` → `deny`, force-push to main →
>   `deny`, `ls -la` → `allow`, in both CLI and PreToolUse modes. A re-exec into
>   bash 4+ is retained as belt-and-braces when one is installed, but is no longer
>   load-bearing. **Remaining fail-open is narrow**: a missing/unsourceable policy
>   file or an absent `validate_tool_call` — genuine breakage, not a supported
>   configuration. A `/governance-health` self-test is still the intended loud
>   signal for those.

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

| Host         | L1 policy | git-gate (VI)    | subagent-mut-deny   | gov-file protect | freeze-scope (DAG) |
|--------------|-----------|------------------|---------------------|------------------|--------------------|
| Claude Code  | followed  | ENFORCED (hook)  | ENFORCED (agent_id) | ENFORCED (hook)  | ENFORCED (hook)    |
| Codex CLI    | followed  | adapter†         | followed            | followed-only\*  | followed-only\*    |
| Cursor       | followed  | adapter†         | followed            | followed-only\*  | followed-only\*    |
| Gemini CLI   | followed  | adapter†         | followed            | followed-only\*  | followed-only\*    |
| Copilot      | followed  | adapter†         | followed            | followed-only\*  | followed-only\*    |
| Aider        | followed  | adapter† (git-hook) | followed (no subagents) | followed-only\* | followed-only\* |

\* the host HAS a pre-tool-use mechanism that COULD host an adapter, but **no
conformant adapter ships today**, so the cell is "followed-only" until one passes
the golden fixture. `subagent-mut-deny` is "followed" everywhere but Claude Code
because `agent_id` is a Claude-internal signal no other host emits.

**Project mandates (`amendments.md`) are `followed` in every column, by
decision — including Claude Code.** They deliberately have no row above, because
a mandate is not an enforcement surface on any host: nothing loads
`.logic-loom/memory/amendments.md`, nothing validates a mandate, nothing fails
closed, and no floor hook consults one. Wiring it into `governance-preflight.sh`
was **considered and declined (2026-08-24)** — this is a settled position, not a
missing adapter, and it should not be read as a gap awaiting Phase 3. The reason
is the same one that produced the fail-open rule elsewhere in this document: a
loader would raise the *appearance* of enforcement without moving a single
verdict, since the hook floor would still never consult a mandate. That is a
phantom gate. A fork gets a file upstream never overwrites, a mandate grammar,
and reader-adjudicated composition rules; it does not get injection, validation,
warning, or any change to `deny`/`ask`/`allow`. See
`.logic-loom/memory/constitution.md` § *Project Amendments* → *What this
mechanism is not: there is no loader*.

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
> **Protected-path floor (fixed) + config additions (additive-only).** The
> protected set is now EXTENSIBLE, because hardcoding `.logic-loom/…` and
> `plugins/loom-governance/…` meant a fork that renamed those directories got a
> **silently broken** governance-file guard — no error, no protection. The shape
> of that extensibility is the whole security question, and the answer is
> deliberately one-directional:
> - **The built-in floor cannot be removed.** `protected_paths` in
>   `governance.conf` may only ADD paths. There is no removal, override, reset, or
>   negation syntax — the parser appends and nothing else, so no config file can
>   express a removal. The floor is checked FIRST and never consults config.
> - **Why it must be one-directional.** The protected set contains
>   `governance.conf` itself and the verdict lib. A REPLACEABLE set would let a
>   fork — or the model — drop those two entries and then rewrite every hook, the
>   constitution, and the lib unopposed. That is privilege escalation dressed as
>   portability. Additive-only bounds the worst case to protecting *too much*:
>   loud, obvious, and undone by deleting a line.
> - **Fail-safe, never fail-open.** Missing, unreadable, or malformed config
>   leaves the floor standing alone; invalid entries are skipped individually. No
>   code path lets a config problem reduce protection.
> - **Entries are literals, not globs.** Matching uses a QUOTED `case` pattern, so
>   `*`/`?`/`[`/`]`/`\` are never interpreted; entries containing them (beyond an
>   optional trailing `/*`, which is spelling for "and everything beneath"),
>   absolute paths, `~`, and `..` segments are ignored. A literal cannot be
>   crafted to match less than it appears to.
> - **Renames self-protect.** Half the floor is derived from the verdict lib's own
>   file location, so a fork using `.specify/` gets its `lib/`,
>   `config/governance.conf`, and `memory/constitution.md` protected with zero
>   configuration; `protected_paths` covers whatever else it moved.
> - **Enforced status is unchanged.** This widens *what* is protected and *who can
>   widen it*; it does not change the `deny`/`ask`/`allow` verdicts or the matrix
>   cells. The invariant is pinned by fixtures in
>   `tests/contract/test_governance_verdicts.sh` (floor holds with no config, an
>   empty key, every removal attempt the syntax permits, and a malformed file).
>
> **Floor-integrity hardening (post-gate-review).** Because the verdict lib is now
> load-bearing, it is itself in the protected set (`loom_path_is_protected` covers
> `.logic-loom/lib/governance-verdicts.sh` + `policy.sh`) — a subagent cannot blank
> it to disarm the git gates. And the two git hooks **fail SAFE, not open**, if the
> lib is ever absent: `subagent-git-guard` falls back to denying ALL subagent git inline (categorical — the §7.3 read-only allowlist is deliberately not duplicated there) and
> `git-safety-gate` still asks on a mutating git inline (verified). The off-host
> adapter likewise fails CLOSED (refuses all git when it cannot classify).
>
> `adapter†` = a conformant adapter ships and passes the golden fixtures;
> enforcement is real **once the host installs it** (opt-in), versus Claude
> Code where it is always-on via hooks.
