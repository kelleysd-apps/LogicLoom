# `logicloom/adopt-plan@1` — the plan format

**Status:** the contract between the read-only half and the applier. Both are
now built — `lib/plan.js` emits this, `lib/apply.js` consumes it. This file was
written first so the applier could be built against a specification rather than
against a guess about what the planner meant, and it stays normative: a change
here is a change to both halves.

**What the applier adds on top of this contract**, stated here because it is the
part a reader of the plan format will ask about:

* It **re-plans at write time**. A plan file is a review artifact, not an
  instruction set. `--apply` rebuilds the plan against the tree as it is and
  applies from that; `--plan <file>` is an *assertion* about what was reviewed,
  and a material divergence (mode, `applyReady`, the blocking set, the additive
  unit ids) refuses with the difference named.
* Units are grouped into four **targets a user types** — `harness` (path),
  `gitignore` (line), `rules` (rules), `hooks` (json-key). `--only=` is mandatory
  with `--apply`; `--only=all` expands to `harness+gitignore+rules` and **never**
  to `hooks`, because a governance floor must not install as a side effect of the
  word "all".
* The manifest's `exclude:` rows are applied **during the copy**. Nothing in the
  plan consults them — a `path` unit is `include: .logic-loom`, and the carve-outs
  beneath it (`.logic-loom/tests`, `update-agent-context.sh`) only exist in the
  manifest.
* On partial failure it **reports and stops**; there is no rollback, because a
  rollback is a delete path and this tool refuses to have one.
* Everything written is listed in `.logicloom-adopt-receipt.json` at the target
  root — the marker manifest named below. Uninstall is a list the human runs.

`logicloom init --json` emits exactly this shape on stdout. Nothing else is
written, anywhere, ever — see *The one invariant* below.

---

## The one invariant

**The planner has no write path.** Not to the target repo, not to a cache, not
to a temp file, not to `.git`. It runs no mutating git verb; the only git it
runs at all is the allowlist in `lib/git-ro.js`, which is a strict subset of
`plugins/loom-governance/hooks/scripts/subagent-git-guard.sh`'s read-only set.

An applier may therefore treat a plan as safe to produce at any time, against
any repository, including one it does not own.

---

## Top level

| Field | Type | Meaning |
|---|---|---|
| `schema` | string | `logicloom/adopt-plan@1`. **An applier MUST refuse a schema it does not know.** |
| `generatedAt` | ISO-8601 | when the plan was produced |
| `generator` | object | `{ package, version, nodeVersion }` |
| `payload` | object | `{ root, source, manifest, manifestEntries }` — where the harness tree came from |
| `mode` | object | `{ mode, reason, content[] }` — **new project or existing project.** See below |
| `target` | object | the repository the plan is about (see below) |
| `detect` | object | what the target already has; report-only, not an instruction |
| `preconditions` | object | `{ blocking[], discounted[], warnings[] }` |
| `buckets` | object | `{ additive[], "keep-theirs"[], replace[], obsolete[] }` |
| `bookkeeping` | array | **the files the TOOL writes**, which are not harness content. See below |
| `counts` | object | per-bucket **unit** counts, plus `bookkeeping` and `wouldWrite`. See below |
| `claudeMd` | object | **the integration mode** — how the harness's instructions reach the model here. See below |
| `defers` | array | unresolved `defer:` rows in the payload manifest |
| `errors` | array of string | anything that made the plan itself unsound |
| `notes` | array of string | named limits, meant to be printed |
| `applyReady` | boolean | **the gate.** See below. |
| `decisions` | array | **what the user must actually decide**, as data. See below |
| `agentGuide` | object | `{ file, command, summary, applyCommand }` — where the agent-facing procedure lives |

`decisions`, `agentGuide`, `bookkeeping`, `preconditions.discounted` and the
`counts.additiveEntries` / `counts.bookkeeping` / `counts.wouldWrite` keys are
**additive fields within `@1`**, added for agent-driven installs and for the two
defects the first real-repo run surfaced. The schema version is unchanged, which the compatibility
clause below permits: nothing was removed, no field changed meaning, and an
applier that ignores unknown fields is unaffected.

### `payload.source`

One of `explicit --payload`, `LOOM_ADOPT_PAYLOAD`, `packaged payload/`, or a
string starting `DEV FALLBACK`. A plan built against a dev checkout is not the
same artifact as one built against a packed payload; the field says which, and
the `DEV FALLBACK` case also adds a line to `notes`.

