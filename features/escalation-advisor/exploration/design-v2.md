# Design v2: tiered workers, side sessions, and hook-delegated approval

**Feature**: `escalation-advisor` · **Type**: exploration / design (revision 2) · **Date**: 2026-10-10
**Supersedes**: `design.md` §A-§H where they conflict (the non-Claude WORKER default in `design.md:88-126` is withdrawn per D7; the ladder, advisor and cadence material stands).
**Inputs**: `design.md` + addenda (`:212-234`), `bakeoff/README.md`, `mods-proof/README.md`, `ORCA-HANDOFF.md`, `vision.md`; maintainer decisions D1-D7; today's live trial; `~/.claude/CLAUDE.md:60-175`; Claude Code 2.1.290 docs (hooks, mods reference/events, sub-agents, agent-teams, headless, permissions).

---

## Summary for the business owner (one sentence each)

- Every working session will have the same shape: one senior AI plans and checks, and hands pieces to cheaper helpers sized to the job — a quick checker, a builder, or a deep thinker.
- The AI will be able to open a private "side desk" — a separate copy of the project on its own branch — run a second full session there, give it instructions, read its results, and tidy up afterwards.
- Today every one of those branch and copy operations stops to ask you; this design lets the harness approve them itself, but only when it can *prove* from the repository's own records that the operation is safe and belongs to this process.
- The proof is mechanical, not an AI's opinion: a reserved name, a reserved folder, a clean copy, and work already merged or recorded — anything it cannot prove still asks you.
- Nothing that could leave the building (pushing code, rewriting history, changing credentials, repository settings) changes at all; those still ask every time, and no setting can silence them.
- One line in a config file turns the whole self-approval off and returns to asking for everything.
- Every self-approved step is written to a log you can read, and a test table (including deliberately hostile cases) must pass before any of it is called "enforced".
- Outside models (Codex, Gemini) stay reviewers, because the bake-off showed the Codex build was clearly worse than the Sonnet build on spec-heavy work (`bakeoff/README.md:35-36`, `:71-73`).
- The cheap checker tier (Haiku) is worth it only if each request stays under about 100k tokens; today's measured starting context (65-88k) is close to that line, so the design names the knobs that keep it under.
- Your personal setup and the shipped product carry the same rules; LogicLoom never edits your personal files — you or the main session does, with your approval.

---

## 0. Ground truth (what exists today)

- **Gate today.** `git worktree add/remove/...` and any branch create/delete/rename are `ask` (`gate-policy.conf:148-156`); classification at `governance-verdicts.sh:1299-1301`, verb list `:61-65`. The FLOOR is five ops (`:970`; `gate-policy.conf:90,95,217-225`) and config cannot silence them (`:1107-1117`, refusal `:1182-1185`). `commit/add/fetch/checkout` are already silent (`gate-policy.conf:167-208`).
- **Subagents.** Any `agent_id` → mutating git denied, allowlisted reads only (`subagent-git-guard.sh:14-22`, verdict `governance-verdicts.sh:522-529`); gate policy never applies to subagents (`:954-957`). Docs: `agent_id` is present "inside a subagent, teammate, or `--agent` session" — a top-level `claude -p` session has none, so a side session's main agent is a *main agent* to the hooks.
- **Hook wiring.** All PreToolUse Bash hooks run from `.claude/settings.json:63-87` with 3000 ms timeouts; the verdict lib is pure (no I/O, `governance-verdicts.sh:16-20`) and is the conformance seam (`governance-threat-model.md:426-433`).
- **Hook semantics (docs, 2.1.290).** PreToolUse `allow` "skips the permission prompt"; multiple hooks combine `deny > defer > ask > allow`; "Deny and ask rules are still evaluated regardless of what the hook returns". Prompt/agent hooks on PreToolUse return `{ok}` only — `ok:false` denies, `ok:true` allows; they cannot return `ask`. A mod's `tool.check` "can approve a call that a hook in [project settings] blocked"; deny rules hold over a mod only under managed settings or a Team/Enterprise login.
- **Worktrees.** `.claude/worktrees/` is gitignored (`.gitignore:183-184`) and is Claude Code's own default worktree directory (docs example path `…/.claude/worktrees/feature-auth`). `WorktreeCreate/Remove` hooks fire only for `--worktree`, `isolation: worktree`, and background sessions — not for a Bash `git worktree add` — so they are not the mechanism here. `worktree-port-namespace.sh:43-65` already indexes worktrees and writes `.loom-worktree-env` (`:78-86`).
- **Headless.** `-p` "runs the hooks in a project's `.claude/settings.json`… even in a folder you've never trusted" (confirmed live today); `--bare` skips hooks and CLAUDE.md, so it is *not* acceptable for a governed side session. `--resume <id>` works from any directory (v2.1.223+); `--output-format json` returns `session_id` and `total_cost_usd`. `--allowedTools` uses permission-rule syntax (`Bash(git commit *)`). `--permission-prompts none` denies anything that would prompt. Agent teams do not spawn in `-p`.
- **Trial.** Worktree + `-p` + `--resume` + both hooks firing + Haiku correct in 24 s + 65-80k tokens/request; the session is invisible to the desktop app; no start-session tool exists there (given).
- **Personal ladder.** Three tiers (`~/.claude/CLAUDE.md:74-81`), cadence (`:139-143`), "Mutation is always a worker's job" (`:68`, rejected for the shipped product by `vision.md:89-94`). Memory rule: branch create/switch/delete need explicit approval (`vault/.brain/memory/shared/git-branch-ops-need-approval.md:11-15`).

