> **2026-10-12 banner.** Side sessions and delegated approval were CANCELLED after three host trials: the desktop task chip was not shown to the user; a terminal-tab session started and ran correctly in its own worktree, but cross-session follow-up messages were held and expired because of a permission-mode mismatch; headless sessions were rejected as not user-visible.
> Sections B, C and the host-adapter material are historical.
> What shipped instead is the execution-mode clause in `.docs/policies/escalation-policy.md`.

# Design v2: tiered workers, visible side sessions, and hook-delegated approval

**Feature**: `escalation-advisor` · **Type**: exploration / design (revision 2.1) · **Date**: 2026-10-12 (v2 2026-10-10; revised after advisor review + maintainer decisions M1-M4)
**Supersedes**: `design.md` §A-§H where they conflict (the non-Claude WORKER default in `design.md:88-126` is withdrawn per D7; the ladder, advisor and cadence material stands). Revision 2.1 supersedes v2's headless side sessions (§B, §C.8, §E, §H2/H5 of v2) — see §B and the final section.
**Inputs**: `design.md` + addenda, `bakeoff/README.md` (Test 3 = the working Orca run, `:43-73`), `mods-proof/README.md`, `ORCA-HANDOFF.md`, `vision.md`; maintainer decisions D1-D7 and M1-M4; `~/.claude/CLAUDE.md:60-175`; Claude Code 2.1.290 docs; the directing-tool roster observed in this desktop-app environment (`ccd_*` tools).

---

## Summary for the business owner (one sentence each)

- Every working session has the same shape: one senior AI plans and checks, and hands pieces to cheaper helpers sized to the job — a quick checker (Haiku), a builder (Sonnet, now the default worker), or a deep thinker (Opus).
- The AI can open a "side desk" — a separate copy of the project on its own branch with a second full session in it — but in this version the side desk is always **somewhere you can see and switch to** (a session in the desktop app, or an Orca pane); invisible background sessions are dropped.
- How the side desk opens depends on where you are working: in the desktop app you click a one-time task chip; in Orca it starts by itself; in a plain terminal there is no side desk in this version — work stays with in-session helpers.
- Today every branch-and-copy operation stops to ask you; this design lets the harness approve the two that it can *prove* from git's own records are safe and process-owned (a reserved name, a reserved folder, a clean copy, work already merged) — but only on the desktop path, where the harness makes the copy itself; on Orca, Orca makes and removes its own copies and the harness only records them.
- Nothing that could leave the building (pushing code, rewriting history, credentials, repository settings) changes at all; those still ask every time, and no setting can silence them.
- The self-approval ships **on** in the shipped `balanced` posture and **off** in `strict`; one config line turns it off anywhere.
- Every self-approved step is logged, and a test table with deliberately hostile cases must pass before any of it is called "enforced"; the advisor review found two conditions in the first draft that would not have held (fixed below) and one open question only a live test can settle.
- Outside models (Codex, Gemini) stay reviewers (`bakeoff/README.md:35-36`, `:71-73`).
- Your personal setup and the shipped product carry the same rules; LogicLoom never edits your personal files.

---

## 0. Ground truth (what exists today)

- **Gate today.** `git worktree add/remove/...` and any branch create/delete/rename are `ask` (`gate-policy.conf:148-156`); classification at `governance-verdicts.sh:1299-1301`, verb list `:61-65`. The FLOOR is five ops (`:970`; `gate-policy.conf:90,95,217-225`) and config cannot silence them (`:1107-1117`, refusal `:1182-1185`). `commit/add/fetch/checkout/cherry-pick` are already silent (`gate-policy.conf:167-208`).
- **Subagents.** Any `agent_id` → mutating git denied, allowlisted reads only (`subagent-git-guard.sh:14-22`, verdict `governance-verdicts.sh:522-529`); gate policy never applies to subagents (`:954-957`). Observed while writing this revision: the guard denied even a `git init` in a throwaway `mktemp` directory from a subagent — the floor is path-blind, as documented.
- **Hook wiring.** All PreToolUse Bash hooks run from `.claude/settings.json:63-87` with 3000 ms timeouts; the verdict lib is pure (`governance-verdicts.sh:16-20`) and is the conformance seam (`governance-threat-model.md:426-433`). The gate emits `allow` for every command it does not `ask` on (`git-safety-gate.sh:120`).
- **Segment rules the owned check reuses.** Segments split on `; | & ( ) { } \`` (`governance-verdicts.sh:87-89`); env assignments before `git` detected by `_loom_seg_has_env_assignment` (`:315-331`); denied globals/args list (`:283-300`); `$(`/backtick smuggling checked on the raw command (`:506-513`).
- **Protected floor.** `_loom_path_in_builtin_floor` (`governance-verdicts.sh:815-828`) covers `.claude/hooks/`, `settings.json`, `governance.conf`, `gate-policy.conf`, `constitution.md`, `governance-verdicts.sh`, `policy.sh`, `plugins/loom-governance/hooks/`, and the loom-governance `plugin.json`. A **new** file under `.logic-loom/lib/` is not on the floor until listed in `governance.conf protected_paths` (`governance.conf:23-70`, additive only).
- **Worktrees.** `.claude/worktrees/` is gitignored (`.gitignore:183-184`); `worktree-port-namespace.sh:43-65` already parses `git worktree list --porcelain` (first block = main checkout).
- **Hosts observed.** Desktop app: has `spawn_task` (a one-click chip; its description says the spawned session "gets a fresh worktree" under the given `cwd`), `send_message`/`get_session`/`search_session_transcripts`/`export_transcript`, `change_directory`, and `clean_up_worktrees`/`discard_kept_worktree` — no click-free start. Orca: `orca orchestration run-create`, `worker-start --agent <claude|codex> --worktree new-child --base-branch <ref> --model <id> --effort <level>`, mailbox `check --wait`, `worker_done`, `worker-release`, `orca worktree rm` — all exercised in `bakeoff/README.md:43-49`; Orca launched the agent with no approvals ("YOLO mode", `:66-67`) and a first-time agent blocked on a directory-trust prompt (`:48-49`).
- **Personal ladder.** Three tiers (`~/.claude/CLAUDE.md:74-81`), cadence (`:139-143`); "Mutation is always a worker's job" (`:68`) is rejected for the shipped product by `vision.md:89-94`. Memory rule: branch create/switch/delete need explicit approval (`vault/.brain/memory/shared/git-branch-ops-need-approval.md:11-15`).