### `mode` — new project vs existing project

`init` serves both cases; that is why `init` is the right verb rather than
`adopt`. `mode.mode` is one of:

| Value | Meaning | Applier behaviour |
|---|---|---|
| `new-project` | the directory holds nothing but `.git` and OS droppings | scaffold fresh; every unit is `additive` |
| `existing-project` | the directory holds anything else | propose; write only what was approved |
| `unknown` | the directory could not be read | **refuse.** Emits `MODE-UNDETERMINED` as blocking |

`mode.reason` is a one-line human explanation and `mode.content[]` lists what was
seen. **Both are meant to be shown before anything happens** — the user must be
able to see which mode was chosen and why.

**The emptiness test, stated so it can be argued with.** The ignorable set is
short and closed: `.git`, `.DS_Store`, `.localized`, `Thumbs.db`, `desktop.ini`,
`.Spotlight-V100`, `.Trashes`. Anything else — one stray `README.md`, one
`LICENSE`, one `.gitignore` — makes the directory an **existing project**.

That errs toward `existing-project` deliberately. The existing-project path is
safe by construction: it proposes and does not write. So a false "existing"
costs the user one extra read of a plan, while a false "new" costs them their
files. `README.md` and `LICENSE` are specifically *not* ignorable, even though
they are plausible contents of a freshly created GitHub repo — treating them as
ignorable is exactly the tempting judgement that ends with someone's work
scaffolded over.

**The classifier is not special-cased by mode.** With nothing in the directory,
every unit falls out of rule `R2` as `additive` on its own. What differs is the
*report*: a new project gets a short "would create" list rather than a
four-bucket table with three empty buckets and a precondition list about dirty
files that cannot exist.

**Git-baseline preconditions soften in `new-project`.** `NOT-A-GIT-REPO` and
`NO-COMMITS` exist to protect something that could be lost; in an empty directory
there is nothing to lose and no prior state a revert would reach, so they are
emitted as `warning` rather than `blocking`. Every other precondition is
unchanged, including `MANIFEST-DEFER-OPEN`, which is about the payload rather
than the target.

**There is deliberately no separate `create-logicloom` package.** npm formalises
`npm create foo` → `create-foo` for scaffolding, and that would be the
conventional second entry point, but one detecting `init` covers both cases and a
second package doubles the publish and version surface for a convenience. If it
is ever wanted, it is a three-line wrapper.

### `claudeMd` — the integration mode

```json
{ "requested": "import", "resolved": "rules", "source": "--claude-md=import",
  "asked": false, "collapsed": true, "reason": "…", "targetHasClaudeMd": false,
  "ruleFiles": [".claude/rules/logicloom-governance.md", "…"],
  "options": [{ "mode": "rules", "summary": "…" }, …],
  "flag": "--claude-md", "env": "LOOM_ADOPT_CLAUDE_MD" }
```

`resolved` is one of `rules` (default), `import`, `none`, and it is a **pure
function of `(requested mode, does a CLAUDE.md exist in the target)`** —
`lib/claude-md.js`, no filesystem opinion, no heuristic, no model. The requested
mode comes from `--claude-md=<mode>` or, failing that, `LOOM_ADOPT_CLAUDE_MD`;
there is no prompt anywhere in this tool, so a scripted or CI install works.

| `resolved` | Applier behaviour |
|---|---|
| `rules` | write `.claude/rules/logicloom-*.md`. The adopter's `CLAUDE.md` is never opened, read, or written |
| `import` | the same files, **plus** one marked block appended to their `CLAUDE.md` carrying an `@` import of each. Append-only, fenced, idempotent, verified to be a pure append before the write lands |
| `none` | write nothing loadable — no rules files, no `CLAUDE.md` edit |

**`asked` is `false` when the target has no `CLAUDE.md`.** That is the
new-project case, and it is not a question: there is nothing to reconcile, and
this tool never creates a `CLAUDE.md`. A requested `import` then **collapses** to
`rules` with `collapsed: true`, recorded rather than ignored. The renderer prints
one line in that case instead of a three-option menu.

Under `import`, `CLAUDE.md` joins `.gitignore` and `.claude/settings.json` as a
merge target for preconditions, so a dirty or untracked `CLAUDE.md` **blocks**.

The resolved mode is a **material fact for `--plan` divergence** (reviewing a
`rules` plan and applying an `import` one is exactly the surprise `--plan`
exists to prevent) and is recorded in `.logicloom-adopt-receipt.json` under
`runs[].claudeMd`, so a re-run and an uninstall both know what happened.

