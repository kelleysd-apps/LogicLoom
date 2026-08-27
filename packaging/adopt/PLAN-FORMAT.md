# `logicloom/adopt-plan@1` — the plan format

**Status:** the contract between the read-only half (built) and the applier
(**not built**). This file exists so the applier can be written against a
specification rather than against a guess about what the planner meant.

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
| `preconditions` | object | `{ blocking[], warnings[] }` |
| `buckets` | object | `{ additive[], "keep-theirs"[], replace[], obsolete[] }` |
| `counts` | object | per-bucket counts plus `total` |
| `defers` | array | unresolved `defer:` rows in the payload manifest |
| `errors` | array of string | anything that made the plan itself unsound |
| `notes` | array of string | named limits, meant to be printed |
| `applyReady` | boolean | **the gate.** See below. |

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
applyReady === (preconditions.blocking.length === 0 && errors.length === 0)
```

**An applier MUST NOT write anything when `applyReady` is `false`,** and MUST
NOT offer a flag that overrides it. Every blocking item is a condition under
which a write can destroy work that has no other copy. There is no `--force`,
because there is no case where forcing is the right answer to "your untracked
work is in the way".

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
| `.claude/settings.json` | `json-key` | **one hook command entry** |
| `.gitignore` | `line` | **one pattern line** |

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

One row stands today: `CLAUDE.md`, pending the `.claude/rules/` split (PRE-7).

---

## Compatibility

Additive fields may appear within `@1`; an applier must ignore unknown fields.
Removing a field, changing a field's meaning, or changing bucket semantics is a
new schema version. `lib/plan.js` holds `SCHEMA` as the single source.