---

## A. What ships in LogicLoom v1

| Path | New/changed | Purpose | Enforced / followed | Protected? |
|---|---|---|---|---|
| `.docs/policies/escalation-policy.md` | NEW | Rubric, four rungs, cadence (D3), three worker tiers + tier rule (D2), side-session lifecycle (§B) incl. the host-adapter table, delegated-approval contract (§C) in prose | FOLLOWED | no |
| `AGENTS.md` Tier 1 | changed | "Escalation Disposition" paragraph (≤12 lines) beside the Cross-Check Disposition (`AGENTS.md:108-110`); Tier 2 rows for `advisor`, `checker`, `reviewer` next to `:243-244` | FOLLOWED | no (tandem-tested) |
| `CLAUDE.md` | changed, short | Same paragraph verbatim under Standing policies (`:113`); one ladder row each (`:603-619`) pointing at the policy doc | FOLLOWED | no |
| `tests/contract/test_disposition_tandem.sh` | changed | Asserts the Escalation paragraph is byte-identical in AGENTS.md, CLAUDE.md, policy doc (same shape as `:37-45`) | ENFORCED (CI) | no |
| `.claude/agents/advisor.md`, `checker.md`, `reviewer.md` | NEW | §A.1 | FOLLOWED (tier) / hooks ENFORCE git+paths | no |
| `.logic-loom/config/models.conf` | changed | `LOOM_MODEL_WORKER = sonnet` (**M3**, from `opus` `:45`); new roles `LOOM_MODEL_ADVISOR = inherit`, `LOOM_MODEL_CHECKER = haiku`; `LOOM_MODEL_REVIEWER = opus` kept (`:46`); `:66` kept (D7). Stays documentary (`:1-6`) | FOLLOWED | no |
| `.logic-loom/scripts/bash/side-session.sh` | NEW | The side-session helper (§B.5). Runs **no mutating git and no host start command itself**: it prints the canonical command for the main agent to run, so every mutation stays hook-visible (§C.4) | helper FOLLOWED; the git it emits ENFORCED | **yes** (via `governance.conf protected_paths`, additive) |
| `.claude/worktrees/side-ledger.jsonl` | NEW (runtime) | The ledger (§B.6); machine-local, gitignored dir (H3a) | data; **never an input to a verdict** (§C.5) | no |
| `.logic-loom/lib/side-session-facts.sh` | NEW | Gathers git facts for one owned-op request and prints `key=value` lines; the only place git runs during a verdict; runs only after a cheap string prefilter matches the owned shape | ENFORCED (input to verdict) | **yes** (via `protected_paths`) |
| `.logic-loom/lib/governance-verdicts.sh` | changed | Ops `git.worktree.owned`, `git.branch.owned`; `loom_side_owned_ok <op> <facts>` (pure, table-tested); classification emits the owned op only when it holds; `side.delegated-approval` switch; posture bodies | ENFORCED | **yes** (floor `:822`) |
| `.logic-loom/config/gate-policy.conf` | changed | `git.worktree.owned = silent`, `git.branch.owned = silent`, `side.delegated-approval = on` (**M1**: `balanced` on, `strict` off/ask, `minimal` on) | ENFORCED (read by lib) | **yes** (floor `:820`) |
| `plugins/loom-governance/hooks/scripts/git-safety-gate.sh` | changed | Prefilter → facts lib → verdict; one audit line per auto-allowed owned op; `permissionDecisionReason` on allow | ENFORCED | **yes** |
| `.claude/settings.json` | changed (one number) | Gate timeout 3000→5000 ms (`:79`) | — | **yes** |
| `.logic-loom/config/governance.conf` | changed | Two `protected_paths` lines (helper, facts lib) | ENFORCED | **yes** |
| `tests/contract/test_side_owned.sh`, `test_side_facts.sh`, `test_side_session.sh` | NEW | §C.7 fixtures (hostile rows); facts-lib probes in temp repos; helper subcommands + ledger + adapters | ENFORCED (CI) | no |
| `tests/contract/test_gate_policy.sh` | changed | Table (`:56-60`) gains the two ops and the switch | ENFORCED (CI) | no |
| `.docs/architecture/governance-threat-model.md` | changed | Residuals #9-#13 (§F) + matrix note | FOLLOWED (doc) | no |
| `.docs/architecture/orchestrator-worker-ladder.md` | changed | Ladder rows for advisor/checker/reviewer; side-session section | FOLLOWED | no |
| `plugins/loom-maintenance/updates/` note + `.check.sh` | NEW | `/update-loom` note (format per `tests/update-loom/fixtures/lint/ok-protected-with-check/`) | ENFORCED by note linter | no |