### `target`

`root`, `isGitRepo`, `gitDetect` (`dir` | `worktree` | `none`), `hasCommits`,
`headState` (`attached` | `detached` | `unborn` | `unknown`), `currentBranch`,
`defaultBranch`, `defaultBranchSource`, `branches[]`, `inProgress[]`,
`trackedFiles`, and `adoption`.

`adoption.state` is `absent` | `partial` | `adopted`, with `evidence[]` naming
the marker paths found. `partial` is not resolved into one of the other two —
that is the point of having three states.

**Any string field may be the literal `"unknown"`.** The planner reports
`unknown` rather than guessing, exactly as
`.logic-loom/scripts/bash/detect-environment-topology.sh` does. An applier must
treat `unknown` as "do not proceed on this fact", never as a falsy default.

---

## `applyReady` — the gate

```
applyReady === (preconditions.blocking.filter(b => !b.selfCaused).length === 0
                && errors.length === 0)
```

**An applier MUST NOT write anything when `applyReady` is `false`,** and MUST
NOT offer a flag that overrides it. Every blocking item is a condition under
which a write can destroy work that has no other copy. There is no `--force`,
because there is no case where forcing is the right answer to "your untracked
work is in the way".

**The discount, stated because it is a deviation and must not be silent.**
`preconditions.blocking` is always the COMPLETE picture of the tree — nothing is
removed from it, ever. What is added is a per-item `selfCaused` flag, and
`preconditions.discounted` is the subset where it is `true`. `applyReady` is
computed over the rest. An item is `selfCaused` only when
`.logicloom-adopt-receipt.json` at the target root accounts for it:

| Code | Discounted when |
|---|---|
| `ALREADY-ADOPTED`, `PARTIAL-ADOPTION` | a prior run of this package is recorded here. Without this, a successful `--only=harness` would block the `--only=hooks` that completes the install. |
| `UNTRACKED-UNDER-TARGET`, `DIRTY-TARGET-PATH`, `DIRTY-MERGE-TARGET` | the receipt records writing at or under that path, **and** every file we MERGED into beneath it still matches the content digest recorded when we left it. Without this, the re-run that confirms an install exits 1 on the install that just succeeded. |

A `selfCaused` item carries `selfCausedReason`. An item where the discount was
CONSIDERED AND REFUSED — the adopter has edited a merged file since, or the
receipt predates digests — stays blocking and carries `selfCausedRefused` saying
so. **That refusal is the safety property**: an ordinary file this tool created
is unreachable by a re-run (refusal 1 opens 'wx', so an existing path is skipped
REFUSE-EXISTS), but a merge target is a file the adopter also owns, and it is
cleared by content or not at all.

It is **not** a flag, not user-settable, reaches nothing else, and is printed
every time it happens. A forged receipt buys nothing: in an already-adopted
repository every unit classifies `keep-theirs`, so the apply writes nothing
anyway, and forging a matching digest requires already knowing the exact bytes.

The exit code carries the same information for shell callers: `0` ready, `1`
blocked, `2` usage error, `3` the plan could not be produced.

---

## Preconditions

Each item:

```json
{
  "code": "UNTRACKED-UNDER-TARGET",
  "severity": "blocking",
  "path": ".claude/",
  "affects": [".claude/hooks", ".claude/agents"],
  "detail": "human-readable, names the actual paths",
  "remedy": "a command the HUMAN runs"
}
```

Codes currently emitted: `NOT-A-GIT-REPO`, `GIT-UNAVAILABLE`, `NO-COMMITS`,
`DETACHED-HEAD`, `IN-PROGRESS-REBASE` / `-MERGE` / `-CHERRY-PICK` / `-REVERT` /
`-BISECT`, `UNTRACKED-UNDER-TARGET`, `DIRTY-TARGET-PATH`, `DIRTY-MERGE-TARGET`,
`ALREADY-ADOPTED`, `PARTIAL-ADOPTION`, `MANIFEST-DEFER-OPEN`. Warnings:
`UNTRACKED-WORK-PRESENT`, `UNCOMMITTED-WORK-PRESENT`.

Items are grouped by the **actual dirty or untracked path**, not by the payload
target, because git collapses untracked directories: one `?? .claude/` concerns
six payload targets, and emitting six items whose remedies name six paths that
do not exist is worse than emitting one that names the path that does.

### `remedy` is never `git stash`

