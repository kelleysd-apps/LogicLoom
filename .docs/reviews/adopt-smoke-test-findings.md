# `logicloom init` — first real-repo smoke test: findings

**Date:** 2026-08-28
**Tester:** Claude Code session, acting on `.docs/guides/adopt-smoke-test.md`
**Package:** `/Users/bkelley/kelleysd-apps/LogicLoom/packaging/adopt` (dev checkout, unpublished)
**Target repo:** a disposable git worktree of the AI OS vault — a real markdown
repository, 248 tracked files, clean tree, scratch branch `worktree-adopt-smoke-test`
**Command applied:** `npx <pkg> init . --apply --only=all,hooks`
**Result:** exit 0 · `WROTE 407` · `SKIPPED 6` · `FAILED 0` · `NOT ATTEMPTED 0`

Six checks were run. **Four passed, two failed.** Neither failure destroyed or
corrupted anything — both are contract/documentation defects. One high-value test
could not be completed and is still owed; it is specified at the end with a repro.

---

## What passed

| # | Check | Evidence |
|---|---|---|
| 1 | Target's files untouched | `git status --porcelain` showed exactly one `M` (`.gitignore`, an approved merge target); everything else untracked-new. Nothing of theirs modified or dropped. |
| 2 | Merges did what they claimed | `.gitignore`: 66 insertions, **0 deletions**. Fence present at lines 18 and 82. Original 16 lines byte-identical to `HEAD` (only a blank separator line added above the fence). |
| 4 | Receipt exists and is honest | `.logicloom-adopt-receipt.json` has `schema`, `runs`, `uninstall`. All **407 of 407** claimed paths verified present on disk. Zero phantom entries. |
| 6 | Harness is functional | `constitutional-check.sh` → exit 0, 0 failed / 2 warned / 7 skipped, each skip carrying an explicit "not evaluated" reason rather than a silent pass. |

Also worth recording as working-as-designed: `keep-theirs` was 0 because there
were no collisions, and the tool wrote nothing at any point during planning —
verified by `git status` immediately after each `--json` run.

---

## Findings requiring action

### F1 — Re-running a successful apply is REFUSED, not a no-op. Contradicts shipped docs. (highest severity)

**`AGENT-INSTALL.md` states:** *"Re-running a successful install is a no-op that
says so. That is safe."*

**Observed:** exit **1**, `REFUSED — 2 blocking precondition(s)`, on preconditions
that **the tool's own first run created**:

```
[DIRTY-MERGE-TARGET]     .gitignore
  `.gitignore` is modified-but-uncommitted and the apply would MERGE INTO it

[UNTRACKED-UNDER-TARGET] .claude/
  `.claude/` is UNTRACKED and the apply would write inside it
  NOTE: this path was written by THIS TOOL in an earlier run (see the receipt).
```

The tool already has the information needed to resolve this: it discounts
`[ALREADY-ADOPTED]` from the receipt in the same report, and the second block
explicitly identifies the path as its own prior output. It then blocks anyway.

`Nothing was written.` — the safety property held.

**Why it matters beyond the doc:** the natural agent behaviour after an apply is
to re-run to confirm idempotency. That produces a hard refusal reading like a
failure, immediately after a successful install. An agent that trusts the guide
over the exit code may report a broken install; one that trusts the exit code may
try to "fix" it.

