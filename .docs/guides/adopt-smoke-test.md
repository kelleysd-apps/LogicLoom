# Adopt e2e smoke test — brief for a coding agent

**Give this file to an agent working in the TEST PROJECT, not in LogicLoom.**
Paste the whole thing, or point the agent at this path in a LogicLoom checkout.

This is the first end-to-end exercise of `npx logicloom init` against a real
repository. Everything before it was fixtures. The point is to find what
fixtures could not.

---

## Before you start

**The test project must be on a scratch branch with a clean tree.** The tool
refuses to touch a dirty tree, and that refusal is deliberate — but you want to
get past it to test the interesting parts. Confirm with `git status` and stop if
it is not clean.

### Try it in a worktree — the reversible way in

The recommended way to run this, and the way to recommend to anyone trying
LogicLoom for the first time: **adopt into a git worktree on a throwaway
branch.** Look at the result there, and only then decide whether to bring it
into a development or production branch.

```bash
cd /path/to/your-repo
git worktree add -b logicloom-trial ../your-repo-logicloom-trial
cd ../your-repo-logicloom-trial

npx $LOOM init .                                   # plan; writes nothing
npx $LOOM init . --apply --only=all --claude-md=rules
npx $LOOM init . --apply --only=hooks              # governance floor, opt-in
```

Your working checkout is never touched, and undoing the whole trial is two
commands:

```bash
cd /path/to/your-repo
git worktree remove --force ../your-repo-logicloom-trial
git branch -D logicloom-trial
```

(Both sequences were run end to end while writing this guide: the adopt exits 0
inside the worktree, and the removal leaves the original checkout clean.)

Worktrees are a pattern you will meet again — this harness's swarm pack is
worktree-based — and the harness ships a `SessionStart` hook,
`.claude/hooks/worktree-port-namespace.sh`, that gives each worktree its own
dev-server and database port range so sibling worktrees do not collide. It
no-ops silently outside a worktree.

### What you are agreeing to

Plainly, so nobody has to guess:

- **What it does not do.** It never deletes, never truncates, never moves your
  source, never overwrites a file it did not create, and never runs a mutating
  git command. Without `--apply` it has no write path at all. There is no
  `--force`. Every one of those is enforced in code — `copyFileNew` opens `'wx'`
  so the kernel refuses an existing path — not merely intended.
- **What it does.** With `--apply` it writes the targets you name, merges
  additively into `.gitignore` and (only if you ask) `.claude/settings.json`
  behind marked fences, and records every path it wrote in
  `.logicloom-adopt-receipt.json` so uninstall is a list you run.
- **What you accept.** This is new software and you run it at your own
  discretion. The properties above are design guarantees backed by tests, not a
  warranty that no defect exists; the software is provided as-is. The first
  real-repository run found no data-safety defect — nothing was deleted,
  dropped, overwritten or corrupted — and the two defects it did find were a
  contract and a documentation defect. The worktree above is the cheap way to
  keep that judgement yours.

`LOOM=/Users/bkelley/kelleysd-apps/LogicLoom/packaging/adopt` for the commands
below. The package is unpublished, so `npx logicloom` will not resolve — the
local path form is the working one.

---

## 1. The agent path

```
npx $LOOM init --agent-guide
```

Read it. It is the procedure. If anything below contradicts it, the guide wins
and that contradiction is itself a finding worth reporting.

## 2. Plan

```
cd /path/to/test-project
npx $LOOM init . --json > /tmp/plan.json
npx $LOOM init .                      # the human report, for your user
```

**Report to your user, in your own words:** the mode it chose and why, the four
bucket counts, anything blocking, and each entry in `decisions[]` — the question,
the options, and what the default would do. Do not paste the raw report at them.

Ask them what they want. Do not choose on their behalf.

## 3. Apply

Assemble the command from their answers. The flags are in `decisions[].flag`.

```
npx $LOOM init . --apply --only=<their answer> --claude-md=<their answer>
```

`--only` is mandatory. `hooks` is deliberately not in `--only=all` — if they want
the governance floor, it must be named.

## 4. Verify — this is the actual test

