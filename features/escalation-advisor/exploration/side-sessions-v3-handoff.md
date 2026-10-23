# Side sessions v3: un-cancelling them with the desktop app's native session tool

**Feature**: `escalation-advisor` · **Type**: handoff / design input · **Date**: 2026-10-22
**Supersedes (in part)**: the 2026-10-12 cancellation banner at `design-v2.md:1-3`. Everything in `design-v2.md` not named below stands as written.
**Audience**: a LogicLoom engineering session picking this up cold; also readable by the owner (non-engineer).
**Status of facts**: "observed" = seen in the owner's desktop app on 2026-10-22. "UNVERIFIED" = not yet tested.

---

## Summary (plain)

1. On 2026-10-12 side sessions were cancelled because the desktop app could not start, steer, or show one reliably (`design-v2.md:1-3`).
2. On 2026-10-22 the desktop app gained a native tool that does exactly that: the AI proposes a card, the owner clicks it once, and a visible child session starts in its own worktree and branch.
3. The child reports back automatically when it finishes; the parent must check the child's actual work before relaying it, and asks before merging.
4. Most of the 2026-10-12 machinery (spawn chip, adopt fallback, owned-worktree auto-approval) is now unneeded; the safety rules (never push, depth 1: a child never starts side sessions, at most 3 live children per parent, brief contract) still apply.
5. Proposed deliverable is small: policy text plus a clause update, no new hook. Five tests (T-a to T-e) must run first; one path (follow-up messages) is still UNVERIFIED.

---

## 1. What changed, and the evidence