A stash is a git mutation. It succeeds silently, prints a cheerful line, and the
work is then one `git stash drop` — or one forgotten entry — from gone. Where a
backup is warranted the remedy is a `cp -a` **the human runs**, so the copy
exists outside git's object model and outside this tool's reach.
`tests/contract/test_adopt_planner.sh` asserts the string never appears in a
remedy.

---

## `bookkeeping` — the files the TOOL writes

Two files land that no manifest row names and no unit describes:

```json
{
  "path": ".logicloom-adopt-receipt.json",
  "owner": "tool",
  "kind": "file",
  "when": "every --apply run, including a no-op one",
  "purpose": "the record of what this tool wrote here, and the uninstall procedure…",
  "countedInWouldWrite": false
}
```

| Path | When |
|---|---|
| `.logicloom-adopt-receipt.json` | every `--apply` run, including a no-op one |
| `.claude/.logicloom-adopt-settings.json` | only when `hooks` is applied AND the settings merge inserts something |

**They are in the plan because the plan is what a user approves.** Both were
already disclosed — in the apply report and in the uninstall procedure — but
afterwards, and a file that lands must be in the artifact that was reviewed.

They are **not** additive units, deliberately: no manifest row names them, they
are not harness content, and an adopter uninstalling has to be able to tell the
harness from the installer's paperwork. `owner: "tool"` is that distinction, and
the second entry appears only when it would actually be written.

`countedInWouldWrite` says whether the file is inside `counts.wouldWrite.total`.
The sidecar is; the receipt is not, because the receipt is the record OF that
count and is written outside the unit worklist.

---

## `counts` — units, and the number that compares to an apply

```json
{
  "additive": 62, "additiveEntries": 62,
  "keep-theirs": 0, "replace": 0, "obsolete": 0, "total": 62,
  "bookkeeping": 2,
  "wouldWrite": { "harness": 401, "rules": 3, "gitignore": 1, "hooks": 2, "total": 407 }
}
```

**`additive` counts UNITS, not files, and that is not a wording problem.** A unit
is the granularity a DECISION is made at — a directory, a file, one `.gitignore`
pattern, one settings hook command — so `additive: 62` sat next to an apply
reporting `WROTE 407` and invited a reader to conclude one of them was wrong.
Twelve of those 62 are whole directories expanding to hundreds of files. Both
numbers were correct; they were not comparable.

`additiveEntries` is the same number under a name that says what it counts.
`additive` keeps its meaning for existing consumers.

**`counts.wouldWrite` is the comparable number.** It resolves the units to the
paths a write would create, broken down per `--only` target:

| Key | Counts |
|---|---|
| `harness` | files **and** directories the copy would create |
| `rules` | `.claude/rules/` files |
| `gitignore` | `1` — one fenced merge, whatever the pattern count |
| `hooks` | `2` — the settings merge and its sidecar |
| `total` | what `--apply --only=all,hooks` reports as `WROTE`, on a tree that has not moved |
| `resolvedFrom` | how many units of each granularity produced the above |
| `unresolved` | anything that could not be resolved, named. `total` is `null` when the payload manifest could not be loaded |

It is produced by running **the applier's own traversal** (`lib/fsops.js`
`copyTree`) with `ctx.predictOnly`, which suppresses the two write calls and
nothing else — same exclusion rows, same symlink and secret refusals, same
REFUSE-EXISTS check. There is one traversal, so the promised number cannot drift
from the copy it predicts.

---

## Units — the applier's actual worklist

Every entry in `additive`, `keep-theirs` and `replace` is a **unit**:

```json
{
  "id":          "settings-hook:PreToolUse|Bash|bash .../git-safety-gate.sh",
  "kind":        "file" | "dir" | "json-key" | "gitignore-line",
  "granularity": "path" | "json-key" | "line",
  "sourcePath":  ".claude/settings.json",
  "targetPath":  ".claude/settings.json",
  "action":      "copy" | "merge-json-key" | "append-line" | "skip",
  "bucket":      "additive",
  "rule":        "R2",
  "reason":      "command not present",
  "targetExists": false,
  "strategy":    "hooks-object-additive-marked",
  "selector":    { "match": "hooks-command", "event": "PreToolUse", "matcher": "Bash", "command": "…" },
  "value":       { "type": "command", "command": "…", "timeout": 3000 },
  "renamedFrom": "AGENTS.md",
  "manifestLine": 225
}
```

### Granularity — why four buckets are enough

