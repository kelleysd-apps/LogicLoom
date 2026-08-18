# Shell Idiom Policy

**Version**: 1.0.0
**Effective Date**: 2026-08-17
**Authority**: Constitution v3.2.0 — Principle VI (Git Approval), Principle IV (Idempotency), Principle VII (Observability)
**Review Cycle**: Quarterly

---

## Purpose

This is a **style guide, not a linter.** It records five shell idioms whose
*absence* has produced real, reproducible failures — in this tree and in the
downstream Cosmos tree that fed them back. Each rule is here because something
broke, not because it reads nicely.

There is deliberately **no enforcement mechanism**. A linter over contributor
shell style would be overbearing on preferences a fork is entitled to hold. The
rules below are followed because the worked examples are real, and every worked
example in §1 is a file in this repository.

**Scope**: all shell under `.logic-loom/`, `plugins/`, `tests/`, `.claude/hooks/`,
and `.github/workflows/`. Applies to `bash 3.2` (stock macOS) as the floor —
see `tests/contract/test_suite_registration.sh` for the house bash-3.2 rules.

---

## 1. `set -e`-safe status capture

**Rule.** Never read `$?` after a `local`/`declare` assignment, and never use
`|| echo <default>` to paper over a command that *both* prints and exits
non-zero. Capture status explicitly:

```bash
rc=0
some_command || rc=$?
```

For a command whose *output* you also need, declare first and assign on its own
line — `local x=$(cmd)` makes `$?` the exit status of **`local`**, which is
almost always 0:

```bash
# WRONG — $? is local's status, not cmd's. Always 0.
local out=$(cmd)
if [ $? -ne 0 ]; then ...

# RIGHT — declare, then assign; $? now belongs to the command substitution.
local out="" rc=0
out=$(cmd) || rc=$?
```

### 1.1 Worked example — the `|| echo 0` two-line value

`grep -c` **prints `0` and exits `1`** when there are no matches. So
`$(... | grep -c PATTERN || echo 0)` does not yield `0` on no-match — it yields
the two-line string `0\n0`, which then blows up every arithmetic test
downstream. Reproduced against the live idiom in
`.logic-loom/scripts/bash/common.sh`:

```
$ changes=$(printf "M foo\nM bar\n")
$ n=$(echo "$changes" | grep -c "^A" || echo 0)
$ printf "value=[%s]\n" "$n"
value=[0
0]
$ [[ $n -gt 0 ]] && echo gt || echo notgt
bash: [[: 0
0: syntax error in expression (error token is "0")
notgt
```

The correct forms, both used in this tree:

```bash
# a) suppress grep's exit status without touching its output
n=$(printf '%s\n' "$hay" | grep -c "$pat" 2>/dev/null || true)
n=${n:-0}

# b) or use the shared helper
#    tests/contract/test_memory_search.sh:19-29 — `count_matches`
```

**Fixed sites in-tree that document this failure** (read them, they carry the
reasoning inline):

| File | What it records |
|---|---|
| `plugins/loom-memory/lib/keyword-backend.sh:153-159` | "Do NOT re-derive the count with `grep -c … \|\| echo 0`: grep -c PRINTS 0 and EXITS 1 on no match, so the `\|\| echo 0` appends a second line" |
| `tests/contract/test_memory_search.sh:19-29` | `count_matches()` — the sanctioned replacement helper |
| `.logic-loom/tests/test-git-safety.sh:130-134` | "assign first, capture status on the NEXT line. `local x=$(cmd)` …" |
| `.logic-loom/tests/test-policy-validation.sh:227-229` | "`\|\| true` would make `$?` unconditionally 0 — capture the real status" |

### 1.2 Known-outstanding instances

Every instance of this idiom found across `.logic-loom/`, `plugins/`, `tests/`
and `.claude/hooks/` at the time of writing. Fixed where trivial and safe;
listed where it is not.

| File:line | Idiom | Status |
|---|---|---|
| `.logic-loom/scripts/bash/common.sh` — `parse_conventional_commit_type()` | `grep -c … \|\| echo 0` ×6 — **live**; every `-gt` test in that function dies when a category has no matches | **FIXED** (now lines 462-470) |
| `.logic-loom/scripts/bash/validate-tasks.sh` | `grep -cE … \|\| echo "0"` ×3 — **live** on a tasks file with no `[P]` or no completed tasks | **FIXED** (now lines 95, 98, 101) |
| `plugins/loom-memory/scripts/memory-log.sh` | `grep -c … \|\| echo "0"` — **live**, and the value is interpolated bare into JSONL, so it emitted *invalid JSON* | **FIXED** (now line 28) |
| `plugins/loom-maintenance/scripts/extract-proposals.sh` | `grep -vc … \|\| echo 0` — **live** when the only upstream change is `.sdd-sync-ref` | **FIXED** (now line 405) |
| `tests/contract/test_spec006_integration.sh` | `grep -c '^### Principle' … \|\| echo "0"` — latent (the target always matches today) | **FIXED** (now line 256) |
| `.claude/hooks/user-prompt-submit/governance-preflight.sh:160` | `grep -c … \|\| echo "0"` — **live** when no domain keyword is detected | **OUTSTANDING** — protected governance surface (`protect-governance-files.sh`: subagent **deny**, main agent **ask**). Must not be fixed as a drive-by; needs its own approved change. |

**Not instances**, and deliberately left alone:

- `grep -oE … \|\| echo 0` (`common.sh:499-501`) — `grep -o` prints **nothing**
  on no match, so the fallback supplies the only value. Correct as written.
- `wc -l … \|\| echo 0` (`debug-hook.sh:161`,
  `cleanup-governance-logs.sh:157,191`) — `wc` does not fail on empty input; the
  fallback is unreachable, not corrupting.
- `jq … 2>/dev/null \|\| echo 0` (`test_product_workspace_boundary.sh`,
  `test_graph_bridge.sh`) — same shape: `jq` either prints a value or fails
  silently, never both.

The distinguishing test is simple: **does the command print a usable value *and*
exit non-zero on the empty case?** Only then does `|| echo <default>` append.

---

## 2. Merge-abort before restore

**Rule.** Never run a restore/checkout/reset against a tree that may be mid-merge.
Abort the merge first, then restore. A `git restore` during an unresolved merge
resolves conflicts by silently picking a side.

```bash
git merge --abort 2>/dev/null || true
git restore --source=HEAD --staged --worktree -- <paths>
```

**Why it is here**: a restore issued against a conflicted tree produced a
"clean" working copy that had quietly discarded one parent's changes — the
failure is invisible at the point it happens and only surfaces at review.

**Governance note**: both commands are git mutations. Under **Principle VI**
they are main-agent-only and pass through `git-safety-gate.sh` for approval;
`subagent-git-guard.sh` denies them outright from a subagent. This idiom
describes the *order* to use once approved — it is not a licence to run either
autonomously.

---

## 3. Scoped `--force-with-lease`, never bare `--force`

**Rule.** A force push names its ref and its expected remote state:

```bash
git push --force-with-lease=refs/heads/<branch>:<expected-sha> origin <branch>
```

Never `git push --force`. Never a bare `--force-with-lease` with no `=` scope —
bare lease checks the *local* remote-tracking ref, which a fetch you did not
intend can silently refresh, converting the safety check into a no-op.

**Why it is here**: bare `--force-with-lease` reads as safe and is not. The
scoped form fails loudly when someone else has pushed; the bare form can
succeed and overwrite them.

**Governance note**: force-push is **`require_approval`**, not blocked — the
hook must not stop the *ask* (see the `38b0144` disposition in
`.docs/reports/backlog-2026-08-13.md`). Approval is still mandatory, and the
autonomous force-push proposal was **REJECTED** as a direct Principle VI
violation. This rule constrains *how* an approved force-push is spelled.

---

## 4. Perform mutations in an isolated worktree

**Rule.** Batch or scripted mutation — history rewrites, sanitization passes,
bulk renames, release promotion — runs in a dedicated `git worktree`, never in
the user's checkout.

```bash
git worktree add /path/to/scratch-wt <branch>
# ... mutate inside the worktree only ...
git worktree remove /path/to/scratch-wt
```

**Why it is here**: an aborted bulk operation in the primary checkout leaves the
user with a tree they have to reason about mid-incident. In a scratch worktree,
abandoning the operation costs a `worktree remove`.

**Governance note**: `git worktree add|remove|prune|move|repair|lock|unlock` are
**gated** as of `38b0144` — they mutate. Sessions that are themselves
worktree-isolated must keep their git operations inside their own worktree.

---

## 5. Baseline run id + bounded waits when polling CI

**Rule.** Before triggering a CI run, capture the id of the newest existing run.
Then poll for a run whose id differs from that baseline, with a hard iteration
cap and a fixed sleep. Never poll "the latest run" unbaselined, and never poll
unbounded.

```bash
baseline=$(gh run list --workflow=<wf> --limit 1 --json databaseId \
             --jq '.[0].databaseId // "none"')
# ... trigger ...
tries=0
while [ "$tries" -lt 30 ]; do
  current=$(gh run list --workflow=<wf> --limit 1 --json databaseId \
              --jq '.[0].databaseId // "none"')
  [ "$current" != "$baseline" ] && break
  tries=$((tries + 1))
  sleep 10
done
[ "$tries" -ge 30 ] && { echo "timed out waiting for a new run" >&2; exit 1; }
```

**Why it is here**: without a baseline, the poller reads the *previous* run's
status, sees `success`, and reports a green result for a run that had not
started. Without a cap, a workflow that never dispatches hangs the session
indefinitely.

**Governance note**: `gh workflow run` and `gh run rerun|cancel` are **gated**
as of `38b0144`; subagents are denied `gh` wholesale, reads included. Read-only
`gh run list` from the main agent is ungated. Poll from the main agent.

---

## Non-goals

- **No linter.** Not shellcheck config, not a pre-commit hook, not a CI gate.
  Adding one would be overbearing on contributor style, which is the reason this
  is a guide.
- **No new abstraction layer.** Each rule is a spelling, not a helper library.
  Where a helper already exists (`count_matches`), use it; do not build more.

---

## References

- Constitution v3.2.0: `.logic-loom/memory/constitution.md`
- Governance threat model: `.docs/architecture/governance-threat-model.md`
- Testing Policy: `.docs/policies/testing-policy.md`
- Code Review Policy: `.docs/policies/code-review-policy.md`
- Backlog §3.5 (origin of this document): `.docs/reports/backlog-2026-08-13.md`

---

**Policy Owner**: Quality Department
**Last Reviewed**: 2026-08-17
**Next Review**: 2026-11-17
