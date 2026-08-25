# Shell Idiom Policy

**Version**: 1.3.0
**Effective Date**: 2026-08-25
**Authority**: Constitution v3.3.0 — Principle VI (Git Approval), Principle IV (Idempotency), Principle VII (Observability)
**Review Cycle**: Quarterly

---

## Purpose

This document records seven shell idioms whose *absence* has produced real,
reproducible failures — in this tree and in the downstream Cosmos tree that fed
them back. Each rule is here because something broke, not because it reads
nicely.

## What is enforced and what is not

Two different things live in this file, and conflating them is how a document
starts lying about itself.

| | Enforced? | By what |
|---|---|---|
| **The seven idioms** (§1-§7) | **No** — style guide | Nothing. Deliberately. A linter over contributor shell style would be overbearing on preferences a fork is entitled to hold. The rules are followed because the worked examples are real, and every worked example in §1 is a file in this repository. |
| **The bash 3.2 floor** (below) | **Yes** — fails CI | `tests/contract/test_bash32_floor.sh`, run by `tests/run_all_tests.sh` and by `.github/workflows/plugin-tests.yml` |

The floor is not a style preference: a `declare -A` in a harness script does not
run at all on stock macOS `/bin/bash`, and the `/specification` quality gates
and `load-context.sh` shipped broken for every macOS user before the gate
existed. That is a correctness bug, not a taste. Hence the asymmetry.

## Scope of the bash 3.2 floor

`bash 3.2.57` (stock macOS `/bin/bash`) is the floor for **harness-owned
shell**. Concretely, and exactly as `test_bash32_floor.sh` scans:

| Path | In scope | Why |
|---|---|---|
| `.logic-loom/`, `.claude/hooks/`, `tests/` | **Yes**, wholesale | Framework-owned by the harness↔product boundary in CLAUDE.md — product code lives in `web/` or `apps/<name>/`, never here |
| `plugins/<p>/` for a plugin **declared in CLAUDE.md's Plugin Registry table** | **Yes** | The harness's own bundled plugins |
| `plugins/<p>/` for any other plugin | **No** | Your plugin, your runner, your call |
| `.github/workflows/` | **No** | See below |

**Why `plugins/` is split.** `plugins/` is the one genuinely mixed namespace: it
holds the eight bundled harness plugins *and* whatever you build there under
Principle XVI / `/create-plugin`. The floor exists because *the harness's* scripts
must run on stock macOS bash — your plugin has no such obligation, and
`declare -A` on your ubuntu/bash-5 runner is a perfectly ordinary thing to write.
Enforcing our portability floor on your plugin code turned your first push red
for something you legitimately did; that was a defect, and this scoping is the
fix.

**The discriminator is a declaration, not a name prefix.** A plugin is
harness-owned iff it appears in the **Plugin Registry** table in `CLAUDE.md` —
the harness's own published inventory of what it ships. A manifest flag was
considered and rejected: it would have to be added to eight `plugin.json` files
that a fork is free to copy, which makes the marker meaningless the first time
someone scaffolds from one of ours. Listing your own plugin in that table is the
supported way to opt **into** the floor, and it is the only reading of that edit.

**The gate must not go decorative.** The risk of scoping by declaration is a
harness plugin quietly dropped from the table and therefore from the scan.
Section 1b of the suite is the backstop: any directory under `plugins/` named
`loom-*` or `sdd-*` that the registry does not declare **fails the suite by
name**. That check can only add coverage, never remove it. The corollary: if you
name your own plugin `loom-something` you have taken our namespace, and the
suite will treat it as ours and hold it to the floor. Name it anything else.

**`.github/workflows/` is deliberately out of scope**, and this is a correction
— an earlier version of this policy claimed the floor covered it while the gate
never scanned it. Every workflow in this repo is `runs-on: ubuntu-latest`
(bash 5), and a `run:` block executes nowhere else — never on a developer's
macOS shell. The floor's entire rationale is absent there, so the *claim* was
the wrong half, not the coverage. A workflow that **calls** a harness script is
still covered, because the script is.

Both directions are asserted, on a purpose-built synthetic tree, in section 2b
of `tests/contract/test_bash32_floor.sh`: a harness plugin's `declare -A` is
caught, a customer plugin's is not.

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

## 6. Never end a `pipefail` pipeline in an early-exiting consumer

**Rule.** Under `set -o pipefail`, never write `producer | grep -q …` (or
`| head -N`, or `| grep -m1`). The consumer exits the instant it has its answer,
closes the pipe, and the producer takes `SIGPIPE` — which `pipefail` then
propagates as the pipeline's status. Feed the consumer a **here-string** built
from a captured value instead. No pipe, no race, and `pipefail` stays on for
every other pipeline in the file.

```bash
# WRONG — a MATCHING grep can report failure. grep -q exits on the first hit,
# printf takes SIGPIPE, and pipefail makes the whole pipeline non-zero.
if printf '%s' "$OUT" | grep -q 'GATE CLEARED'; then

# WRONG — same shape, any producer, any early-exiting consumer.
if head -10 "$f" | grep -q "$MARKER"; then
value=$(cmd | grep -oE '[0-9]+' | head -1)

# RIGHT — here-string: the consumer reads a temp file, so there is no writer
# to signal. Flags and pattern are unchanged.
if grep -q 'GATE CLEARED' <<< "$OUT"; then
if grep -q -- "$MARKER" <<< "$(head -10 "$f")"; then

# RIGHT — where a consumer must stay in the pipeline, use one that reads to EOF.
value=$(cmd | grep -oE '[0-9]+' | sed -n '1p')
```