---

## A. What ships in LogicLoom v1

| Path | New/changed | Purpose | Enforced / followed | Protected? |
|---|---|---|---|---|
| `.docs/policies/escalation-policy.md` | NEW | Rubric, four rungs, cadence (D3), **three worker tiers with the tier rule (D2)**, side-session lifecycle (§B), delegated-approval contract (§C) in prose | FOLLOWED | no |
| `AGENTS.md` Tier 1 | changed | "Escalation Disposition" paragraph (≤12 lines: two axes, four rungs, tier rule, cadence) beside the Cross-Check Disposition (`AGENTS.md:108-110`); Tier 2 rows for `advisor`, `checker`, `reviewer` next to `:243-244` | FOLLOWED | no (tandem-tested) |
| `CLAUDE.md` | changed, **short** | Same paragraph verbatim under Standing policies; one row each in the hooks table and the ladder section (`:599-626`) pointing at the policy doc; `models.conf` reference line | FOLLOWED | no |
| `tests/contract/test_disposition_tandem.sh` | changed | Asserts the Escalation paragraph is byte-identical in AGENTS.md, CLAUDE.md, policy doc | ENFORCED (CI) | no |
| `.claude/agents/advisor.md` | NEW | Adversarial second opinion; Read/Grep/Glob; `model: inherit`; `effort: medium` | FOLLOWED | no |
| `.claude/agents/checker.md` | NEW | Haiku check-and-report (D2): `model: haiku`, tools Read/Grep/Glob/Bash, `omitClaudeMd: true`, `maxTurns: 25`, no Agent tool; body says what it may not touch | FOLLOWED (tier) / hooks still ENFORCE git+paths | no |
| `.claude/agents/reviewer.md` | NEW | Phase reviewer over a combined diff; Read/Grep/Glob/Bash(read-only); `model: opus`, `effort: high` | FOLLOWED | no |
| `.claude/agents/fast-worker.md`, `deep-reasoner.md` | unchanged | Sonnet builder (`fast-worker.md:8-15`), Opus reasoner (`deep-reasoner.md:8-14`) | — | no |
| `.logic-loom/config/models.conf` | changed | Roles `LOOM_MODEL_ADVISOR = inherit`, `LOOM_MODEL_CHECKER = haiku`, `LOOM_MODEL_REVIEWER = opus` (exists `:46`), `LOOM_MODEL_WORKER = sonnet` (from `opus`, `:45`); tier IDs `:50-54` refreshed to current flagship names; `:66` kept ("never workers") per D7. Stays documentary (`:1-6`). | FOLLOWED | no |
| `.logic-loom/scripts/bash/side-session.sh` | NEW | The side-session helper (§B): `create`, `start`, `send`, `read`, `status`, `open-hint`, `cleanup`, `list`, `gc`. **Runs no mutating git itself** — it prints the canonical git command for the main agent to run, so every mutation passes the hook (see §C.4) | helper FOLLOWED; the git it emits ENFORCED by the gate | **yes** (added to `governance.conf protected_paths`, additive `:23-48`) |
| `.claude/worktrees/side-ledger.jsonl` | NEW (runtime) | The ledger (§B.7); machine-local, inside the gitignored dir | data, agent-writable (see §C.5) | no |
| `.logic-loom/lib/side-session-facts.sh` | NEW | Gathers git facts for one owned-op request (branch exists / merged / clean / checked out elsewhere / reflog creation / path realpath / ledger state) and prints them as key=value; the only place git runs during a verdict | ENFORCED (input to verdict) | **yes** |
| `.logic-loom/lib/governance-verdicts.sh` | changed | New ops `git.worktree.owned`, `git.branch.owned`; `_loom_seg_git_op` emits them only when `loom_side_owned_ok <op> <facts>` (pure, table-tested) holds; `side.delegated-approval` kill switch; postures updated (`:1406-1420`) | ENFORCED | **yes** (floor `:822`) |
| `.logic-loom/config/gate-policy.conf` | changed | Lines `git.worktree.owned = silent`, `git.branch.owned = silent`, `side.delegated-approval = on`, with commentary; `strict` posture sets all three to ask/off | ENFORCED (read by lib) | **yes** (floor `:820`) |
| `plugins/loom-governance/hooks/scripts/git-safety-gate.sh` | changed | Calls the facts lib before the verdict; appends one audit line per auto-allowed owned op to `.logic-loom/logs/operations/<date>.log` (`logging.sh:24-25`); timeout in `settings.json:79` raised 3000→5000 ms | ENFORCED | **yes** |
| `.claude/settings.json` | changed (one number) | The timeout above | — | **yes** |
| `tests/contract/test_side_owned.sh` | NEW | Table-driven allow/ask/deny fixtures incl. hostile rows (§C.7); `test_gate_policy.sh` table (`:56-60`) gains the two ops and the switch | ENFORCED (CI) | no |
| `tests/contract/test_side_session.sh` | NEW | Helper subcommands against a temp repo: create/ledger/status/cleanup rules, crash recovery, `gc` | ENFORCED (CI) | no |
| `.docs/architecture/governance-threat-model.md` | changed | Residuals #9-#11 (§F) and a matrix note | FOLLOWED (doc) | no |
| `.docs/architecture/orchestrator-worker-ladder.md` | changed | Ladder rows for advisor/checker/reviewer; side-session section; §115-127 kept (D7) | FOLLOWED | no |
| `plugins/loom-maintenance/updates/7.x/escalation-ladder.md` + `.check.sh` | NEW | `/update-loom` note: done-when = policy doc, three agents, ops present, tests green | ENFORCED by note linter | no |