**Not in v1** (deferred): a mod (status pane, fan-out, `agent.spawn` routing); any non-Claude worker (D7); **headless `claude -p` side sessions** (M2); a terminal-only side session (M2); the model-reword step of §C.1 option (3); a tmux adapter (see final section, F-12).

### A.1 Agents
- `advisor.md` — adversarial second opinion; `tools: Read, Grep, Glob`; `model: inherit`; `effort: medium`.
- `checker.md` — Haiku check-and-report (D2, H6a): `model: haiku` (no `effort`, `models.conf:54`), `tools: Read, Grep, Glob, Bash`, `omitClaudeMd: true`, `maxTurns: 25`, no Agent tool; body names what it may not touch (anything hook/auth/payment/customer-data/floor-adjacent).
- `reviewer.md` — phase reviewer over a combined diff; `tools: Read, Grep, Glob, Bash`; `model: opus`; `effort: high`.
- `fast-worker.md` (`model: sonnet`, `fast-worker.md:8`) and `deep-reasoner.md` unchanged. `test_model_agnostic.sh:49` already enforces tier keywords only.

---

## B. Side-session lifecycle (visible only — M2)

**Rule.** A side session must open somewhere the user can see and switch to. The helper exposes one interface; a host adapter supplies the start/direct/read/stop mechanics. There is no click-free start in the desktop app; Orca starts click-free; a plain terminal has no side sessions in v1.

### B.1 Host adapters