A file-level classifier would need a fifth `merge` bucket, because
`.claude/settings.json` and `.gitignore` are neither ours nor theirs. Classifying
at the level the *decision* is made at removes the need:

| Payload thing | Granularity | One unit is… |
|---|---|---|
| `.logic-loom/`, `plugins/`, `.claude/agents/`, … | `path` | the path |
| `.claude/settings.json` | `json-key` | **one hook command entry of `merge/settings-hooks-fragment.json`** |
| `.gitignore` | `line` | **one pattern line of `merge/gitignore-block.txt`** |
| `.claude/rules/logicloom-*.md` | `rules` | **one authored rules file** |

**The two merge granularities enumerate the SHIPPED MERGE ARTIFACT, not the
payload.** A `json-key` unit comes from `merge/settings-hooks-fragment.json` and
a `line` unit from `merge/gitignore-block.txt` — the same two files the applier
hands to `merge_settings_json.py` and `merge-gitignore.sh`. Each such unit
carries `mergeSource` naming its file. This is structural, not a convention: the
planner previously derived line units by filtering LogicLoom's own `.gitignore`
by harness-owned prefix, which promised three patterns the curated block
deliberately drops and omitted five it ships. A plan is the artifact under
review; it may not overstate or understate what the apply will write. `sourcePath`
and `targetPath` remain `.gitignore` / `.claude/settings.json` — the merge target
is still the file being merged into.

A `rules` unit carries `sourceRoot: "package"` and its `sourcePath` resolves
against the **package** root, not the payload root — it comes from a manifest
`author:` row, and those files are authored by the adopt package rather than
carried in the harness tree. Everything else about it is an ordinary path unit,
including refusal 1: an existing file at the target path is kept, never
overwritten.

At that granularity every unit has exactly one counterpart-or-not question.

### `action`, per granularity

- **`copy`** — copy `payload/<sourcePath>` to `<target>/<targetPath>`. A `dir`
  is recursive. `renamedFrom` is informational; `targetPath` is authoritative.
- **`merge-json-key`** — add `value` into the target's `hooks` object under
  `selector.event`, in the group whose `matcher` equals `selector.matcher`,
  creating the event/group if absent. Additive only: **never remove or reorder
  an entry the adopter added.** Fence with a marker so a re-run is idempotent,
  and preserve the adopter's existing indentation
  (`detect.claude.settings.indent` carries `"2"`, `"4"`, `"tab"` or `"unknown"`)
  — husky's `init` is the precedent for the care level.
- **`append-line`** — append `value` to `.gitignore` inside a marked fence.
- **`skip`** — do nothing. Every `keep-theirs` unit carries this.

**Match on `selector`, never on array index.** The index of a hook entry is not
stable across the adopter's own edits; `(event, matcher, command)` is.

### Bucket semantics

| Bucket | Applier behaviour |
|---|---|
| `additive` | apply, using `action` |
| `keep-theirs` | **never write.** Present so the drop is visible, not silent |
| `replace` | apply, overwriting. Empty by design — see below |
| `obsolete` | **never write.** Not units; findings about the target |

### `obsolete` entries are a different shape

```json
{ "kind": "missing-hook-script", "source": ".claude/settings.json",
  "reference": "scripts/gone.sh", "detail": "…", "action": "report-only" }
```

`kind` is `missing-hook-script`, `missing-import`, or `missing-cited-path`. No
applier ever actions these: the reference may be to a file the human is about to
write.

---

## The classifier's rules

Each unit carries the `rule` that produced it.

| Rule | Bucket | Condition |
|---|---|---|
| `R0` | *(error)* | the manifest names a path the payload does not contain |
| `R1` | `replace` | `targetPath` is in `REPLACE_ALLOWLIST` in `lib/classify.js` |
| `R2` | `additive` | no counterpart at `targetPath` / `selector` |
| `R3` | `keep-theirs` | a counterpart exists and `R1` did not name it — **the default for every collision** |
| `R4` | `keep-theirs` | a counterpart exists and is byte-identical (or, for `json-key`/`line`, the same command/pattern) |

An unknown counterpart (their `settings.json` does not parse, their `.gitignore`
is unreadable) resolves to `R3`. **Failing toward theirs is the fail-safe
direction**, and it is chosen deliberately.

### `replace` is empty, and that is the design

`REPLACE_ALLOWLIST` is an empty array. There is no rule that *computes* "ours is
better" — a classifier cannot know that about a file it has not read, and one
that guesses it overwrites someone's work. An entry requires the path named
explicitly, with a `reason` a human can disagree with and a `test` describing
what would have to be true of the adopter's copy. Near-empty is the target state,
not a stub awaiting fill.