Not shipped in v1: a mod (status pane, fan-out, `agent.spawn` routing), Orca, any non-Claude worker, the delegation watcher, gateway routing, any write to `~/.claude/`.

---

## B. Side-session lifecycle (exact terms)

1. **Naming.** Branch `side/<id>`, `<id>` = `[a-z0-9-]{1,40}` chosen by the helper (`<topic>-<4 hex>`), e.g. `side/trial-1`. Worktree `<repo-root>/.claude/worktrees/side-<id>` — the directory git ignores (`.gitignore:184`) and Claude Code already uses. Anything else is not process-owned.
2. **Base.** Always the current branch's `HEAD` sha in the directing checkout (D5). The helper records `base_branch` and `base_sha`. Canonical create command (one segment, no other flags): `git worktree add -b side/<id> .claude/worktrees/side-<id> HEAD`.
3. **Create.** `side-session.sh create <topic>` → validates, prints the canonical command + the follow-up `side-session.sh register <id>`; the main agent runs the git command (hook decides — §C), then `register` writes the ledger row (`state: created`). `.worktreeinclude` is not processed on a Bash `git worktree add`; the helper copies nothing — a side session that needs `.env` gets it from the brief, never by copying secrets.
4. **Start / send / read.** `start <id> "<brief>" [--model <tier>]` runs, with cwd = worktree:
   `claude -p "<brief>" --model <model> --output-format json --permission-mode acceptEdits --permission-prompts none --allowedTools "<list>" --append-system-prompt-file <side-brief.md>` and stores `session_id` + `total_cost_usd` in the ledger (`state: running` → `idle`). `send <id> "<text>"` = same flags + `--resume <session_id>` (verified today). `read <id>` prints the last result and `git -C <wt> log --oneline <base_sha>..HEAD` + `diff --stat`. The brief file states: you are a full orchestrator on branch `side/<id>` in `<wt>`; commit on this branch; never push; never leave this directory; never create worktrees or branches; report a summary and the commit range.
   `--allowedTools` for a side session: `Read,Edit,Write,Grep,Glob,Agent,Bash(git status *),Bash(git diff *),Bash(git log *),Bash(git add *),Bash(git commit *),Bash(git show *),Bash(git rev-parse *)` plus the project's test runner(s) by prefix (`Bash(npm test *)`, `Bash(bash tests/*)`). Never `--dangerously-skip-permissions`; never `bypassPermissions`. Anything that would prompt is denied (`--permission-prompts none`), so inside a side session `push` (FLOOR), branch/worktree writes (`ask`), `clean/reset --hard` (`ask`) all become denials without a human. That is what makes "headless" safe: the gate's `ask` *is* a deny there.