**Options (maintainer's call):**
- Extend the receipt-based discount to paths recorded in `runs[].wrote[].path`, so
  the tool's own output does not block its own re-run; or
- Correct `AGENT-INSTALL.md` to state that a re-run on an uncommitted tree refuses,
  and that the tree must be committed between apply and re-run.

### F2 — Two files were written that the plan never promised

Reconciled the plan's `buckets.additive[].targetPath` against the receipt's
`runs[0].wrote[].path`:

- **Written but not promised: 2**
  - `.logicloom-adopt-receipt.json`
  - `.claude/.logicloom-adopt-settings.json`
- **Promised but not written: 0**

Both are the tool's own bookkeeping and both are disclosed in the *apply report*
and the *uninstall procedure* — but not in the *plan*, which is the artifact a
user reviews and approves. `adopt-smoke-test.md` check 5 asks for "no path written
that the plan did not promise," so this is a literal failure of the stated contract.

**Suggested fix:** emit both in the plan (a `bookkeeping` bucket, or additive
entries flagged as tool-owned), so what a user approves is what lands.

### F3 — `counts.additive` is not a file count, and reads like one

`counts.additive: 62` sits directly beside an apply reporting `WROTE 407`.

The 62 mixes granularities — `kind` values present are `dir`, `file`,
`gitignore-line`, `json-key`, and **12 entries are whole directories** that expand
to hundreds of files. The numbers are both correct and not comparable.

**Suggested fix:** either label it (`counts.additive` → "plan entries, not files"),
or add a resolved file count so plan and apply can be compared at a glance. An
agent instructed to "compare the plan's counts to what was written" will hit this
on every run.

### F4 — Nothing warns that applying will itself block the next apply

This is the root cause that makes F1 surprising rather than merely wrong. Applying
necessarily dirties `.gitignore` and creates `.claude/` untracked — the exact two
conditions the preconditions refuse on. No `decisions[]` entry, `notes[]` entry, or
line in the apply report says so.

**Suggested fix:** one line in the apply report's closing section — *"the tree is
now dirty with our output; commit before re-running, or the next apply will
refuse"* — would remove the surprise without changing any behaviour.

### F5 — Unsupported Node/npm combination warns on every invocation

```
npm warn cli npm v12.0.2 does not support Node.js v20.20.2.
This version of npm supports: ^22.22.2 || ^24.15.0 || >=26.0.0
```

Every `npx` invocation emits this to stderr. Everything worked, but the
combination is formally unsupported. Worth an `engines` field in
`packaging/adopt/package.json`, and a decision on whether to warn or refuse.

### F6 — The smoke-test brief's own check 3 is unrunnable as written

`.docs/guides/adopt-smoke-test.md` check 3 says: *re-run the same apply → expect
`NO-OP`, writes nothing.* Per F1, a fresh install has not been committed at that
point, so the re-run refuses. Only the "writes nothing" half can pass.

**Suggested fix:** either add a commit step between check 2 and check 3, or change
the expectation to "REFUSED with self-inflicted preconditions, nothing written."

---

## Still owed — the highest-value test, not completed

Section 5 of the brief — *does `.claude/rules/` load at `CLAUDE.md` priority in
project scope?* — **was attempted and the result is inconclusive.** Reporting the
method honestly, because the negative result is not usable:

- The proxy used was a subagent, not a freshly launched session.
- **Fatal confound:** the testing session launched *before* the install existed
  (the worktree was created and adopted mid-session), so any inherited context was
  assembled when `.claude/rules/logicloom-*.md` was not on disk. A negative cannot
  distinguish "project rules don't load" from "they weren't there at launch."

**One usable data point did survive:** the subagent enumerated its own context and
named a **user-scope** rules file (`~/.claude/rules/ai-os-vault.md`). So user-scope
`.claude/rules/` demonstrably loads. **Project-scope remains untested.**

**Exact repro for whoever finishes it** — must be a session launched *after* the
install:

1. Open a fresh Claude Code session with cwd = the adopted repository.
2. Ask, without permitting a filesystem search: *"How many operations are on the
   gate-policy floor, and what are they?"*
3. Correct answer (from `.claude/rules/logicloom-governance.md:86-88`): **five** —
   `git.push`, `git.history-rewrite`, `gh.repo.admin`, `gh.secret.write`, `gh.auth`.
4. A second probe: *"What does `subagent-git-guard.sh` enforce?"* Correct answer:
   denies mutating git from a subagent, permits allowlisted read-only git, denies
   `gh` outright for subagents.

If it knows either without searching, `rules` mode is validated. If not, `import`
should become the default.

---

## Coverage gaps — not tested, no finding either way

State these so nobody reads this report as broader than it is:

- **Uninstall was never executed.** The procedure was read and judged coherent; it
  was not run.
- **`--claude-md` was never exercised.** The target had no `CLAUDE.md`, so the
  decision was correctly marked `applicable: false` and `import` mode — the one
  mode that appends to a user-owned file — is untested.
- **`keep-theirs` was never exercised.** Zero collisions in this repo, so the
  "theirs is kept, ours is dropped" path saw no traffic.
- **Exit code 4 (partial) was never reached.** No target partially landed.
- **Only one repo shape was tested** — a markdown/docs repository with no product
  workspace, no `package.json`, and no test suite. A code repo will exercise
  classification rules this run never touched.

---

## Answers to the brief's five report questions

1. **Every check, pass/fail** — table above; failures F1 (check 3) and F2 (check 5)
   with actual output.
2. **Anything the plan said that turned out not to be true** — F2 (two unpromised
   files) and F3 (`counts.additive` not comparable to what was written). Plus the
   `AGENT-INSTALL.md` no-op claim in F1.
3. **Was `decisions[]` enough to guide the user without inference?** **Yes.**
   `targets` was unambiguous, `hooks` carried an unusually honest consequence
   string that made the choice real, and `claude-md` was correctly suppressed with
   a reason. Nothing had to be inferred. The one gap is F4 — the decisions do not
   mention that applying blocks the next apply.
4. **The `.claude/rules/` result** — inconclusive; see "Still owed" above.
5. **Anything the tool refused, and was the refusal right?** One refusal: the F1
   re-run block. **Right in principle, wrong in this instance** — protecting
   uncommitted work is correct and having no `--force` is correct, but this block
   was raised against the tool's own output, which the same report identifies as
   its own. Per the brief's instruction, the refusal was relayed and not worked
   around; nothing was committed or stashed to clear it.

---

## Verdict

The tool's safety properties held under a real repository: it wrote nothing while
planning, modified nothing it did not announce, dropped nothing, deleted nothing,
ran no mutating git, and produced an accurate receipt. **Both failures are contract
and documentation defects, not data-safety defects.**

The single most important open item is the project-scope `.claude/rules/` load
test, because it decides a shipped default.