**Mechanism.** Desktop-app tool `mcp__ccd_session__start_session`. Companions: `dismiss_task` (withdraw a stale card), `hand_off_to_session` (move an in-flight task into its own session), `SendMessage` to a `local_...` id (follow-ups), and `mcp__ccd_session_mgmt__` `list_sessions {linked:true}`, `get_session`, `list_events` (read a child's transcript).

**Parameters and semantics (observed in the tool description).**
- `initiation`: `"offer"` asks the owner "New session vs Do it here" before anything runs; `"user_asked"` starts now and is only for when the owner's own words asked for separate/parallel/background work; `"own_initiative"` renders a card the owner clicks (expires after a week; max 3 per turn, 4 after an approved plan).
- `context`: `"fork"` (child inherits the conversation) or `"fresh"` (brief only). `use_worktree`: true/false; the owner's clause always passes `use_worktree: true` (own-worktree is a parameter, not a property of the tool). Optional `model`, `cwd`, cloud/ssh target. There is no `effort` parameter: `model` goes on the card and effort is set right after start with `mcp__ccd_session_mgmt__set_session_effort`.
- The app REFUSES a start on a turn that another session's message or an automated event started; the agent proposes instead.
- When a child ends a turn the parent is auto-continued with a `<side-sessions-event>` note quoting the child's report. Cloud children send no reports back.
- Merge a child's branch only on the owner's own instruction; never push child branches.

**Evidence (observed 2026-10-22, owner's desktop app).** The kori-beta session `local_43e26f11-19af-4c36-863b-8b8a2c4337f6` ("Household engine step 1...") proposed a card (`task_ee1e32cc`). The owner clicked it. Child `local_bb54f28f-48df-4487-93e3-628bfee3660b` ("Research: Kori via major AI assistants (A2A/MCP)") started in its own worktree `kori-beta-worktrees/supabase-data-api-grants-3661f1`, branch `claude/serene-moser-619cc1`, source branch `main`, model opus, effort medium. `get_session` showed `parentSessionId` set and `detached:false`; `list_sessions` showed `startedBy` and a short `name`. The child ran 57 turns, committed `da71c4c`, and reported back. ("A2A/MCP" in the title is the research topic, not the mechanism.)

**How it answers each 2026-10-12 cancellation reason (`design-v2.md:1`).**

| 2026-10-12 reason | 2026-10-22 status |
|---|---|
| Task chip not shown to the user | Resolved: cards render in the transcript; children nest in the sidebar (observed) |
| Follow-up messages held/expired by permission-mode mismatch | Reports resolved (observed). Follow-up `SendMessage` to a child **UNVERIFIED**; becomes test T-a |
| Headless sessions rejected as not user-visible | Resolved: children are visible sessions (observed) |

## 2. Owner decisions, 2026-10-22 (binding)

- **Trigger = agent judgment, hybrid.** Open a side session when (a) the work is a job of its own, OR (b) the scope is large, multi-phase or layered so that parallel sessions in separate worktrees converge back. The rung tunes the child's model/effort and the parent's review depth (Standard and above: rung-level review before done).
- **Start = card, one click** (`own_initiative`), or `user_asked` when the owner's message asks for it.
- **Return = parent verifies the child's actual diff/branch before reporting; asks before merging.**
- These are in the owner's personal global CLAUDE.md as a "Side session" execution mode, including: always `use_worktree: true`; depth 1 (a child never starts side sessions); at most 3 live children per parent; an unrelated new request gets an `offer` card first; merging or cherry-picking a child's commits waits on the owner's instruction. LogicLoom never writes `~/.claude/` (`design-v2.md:203`).

**Reconciliation with the host rule.** The host rule is that parts of one change belong to workers unless the owner asks. Shape (b) (parallel layered scope) is reconciled with it as follows: it applies only when each piece ends in its own branch, needs no result from the current turn, and is proposed as a card, so the owner's click is the ask. Pieces that do not meet all three stay with workers. Policy text (P-1) must carry the same condition.

## 3. Mapping onto design-v2

Verdict per part: **keep** (carries over), **drop** (obsolete), **revisit** (needs a decision).

| design-v2 part | Cite | Verdict | One-line reason |
|---|---|---|---|
| `spawn_task` chip as the desktop start | `:83`, `:35` | **drop** | Replaced by `start_session`; the chip was the thing that failed |
| Adopt fallback (`side-session.sh adopt`) | `:82`, `:104` | **drop** | The app creates and registers the worktree itself; nothing to adopt |
| Owned `git worktree add`/`remove` + `git branch -d` verdicts (`git.worktree.owned`, `git.branch.owned`) | `:95`, `:127-135`, `:53-54` | **revisit (decision D-1)** | The app now creates the worktree, so the consumer of the owned-create verdict may not exist; removal path unknown (see D-1) |
| Delegated-approval switch and facts lib | `:52`, `:145-146` | **revisit (D-1)** | Same dependency; findings F-11/F-12 (`:279-280`) already warned this was a contingent consumer |
| Orca adapter | `:83`, `:140` | **keep, unchanged** | Orca owns its own worktrees; independent of the desktop tool; still unverified for `--agent claude` (`:90`, `:287`) |
| Plain-terminal "no side sessions" | `:83`, `:92` | **keep** | Still true; fall back to workers/workflow (section 7) |
| Ledger `.claude/worktrees/side-ledger.jsonl` | `:106-107`, `:143` | **revisit (D-2)** | The app tracks parent/child itself (`parentSessionId`, `list_sessions`); a second record may duplicate it |
| Cleanup rules (clean + harvested before removal) | `:109-110`, `:101` | **keep (rule), revisit (mechanism)** | "Harvested is defined by git, not a ledger" stays; who removes the worktree is test T-d |
| Depth = 1 | `:113` | **keep** | Brief must still say "never spawn side sessions"; hook-side `cwd` enforcement was owned-verdict-only and goes with D-1 |
| Max 3 concurrent | `:113`, `:277` | **keep (followed)** | Matches the app's 3-cards-per-turn cap; still a followed rule |
| Brief contract (what a side session is told) | `:97-98` | **keep, amend** | Drop "never create worktrees/branches" wording that assumed a pre-made tree; keep never push, never leave the tree, never `gh`, report summary + commit range |
| Must-not list | `:115-116` | **keep** | Unchanged; each item is still the right boundary |
| "A side session is a main agent to hooks" | `:98`, `:234` | **keep** | Confirmed relevant: see section 4 |
| Helper `side-session.sh` | `:50`, `:104` | **revisit (D-3)** | Its jobs (create/start/direct/register) moved into the app; remaining value is brief generation and a status read |
| Personal-config text (section D) | `:203-213` | **drop** | Superseded by the owner's own CLAUDE.md "Side session" mode |
| Headless `-p` sessions | `:64` | **keep dropped** | Visible-only (M2) stands |

**Flagged decision.** The owned-worktree verdict (`design-v2.md:127-135`) was built so the harness could safely approve a `git worktree add -b side/<id> ...` that the directing session ran itself. With `start_session` the app makes the worktree and branch (name pattern `claude/<adjective-surname>-<hex>` was observed), so no `side/<id>` Bash command is issued and the verdict has no caller. See D-1.

## 4. Interaction with the git-safety gate and the FLOOR

- **A child is a main agent to the hooks** (no `agent_id`), so the gate's `ask` reaches the owner inside the child session, which is visible (`design-v2.md:98`, residual #11 at `:234`). Not yet re-tested for this tool: T-e.
- **FLOOR unchanged.** `git.push = ask [FLOOR]` at `.logic-loom/config/gate-policy.conf:90`; floor op list at `.logic-loom/lib/governance-verdicts.sh:970`. A child cannot silence it. "Never push child branches" is therefore followed in the brief and enforced once T-e passes (the gate prompting the owner inside the child). Caveat: `.claude/settings.local.json` is gitignored (`.gitignore:67`) and will not travel into an app-created worktree, so only hooks in the committed `.claude/settings.json` can apply there.
- **Merge stays ask.** `git.merge = ask` at `gate-policy.conf:103`; so the parent's merge of a child branch prompts the owner even after the parent verified it.
- **Cherry-pick harvest is NOT gated.** `git.cherry-pick = silent` (`gate-policy.conf:193`) lets a parent harvest a child's commits with no prompt. The clause and the policy must state that cherry-picking a child's commits also waits on the owner's instruction; this is followed, not enforced (see open decision D-8).
- **Worktree and branch ops stay ask.** `git.worktree.write = ask` (`gate-policy.conf:156`), `git.branch.write = ask` (`:151`). If the parent must remove a child's worktree after merge via Bash, it prompts. The app's own cleanup tools (`clean_up_worktrees`, `discard_kept_worktree`) are host-side and invisible to hooks (residual #13, `design-v2.md:236`). Do not claim they are gated.
- **Workers inside a child.** Subagents are denied all mutating git (`plugins/loom-governance/hooks/scripts/subagent-git-guard.sh`; verdict `governance-verdicts.sh:522-529`). A child that dispatches workers still has to do its own commits. Same as today.
- **Protected governance surface.** The child checks out the repo, so `.claude/settings.json` hooks travel with it (`design-v2.md:98`); whether they fire in an app-created worktree is T-e. Edits to hooks/gate-policy still go through the owner's prompts.
- **Uncommitted work in the parent checkout is not in the child.** A child branches from a commit. The parent must commit (or hand over a diff) before starting a child that needs that work.

## 5. Proposed LogicLoom deliverables (with acceptance criteria)

**P-1. Policy text: new "Side sessions" section in `.docs/policies/escalation-policy.md`** (after section 4, which currently ends at `:98`; section 5 "Enforced versus followed" at `:100-106` gets one line).
Acceptance: (a) states the hybrid trigger, card/`user_asked` start, parent-verifies-diff, ask-before-merge, depth 1, max 3, never-push, and the host fallback table; (b) states enforcement honestly: FOLLOWED except that push/merge/worktree/branch asks are hook-enforced by existing gate lines cited in section 4; (c) names the app tool as host-specific and says nothing about it for CLI/claude.ai/Cowork; (d) `tests/contract/test_disposition_tandem.sh` still passes. Caution: the pinned sentence E3 ("Pick the lightest execution mode that fits: background task, workers, workflow, or swarm; state it in one line.") enumerates the modes, and policy `:80` says "the four delegated modes". Adding a side-session mode requires updating E3 in all four places (`tests/contract/test_disposition_tandem.sh:74`, `.docs/policies/escalation-policy.md:12`, `AGENTS.md:120`, `CLAUDE.md:127`) plus the "four" count at `escalation-policy.md:80` in ONE commit (recommended); the alternative is to label side session an out-of-list host extension (see D-9). The pinned sentences are `escalation-policy.md:10-12`.

**P-2. Execution-mode clause update.** Add a "Side session" line to the clause in `features/escalation-advisor/exploration/personal-ladder-mode-clause.md:5-19` (shipped counterpart: `escalation-policy.md` section 4 table at `:82-88`, plus the one-liner at `orchestrator-worker-ladder.md:81-86`).
Acceptance (subject to D-9): the mode table gains a row "Side session (host tool; desktop app only)" with Use-when (hybrid a/b) and Do-not-use-when (single-sitting change; host lacks the tool; turn started by another session's message or an automated event, where the app refuses and the agent proposes instead); the "escalate the mode" paragraph says what moves to a side session (parallel layered scope) and what falls back (section 7); the owner's personal CLAUDE.md text is not edited by LogicLoom.

**P-3. Brief template** (inside the policy doc, not a script). Fields: goal, branch/base, owned files, must-not list (`design-v2.md:115-116`), required report (summary + commit range + test result), model/effort from the rung.
Acceptance: a parent can paste it into `start_session` with `context:"fresh"` or `"fork"` and the child's first report contains the commit range.

**P-4. Verification routine for the parent** (policy text). Before relaying a child report: `git log --oneline <base>..<branch>`, `git diff --stat`, read the diff, run the child's claimed tests, apply the rung's review (Standard and up: advisor/reviewer per `escalation-policy.md:41-60`). Evidence rule: quote the commit sha, not the child's claim.
Acceptance: the policy lists those exact checks; T-b exercises them.

**P-5. Optional helper (decision D-3).** If kept, a read-only `side-session.sh status` that prints the commit range and diff stat for a given child branch. No mutating git, consistent with `design-v2.md:104,140`. Not required for the first release.

**Not proposed:** any change to hooks, `gate-policy.conf`, `governance-verdicts.sh`, or protected paths. That is the main saving versus v2 (`design-v2.md:242-244`: packages P1-P6 and a Heavy-rung review on the protected package). Score for P-1..P-4: reversibility 1 (docs revert), width 1 (several docs that move together) = Standard.

## 6. Build-time test plan (run before the policy says "verified")

| Id | Test | Pass criterion | Status |
|---|---|---|---|
| T-a | Follow-up: parent calls `SendMessage` to a running and to an idle child `local_...` id | Message is delivered and acted on, not held or expired (the 2026-10-12 failure, `design-v2.md:1`); test in `default` and `acceptEdits` modes | **UNVERIFIED** |
| T-b | Two parallel children, non-overlapping files, each commits; parent verifies each diff then merges both | Both merge cleanly (merge asks the owner per `gate-policy.conf:103`); parent's pre-merge verification catches a deliberately wrong claim planted in one child report | not run |
| T-c | Start attempted on a turn that began from an automated event or another session's message | App refuses; agent falls back to a proposal card and says so | not run (refusal behavior known from the tool description, not tested) |
| T-d | Worktree cleanup after merge | Identify which of: parent Bash `git worktree remove` (asks, `gate-policy.conf:156`), the app's `clean_up_worktrees`, or the owner's sidebar action removes the tree and branch; confirm no dirty or unmerged work is lost; record the answer in the policy | not run |
| T-e | Hooks in the child | In an app-created worktree: `git push` and `git merge` produce the owner prompt in the child; a subagent inside the child is denied mutating git; protected-path edit prompts | not run |

Record results under `features/escalation-advisor/exploration/side-trial/` (the directory `design-v2.md:244` already reserves for build-time tests).

## 7. Host fallbacks

| Host | Behavior |
|---|---|
| Desktop app with `start_session` | Side session per P-1/P-2 |
| Claude Code CLI (terminal) | No side session (`design-v2.md:83,92`). Use workers; use `/workflow` for fan-out; `/swarm` where the project provides it (`escalation-policy.md:86-88`) |
| claude.ai, Cowork | Same: no native session tool assumed. Workers/workflow equivalents only. UNVERIFIED whether Cowork exposes any equivalent |
| Orca | Unchanged from `design-v2.md:83-86,90`: `orca orchestration run-create` + `worker-start --agent claude --worktree new-child`. Hooks firing for `--agent claude` still UNVERIFIED (`:90,:287`); `orca worktree rm` is outside the gate (residual #13) |
| Cloud/ssh child sessions | Report-back does not occur; a parent must not rely on it. Do not use for work the parent must verify unless the owner reads the result directly |

Detection rule for the policy: use a side session only when the tool is present in the session's tool list; otherwise behave as the fallback row.

## 8. Open decisions for the owner

1. **D-1: Keep or retire the owned-worktree/branch verdict (`design-v2.md:127-135`, protected package P6 at `:244`)?** Recommend **retire for now**: there is no caller on the desktop path, it costs a Heavy-rung protected-file build, and the gate's existing `ask` is acceptable for the rare manual cleanup. Revisit only if T-d shows cleanup always prompting and that annoys you. Tradeoff: manual worktree removal keeps asking.
2. **D-2: Keep the ledger?** Recommend **drop** and rely on the app's session list: `list_sessions {linked:true}` / `parentSessionId` is the record of children. `git branch --list 'claude/*'` is a hint only: it matches every app-made session branch, not only children. Tradeoff: no LogicLoom-side audit trail of who started what; add a one-line log entry in the parent's report instead.
3. **D-3: Ship a helper script?** Recommend **no helper in release 1**; policy text and brief template only. Tradeoff: verification stays a followed routine rather than a script.
4. **D-4: Concurrency cap enforcement.** Max 3 stays a followed rule (matches the app's per-turn card cap). Recommend **leave followed**; no way to enforce it in a hook without D-1 machinery.
5. **D-5: Child model/effort by rung.** Recommend the existing tier rule (`escalation-policy.md:74`): cost 0 low, 1 medium, 3 high, 4-5 xhigh. Observed child ran opus/medium; confirm the owner wants opus as the default child model for research-type jobs and Sonnet for build-type jobs.
6. **D-6: `fork` vs `fresh` context default.** Recommend **fresh with a written brief** for build children (the brief contract is the safety boundary, and a fork inherits the parent's whole conversation cost); `fork` only for research that needs the thread.
7. **D-7: Uncommitted parent work.** Recommend the policy requires the parent to commit (to a non-pushed branch, via the normal ask) or hand over a patch before starting a child that depends on it.
8. **D-8: Gate cherry-pick from child branches?** `git.cherry-pick = silent` (`gate-policy.conf:193`) means harvest by cherry-pick is unprompted. Decide whether to make cherry-pick from a `claude/*` child branch `ask`. Recommend **leave followed for release 1** (no gate change, consistent with "Not proposed" in section 5); tradeoff: the rule is honor-system until changed.
9. **D-9: How to add side session to the pinned mode list.** Option A (recommended): update E3, the "four delegated modes" count, and the four pinned copies in one commit. Option B: leave E3 unchanged and label side session an out-of-list host extension in the policy; tradeoff: the pinned sentence then understates the available modes.

## 9. Not verified (carry forward)

- Follow-up `SendMessage` to a child (T-a).
- That hooks fire in an app-created worktree (T-e); hooks are expected to, since the checkout carries `.claude/settings.json`.
- How cleanup is performed and whether it is gated (T-d).
- Behavior in `acceptEdits` and plan permission modes for children.
- The refusal path (T-c) beyond the tool description.
- Cowork/claude.ai equivalents.
- Orca items listed in `design-v2.md:287`.
- LogicLoom checkout note: this file was written while the checkout was on `feature/v7-update-migrations` with another session's uncommitted work; no other file there was touched. Line cites for `governance-verdicts.sh` (`:522-529`, `:970`) and `gate-policy.conf` (`:90`, `:103`, `:151`, `:156`) were re-checked on 2026-10-22; other cites are carried from `design-v2.md` and its own checks.