5. **What it inherits.** Hooks (the worktree is a checkout, so `.claude/settings.json` is present — both hooks fired today), project `CLAUDE.md`, the user's `~/.claude/CLAUDE.md` and user hooks (`-p` loads the same context as interactive unless `--bare`). It does **not** get the desktop app's session registry or the main session's conversation. Output style: not inherited by subagents (docs); for a `-p` session it is unverified — the brief file carries the needed instructions instead.
6. **What comes back.** Commits on `side/<id>`. The directing session reads the diff (`read`), reviews it at the rung, and either (a) cherry-picks/merges into the directing branch — `merge` is `ask` (`gate-policy.conf:103`), `cherry-pick` is silent (`:193`) — or (b) records "harvested" with the tip sha. Merging to anything shared stays the user's call through `/git-push`.
7. **Ledger** (`.claude/worktrees/side-ledger.jsonl`, one JSON object per event, append-only): `id, branch, path, base_branch, base_sha, created_by_session, created_at, session_id, model, state (created|running|idle|harvested|abandoned|removed), tip_sha, cost_usd, last_event_at`. `status` folds events into one row per id. `list` prints it.
8. **Concurrency.** Default max 3 live side sessions per checkout (helper refuses a 4th; `LOOM_SIDE_MAX`). One side session per `<id>`; no two side sessions share files unless the briefs say so (the vision's non-overlap rule `vision.md:60-62`). Port namespace comes free from `worktree-port-namespace.sh:68-71`.
9. **Depth.** Side sessions may spawn subagents but **not** side sessions: the owned verdict allows only when the hook's `cwd` is the main checkout (first entry of `git worktree list --porcelain`, as `worktree-port-namespace.sh:50` already parses), so from inside a worktree the op stays `ask` → denied headless. Depth = 1, enforced.
10. **Crash / stale.** `gc` reconciles ledger vs `git worktree list --porcelain` vs `git branch --list 'side/*'`: a worktree with no ledger row → reported, never removed; a ledger row whose path is gone → `state: removed`; a `running` row older than `LOOM_SIDE_STALE_HOURS` (default 24) → `idle` with a warning; a prunable entry (`git worktree list` marks it) → the helper prints `git worktree prune` (an `ask` op; stays ask). `gc` writes only the ledger.
11. **Cleanup rules.** `cleanup <id>` prints, in order: `git worktree remove .claude/worktrees/side-<id>` then `git branch -d side/<id>`, each judged by the owned verdict (§C.3). It refuses to print `--force`/`-D` ever; a dirty or unmerged side branch stays until the user harvests or says "abandon" (then `state: abandoned`; the branch is still only deletable with `-D`, which stays `ask`). Before printing, the helper runs the vault rule's check for worktree-bound services (processes/launchd plists pointing into the path, `shared/worktree-bound-services.md:15`) and warns.
12. **Visible on request.** Terminal (template users): `open-hint <id>` prints `cd <wt> && claude --resume <session_id>`; resuming interactively takes over the transcript (the headless run has ended, so there is no contention). Desktop: the app cannot see `-p` sessions (observed) and has no start-session tool here; `open-hint` prints the same command plus, when a task-chip tool is available, offers a chip whose prompt is "run `claude --resume <id>` in `<wt>` and continue" — the chip opens its own fresh worktree (observed), so this is a hand-off, not a window onto the side session. Honest status: one-click open in the desktop app is **not achievable with verified tools today** (H5).
13. **Must not.** Push; `fetch` (silent for a main agent `:208`, but a side session's allowlist omits it); touch another worktree or the main checkout; create branches/worktrees; run `gh`; read secrets outside its tree; spawn side sessions.

---

## C. The delegated-approval hook (D6)

### C.1 Options

**(1) Deterministic ownership check in the existing gate.** New verdict ops `git.worktree.owned` / `git.branch.owned` returned by classification *instead of* `git.worktree.write` / `git.branch.write` only when every verifiable condition holds; default `silent`; otherwise the ordinary op and `ask`.
**(2) Model-evaluated hook.** A `type: prompt` or `type: agent` PreToolUse hook, or a mod `tool.check`, where a model judges each request.
**(3) Hybrid.** (1) for allow; a model only to turn an `ask` into a better-worded question, never into an allow.

### C.2 Analysis

| Concern | (1) deterministic | (2) model-evaluated | (3) hybrid |
|---|---|---|---|
| Self-approval | None: the requester (model) and the approver (shell over git facts) are different kinds of thing; the facts come from git, not from the prompt | Same lineage requests and approves; the hook model reads `$ARGUMENTS` the requester shaped — prompt-injection by construction | Allow path as (1); the model never allows |
| Confused/hostile agent | Can only get allow by making the facts true (reserved name, clean, merged) — which is the safe state anyway | Can be talked into `ok:true`; prompt hooks cannot even return `ask`, so a mistake is an allow, not a question | As (1); the model can only reword |
| FLOOR | Untouched: `LOOM_GATE_FLOOR_OPS` (`:970`) is not consulted by the new ops; `push` etc. still classify to their own ids | A prompt/agent hook's `ok:true` combines with the gate by `deny > ask > allow`, so the FLOOR's `ask` still wins — but a mod's `tool.check` can override a project hook's `ask` | As (1) |
| Subagent guard | Unchanged: verdicts for `agent_id` never read gate policy (`:954-957`) → subagents still denied; a side session's *main* agent has no `agent_id` and is judged as main — but depth=1 (§B.9) keeps owned ops `ask` inside worktrees | Same | Same |
| bypassPermissions | `mode.bypassPermissions` stays `enforce` (`gate-policy.conf:311`); owned ops are `silent` by policy, so mode is irrelevant to them; `relax` would silence the *un*-owned forms too — unchanged risk, documented | Same | Same |
| Mods override | A user-installed mod can approve what a project PreToolUse hook blocked (docs). True for every verdict today — new residual #9, not new to this design | Worse: a mod could also *be* the judge | As (1) |
| Testability | Pure function over facts → golden fixtures (`threat-model.md:426-433`) | Non-deterministic; cannot be fixture-tested; `agent` hooks are "experimental" (docs) | (1) testable; model path advisory only |
| Latency | ~5 git probes, well inside 5000 ms | 30-60 s default timeouts per call | (1) latency |

**Recommendation: (1).** Ship (1) alone in v1; defer (3)'s reword-only model step (it adds a model call to every `ask` for cosmetic benefit). Reject (2): the maintainer's phrase "evaluated and decided by you" is satisfied by a decision procedure *the harness* runs; a model judging its own request is the self-review-in-lineage problem the Cross-Check Disposition already names (`AGENTS.md:110`).

### C.3 Exact conditions (all must hold; any failure → the ordinary op → `ask`)

Common: `side.delegated-approval = on`; the Bash command is a single segment (no `;`, `&&`, `||`, `|`, newlines, backticks, `$(`), with no env assignment or `-c`/`--git-dir`/`--work-tree` global (reuse rules 3-6 of `governance-verdicts.sh:243-260`); hook `cwd` is the main checkout; `.claude/worktrees` is ignored (`git check-ignore -q .claude/worktrees`); the path operand is literally `.claude/worktrees/side-<id>` and `realpath -m` of it is under `<main-checkout>/.claude/worktrees/` with no symlink in any component (`.claude` and `worktrees` both `! -L`); branch operand matches `^side/[a-z0-9-]{1,40}$` and `<id>` equals the path's suffix.

`git worktree add -b side/<id> .claude/worktrees/side-<id> HEAD` → `git.worktree.owned` iff: exactly those tokens (`-b` present, start point `HEAD`, no `-B`/`--force`/`--detach`/`--lock`/`--orphan`/`--track`); branch does not exist; path does not exist.

`git worktree remove .claude/worktrees/side-<id>` → `git.worktree.owned` iff: no `--force`/`-f`; path is listed by `git worktree list --porcelain` **and** its `branch refs/heads/side/<id>` line matches; `git -C <path> status --porcelain --no-optional-locks` is empty (no modified, staged, or untracked files); the branch tip is reachable from the directing branch or from `base_branch` (`git merge-base --is-ancestor side/<id> HEAD` or `... <base_branch>`), **or** the ledger row is `harvested` with `tip_sha == $(git rev-parse side/<id>)` — ledger alone is never enough (see C.5); the reflog's first entry for the branch reads `branch: Created from HEAD` (`git reflog show --format=%gs side/<id> | tail -1`) — a user branch renamed into the namespace fails this (its oldest entry is the original creation on another name, and the rename itself was an `ask`).

`git branch -d side/<id>` → `git.branch.owned` iff: `-d` not `-D`/`--force`/`-M`/`-m`; branch is not the current branch and is checked out in no worktree (`git worktree list --porcelain` has no `branch refs/heads/side/<id>`); merged/harvested as above; reflog creation as above. Branch *creation* via bare `git branch side/x` and any rename stay `ask` — creation is only owned through the `worktree add -b` form.

`git worktree prune|move|lock|unlock|repair` → never owned (`ask`).

### C.4 Why the helper emits commands instead of running them
A hook cannot see git inside a script (residual #1, `threat-model.md:124-127`). If `side-session.sh` ran `git worktree add` itself, the only thing the gate would judge is `bash side-session.sh create`, and the actual mutation would be invisible — the design would *weaken* the floor while claiming to extend it. Emitting the canonical command keeps every mutation hook-visible, keeps the verdict lib pure (facts gathered by the hook adapter, decision by a pure function), and means the owned verdict works for a human typing the same command.

### C.5 Ledger tamper-resistance (stated plainly)
The ledger is an agent-writable file in a gitignored directory; nothing stops a worker or the main agent from writing any row. Therefore the verdict never lets the ledger *loosen* a condition: creation needs no ledger; removal's safety facts (listed in git's worktree table, clean, merged-or-reachable, created-from-HEAD reflog, not checked out) all come from git. The ledger adds exactly one thing — the `harvested + tip_sha` alternative to "merged" — and that alternative still requires the tip sha to match git, so a forged row can at most delete a *clean* side branch whose commits are recorded in the row (and in reflog for ≥30 days). The hostile cases that matter (deleting a dirty tree, an unmerged user branch, the current branch, forcing) are closed by git facts, not by the ledger. Cross-checks used: `git worktree list --porcelain`, `merge-base --is-ancestor`, `reflog show`, `status --porcelain`, `check-ignore`, `realpath`.

### C.6 Audit trail and kill switch
Per auto-allowed op the gate appends: `<ts> side-owned ALLOW <op> branch=<b> path=<p> base=<sha> clean=1 merged=1|harvested reflog=created-from-HEAD cwd=main` to `.logic-loom/logs/operations/<date>.log` (`logging.sh:24-25`), and emits `permissionDecisionReason` even on allow so it shows in the transcript. Kill switch: `side.delegated-approval = off` in `gate-policy.conf` → classification never emits an owned op; both owned lines also accept `ask` individually. `strict` posture = off/ask; `balanced` = on/silent; `minimal` = on/silent (`loom_gate_posture_body`, `governance-verdicts.sh:1406-1420`). An unknown value → `off` (fail-safe, matching `:946-952`).

### C.7 Test fixtures (table-driven; must be green before "enforced")

| # | Command / state | Expected |
|---|---|---|
| 1 | canonical `worktree add -b side/a .claude/worktrees/side-a HEAD`, clean repo | allow (`git.worktree.owned`) |
| 2 | same with `--force` / `-B` / `--detach` / start point `main` | ask |
| 3 | `-b side/a .claude/worktrees/side-b HEAD` (id mismatch) | ask |
| 4 | `-b sides/a …`, `-b side/A …`, `-b side/../x …`, id > 40 chars | ask |
| 5 | path `.claude/worktrees/../../side-a`, absolute path, `/tmp/side-a` | ask |
| 6 | `.claude/worktrees` replaced by a symlink to `/tmp` | ask |
| 7 | `.claude/worktrees` not gitignored (line removed) | ask |
| 8 | branch `side/a` already exists | ask |
| 9 | command `cd x && git worktree add …`, or `VAR=1 git worktree add …`, or `git -c k=v worktree add …` | ask |
| 10 | run with hook `cwd` = a side worktree (nesting) | ask |
| 11 | `side.delegated-approval = off` | ask |
| 12 | `worktree remove side-a`, clean, merged into HEAD | allow |
| 13 | remove, clean, unmerged, ledger `harvested` with matching tip | allow |
| 14 | remove, clean, unmerged, ledger `harvested` with wrong tip / no row | ask |
| 15 | remove, one untracked file | ask |
| 16 | remove with `--force` | ask |
| 17 | `branch -d side/a` while checked out in its worktree | ask |
| 18 | `branch -D side/a` | ask |
| 19 | user branch `feature/x` renamed to `side/x` (reflog oldest entry not "Created from HEAD") | ask |
| 20 | `branch -d side/a` where `side/a` is the current branch | ask |
| 21 | any owned-shaped command with `agent_id` set | deny (unchanged) |
| 22 | `git push origin side/a` | ask (FLOOR, unchanged) |
| 23 | `gate-policy.conf` sets `git.push = silent` alongside the new lines | refused as today (`test_gate_policy.sh` §3) |
| 24 | facts lib missing / git probe times out | ask (fail-safe) |

### C.8 "But also for the above etc." — every routine operation this process introduces

| Operation | Verdict |
|---|---|
| Starting / resuming a headless side session (`claude -p …` via Bash) | **already silent** — not git; ordinary Bash permission. The helper is on the protected list so its flags can't be silently loosened; `Bash(bash .logic-loom/scripts/bash/side-session.sh *)` may be allowlisted by the user |
| Committing inside an owned worktree (side session's own commits) | **already silent** (`git.commit = silent`, `gate-policy.conf:167`) and allowlisted in §B.4 |
| `git add`, `status`, `diff`, `log` in the worktree | already silent / reads |
| Fetching from the directing session | already silent (`:208`); omitted from a side session's allowlist |
| Creating the owned worktree+branch | **needs the owned verdict** |
| Removing the owned worktree, deleting the owned branch after harvest | **needs the owned verdict** |
| Cherry-picking harvested commits into the directing branch | already silent (`:193`) |
| Merging the side branch | **must keep asking** (`:103`) — it changes what "my branch" means |
| `worktree prune/move/lock`, `branch -m/-D`, `reset --hard`, `clean` in any tree | **must keep asking** |
| Writing the ledger / `gc` | plain file write in a gitignored dir — no gate; logged |
| Switching a worker's model tier (frontmatter `model:`, `--model` on start) | **not gated** — nothing can see it (`ladder.md:107-109`); followed policy. Editing `.claude/agents/*.md` is an ordinary edit |
| Any push, `gh`, history rewrite, secret/auth | **FLOOR**, unchanged |

Autonomy is widened for exactly two operations on process-owned artefacts and nothing else.

---

## D. Personal config (text to add; LogicLoom never writes `~/.claude/`)

Append to `~/.claude/CLAUDE.md` after "How work gets done" (`:91`):

> **Side sessions.** When a piece of work should run as its own orchestrator — long, parallel, or something I may want to watch — open a side session: a worktree of the current branch under `.claude/worktrees/side-<id>` on branch `side/<id>`, started headless with `side-session.sh` in a LogicLoom project (elsewhere: `git worktree add -b side/<id> … HEAD` then `claude -p … --permission-prompts none`). Direct it with follow-up messages into the same session, read its diff yourself before harvesting, and clean up when done. At most three at a time; a side session never pushes, never opens another side session, and never touches a tree it does not own. Offer me the resume command when I might want to watch or take over.
>
> **Delegated approval.** Creating and removing *process-owned* side worktrees and branches — reserved `side/` namespace, reserved directory, clean and merged-or-harvested — is approved by the hook, not by me; the gate logs each one. Everything else about branches still asks, and push, history rewriting, repo admin, secrets and auth always ask.

Memory rule change (`shared/git-branch-ops-need-approval.md:11-15`): append one paragraph — "**Exception (2026-10-10):** branches named `side/<id>` and worktrees at `.claude/worktrees/side-<id>` created by the side-session process are process-owned; their creation and post-harvest removal are approved by LogicLoom's gate (`git.worktree.owned` / `git.branch.owned`) when its conditions hold, and do not need a prompt. Everything else in this rule stands." (Vault write rules: this is memory, not wiki, so the main session may edit it with his approval.)

---

## E. Haiku economics

- **Measured:** 65-80k tokens per request for a Haiku `-p` side session with four tools; the 5x-above-100k Haiku 5.5 billing claim is **unverified** (secondary sources) — treat the 100k line as a cost cliff until checked against the live pricing page (grounding rule, `models.conf:99-119`).
- **Where the context goes (inference, unverified):** this environment exposes several hundred MCP tools whose schemas are sent as deferred-tool names and loaded tools; plus `CLAUDE.md` (~700 lines) and `~/.claude/CLAUDE.md`, plus the agent-definition roster. A side session inherits all of it unless told not to.
- **Knobs (ordered by expected saving):** (1) for side sessions, pass `--strict-mcp-config --mcp-config '{"mcpServers":{}}'` so no MCP server (and no tool schema) loads — **unverified** that `-p` honours it without `--bare`; measure with `--output-format json` usage before relying on it; (2) for the `checker` subagent, `tools: Read, Grep, Glob, Bash` (MCP tools inherited by subagents are narrowed by the `tools` allowlist per the docs), `omitClaudeMd: true`, no `skills:`, `maxTurns: 25`; (3) briefs under ~2k tokens with file paths, not pasted content; (4) `--bare` only for Haiku check-and-report *side* runs that need neither hooks nor CLAUDE.md — not for governed sessions; (5) never route anything hook/auth/payment/customer-data/floor-adjacent to Haiku (D2).
- **Rule of thumb for the policy doc:** a checker request should start under 30k tokens; if a measured start exceeds 60k, move the task to Sonnet rather than pay the cliff.

---

## F. Enforced-vs-followed honesty

**Enforced by hooks (Claude Code only):** the two owned verdicts and their conditions; the kill switch; FLOOR unchanged; subagent deny unchanged; depth=1 via `cwd`; protected-path status of the helper, facts lib, verdict lib, gate-policy. Each is "enforced" only once its golden fixtures pass (`threat-model.md:426-433`).

**Followed (model-read policy):** the three-tier rule and tier selection; cadence; "read the combined diff"; everything in the side-session brief (no push is *also* enforced headless by `ask`→deny, but only because `--permission-prompts none` is set by the helper — a user who starts a side session by hand without it gets a prompt no one answers); concurrency cap (helper refuses; a hand-typed `git worktree add` with a fourth `side/` id is still allowed by the verdict — add a cap check to the facts lib if this matters, H6); the ledger's completeness.

**New residuals for the threat model:**
9. **Mods override project hooks.** A user-installed mod's `tool.check` can approve a call a project `PreToolUse` hook blocked, and deny rules hold over mods only under managed settings or a Team/Enterprise login (docs). This weakens every LogicLoom verdict, not only the new ones; mitigation is operator-side (`allowManagedModsOnly`, `disableSideloadFlags`) and a `plugin.register` guard mod is a later option. Document; do not pretend the hook floor is mod-proof.
10. **Ledger writability.** See C.5; the verdict's safety does not rest on it.
11. **Headless sessions with pre-approved tools.** A side session runs `Edit/Write` and allowlisted Bash with no human; its blast radius is its own worktree plus anything a Bash command can reach (residual #1 applies inside it too). Mitigation: allowlist by prefix, no `fetch`, no network tools, `--permission-prompts none`, and the host sandbox (residual #4) if the operator enables it.
12. **String-gate limits carry over.** `G=git; $G worktree remove …` is invisible as before (residual #1); the owned verdict can only ever be *more* restrictive than today for the strings it does see.

---

## G. Build plan

Score: reversibility 1 (a revert fixes it; nothing leaves the tree), width 2 (hooks, lib, config, agents, docs) → **Standard**, but the governance packages (WP4) get their own review at Heavy per D3 and the cadence rule (`~/.claude/CLAUDE.md:139-143`).

**Phase 1 — non-protected, three concurrent Sonnet workers, non-overlapping:**
- **WP1 policy text** owns `.docs/policies/escalation-policy.md`, `AGENTS.md`, `CLAUDE.md` (short), `tests/contract/test_disposition_tandem.sh`.
- **WP2 roles** owns `.claude/agents/advisor.md`, `checker.md`, `reviewer.md`, `.logic-loom/config/models.conf`, `.docs/architecture/orchestrator-worker-ladder.md`.
- **WP3 helper + tests** owns `.logic-loom/scripts/bash/side-session.sh`, `tests/contract/test_side_session.sh`, `tests/contract/test_side_owned.sh` (fixtures written first, red until WP4), `.docs/architecture/governance-threat-model.md` (residuals 9-12).

**Phase 2 — protected edits (main agent applies each with a user prompt; one Opus `deep-reasoner` drafts, main agent pastes):**
- **WP4a** `.logic-loom/lib/side-session-facts.sh` (new; then add to `governance.conf protected_paths` with `side-session.sh`).
- **WP4b** `.logic-loom/lib/governance-verdicts.sh`: `loom_side_owned_ok`, the two ops in `LOOM_GATE_DEFAULTS` (`:976-1015`), classification change at `:1299-1301`, posture bodies.
- **WP4c** `.logic-loom/config/gate-policy.conf` three lines + commentary; `git-safety-gate.sh` facts call + audit line; `.claude/settings.json:79` timeout.
Review: advisor (medium) on Phase 1 combined diff; `/cross-check` (Codex, high) + advisor on the Phase 2 combined diff; `test_governance_verdicts.sh`, `test_gate_policy.sh`, `test_governance_hooks.sh`, `test_side_owned.sh` all green before the word "enforced" appears in any doc.

**Phase 3 —** `/update-loom` note; a live trial (create → start Haiku checker → send → read → cleanup) recorded under `exploration/side-trial/`.

**Deferred:** mod status pane / one-command fan-out / `agent.spawn` per-worker model routing (`mods-proof/README.md:9-15` proves feasibility; not a v1 dependency); Orca (`ORCA-HANDOFF.md`); non-Claude worker (D7); a desktop one-click open (H5); the model-reword step of option (3).

---

## H. Decisions for the maintainer

1. **Ship delegated approval on or off by default for template users?** (a) **Recommended:** `balanced` ships `on` — the conditions are provable and every op is logged; `strict` ships off. (b) Ship `off` everywhere; each project opts in with one line. (c) On only in `minimal`.
2. **Side-session permission posture.** (a) **Recommended:** `acceptEdits` + explicit `--allowedTools` prefixes + `--permission-prompts none`. (b) `auto` mode (classifier judges each Bash) + `--permission-prompts none` — fewer hand-listed prefixes, less predictable. (c) `dontAsk` — strictest; many ordinary test commands will be denied.
3. **Ledger location.** (a) **Recommended:** `.claude/worktrees/side-ledger.jsonl` (already gitignored, per-checkout). (b) `.logic-loom/logs/side-sessions/` beside the operations log. (c) `~/.claude/…` — rejected by the harness↔user boundary.
4. **Concurrency cap enforcement.** (a) **Recommended:** helper-enforced only (followed), default 3. (b) Add the cap to the facts lib so a 4th `worktree add` asks (enforced; one more git probe per op).
5. **Desktop "visible on request".** (a) **Recommended:** terminal `claude --resume` only in v1; print it in `open-hint`; state plainly that the desktop app cannot show a `-p` session. (b) Also offer a desktop task chip that hands off into a *new* session (not the same transcript). (c) Hold v1 until a start-session tool exists.
6. **Checker model pin.** (a) **Recommended:** `model: haiku` tier keyword (D4). (b) `inherit` and let the orchestrator pass `--model` per call — loses the "never Haiku for X" guard being visible in the agent file.
7. **`LOOM_MODEL_WORKER` default.** (a) **Recommended:** `sonnet` (matches D2 and `fast-worker.md:8`; `models.conf:45` is `opus` today). (b) Leave `opus`; the ladder doc already says Sonnet.
8. **Personal "Mutation is always a worker's job" (`~/.claude/CLAUDE.md:68`).** (a) **Recommended:** keep personal, unchanged; the shipped policy stays with Principle X (`vision.md:89-94`). (b) Soften it personally to allow the main agent to run the canonical owned git commands itself (it must — the hook needs a main-agent Bash call; a worker is a subagent and is denied). Note: (a) already implies this exception for those two commands.

---

## Could not verify
- Haiku 5.5 billing multiplier above 100k tokens per request (secondary sources only).
- Whether `--strict-mcp-config` / `--mcp-config` with an empty server set shrinks a `-p` session's context without `--bare`; whether `-p` sessions honour `outputStyle`.
- Whether a desktop task chip or any `ccd_*` tool can open an existing `-p` session by id (observed: no, in this environment).
- `git status` latency on a large product repo inside a 5000 ms hook budget (measure; fall back to `ask` on timeout — fixture #24).
- That the hooks-doc statement "allow skips the permission prompt" holds identically under `acceptEdits` for a Bash call not matched by any allow rule (the gate today emits `allow` and the host still applies its own permission flow, `gate-policy.conf:24-28`); the owned verdict only removes LogicLoom's `ask`, exactly as `git.commit = silent` does today.