| | **Desktop app (`host=desktop`)** | **Orca (`host=orca`)** | **Plain terminal (`host=none`)** |
|---|---|---|---|
| Worktree + branch | **Primary:** directing session creates `side/<id>` at `.claude/worktrees/side-<id>` (§B.2) — the **owned verdict (§C) applies here**. **Fallback (adopt):** the app's own fresh worktree is adopted into the ledger; no owned op occurs | Orca creates its own child worktree (`--worktree new-child --base-branch <current branch>`); the ledger records Orca's path + branch (`host=orca`). **No owned verdict** on this path — the harness never runs the git | — |
| Start | `spawn_task` chip (one click by the user). Primary chip prompt: "change directory to `<wt>` (the `change_directory` tool), confirm `git branch --show-current` = `side/<id>`, then <brief>". Fallback chip prompt: "run `side-session.sh adopt --host desktop` first, then <brief>" | `orca orchestration run-create` then `worker-start --agent claude --worktree new-child --base-branch <branch> --model <tier id> --effort <level>` — helper prints the exact command; main agent runs it (plain Bash; not git, not gated) | **not available** — work stays with in-session workers (`fast-worker`/`checker`/`deep-reasoner`) |
| Direct | `send_message` to the chip's session id (recorded by `adopt`/`register` once known; the chip's result does not return it, so `list_sessions` is used to find it by title) | Orca mailbox (`check --wait`, `worker_done`) | — |
| Read | `git -C <wt> log --oneline <base_sha>..HEAD`, `diff --stat` (main-agent reads; `-C` is allowed for the main agent), plus `get_session`/`search_session_transcripts` | same git reads on Orca's path + mailbox result | — |
| Stop / cleanup | Primary: `git worktree remove` + `git branch -d` via the owned verdict (§C.3). Fallback: the app's `clean_up_worktrees` / `discard_kept_worktree`; ledger → `removed` | `worker-release` then `orca worktree rm <path>` — Orca's subprocess git, **invisible to the gate** (residual #13); the helper refuses to print it until its own clean+merged check passes (followed, not enforced) | — |

**Open question (desktop primary).** Whether the chip's new session can act on an *existing* worktree is **unknown**: the tool description says it gets a fresh worktree of its own, and no repo doc or note records a test of `change_directory` into a path outside that worktree. Build-time test T1 (final section) settles it. If it fails, the desktop path is the **adopt** fallback only, and the owned verdict's only v1 consumer disappears (see F-1).

**Orca notes.** Orca launched the Codex worker with no approvals (`bakeoff/README.md:66-67`); for a Claude worker the project hooks are expected to fire because the child worktree is a checkout with `.claude/settings.json` present (`ORCA-HANDOFF.md:15`, expected, **unverified for `--agent claude`**). A first-time agent may block on a directory-trust prompt (`:48-49`) — the helper's `start` output says so. Whether `--worktree` accepts an existing path (which would let the owned worktree be used on Orca too) is unknown; v1 uses `new-child`.

**Terminal.** Orchestrator's assumption, maintainer-reversible: with no multiplexer there is no place for a second session to be visible, so v1 ships none. A tmux adapter (`tmux new-window -c <wt> claude …`) would be the natural third host and would be a second consumer of §C; deferred (F-12).

### B.2 Owned naming and base (desktop primary only)
Branch `side/<id>`, `<id>` = `[a-z0-9-]{1,40}` chosen by the helper (`<topic>-<4 hex>`). Worktree `<main-checkout>/.claude/worktrees/side-<id>`. Base = the directing checkout's current `HEAD` (D5); the helper records `base_branch`, `base_sha`. Canonical create command, one segment, no other flags: `git worktree add -b side/<id> .claude/worktrees/side-<id> HEAD`. `.worktreeinclude` is not processed on a Bash `git worktree add`; the helper copies nothing — a side session that needs `.env` gets it from the brief, never by copying secrets.

### B.3 What a side session is told (brief file, all hosts)
You are a full orchestrator on branch `<branch>` in `<wt>`; commit on this branch; never push; never leave this directory; never create worktrees or branches; never run `gh`; never spawn side sessions; report a summary and the commit range. It inherits the project hooks (a checkout carries `.claude/settings.json`), project `CLAUDE.md`, and the user's `~/.claude/` context; it is a *main agent* to the hooks (no `agent_id`), so the gate's `ask` reaches **the user**, in that visible session — which is why visibility is the safety property that replaced `--permission-prompts none`.

### B.4 What comes back; harvest
Commits on the side branch. The directing session reads the diff, reviews it at the rung, then either cherry-picks (silent, `gate-policy.conf:193`) or merges (`ask`, `:103`) into the directing branch. **"Harvested" is defined by git, not the ledger** (§C.3): every commit on the side branch is either an ancestor of the directing branch or patch-equivalent to one already there (`git cherry HEAD side/<id>` prints only `-` lines). A squash-merge of several side commits is *not* patch-equivalent; the branch then asks on removal — by design, not by accident. Merging to anything shared stays the user's call via `/git-push`.

### B.5 Helper subcommands (`side-session.sh`)
`create <topic> [--host desktop|orca]` → validates, prints the canonical command(s) for the host and the follow-up `register`; `register <id> --path <p> --branch <b> [--session <sid>|--orca-run <rid>]` → ledger `created`; `adopt --host desktop [--path <p>]` → ledger row for a host-created worktree (run from inside it); `start <id> "<brief>" [--model <tier>] [--effort <level>]` → prints the host's start step (desktop: chip title+prompt text for the main agent to pass to `spawn_task`; orca: the `worker-start` command) and writes the brief file; `direct <id> "<text>"` → prints the host's direct step; `read <id>` → commit range + `diff --stat` + host transcript hint; `status`, `list`; `cleanup <id>` → §B.7; `gc` → §B.8. Every printed git command is one segment with no globals. The helper **never** runs `git worktree`, `git branch`, `claude`, `orca`, or `spawn_task` itself.

### B.6 Ledger
`.claude/worktrees/side-ledger.jsonl` (H3a), one JSON object per event, append-only: `id, host (desktop|orca), owned (true|false), branch, path, base_branch, base_sha, created_by_session, created_at, session_id|orca_run_id, model, effort, state (created|running|idle|harvested|abandoned|removed), tip_sha, last_event_at`. `cost_usd` dropped (no `--output-format json` on visible hosts). `status` folds events into one row per id.

### B.7 Cleanup rules
`cleanup <id>` first runs the vault rule's check for worktree-bound services (processes/launchd plists pointing into the path, `shared/worktree-bound-services.md:15`) and warns; then, for `owned=true`, prints `git worktree remove .claude/worktrees/side-<id>` then `git branch -d side/<id>`, each judged by §C.3; for `host=orca`, prints `worker-release` and `orca worktree rm <path>` **only if** its own check (clean, harvested per §B.4) passes — otherwise it prints why and stops; for desktop-adopt, prints the app's cleanup tool name. It never prints `--force`/`-D`; a dirty or unharvested branch stays until the user harvests or says "abandon" (`state: abandoned`; deletion then needs `-D`, which stays `ask`).

### B.8 Concurrency, depth, crash
Max 3 live side sessions per checkout, **helper-enforced only** (H4a, `LOOM_SIDE_MAX`); a hand-typed fourth canonical `worktree add` is still allowed by the verdict (F-9). One side session per `<id>`; non-overlapping files per `vision.md:60-62`. Depth = 1: the owned verdict allows only when hook `cwd` **equals** the main checkout's top-level (not merely lies under it), so from inside any worktree the op is `ask`. `gc` reconciles ledger vs `git worktree list --porcelain` vs `git branch --list 'side/*'`: unknown worktree → reported, never removed; row whose path is gone → `removed`; `running` older than `LOOM_SIDE_STALE_HOURS` (24) → `idle` + warning; prunable entry → prints `git worktree prune` (stays `ask`). `gc` writes only the ledger.

### B.9 Must not (all hosts)
Push; `fetch` from inside a side session (brief); touch another worktree or the main checkout; create branches/worktrees; run `gh`; read secrets outside its tree; spawn side sessions.

---

## C. The delegated-approval hook (D6) — desktop primary path only

### C.1 Options and C.2 analysis (unchanged from v2, condensed)
(1) deterministic ownership check in the existing gate; (2) model-evaluated hook (`type: prompt`/`agent` or a mod `tool.check`); (3) hybrid. **(1) ships.** The requester (a model) and the approver (shell over git facts) are different kinds of thing; (2) is the self-review-in-lineage problem the Cross-Check Disposition names (`AGENTS.md:110`), cannot return `ask` from a prompt hook, and cannot be fixture-tested. FLOOR untouched: `LOOM_GATE_FLOOR_OPS` (`:970`) is not consulted by the new ops; `push` still classifies to its own id. Subagents unchanged (`:954-957`). `mode.bypassPermissions` stays `enforce` (`gate-policy.conf:311`). Off-host adapters that call `loom_verdict_git_mutation` with no facts argument get the ordinary op → `ask` (fail-safe, signature-compatible).

### C.3 Exact conditions (all must hold; any failure → the ordinary op → `ask`)

**Common.** `side.delegated-approval = on`; the Bash command is a **single segment** (reuse `_loom_split_segments` `:87-89`; reject if more than one non-empty segment or any newline), no `$(`/backtick/`<(`/`>(` (`:506-513`), no env assignment before `git` (`:315-331`), no git global at all (`-c`, `-C`, `--git-dir`, `--work-tree`, `--exec-path`, `--namespace`, …; the only tolerated global is `--no-optional-locks`); the facts lib refuses (→ ask) when `GIT_DIR`, `GIT_WORK_TREE`, `GIT_COMMON_DIR`, `GIT_NAMESPACE` or `GIT_CONFIG_*` is set in the hook's own environment (an exported env var is invisible in the command string — new, from advisor finding F-4); hook `cwd` **equals** `git rev-parse --show-toplevel` **and** equals the first `worktree` line of `git worktree list --porcelain` (main checkout); `git check-ignore -q .claude/worktrees` succeeds; the path operand is literally `.claude/worktrees/side-<id>`; canonicalized path (python3 `os.path.realpath`, as `freeze-write-scope.sh:238-242` already does — `realpath -m` is **not** portable to macOS/bash 3.2) is `<main-checkout>/.claude/worktrees/side-<id>`, and `.claude`, `.claude/worktrees` are each `! -L`; branch operand matches `^side/[a-z0-9-]{1,40}$` and `<id>` equals the path suffix.

**`git worktree add -b side/<id> .claude/worktrees/side-<id> HEAD` → `git.worktree.owned`** iff exactly those tokens (`-b` present, start point literally `HEAD`, no `-B`/`--force`/`--detach`/`--lock`/`--orphan`/`--track`/`--guess-remote`); `git show-ref --verify -q refs/heads/side/<id>` fails (branch absent); path does not exist.

**`git worktree remove .claude/worktrees/side-<id>` → `git.worktree.owned`** iff no `--force`/`-f`; the path is listed by `git worktree list --porcelain` **and** that block's `branch refs/heads/side/<id>` line matches; `git -C <path> --no-optional-locks status --porcelain` is empty (**`--no-optional-locks` is a git global, not a `status` option** — v2 had it after `status`, which errors; F-2) — note ignored files are not reported and would be deleted with the tree; the facts lib additionally runs `status --porcelain --ignored=matching` and the verdict asks if any ignored path matches `.env*`, `*.pem`, `*.key` (F-6); **harvested** per §B.4: `git merge-base --is-ancestor side/<id> HEAD` **or** `git cherry HEAD side/<id>` has no `+` line (patch-equivalence; the ledger is no longer an input — F-3); **provenance:** the branch's reflog (`git reflog show --format=%gs refs/heads/side/<id>`) contains **no** `Branch: renamed` and no `Branch: copied` entry and its oldest entry is `branch: Created from HEAD` — v2 relied on the oldest entry alone, but a user branch made with `checkout -b` has that same oldest message and a rename carries the old reflog across, so the rename/copy entries are the real signal (F-1 of the advisor; verify messages in T2); a reflog that is absent or empty → ask.

**`git branch -d side/<id>` → `git.branch.owned`** iff `-d` (not `-D`/`--force`/`-m`/`-M`/`-c`/`-C`); not the current branch; no `git worktree list --porcelain` block has `branch refs/heads/side/<id>`; harvested and provenance as above. Bare `git branch side/x`, `checkout -b side/x`, `switch -c`, and any rename/copy stay `ask`.

**`git worktree prune|move|lock|unlock|repair`** → never owned.

**Git's own refusals are the backstop for check-then-act races.** Between fact gathering and execution another process could dirty the tree or add commits; `git worktree remove` without `--force` refuses a worktree with modified or untracked files, and `git branch -d` refuses a branch not merged into HEAD. The verdict is strictly narrower than git's own checks, never wider (F-5). The one case git does not backstop — commits added to `side/<id>` after the hook's `cherry` check but before `branch -d` — is closed by `-d`'s own merged check as well.

### C.4 Why the helper emits commands instead of running them
A hook cannot see git inside a script (residual #1, `threat-model.md:124-127`). If the helper ran `git worktree add` itself, the gate would judge only `bash side-session.sh create` and the mutation would be invisible — weakening the floor while claiming to extend it. Emitting the canonical command keeps every mutation hook-visible, keeps the verdict lib pure (facts gathered by the adapter, decision by a pure function), and means the owned verdict works for a human typing the same command. **The Orca path breaks this symmetry knowingly:** `orca worktree rm` is subprocess git. It is recorded as residual #13, mitigated by the helper's followed check (§B.7), and is the reason the owned verdict is not claimed on that host.

### C.5 Ledger: audit only
The ledger is an agent-writable file in a gitignored directory. In v2 it supplied one alternative ("harvested + tip_sha") to the merged check; the advisor's F-3 replaces that with `git cherry`, so **no verdict reads the ledger**. The ledger's only roles are the helper's `status`/`list`/`gc` and the audit trail. Residual #10 shrinks to "the ledger can be wrong about what the helper reports", which affects no decision.

### C.6 Audit trail, kill switch, postures
Per auto-allowed op the gate appends `<ts> side-owned ALLOW <op> branch=<b> path=<p> clean=1 harvested=ancestor|cherry provenance=created-from-HEAD cwd=main` to `.logic-loom/logs/operations/<date>.log` (`logging.sh:24-25`) and emits `permissionDecisionReason` even on allow. `side.delegated-approval = off` → classification never emits an owned op; each owned line also accepts `ask` individually. Postures (**M1**): `strict` = `off` + both `ask`; `balanced` = `on` + both `silent`; `minimal` = `on` + both `silent` (`loom_gate_posture_body`, `governance-verdicts.sh:1406-1420`). Unknown value → `off` (fail-safe, `:946-952`). The refusal lister (`:1159-1190`) must learn the new keys or it reports them as `unknown-operation`.

### C.7 Test fixtures (table-driven; green before "enforced")

| # | Command / state | Expected |
|---|---|---|
| 1 | canonical `worktree add -b side/a .claude/worktrees/side-a HEAD`, clean repo | allow (`git.worktree.owned`) |
| 2 | same with `--force` / `-B` / `--detach` / start point `main` / `HEAD~1` | ask |
| 3 | `-b side/a .claude/worktrees/side-b HEAD` (id mismatch) | ask |
| 4 | `-b sides/a`, `-b side/A`, `-b side/../x`, id > 40 chars, `-b side/` | ask |
| 5 | path `.claude/worktrees/../../side-a`, absolute path, `/tmp/side-a`, `./.claude/worktrees/side-a` | ask |
| 6 | `.claude/worktrees` or `.claude` replaced by a symlink | ask |
| 7 | `.claude/worktrees` not gitignored | ask |
| 8 | branch `side/a` already exists; path already exists | ask |
| 9 | `cd x && git worktree add …`, `VAR=1 git …`, `git -c k=v …`, `git -C . …`, `git worktree add … ; echo`, command with `$(…)` | ask |
| 10 | hook `cwd` = a side worktree; `cwd` = a subdirectory of the main checkout | ask |
| 11 | `side.delegated-approval = off`; value `maybe` | ask |
| 12 | `GIT_DIR` exported in the hook environment | ask |
| 13 | `worktree remove side-a`, clean, ancestor of HEAD | allow |
| 14 | remove, clean, not ancestor, every commit patch-equivalent (`git cherry` all `-`) | allow |
| 15 | remove, clean, one commit not in HEAD by patch-id; squash-merged | ask |
| 16 | remove, one untracked file; one modified tracked file | ask |
| 17 | remove, clean, ignored `.env` present | ask |
| 18 | remove, clean, ignored `node_modules/` only | allow (logged `ignored=N`) |
| 19 | remove with `--force` / `-f` | ask |
| 20 | `branch -d side/a` while checked out in its worktree | ask |
| 21 | `branch -D side/a`; `branch -m side/a x`; `branch side/b` | ask |
| 22 | `feature/x` renamed to `side/x` (reflog has `Branch: renamed`); `branch -c` copy | ask |
| 23 | `branch -d side/a` where `side/a` is the current branch | ask |
| 24 | reflog absent (`core.logAllRefUpdates=false` at creation) | ask |
| 25 | any owned-shaped command with `agent_id` set | deny (unchanged) |
| 26 | `git push origin side/a` | ask (FLOOR) |
| 27 | `gate-policy.conf` sets `git.push = silent` beside the new lines | refused as today (`test_gate_policy.sh` §3) |
| 28 | facts lib missing / probe exits non-zero / probe exceeds budget | ask (fail-safe) |
| 29 | verdict lib called without a facts argument (off-host adapter) | ask (ordinary op) |

### C.8 Every routine operation this process introduces

| Operation | Verdict |
|---|---|
| Opening the desktop chip / sending a message / reading a transcript (`ccd_*` tools) | not Bash, not git — host permission only; the user clicks the chip |
| `orca orchestration run-create` / `worker-start` / mailbox / `worker-release` via Bash | plain Bash; not git; **not gated** (residual #13 for the worktree parts) |
| Committing / `add` / `status` / `diff` / `log` inside a side session | already silent / reads (`gate-policy.conf:167-170`) |
| Creating the owned worktree+branch (desktop primary) | **owned verdict** |
| Removing the owned worktree, deleting the owned branch after harvest (desktop primary) | **owned verdict** |
| `orca worktree rm` (Orca) / `clean_up_worktrees` (desktop adopt) | host-owned; invisible to the gate; helper check is followed-only |
| Cherry-picking harvested commits | already silent (`:193`) |
| Merging the side branch | **keeps asking** (`:103`) |
| `worktree prune/move/lock`, `branch -m/-D/-c`, `reset --hard`, `clean` | **keep asking** |
| Writing the ledger / `gc` | plain file write in a gitignored dir — no gate; logged |
| Switching a worker's model tier / effort | **not gated** — nothing can see it (`ladder.md:107-109`) |
| Any push, `gh`, history rewrite, secret/auth | **FLOOR**, unchanged |

Autonomy is widened for exactly two operations on process-owned artefacts on one host path, and nothing else.

---

## D. Personal config (text to add; LogicLoom never writes `~/.claude/`)

Append to `~/.claude/CLAUDE.md` after "How work gets done" (`:91`):

> **Side sessions.** When a piece of work should run as its own orchestrator — long, parallel, or something I may want to watch — open a visible side session: in the desktop app, create the owned worktree (`side/<id>` at `.claude/worktrees/side-<id>`) and offer me the task chip; in Orca, start a Claude worker in a child worktree. Direct it, read its diff yourself before harvesting, and clean up when done. At most three at a time; a side session never pushes, never opens another side session, and never touches a tree it does not own. In a plain terminal, keep the work with in-session workers.
>
> **Delegated approval.** Creating and removing *process-owned* side worktrees and branches — reserved `side/` namespace, reserved directory, clean and harvested — is approved by the hook, not by me; the gate logs each one. Everything else about branches still asks, and push, history rewriting, repo admin, secrets and auth always ask.

"Mutation is always a worker's job" (`:68`) stays as is (H8a); the two canonical owned commands are the implied exception, because a worker is a subagent and is denied them (`subagent-git-guard.sh:4-6`).

Memory rule (`shared/git-branch-ops-need-approval.md:11-15`): append — "**Exception (2026-10-12):** branches `side/<id>` and worktrees `.claude/worktrees/side-<id>` created by the side-session process are process-owned; their creation and post-harvest removal are approved by LogicLoom's gate (`git.worktree.owned` / `git.branch.owned`) when its conditions hold. Everything else in this rule stands." (Memory, not wiki — the main session may edit it with his approval.)

---

## E. Checker economics (Haiku, in-session only after M2)

- Headless `-p` measurements from v2 (65-80k tokens/request) no longer describe a shipped path; they remain the warning that a Haiku session inheriting this environment's MCP roster starts near the suspected 100k cost line (Haiku billing multiplier **unverified**, grounding rule `models.conf:99-119`).
- The `checker` subagent keeps the knobs that apply in-session: `tools: Read, Grep, Glob, Bash` (narrows inherited MCP tools per the docs), `omitClaudeMd: true`, no `skills:`, `maxTurns: 25`, briefs under ~2k tokens with paths not pasted content; never route hook/auth/payment/customer-data/floor-adjacent work to Haiku (D2).
- Rule of thumb for the policy doc: a checker request should start under 30k tokens; above 60k, move the task to Sonnet.

---

## F. Enforced-vs-followed honesty

**Enforced by hooks (Claude Code only):** the two owned verdicts and their conditions; the kill switch; FLOOR unchanged; subagent deny unchanged; depth=1 via `cwd` equality; protected-path status of the helper, facts lib, verdict lib, gate-policy. Each is "enforced" only once its golden fixtures pass (`threat-model.md:426-433`).

**Followed (model-read policy):** tier rule and selection; cadence; "read the combined diff"; everything in the side-session brief (no push is *also* enforced in the side session by the gate's `ask` reaching the user there); concurrency cap (helper); the Orca and desktop-adopt cleanup checks; ledger completeness.

**New residuals for the threat model:**
9. **Mods override project hooks.** A user-installed mod's `tool.check` can approve a call a project `PreToolUse` hook blocked; deny rules hold over mods only under managed settings or a Team/Enterprise login (docs). Weakens every LogicLoom verdict, not only the new ones; mitigation is operator-side. Document; do not pretend the floor is mod-proof.
10. **Ledger writability.** No verdict reads it (§C.5); it can only misreport.
11. **Side sessions are main agents.** A side session runs with the user's permission mode and the project hooks; its gate `ask`s reach the user *in that session*, so a side session left unattended simply stalls. Blast radius: its worktree plus anything Bash can reach (residual #1 inside it too).
12. **String-gate limits carry over.** `G=git; $G worktree remove …` is invisible as before; the owned verdict is only ever *more* restrictive than today for the strings it does see.
13. **Host-owned worktrees are outside the gate.** `orca worktree rm` and the desktop app's own worktree cleanup are subprocess/host git the hooks never see. The harness records them (ledger) and checks before *printing* the command (followed). This is residual #1 applied to a path the harness itself recommends — stated, not hidden.

---

## G. Build plan (packages in `packages-v1.json`)

Score: reversibility 1, width 2 → **Standard**; the protected package gets its own review at **Heavy** (hooks + gate = governance floor; `~/.claude/CLAUDE.md:139-143`).

Order: **P1** fixtures first (red) → **P2-P5** concurrent, non-overlapping → **P6** protected edits applied by the main session (the governance hooks prompt the user for each file) → **P7** registrations + docs. Review: advisor (medium) on the P2-P5 combined diff; `/cross-check` (Codex, high) + advisor on P6; all of `test_governance_verdicts.sh`, `test_gate_policy.sh`, `test_governance_hooks.sh`, `test_side_owned.sh`, `test_side_facts.sh`, `test_side_session.sh`, `test_suite_registration.sh` green before the word "enforced" appears in any doc. Then the build-time tests T1-T4 below, recorded under `exploration/side-trial/`.

---

## H. Decisions for the maintainer — status after M1-M4

1. Delegated approval default → **settled (M1)**: `balanced` on, `strict` off.
2. Headless permission posture → **moot** (M2 drops `-p` sessions).
3. Ledger location → (a) `.claude/worktrees/side-ledger.jsonl` (M4).
4. Concurrency cap → (a) helper-enforced (M4).
5. Desktop "visible on request" → **superseded by M2**: visible is the only mode; the chip is the desktop start.
6. Checker model pin → (a) `model: haiku` (M4).
7. `LOOM_MODEL_WORKER` → `sonnet` (M3).
8. Personal wording → (a) keep, with the implied two-command exception (M4).

**New, open (from the advisor):** H9 ignored-file policy on removal (`.env*`/keys → ask; other ignored → allow) — accept or tighten to "any ignored → ask". H10 whether to add a tmux adapter in v1.1 so §C has a second consumer. H11 if T1 fails, whether to ship §C at all in v1 or hold it until a host can target an existing worktree.

---

## Advisor findings and disposition

**Approach verdict: sound, with one structural caveat.** Option (1) — deterministic facts, pure verdict, helper that emits rather than runs — is the right shape and does not soften the FLOOR. The caveat is not about §C's mechanics but its *consumer*: after the visible-only pivot, the only path on which the harness itself creates and removes worktrees is the desktop primary path, and that path depends on an unverified host behaviour (T1). If T1 fails, §C is correct code with no caller in v1. That does **not** make the approach wrong; it makes the protected package's value contingent, and the maintainer should decide H11 before P6 is applied.

| # | Finding | Severity | Disposition |
|---|---|---|---|
| F-1 | **Rename spoofing passes v2's reflog check.** v2 (`:116`) said a renamed user branch "fails this" because its oldest reflog entry is the original creation — but `git checkout -b feature/x` writes the same `branch: Created from HEAD` message, and `git branch -m` carries the reflog to the new name. The oldest entry proves nothing about the name. | high | **fixed in design** (§C.3 provenance now requires *no* `Branch: renamed`/`Branch: copied` entry; fixture #22) — **needs build-time test T2** to confirm exact reflog message strings on the shipped git version (my temp-repo check was blocked by the subagent guard) |
| F-2 | `git status --porcelain --no-optional-locks` errors: the flag is a git global (`git --no-optional-locks status`), verified here (`error: unknown option`). As written, every removal would fail-safe to `ask`, so the allow path never worked. | medium (silent no-op, not unsafe) | **fixed in design** (§C.3) |
| F-3 | **"Harvested" was ledger-defined and therefore forgeable.** Cherry-picked commits have new shas, so the only non-ancestor harvest path was a ledger row anyone can write. Replace with `git cherry HEAD side/<id>` (patch-id equivalence): a git fact, no ledger. Squash-merges then ask — acceptable and stated. | high | **fixed in design** (§B.4, §C.3, §C.5; fixtures #14-15) |
| F-4 | **Exported `GIT_DIR`/`GIT_WORK_TREE` are invisible to the string gate** (rule 4 only sees in-segment assignments, `:315-331`), yet they redirect every probe and the command. | medium | **fixed in design** (facts lib refuses when set in the hook's own environment; fixture #12). Residual: an env set only for the Bash tool subprocess but not the hook — unlikely to differ, flag in T3 |
| F-5 | **Check-then-act race.** Facts are gathered in the hook; git runs after. | low | **fixed in design** by argument (§C.3: git's own `remove`/`-d` refusals backstop every race the verdict cares about); fixture not possible, note in threat model |
| F-6 | **Dirty-but-ignored worktree.** `status --porcelain` omits ignored files; `worktree remove` deletes them. A side session's `.env` dies silently. | medium | **fixed in design** partially (ask on `.env*`/`*.pem`/`*.key`; allow otherwise, logged) — **open for maintainer** (H9) |
| F-7 | `realpath -m` is not available on macOS (bash 3.2 floor, `shell-idiom-policy.md`). | low | **fixed in design** (python3 `os.path.realpath` as `freeze-write-scope.sh:238-242`; no python3 → ask) |
| F-8 | **`cwd` under, not equal to, the main checkout.** A relative path operand from a subdirectory lands elsewhere. | medium | **fixed in design** (equality with `--show-toplevel` and the first porcelain block; fixture #10b) |
| F-9 | **Concurrency cap is followed-only**; a hand-typed fourth `worktree add` is allowed. | low | accepted (M4/H4a); stated in §B.8 |
| F-10 | **3000 ms budget.** The five probes took ~55 ms here, but `git status` on a large product tree can take seconds; the hook runs on *every* Bash call. | medium | **fixed in design** (string prefilter before any probe; 5000 ms; probe timeout → ask, fixture #28) — **needs build-time test T4** on a large repo |
| F-11 | **Does `allow` actually remove the prompt?** The gate already emits `allow` for every non-asking command (`git-safety-gate.sh:120`). Either (a) the host honours it and skips its own prompt — then the owned verdict delivers the promised silence *and* every non-git Bash command is already auto-approved today, a pre-existing fact worth stating; or (b) the host still prompts for a command no allow rule matches — then the feature removes only LogicLoom's prompt and the user must also add `Bash(git worktree *)`/`Bash(git branch *)` rules, which is the intended division (host rule broad, LogicLoom gate narrow). v2 listed this as unverified; it decides whether the feature is felt at all. | high (value, not safety) | **needs build-time test T3**; the policy doc states both worlds until then |
| F-12 | **§C has at most one v1 consumer** (desktop primary) and that consumer is contingent on T1. Orca owns its worktrees; terminal has none. | high (scope) | **open for maintainer** (H10 tmux adapter, H11 hold §C if T1 fails). Packages keep P1/P5/P6 so the tests exist either way; P6 is applied last and can be withheld |
| F-13 | **Orca path weakens C.4's own argument**: the harness recommends a command (`orca worktree rm`) whose git is invisible to the gate. | medium | **fixed in design** as an honest residual (#13) + followed-only helper check; the owned verdict is not claimed on Orca |
| F-14 | `loom_gate_policy_refusals` (`:1159-1190`) will report the new keys as `unknown-operation` unless its known-key source grows with `LOOM_GATE_DEFAULTS`; `side.delegated-approval` is `on|off`, not `ask|silent`, so it needs its own validation branch like `mode.*` (`:1171-1177`). | low | **fixed in design** (§C.6); P1 fixture #11b |
| F-15 | Depth=1 relies on `cwd` only; a side session that `cd`s to the main checkout path in a compound command is rejected by the single-segment rule, but a side session whose *persistent* cwd is the main checkout (the user moved it) is judged as main. | low | accepted; the side session is a visible main agent whose `ask` reaches the user anyway (residual #11) |

**Build-time tests (must run before "enforced"):** **T1** desktop chip + `change_directory` into an existing owned worktree (decides the desktop primary path). **T2** reflog message strings for `checkout -b`, `branch`, `branch -m`, `branch -c`, `worktree add -b` on the shipped git. **T3** whether a hook `allow` suppresses the host prompt in `default` and `acceptEdits` modes for a Bash command with no allow rule; and whether `GIT_DIR` exported in the terminal reaches the hook process. **T4** facts-lib wall time on a large product checkout.

**Could not verify (unchanged from v2 where still relevant):** Haiku billing multiplier; whether `-p` honours `outputStyle` (moot); Orca `--worktree <existing path>`; that project hooks fire for `--agent claude` inside Orca.