---

## Manifest `defer:` rows

`packaging/adopt/payload-manifest.txt`'s own grammar says the installer must
refuse to run while a `defer:` row stands. The planner enforces that by emitting
`MANIFEST-DEFER-OPEN` as **blocking**, which makes `applyReady` false. The rows
are also listed in `defers[]` and printed as their own report section — because a
`defer:` is why a collision the adopter can *see* in their repo (their 500-line
`CLAUDE.md`) may be absent from the buckets: not resolved, not classified.

**No row stands today.** The one that did — `CLAUDE.md`, pending the
`.claude/rules/` split (PRE-7) — was resolved on 2026-08-27 into an
`exclude: CLAUDE.md` (our file never ships) plus three `author:` rows and the
`claudeMd` integration mode above. `logicloom init --apply` therefore runs
end-to-end against the shipped manifest. Adding a new `defer:` row blocks every
apply again, by design.

---

## `decisions` — the questions, as data

The plan already *contains* every choice: `claudeMd` carries the integration
mode, `buckets` carries the worklist, `preconditions` carries what blocks. A
person reading the rendered report gets them for free, because the report is
written to present them. An **agent** does not — it has to reverse-engineer
"what must my user decide?" out of four unrelated fields, and every agent does
that slightly differently. That is a contract gap, not a documentation gap.

So it is stated once. Each entry:

```json
{
  "id": "targets",
  "question": "Which parts of LogicLoom should be installed here?",
  "kind": "multi-select",
  "required": true,
  "applicable": true,
  "notApplicableReason": null,
  "flag": "--only",
  "flagForm": "--only=<comma-separated values, or \"all\">",
  "env": null,
  "default": { "value": "all", "expandsTo": ["harness","gitignore","rules"], "why": "…" },
  "options": [ { "value": "hooks", "summary": "…", "consequence": "…",
                 "inDefault": false, "wouldWrite": 11, "wouldKeepYours": 0,
                 "noOp": false } ],
  "notes": ["…"]
}
```

| Field | Meaning |
|---|---|
| `id` | stable. `targets`, `claude-md` |
| `kind` | `multi-select` or `single-select` |
| `required` | the flag must appear in the apply command; there is no default-by-omission |
| `applicable` | **`false` means do not ask.** `notApplicableReason` says why — it is a case the tool has already settled |
| `flag` / `flagForm` / `env` | **the exact flag that sets the answer.** An applier must not infer one |
| `default` | `value` + `why`. Answering every decision with its default is a valid, complete install |
| `options[].consequence` | the sentence a summary cannot carry — what the option does to the user's repository |
| `options[].noOp` | nothing to do for this option here; mention it, do not ask about it |
| `resolved` | (`claude-md` only) what the flags/env already in force resolved to |

**Two properties this list commits to.** It is **derived** — target options come
from `lib/apply.js`'s `TARGETS`, mode options from `lib/claude-md.js`'s `MODES`,
so adding either adds an option automatically rather than requiring a second
list to be remembered. And it introduces **no policy**: every `default` is the
behaviour the tool already has when the flag is omitted, and every
`applicable: false` is a collapse the tool already performs. `lib/decisions.js`
reports; it does not choose.

Today the set is two: `targets` (`--only`) and `claude-md` (`--claude-md`). The
other flags — `--payload`, `--manifest`, `--plan`, `--json` — are operational
and are not decisions a user is asked to make.

## `agentGuide` — where the procedure lives

```json
{ "file": "AGENT-INSTALL.md", "command": "npx logicloom init --agent-guide",
  "summary": "…", "applyCommand": "npx logicloom init <dir> --apply --only=<targets>" }
```

`AGENT-INSTALL.md` ships in the package and is printed by
`npx logicloom init --agent-guide`, which resolves no target, reads no
repository and writes nothing. It is an **output mode** and not only a file
because of the chicken-and-egg: the adopting project does not have LogicLoom
yet, so the procedure cannot be a skill or a slash command, and an agent has no
reason to go reading inside `node_modules`. The human report prints one pointer
line at its foot; the report itself is unchanged.

## Compatibility

Additive fields may appear within `@1`; an applier must ignore unknown fields.
Removing a field, changing a field's meaning, or changing bucket semantics is a
new schema version. `lib/plan.js` holds `SCHEMA` as the single source.