Run each and record the result.

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | Their files are untouched | `git status --porcelain` | only additions; nothing of theirs modified except the merge targets they approved |
| 2 | The merges did what they said | `git diff .gitignore` and `.claude/settings.json` | a fenced block appended; their existing keys and lines intact and in place |
| 3 | Idempotency | re-run the exact same apply command, **without committing first** | **exit 0**, reports `NO-OP`, writes nothing, and prints a `DISCOUNTED` section naming the blocks its own first run caused |
| 3b | The discount is narrow | append a line to `.gitignore`, then re-run the same apply | **exit 1**, `DIRTY-MERGE-TARGET`, and a note that the discount was *REFUSED* because the file changed since. Nothing written. Then remove your line again and the re-run is a `NO-OP` once more |
| 4 | The receipt exists and is honest | `cat .logicloom-adopt-receipt.json` | lists what landed, and carries an `uninstall` procedure |
| 5 | Plan matched apply | `counts.wouldWrite.total` in the plan vs `WROTE` in the apply report | **the same number.** And reconciling `buckets.additive[].targetPath` **plus `bookkeeping[].path`** against `runs[].wrote[].path` comes out empty in both directions |
| 6 | The harness is functional | `bash .logic-loom/scripts/bash/constitutional-check.sh` | runs and reports |

Two notes on the table, both of which cost an earlier tester time:

- **Check 3 runs on an uncommitted tree, on purpose.** An apply necessarily
  leaves `.gitignore` modified and `.claude/` untracked — its own output — and
  those are the two conditions a blocking precondition names. The applier
  discounts the blocks its own receipt accounts for, so the re-run is a `NO-OP`.
  Do not commit between check 2 and check 3; committing would test something
  easier than the thing that matters. Check 3b is the other half: a file the
  tool *merged into* is cleared only while its recorded content digest matches,
  so your own edit brings the block back.
- **Do not compare `counts.additive` to `WROTE`.** `additive` counts plan
  *units* — a directory is one unit and hundreds of files — so `62` beside
  `WROTE 407` is two correct numbers that are not comparable.
  `counts.wouldWrite.total` is the one to compare, and it should match exactly.

## 5. The unverified assumption — the most valuable thing you can test

`.claude/rules/` is believed to load at launch at `CLAUDE.md` priority. This has
been confirmed from vendor documentation and the CLI's own settings text, but
**never observed end to end in a project scope.** If it does not load, `rules`
mode silently installs three files nobody reads, and `import` mode should be the
default instead.

**This test has been attempted once and came back inconclusive.** The confound
is worth stating, because it is easy to repeat: the testing session had been
launched *before* the install existed, so whatever context it inherited was
assembled when `.claude/rules/logicloom-*.md` was not on disk. A negative result
from that session could not distinguish "project rules do not load" from "they
were not there at launch." One usable datum survived — a **user-scope** rules
file (`~/.claude/rules/...`) demonstrably does load. Project scope is untested.

### The repro — follow it exactly

Three conditions, and skipping any one of them produces another inconclusive
result:

1. **The session must be launched AFTER the install.** Not a subagent of an
   existing session, not a `/clear`, not a resumed session. Quit Claude Code
   entirely and start it fresh, with `cwd` set to the adopted repository. Rules
   files are read at launch; a session that started earlier never saw them.
2. **The probe must be unanswerable from general knowledge.** These facts exist
   only in the installed files, so a correct answer cannot come from training.
3. **The model must not search the filesystem for it.** Say so in the prompt —
   *"answer from what you already have loaded; do not read or search any files"*
   — and if it reads a file anyway, the run is void. Ask again in a new session.

Probe A:

> Answer from context you already have loaded — do not read or search any files.
> How many operations are on the gate-policy floor, and what are they?

Correct answer, from `.claude/rules/logicloom-governance.md`: **five** —
`git.push`, `git.history-rewrite`, `gh.repo.admin`, `gh.secret.write`, `gh.auth`.

Probe B:

> Same rule — no file reads. What does `subagent-git-guard.sh` enforce?

Correct answer: it denies **mutating** git from a subagent, permits an
explicitly allowlisted set of **read-only** git commands, and denies `gh`
outright for subagents.

**Report which probes it answered, and whether it read anything.** If it knew
without searching, `rules` mode is validated and stays the default. If it did
not, `import` should become the default instead. That single answer decides a
shipped default, which is why an inconclusive result is worth less than no
result — it looks like data.

---

## What to report back

1. Every check above, pass or fail, with the actual output for anything that failed.
2. **Anything the plan said that turned out not to be true.** This is the highest-value finding available and the whole reason for a real-repo test.
3. Whether the decisions list was enough to guide your user without you inferring anything.
4. The `.claude/rules/` result from section 5.
5. Anything you wanted to do that the tool refused, and whether the refusal was right.

## Refusals — do not work around these

The tool never deletes, never truncates, never moves source, never runs a
mutating git command, and never stashes. There is no `--force`.

**If it blocks: relay the remedy to your user and stop.** Do not clear the way
yourself, do not retry with different flags to get past it, and do not commit or
stash on their behalf to make a precondition pass. A block is the tool working.

If you believe a refusal is wrong, that is a finding to report, not an obstacle
to route around.