Do **not** "fix" this by dropping `set -o pipefail` for the assertion — that
silently weakens every other pipeline in the file, which is a far larger loss
than the one line being repaired.

**Why it is here.** `tests/contract/test_promotion_lifecycle.sh` asserted with
`printf '%s' "$OUT" | grep -q 'different claims'`. The assertion failed
**precisely because it succeeded**: `grep -q` matched early and exited, `printf`
died on the closed pipe, and `pipefail` scored the match as a failure. A 40-run
loop measured **18 failures** — reported as `printf: write error: Broken pipe`
about half the time and as a bare `❌ FAIL` the rest, since a builtin killed by
`SIGPIPE` does not always get to print. Two separate workers in one session
reported the suite red when it was green, which is the real cost: a harness that
lies at random trains everyone to re-run until it agrees with them.

The size of the producer's output is **not** a defence. The failing case emitted
a few hundred bytes — well under the pipe buffer — and still raced roughly one
run in two. Treat every `pipefail` pipeline ending in an early-exiting consumer
as at-risk unless the producer is a here-string or a file redirect.

Repaired across the test tree in one pass (204 sites in 22 files); consumers
that read to EOF (`grep -c`, `sed -n '1,Np'`, `wc`) were left alone, as were
`$(…)` captures in files without `set -e`, where the status is discarded.

---

## 7. Filter `git ls-files` for presence before you stat, read, or archive

**Rule.** Never feed `git ls-files --cached` (or bare `git ls-files`) straight
into anything that must stat, read, or archive each path. `--cached` reports the
**index**, so a tracked file deleted but not yet committed is still listed, and
the consumer dies on a path that is not on disk. Filter for presence first.

```bash
# WRONG — one tracked-but-deleted path and tar exits non-zero, taking the
# whole pipeline (and whatever function wraps it) with it.
git ls-files -z --cached --others --exclude-standard | tar --null -T - -cf -

# RIGHT — drop paths that are not on disk, and only those.
git ls-files -z --cached --others --exclude-standard \
  | while IFS= read -r -d '' f; do
      [ -e "$f" ] || [ -L "$f" ] || continue
      printf '%s\0' "$f"
    done \
  | tar --null -T - -cf -
```

`--others --exclude-standard` still contributes untracked-but-present files —
the filter takes nothing away from that. The `-L` test keeps dangling symlinks,
which are on disk and which `tar` handles.

**This does not apply to membership questions.** "Is this path tracked?" is
correctly answered *yes* for a deleted-but-tracked file, and
`check-generated-freshness.sh` depends on exactly that to keep its rot-detection
teeth. The distinguishing test is the same shape as §1's: **does the consumer
have to touch the path, or only name it?** Only the first needs the filter.
Verified unaffected, and deliberately left alone:

| File:line | Why it is fine |
|---|---|
| `.logic-loom/scripts/bash/strip-harness-dev.sh:35` | Feeds `rm -f` — an already-absent path is the desired end state |
| `.logic-loom/scripts/bash/check-generated-freshness.sh:410` (`index_flag`) | Reads an `ls-files -v` status letter; a deletion is signal, not an error |
| `tests/contract/test_backlog_index.sh:421`, `tests/contract/test_generated_artifacts_declared.sh:205` | Membership assertions — never open the path |

**Why it is here.** `tests/contract/test_shipped_gates_vs_strip.sh` built its
throwaway tree with the WRONG form above. Three tracked scripts were deleted
mid-session as an intentional fix — an utterly ordinary state during exactly the
cleanup work that suite exists to guard — `tar` could not stat them, exited
non-zero, and the builder returned 1. The suite reported **25/27, exit 1**;
restoring the files gave **32/32**; re-deleting gave **25/27** again. Causation
established in both directions.

There are two lessons here, not one. The failure named the *strip pipeline*
rather than the builder, because a `2>/dev/null` on the copy stage swallowed
`tar: …: Cannot stat`. A diagnostic silencer on the stage that can fail is how a
five-second fix becomes a session-long hunt; capture stderr and reprint it on
failure instead.

What makes this a rule and not a one-off repair is that
`.logic-loom/scripts/bash/leak-guard.sh:44` had already arrived at the identical
filter independently —
`TRACKED="$(git -C "$REPO_ROOT" ls-files | while IFS= read -r _f; do [ -e "$REPO_ROOT/$_f" ] && printf '%s\n' "$_f"; done)"`
— so the bug was found and fixed once before, in isolation, and the second site
was then written without that knowledge. Two spellings of one rule is precisely
what this document is for.

---

## Non-goals

- **No linter for §1-§7.** Not shellcheck config, not a pre-commit hook, not a
  CI gate. Adding one would be overbearing on contributor style, which is the
  reason those seven rules are a guide. This does **not** extend to the bash 3.2
  floor, which is a correctness gate and *is* enforced — see
  [What is enforced and what is not](#what-is-enforced-and-what-is-not).
- **No new abstraction layer.** Each rule is a spelling, not a helper library.
  Where a helper already exists (`count_matches`), use it; do not build more.

---

## References

- Constitution v3.3.0: `.logic-loom/memory/constitution.md`
- Governance threat model: `.docs/architecture/governance-threat-model.md`
- Testing Policy: `.docs/policies/testing-policy.md`
- Code Review Policy: `.docs/policies/code-review-policy.md`
- Backlog §3.5 (origin of this document): `.docs/reports/backlog-2026-08-13.md`
- bash 3.2 floor gate: `tests/contract/test_bash32_floor.sh`

---

**Policy Owner**: Quality Department
**Last Reviewed**: 2026-08-25
**Next Review**: 2026-11-25
