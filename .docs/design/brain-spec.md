# `.brain/` — design specification

**Status:** design only. No repo file changed, no git mutation run.
**Repo:** `/Users/bkelley/kelleysd-apps/LogicLoom` @ `dev-main`, v6.5.0.
**Sibling system:** `/Users/bkelley/kelleysd-apps/AI OS` (`_agent/SCHEMA.md`, `_agent/memory/MEMORY.md`).

The premise, restated in the vault's own words: the vault's `projects/` rule is
*"a project's own code/docs stay in its actual repo — link to it via the `repo`
field, don't duplicate it into the vault."* `.brain/` is the same move one level
down: **a document whose location is load-bearing stays where its reader expects
it; `.brain/` holds a distilled, linked entry that points at it.** `.brain/` is
the index of record. It is the storage of record only for documents nothing reads.

---

## 1. The boundary, as a test

Two questions, asked in this order. Neither requires asking the maintainer.

> **Test A — the parse test.** *Does any script, hook, test, or command read this
> file's **content** to make a decision?*
> Not "does anything reference the path" — that is a doc cross-reference and
> costs a `sed`. **Parses the bytes and branches on them.**
>
> **Test B — the reuse test.** *Would this file still be true in someone else's
> clone of LogicLoom?*
> Yes = it describes the system (a reusable convention). No = it is a record of
> *our* use of the system (a project-specific instance).

The two answers give four cells:

| | **A: nothing parses it** | **A: something parses it** |
|---|---|---|
| **B: reusable convention** | Ships in place. `.docs/policies/`, `.docs/architecture/`, `features/README.md`, `.logic-loom/templates/` | Ships in place — it *is* machinery. `constitution.md`, `gate-policy.conf`, `template-strip-manifest.txt` |
| **B: project-specific instance** | **`.brain/` — storage of record.** The file moves. | **`.brain/` — index of record.** The file does **not** move; `.brain/index/` holds a pointer entry. |

`.brain/` owns the entire bottom row. What differs between the two bottom cells
is only *whether the bytes move*. That is the whole design.

**Why Test A comes first.** It is the one with a mechanical answer (`grep` for the
path inside `.logic-loom/scripts`, `.claude/hooks`, `tests/`, `plugins/`) and the
one whose wrong answer breaks a gate rather than merely misfiling a document.

### 1.1 Applied to every existing doc location

| Path | Parsed by | Instance? | Verdict |
|---|---|---|---|
| `.docs/architecture/*.md` | no | convention | **ships in place** |
| `.docs/policies/*.md` (13 files) | no | convention | **ships in place** |
| `.docs/references/**` | no | convention | **ships in place** |
| `.docs/guides/{FRAMEWORK_SYNC,git-push,unified-specification}-guide.md` | no | convention | **ships in place** |
| `.docs/guides/dev-main-template-split.md` | no | **instance** (our release runbook) | **→ `.brain/wiki/`** |
| `.docs/governance/{browser-*,hybrid-architecture}.md` | no | convention | **ships in place** |
| `.docs/reports/**` | no | instance | **→ `.brain/raw/reports/`** |
| `.docs/design/**` | no | instance (historical) | **→ `.brain/raw/design/`** |
| `.docs/archive/**` | no | instance | **→ `.brain/raw/archive/`** |
| `.docs/reviews/**` | no | instance | **→ `.brain/raw/reviews/`** |
| `.docs/plans/`, `.docs/history/` | no | instance (empty, `.gitkeep`) | **→ `.brain/`; drop the stubs** |
| `.docs/memory/` (search-log telemetry) | yes (writer only) | instance | stays; runtime, gitignored except `.gitkeep` |
| `.docs/governance/audit/**` | no | instance | **→ `.brain/raw/audit/`** (or stay gitignored) |
| `.docs/agents/*/*/decisions/*.json` | yes (agent runtime) | instance | **stays** — runtime state, not a document |
| `.logic-loom/plans/` | no | instance | **→ `.brain/wiki/`** |
| `.logic-loom/memory/constitution.md` | yes (preflight, tests) | convention | **ships in place** |
| `.logic-loom/memory/{todos,backlog}.md` | **yes** — `lint-backlog.sh`, `build-backlog-index.sh` | instance | **stays; pointer entry** |
| `.logic-loom/memory/amendments.md` | no (nothing loads it, by decision) | instance | **stays** — see §1.2 |
| `.logic-loom/config/*.conf` | yes | convention | **ships in place** |
| `features/<x>/plan.md` | **yes** — `freeze-write-scope.sh` (floor hook) | instance | **stays; pointer entry** |
| `features/<x>/{vision,prd,plan-review,retro}.md` | no | instance | **→ `.brain/raw/`** — see §1.2 |
| `features/<x>/exploration/`, `research/` | no | instance | **→ `.brain/raw/{exploration,research}/`** |
| `features/README.md` | no | convention | **ships in place** |
| `specs/###/tasks.md` | **yes** — `validate-tasks.sh`, `/specification` | instance | **stays; pointer entry** |
| `specs/###/{spec,plan}.md` | yes — `validate-spec.sh`, `validate-plan.sh` | instance | **stays; pointer entry** |
| `artifacts/backlog-dashboard.html` | **yes** — `check-generated-freshness.sh` | instance, *generated* | **stays; pointer entry** |
| `artifacts/{harness-graph,logicloom-vision}.html` | no | instance | **→ `.brain/wiki/`** (as HTML deliverables) |
| `.logic-loom/graph/graph-bridge.jsonl` | yes | instance, generated | **stays** — machine index, not a document |
| root `CHANGELOG.md` | no | instance | **stays** — see §1.2 |
| root `VISION.md`, `CLAUDE.md`, `AGENTS.md`, `README.md`, `START_HERE.md` | yes (graph corpus, tests) | convention w/ instance content | **stays** — see §1.2 |

### 1.2 Where the rule gives an uncomfortable answer

Four, stated rather than special-cased.

1. **`CHANGELOG.md` is a pure instance and the rule says move it.** It is our
   version history; a cloner's clone is not v6.5.0 of anything. But it is a
   root file every tool, every convention and every human expects at the root,
   and it is already handled by one manifest line. **Overriding the rule here on
   the grounds of a filename convention older than this design.** Cost: the rule
   has one named exception, and exceptions breed.

2. **`features/<x>/` gets split down the middle.** `plan.md` is operational;
   `exploration/`, `research/`, `vision.md`, `prd.md`, `retro.md` are not.
   `features/README.md` documents the folder as a single unit, and the swarm
   workflow reads as one. The rule splits it anyway. I recommend following the
   rule and amending `features/README.md`, because the alternative is a folder
   half of which is indexed and half of which isn't — but this is the one place
   the boundary fights an existing shipped convention, and it is the highest-
   friction move in the whole migration.

3. **Root `VISION.md` fails Test B in content and passes it in name.** The
   manifest already resolves this with a stub. `.brain/` does not improve on
   that; it just leaves the existing stub rule in place. So one of the 28 rules
   the brain was supposed to absorb, it cannot.

4. **`amendments.md` is an instance nothing parses, so the rule says move it —
   and it must not.** `CLAUDE.md` and `AGENTS.md` instruct agents to read it at
   that exact path; that instruction *is* its entire enforcement. Moving it
   breaks the only mechanism it has. **Test A is too narrow here: "parsed by a
   script" misses "named as a literal path in an instruction an agent follows."**
   This is a genuine gap in the test, not a special case. The honest patch is to
   read Test A as *"does anything — script or standing instruction — depend on
   this exact path?"*, which then also correctly keeps `constitution.md`,
   `gate-policy.conf` and the root markdown files in place.

---

## 2. Layout

```
.brain/
├── README.md                 # layer conventions — the ONLY file a cloner gets
├── raw/                      # immutable after capture; never edited in place
│   ├── research/             # /research tribunal output
│   ├── exploration/          # /swarm explore output
│   ├── reviews/              # /review-team, /cross-check, /plan-review verdicts
│   ├── reports/              # forensics, one-off investigations
│   ├── retro/                # /retro raw output
│   └── archive/              # superseded plans, historical designs
├── wiki/                     # distilled, compounding; every page cites its raw sources
│   ├── concepts/
│   └── decisions/            # ## Context / ## Decision / ## Why
└── index/                    # POINTER ENTRIES — one per operational primary
    ├── INDEX.md              # generated router (see §4)
    └── <slug>.md
```

**Carried over deliberately from the vault:**

- `raw/` is **immutable after capture** — append or supersede with a new file,
  never rewrite. Same reason: a capture is evidence, and evidence you can edit
  isn't. `/research` and `/swarm explore` output is exactly this shape already.
- `wiki/` pages **cite the `raw/` files they were distilled from** in a `sources:`
  frontmatter list, so a claim always has a checkable origin.
- **One fact, one file.** A fact lives in exactly one `.brain/` page; everything
  else links to it. This is the rule that makes the whole thing worth having, and
  the one nothing can enforce.
- **`[[wikilinks]]` and relative `[md links](...)`** — because
  `build-graph-bridge.sh` already harvests both into `links-to` edges
  (`.logic-loom/scripts/bash/build-graph-bridge.sh`, pass 2a). Using the vault's
  link syntax buys the graph for free.
- **Frontmatter discipline**, in the vault's shape but a shorter schema (§3).

**Deliberately NOT carried over, with reasons:**

| Vault feature | Why not |
|---|---|
| `projects/` layer | `.brain/` *is* one project's knowledge base. A `projects/` layer inside it is a level of nesting with one child forever. |
| **`memory/` layer** | **The strongest omission — see §7.3.** `_agent/memory/logicloom/` already exists in the vault with 22 files. Two memory stores for one subject is precisely the one-fact-one-file violation the vault exists to prevent. `.brain/README.md` points at the vault bucket instead. |
| Tags-not-folders + `project/<name>` taxonomy | A repo already has a stronger association mechanism: `covers:` frontmatter, which `build-graph-bridge.sh` turns into real `covers`/`decided-by` edges that `lint-graph.sh` validates. A parallel tag taxonomy would be a second, unvalidated answer to the same question. |
| Dataview queries / `templates/Project.md` | Requires Obsidian. The harness has no Obsidian dependency and the graph skill explicitly keeps it optional ("Obsidian is for the *human's* visual graph"). |
| The Contrarian Loop, `claim:`/`assumption:`/`ready_for_contra:` | Unbuilt even in the vault, and gated there on "3+ weeks of tagged pages." This repo would have fewer pages than that at launch. Do not ship fields nothing reads. |
| `raw/{voice,journal,media}/`, `type: media` wrappers | No capture surface. A repo has no voice notes. |
| `status: unprocessed` → scheduled distillation pass | There is no scheduled pass here and §7.1 argues there should not be one. Distillation is a side-effect of `/retro` and `/review-team`, or it does not happen. |

**Added, which the vault does not have:** the **`index/` layer**. A pointer entry
is neither `raw/` (it is derived, and it is re-derived when its primary changes)
nor `wiki/` (it is a mirror with a freshness contract, not a compounding
distillation). It gets its own layer because the staleness gate in §4 needs one
directory to scope to, and because mixing gated files with ungated ones inside
`wiki/` would make the gate's coverage invisible.

---

## 3. The pointer entry

An entry has to serve two readers with different needs. A human wants to know
what the primary says without opening it. An **agent** wants to know *whether it
must open the primary* — an entry that does not answer that gets routed around
and the whole index becomes decoration.

`.brain/index/plan-code-knowledge-graph.md`:

```markdown
---
type: pointer
title: "Sprint plan — code-knowledge-graph"
primary: features/code-knowledge-graph/plan.md
primary-sha: 9f2c1ab4e7d3b58a0c6e12f4d7a93b0e5c8412af
date-distilled: 2026-08-26
why-outside: "freeze-write-scope.sh parses the owns:/freeze: DAG from this exact path"
status: current
covers:
  - features/code-knowledge-graph/plan.md
sources:
  - "[[graph-stack-decision]]"
---

# Sprint plan — code-knowledge-graph

**Primary lives at `features/code-knowledge-graph/plan.md`** and cannot move:
`.claude/hooks/freeze-write-scope.sh` resolves `features/<feature>/plan.md`
and parses its `owns:`/`freeze:` blocks to decide every write during
`/swarm implement`. Moving it would thin a governance floor hook.

## What it decides

- Three sprints; sprint 02 owns `.logic-loom/scripts/bash/build-graph-bridge.sh`
  and freezes `.claude/hooks/`.
- The bridge is text-first and git-tracked; no daemon, no default LLM pass.
- Code-half MCP is opt-in per product workspace, never a floor dependency.

## Open the primary when

- You are about to run `/swarm implement` — the `owns:` lists are normative and
  this summary is not.
- You need a task id, a dependency edge, or an exact path glob.
- `status:` above is anything other than `current`.

## Do not open it for

- Which sprint a concern lives in, or what the plan's shape is. That is here.

## Links

Distilled from [[graph-stack-decision]] · convention:
`.docs/architecture/project-graph-convention.md` · builder:
`.logic-loom/scripts/bash/build-graph-bridge.sh`
```

**Why each field earns its place:**

- **`primary`** — the pointer. Repo-relative, so it is a graph node id verbatim.
- **`primary-sha`** — the **git blob hash** of the primary at distillation time,
  i.e. `git hash-object features/.../plan.md`. This is the staleness mechanism's
  entire state, it is exact, it costs nothing to compute, and reading it needs
  only read-only git (allowlisted for subagents by `subagent-git-guard.sh`).
- **`why-outside`** — the answer to "why isn't this in the brain like everything
  else". Without it the layout looks arbitrary within a month.
- **`covers:`** — duplicates `primary` on purpose. `build-graph-bridge.sh` pass
  2c already turns `covers:` frontmatter into `covers` + `decided-by` edges, and
  `lint-graph.sh` already **warns on a dangling `covers` target**. Writing the
  primary into `covers:` means a renamed or deleted primary is caught by a linter
  that already exists, with zero new code.
- **`status: current | tracking | superseded`** — the gate's scope control (§4.3).
- **`## Open the primary when` / `## Do not open it for`** — the agent contract.
  This pair is the difference between an index and a pile of summaries.

---

## 4. Staleness

The defect class this release cycle was spent removing is *a claim nothing
verifies*. A pointer entry is a claim about another file's contents. So it needs
a verifier or it should not be built.

### 4.1 What the existing mechanisms give for free

**`lint-graph.sh` — free, zero new code.**
Once `.brain/` is in the graph corpus (§4.4), a pointer's `covers: [<primary>]`
becomes a `covers` edge, and `lint-graph.sh` already emits
`WARN: dangling covers -> missing code path '<p>'` when the target is gone. So
**deleted or renamed primaries are already detected**. Fail-open (warns, exits 0),
which is right for this class.

**`build-graph-bridge.sh` — free.** Backticked paths in entry bodies become
`mentions` edges; `[[wikilinks]]` and md links become `links-to`. The "tracking,
linking" half of the ask is delivered by a script that already ships. `/graph
query` walks pointer entries with no change.

**`check-generated-freshness.sh` — mostly *not* reusable, and this matters.**
Its mechanism is *regenerate-and-diff*. A pointer entry's body is **hand-authored
prose that no generator can reproduce**, so it cannot be regenerated and cannot be
diffed. It covers exactly one thing here: `.brain/index/INDEX.md`, a generated
router (title + primary + status per entry), which it can regenerate and byte-diff
like `graph-bridge.jsonl`. Worth adding *only* if a router is wanted; it does not
address entry staleness at all.

### 4.2 What is genuinely new

**One script, `~80 lines`: `.logic-loom/scripts/bash/check-brain-pointers.sh`.**

```
for each .brain/index/**/*.md with status: current
    read primary, primary-sha from frontmatter
    [ -f "$primary" ]            || FAIL  "pointer names a primary that does not exist"
    actual=$(git hash-object "$primary")
    [ "$actual" = "$primary-sha" ] || FAIL  "DRIFTED"
```

On failure it prints the command that closes the loop:

```
DRIFTED: .brain/index/plan-code-knowledge-graph.md
  primary : features/code-knowledge-graph/plan.md
  stamped : 9f2c1ab…   actual: 3ea77b1…
  review  : git diff 9f2c1ab…..HEAD -- features/code-knowledge-graph/plan.md
  then    : re-read the diff, update the entry, re-stamp primary-sha
```

- **Fail-closed**, wired into `.github/workflows/plugin-tests.yml` beside the
  freshness gate.
- **Runs no mutating git.** `git hash-object <path>` and `git diff` are read-only
  and on the subagent allowlist.
- **Writes nothing into the repo**, matching `check-generated-freshness.sh`'s
  contract.
- **No `--restamp` mode that CI can reach.** A restamp is the human act of having
  read the diff. A gate that can restamp is a gate that can turn itself off —
  the exact hole `check-generated-freshness.sh` spends forty lines closing.
  Restamping is a manual edit, deliberately.

### 4.3 The honest limits — read this before deciding to build it

**This detects byte drift, not meaning drift.** Two failure directions, and they
are not symmetric.

- **False positive (tolerable).** A typo fix in `plan.md` flips every entry
  pointing at it to DRIFTED even though the summary is still perfectly true.
  Cost: a review that concludes "no change needed" and a restamp.
- **False negative (the one that matters, and it is unclosable).** Restamp
  without reading, and the entry is marked `current` while it lies. Nothing can
  verify that prose summarizes bytes — that would require the thing the
  distillation is a compression of. **A summary can also go stale without the
  source's bytes changing meaning, and can stay true across bytes that did.**

The gate therefore makes drift **conspicuous, not impossible** — the same posture
the amendments grammar takes, where the missing `Overrides` verb makes weakening
conspicuous rather than preventing it. The single mitigation is the failure
message putting a `git diff` in front of the person restamping, so ignoring it is
an act rather than an oversight. **If that is not enough for you, do not build
the index layer** — an index that confidently holds stale entries is worse than
no index, and §7 says so again.

**What escapes entirely, named:**

- A primary whose *meaning* changed with the same bytes (a referenced file was
  deleted; a term was redefined elsewhere).
- Drift in `.brain/wiki/` pages. They summarize *many* sources and no `sha`
  captures that. `sources:` links + `lint-graph.sh`'s dangling warning are all
  they get. Wiki pages are **not gated and must not pretend to be.**
- Contradictions between two `.brain/` pages. The vault flags these with a
  Contrarian Loop that does not exist yet, here or there.

**False-positive fatigue is the real kill risk.** A `plan.md` under active
implementation changes daily; the gate goes red daily; the trained response
becomes blind restamping, which converts the gate into a liar with a green check.
Hence `status:`:

- **`current`** — gated, fail-closed. For settled primaries.
- **`tracking`** — linted-only (a warning), for a primary under active churn.
- **`superseded`** — ignored; the entry is history.

This is the same posture as `gate-policy.conf`: an escape hatch that costs one
explicit line per thing weakened, with no wildcard. `tracking` should be rare and
a reviewer should ask about each one.

### 4.4 One-line corpus change

`build-graph-bridge.sh` line ~139:

```bash
for d in .docs features specs; do          # today
for d in .docs features specs .brain; do   # after
```

That is the entire wiring for the graph half. **Consequence to plan for:** it
changes `graph-bridge.jsonl`, so `check-generated-freshness.sh` will demand the
regenerated bridge in the same commit.

---

## 5. Strip behaviour

### 5.1 The manifest delta

Five lines, using the manifest grammar unchanged:

```
# --- Project brain: the CONVENTION ships (README + layer names), the CONTENTS
#     are ours end to end. Same class as .docs/reports and artifacts. ---
.brain/raw
.brain/wiki
.brain/index
stub: .brain/README.md :: .logic-loom/templates/brain-readme-template.md
```

(Four, if `.brain/index/INDEX.md` is not built.)

### 5.2 What a cloner gets

`.brain/` containing exactly `README.md` — the stubbed layer conventions, the
boundary test from §1, the pointer-entry shape from §3, and the note that
`.brain/` is the default home for any new project-specific document. No `raw/`,
`wiki/` or `index/` directories: a cloner creates a layer the first time they
have something to put in it, the same treatment `artifacts/` and `web/` already
get. `check-brain-pointers.sh` ships and passes trivially on zero entries — a
live gate, not a dead one, exactly the property
`check-generated-freshness.sh` engineered for.

### 5.3 Operational docs that stay outside

Unchanged. `features/` and `specs/` continue to ship as directory + `.gitkeep` +
`README.md`; `.logic-loom/memory/{todos,backlog}.md` continue to ship as stubs;
`artifacts/` continues to be stripped wholesale. `.brain/` adds nothing and
removes nothing for these. **A pointer entry lives under `.brain/index/` and is
therefore stripped, while its primary's stub still ships** — which is correct: a
cloner gets the empty machinery and none of our index.

### 5.4 The strip prize, measured honestly

Of the **28** current manifest rules, `.brain/` retires **9**:

| # | Rule | Absorbed by |
|---|---|---|
| 14 | `.docs/features` | `.brain/raw/` |
| 15 | `.docs/archive` | `.brain/raw/archive/` |
| 16 | `.docs/reports` | `.brain/raw/reports/` |
| 17 | `.docs/design` | `.brain/raw/design/` |
| 18 | `.docs/guides/dev-main-template-split.md` | `.brain/wiki/` |
| 19 | `.logic-loom/plans` | `.brain/wiki/` |
| 21 | `artifacts` | `.brain/wiki/` — **but see caveat** |
| 25 | `.docs/memory` | `.brain/raw/` or stays gitignored |
| 26 | `.docs/governance/audit` | `.brain/raw/audit/` |

Add 5 `.brain/` lines. **28 − 9 + 5 = 24. Net −4.**

**That is nowhere near one line, and the reason is worth stating.** The
manifest's irreducible core is **maintainer release plumbing** — rules 4–13 are
the stripper, leak-guard, audit, history-scrub, `/promote`, `bump-version`; rules
1–3 are stubs of files a cloner must inherit; 22, 23, 24, 27, 28 are generated
indices, GitHub scaffolding, and runtime markers. **Thirteen of the 28 rules have
nothing to do with where documents live**, and no reorganization of documents can
touch them. The "one-line contract" is not reachable by this design or, I
believe, by any design that does not also move the release plumbing out of the
repo.

**Caveat on rule 21 (`artifacts`).** It is currently load-bearing for the tracked
generated `artifacts/backlog-dashboard.html`. If the dashboard stays at
`artifacts/` (it must — `check-generated-freshness.sh` derives it from that path),
rule 21 **does not retire**, and the honest count is **28 − 8 + 5 = 25, net −3.**

### 5.5 The prize that is real, and is not line count

**Unlisted paths that ship today.** The manifest only asserts *listed* paths are
absent, so an unlisted new document ships verbatim. Right now **8 tracked
project-specific documents are covered by no rule at all** and are shipping to
every cloner:

```
features/code-knowledge-graph/exploration/graph-design.md
features/code-knowledge-graph/exploration/graph-stack-decision.md
features/code-knowledge-graph/exploration/project-graph-design.md
features/escalation-advisor/vision.md
features/harness-product-boundary/exploration/cosmos-cross-reference.md
features/harness-product-boundary/exploration/harness-product-boundary.md
features/modular-harness/exploration/modular-harness-design.md
features/modular-harness/exploration/unified-architecture.md
.docs/reviews/LOGICLOOM_ISSUE_harness-product-boundary.md
```

(That is 8 instances plus `features/README.md`, which correctly ships.) The
manifest's own "intentionally NOT stripped" note asserts *"features/, specs/ :
empty customer workspaces (ship; .gitkeep only)"* — **which is not true of the
current tree.** With `.brain/` as the default home for a new instance document,
the class of *silently shippable new document* shrinks to "someone put an
instance outside `.brain/`", which a reviewer can see. That, not −4 lines, is the
prize; and it is the prize because the failure mode it removes is silent.

---

## 6. Migration

### Phase 1 — pure knowledge only. No operational path touched. No floor hook modified.

| Step | Action | Escalation |
|---|---|---|
| **1a** | Create `.brain/README.md` + `.logic-loom/templates/brain-readme-template.md`. No moves. Add the 5 manifest lines (they match nothing yet — harmless). | Light |
| **1b** | Add `check-brain-pointers.sh`; wire into `plugin-tests.yml`. **Passes on zero entries.** | Light |
| **1c** | `git mv` `.docs/{reports,design,archive,reviews}`, `.logic-loom/plans` → `.brain/`. Retire manifest rules 14–17, 19, 25, 26. Fix the ~6 prose cross-references. | Standard |
| **1d** | `git mv` `features/*/exploration/`, `features/escalation-advisor/vision.md` → `.brain/raw/`. Amend `features/README.md` (§1.2 case 2). | Standard |
| **1e** | Add `.brain` to the graph corpus (§4.4); regenerate `graph-bridge.jsonl` in the same commit. Distill 3–5 `wiki/` pages from what moved. | Standard |

**Order matters at 1b.** The gate goes in *before* any entry exists, so it never
has to argue with pre-existing drift — the lesson
`check-generated-freshness.sh` records ("a warning is a suggestion, and drift
accumulates behind it").

Phase 1 stops here and is worth doing on its own: it fixes the 8 leaking files,
retires 7 manifest rules, and touches no operational path.

### Phase 2 — pointer entries. Still no floor hook modified.

Write `.brain/index/` entries for `features/<x>/plan.md`, `specs/###/tasks.md`,
`.logic-loom/memory/{todos,backlog}.md`, `artifacts/backlog-dashboard.html`.
**No file moves.** Every primary stays exactly where its reader resolves it.

### The floor-hook cost, named

**Phase 2's cost to `freeze-write-scope.sh` is zero.** The hook resolves
`"$REPO_ROOT/features/${active_feature}/plan.md"` (line ~165) and parses its
`owns:`/`freeze:` blocks. A pointer entry does not move that file, does not
change its grammar, and is never read by the hook. The pointer design exists
*specifically* so this stays true. That is the answer to "prefer reusing an
existing mechanism": the cheapest change to a governance floor hook is none.

**Phase 3 — moving `plan.md` under `.brain/` — should not be built.** For the
record, its cost:

- `.claude/hooks/freeze-write-scope.sh` — fallback path B, plus the marker-file
  contract in the header comment.
- `.logic-loom/lib/policy.sh` — `loom_verdict_freeze_scope` / `loom_freeze_match`,
  which the hook and the verdict library share.
- `.docs/architecture/freeze-scope-protocol.md` — the published hook contract.
- `plugins/loom-orchestrator/skills/swarm-implement/SKILL.md` §6 — writes the
  marker file before each worker dispatch.
- `features/README.md`, `CLAUDE.md`, `AGENTS.md` — all name the path.
- `tests/contract/` — the freeze-scope regression suite.
- And every edit above trips `protect-governance-files.sh`, forcing an approval
  prompt on the main agent and a hard **deny** for any subagent.

That is a **Heavy**-rung change (cost 3: it changes governance-floor logic; width
2: many independent places) to relocate a file for tidiness, against a repo whose
stated bet is a thin floor. **Recommendation: never.**

---

## 7. What this does not solve, and what it costs

### 7.1 The ongoing human cost of distillation — the thing that decides it

The vault gets away with `raw/` → `wiki/` because a **scheduled distillation
pass** does the promoting. This repo has no such pass and no cadence. A
`wiki/` layer maintained by intention alone will hold four pages from launch week
and nothing after, and every one of those pages will still assert its claims
confidently a year later. **A brain that requires discipline nobody sustains is
worse than no brain**, because a stale entry that looks maintained is consulted.

The only version I would build:

- **`raw/` is free.** `/research`, `/swarm explore`, `/review-team`,
  `/cross-check` and `/retro` already produce these files. Redirecting their
  output path is the entire cost. Zero ongoing discipline.
- **`index/` is nearly free and self-policing.** An entry is written once and the
  gate tells you when to revisit. Cost is bounded and externally triggered.
- **`wiki/` is the expensive one and should be built only if the distillation is
  a side effect of a command that already runs** — `/retro` writing a
  `wiki/decisions/` page as part of its existing memory write is the natural seam.
  **If that wiring is not part of the build, do not build the `wiki/` layer.**
  Ship `raw/` + `index/` and call it what it is.

### 7.2 What it does not solve

- **Meaning drift** (§4.3) — permanently.
- **Contradictions between entries.** No mechanism, here or in the vault.
- **The manifest's size.** −3 to −4 lines of 28 (§5.4).
- **Coupling.** Nothing decouples. `freeze-write-scope.sh` still parses
  `plan.md`; `lint-backlog.sh` still parses `backlog.md`. The design *accepts*
  the coupling and indexes around it — that is the point, not a shortfall.
- **Discovery.** `.brain/` makes a document findable once it is written. It does
  nothing about the ones nobody wrote.
- **A pointer entry for a primary that never churns** is pure overhead: a second
  file, a gate entry, and a restamp obligation for no benefit. Write entries only
  for primaries that are both *load-bearing* and *changing*.

### 7.3 The part I recommend not building

**No `.brain/memory/` layer.** `_agent/memory/logicloom/` in the vault already
holds 22 files on exactly this subject, is loaded into every session via
`autoMemoryDirectory`, is bucketed by subject, and has a router. Adding a
second memory store inside the repo would:

- violate one-fact-one-file across the two systems, which is the rule the vault
  is built on;
- create a store that ships-or-strips (a strip decision memory should never need);
- give the maintainer two places to look and two places to write, which in
  practice means facts land in whichever one the session happened to be in — the
  precise failure `MEMORY.md` warns about ("pick the bucket by the fact's
  SUBJECT, never by the session's working directory").

`.brain/README.md` should say, in one line, that memory for this repo lives at
`~/kelleysd-apps/AI OS/_agent/memory/logicloom/` and link the two. That is the
sibling relationship the ask asked for.

### 7.4 Measurement note

I could not reproduce the stated coupling counts (47 / 25 / 16 / 15 / 8). Their
**ordering is right** — `.docs/` most coupled, `artifacts/` least — but the
magnitudes depend entirely on the scope of the scan. Measured over
`.logic-loom/scripts`, `.logic-loom/lib`, `.claude/hooks`, `tests`, `plugins`,
`.github/workflows`:

```
grep -rlF '<path>' .logic-loom/scripts .logic-loom/lib .claude/hooks tests plugins .github/workflows | wc -l
  .docs/  75   .logic-loom/memory/  40   features/  34   specs/  31   artifacts/  9
```

Restricted to executable/config extensions the numbers are higher again
(95/57/41/36/15). **None of these are the coupling that matters.** Most hits are
path *references* in prose or in a `sed`; the design's Test A asks about *content
parsing*, and by that measure the operational set is small and enumerable: five
paths (`features/<x>/plan.md`, `specs/###/{spec,plan,tasks}.md`,
`.logic-loom/memory/{todos,backlog}.md`, `artifacts/backlog-dashboard.html`,
`.logic-loom/graph/graph-bridge.jsonl`) and their readers
(`freeze-write-scope.sh`, `validate-*.sh`, `lint-backlog.sh`,
`build-backlog-index.sh`, `check-generated-freshness.sh`). That short list, not
the grep counts, is what the boundary has to respect — and it is short enough
that the whole operational half of the design is four pointer entries.

---

## 8. The distillation routine

This section exists to satisfy the condition §7.1 sets: `wiki/` is worth building
only if distillation is a side effect of something that already runs. It ports
the vault's scheduled distillation pass into the harness as a shipped routine,
knowing it is a **stopgap for a product that will later live outside every
project**.

It supersedes exactly one row of §2's "deliberately NOT carried over" table — the
`status: unprocessed` → scheduled-pass row. Everything else in §2 stands, and §8.8
re-declines three of the same items on the same grounds.

### 8.1 What is actually being copied — measured, not summarised

The routine is `~/.claude/scheduled-tasks/vault-distillation-pass/SKILL.md`: a
Claude Code **scheduled task**, ~370 lines of prose and zero lines of code, firing
`0 6 * * *` local. Its run record is
`"AI OS"/_agent/memory/working/distillation-log.md` (305 lines, 2026-07-17 →
2026-08-26), committed each run under a `Distillation pass <date>: …` subject.

Four facts from that record decide most of this design.

1. **Eight of the last ten logged runs are zero-op.** Commit subjects say so
   outright ("zero-op run, only foundational doc in scope"). The queue's normal
   state is empty.
2. **`raw/` right now holds one file**, `status: processed`, deliberately kept
   under the pass's foundational-document exception. Depth has read zero for
   weeks.
3. **The pass deletes**, and its own contract disagrees with it. The task's step 5
   deletes the raw file after merging; `_agent/SCHEMA.md` — the file the task
   instructs itself to read in full every run — still describes `raw/` as
   *"immutable captured sources… append or supersede, don't rewrite"* with
   `status: unprocessed | processed`. Delete-after-merge has been live policy
   since the 2026-07-20 run. **SCHEMA.md is stale on the single most destructive
   rule in the system.** Noted here because it is the exact defect class this
   release cycle removed — a claim nothing verifies — sitting in the source we
   are copying from.
4. **The health check is a diff against the previous run's logged figures**, and
   the task says why in one line: *log the result every run, healthy or not,
   because a one-line healthy entry is what makes a later break visible by
   contrast.* That sentence is the most valuable thing in the routine and §8.4
   is built on it.

**Two things do not port.**

- **The runner.** Scheduled tasks are stored in `~/.claude/scheduled-tasks/` —
  the user's tree, outside every repo, one per machine. CLAUDE.md § *Harness ↔
  user boundary* forbids the harness writing there. The harness can ship the
  prompt; it cannot ship the schedule. It also "runs while the app is open,"
  so even installed it is not a guarantee.
- **The unattended git posture.** The vault's pass pulls, commits and pushes at
  6am with nobody watching. In this repo that is Principle VI: `git-safety-gate.sh`
  forces an approval prompt on the main agent and `subagent-git-guard.sh` denies a
  subagent outright. **The port therefore runs no git at all.** It leaves its
  writes in the working tree and the human commits them through the existing
  approval path. This is not a compromise — it removes the failure mode the
  vault's task spends three paragraphs mitigating (`--ff-only`, "do not force
  anything", "UNSYNCED — needs human attention").

### 8.2 The runner

| Option | Verdict |
|---|---|
| **Scheduled task / cron** (`mcp__scheduled-tasks`, `/schedule`) | Cannot ship — user tree (§8.1). Runs only while the app is open. Would want git. **Not the shipped runner; offered as an optional user-installed wrapper** whose entire prompt is "open `<repo>` and run `/distill`". |
| **`/loop`** | Session-scoped and self-paced; dies with the session. Adds the cadence problem back without adding durability. No. |
| **A hook** (SessionStart / UserPromptSubmit) | A hook must be fast, deterministic, and non-blocking. Distillation is open-ended judgment. Hooks get the **health signal** (§8.4), never the pass. |
| **Side effect of `/retro`** | §7.1's proposal. Tested below and it fails as the *sole* trigger; kept as an *additional* trigger for the decisions half. |
| **A slash command, `/distill`** | **Chosen.** |

**Testing §7.1's claim that `/retro` is the natural seam.** It is half right, and
the half that fails is the half that matters.

1. **Coverage.** `/retro` is per-feature and terminal. Captures come from
   `/research`, `/swarm explore`, `/review-team` and `/cross-check` — and three of
   those are routinely run with no feature at all (`/cross-check` on a diff,
   `/research` on a standing question). Those captures would never be reached.
   This repo's own tree proves it: `.docs/reviews/LOGICLOOM_ISSUE_harness-product-boundary.md`
   and `.docs/reports/backlog-2026-08-13.md` belong to no feature and would have
   no retro.
2. **Cadence.** Four `features/` folders exist, over roughly three months. A pass
   that fires four times a quarter is not a cadence; it is an occasion.
3. **It destroys the health signal.** If `/retro` is the only trigger, "no
   distillation in 60 days" and "no feature finished in 60 days" are the same
   reading — and the second is normal. The signal stops meaning anything, which
   is worse than not having one.
4. **`/retro` already writes knowledge outside the repo.** Its SKILL.md step 8
   writes `$HOME/.claude/projects/<slug>/memory/retro_<feature>_<date>.md`.
   Bolting a second, in-repo knowledge destination onto the same command gives it
   two stores with two lifecycles and two strip decisions — the precise
   two-places-to-write failure §7.3 rejects.

   **A live collision, independent of `.brain/` and worth fixing regardless:**
   `autoMemoryDirectory` now redirects agent memory into the vault, and the
   vault's distillation task treats *any* file under `~/.claude/projects/*/memory/`
   with an mtime after 2026-08-20 as **the defined symptom that the redirect
   broke** (health check 3). `/retro` writes exactly there, by design. The next
   `/retro` run in this repo will trip that check and be logged as needing human
   attention. That belongs in the backlog on its own merits.

**So:** `/retro` gets *one* job — writing a `.brain/wiki/decisions/` page for the
decisions it already surfaces, because that content is a genuine byproduct of work
already done. It does not get the pass.

**`/distill`** ships as a `loom-orchestrator` command + skill, the same shape as
every other pack command. It is a prompt, not an engine — which is what makes
§8.6's extraction seam real, and it is also why the vault's own routine is 370
lines of prose. The repo's stated bet (ride native primitives, never reimplement
orchestration) is honoured: the command is a skill, the optional scheduler is
Claude Code's own, and no runner is written.

### 8.3 The promotion contract

**Reads.** Every file under `.brain/raw/**` whose frontmatter `status` is
`unprocessed`. **Parse the frontmatter block; never grep for `status: unprocessed`**
— the vault's log records a real miss caused by exactly that, because quoted
(`status: "unprocessed"`) and unquoted YAML both occur.

**Writes.** One of four outcomes per capture, carried over unchanged because each
one is load-bearing:

- **Extend** an existing `.brain/wiki/` page (append, bump `date-updated`) when the
  material is additive. Search `wiki/` first — a near-duplicate page is the
  one-fact-one-file violation the layer exists to prevent.
- **Create** a new `wiki/concepts/` or `wiki/decisions/` page when the topic is
  genuinely new, cross-linked with `[[wikilinks]]` so `build-graph-bridge.sh`
  harvests the edges (§2).
- **Discard** — record `discarded: "<reason>"` on the capture. Never silent.
- **Flag a contradiction** — quote both sides into the run log, touch neither page.
  A human decides merges (vault write rule 3). This is the one rule with no
  mechanism behind it in either system.

Provenance must be written into the page's `sources:` **before** the capture is
marked processed, inline and self-describing — source path, command that produced
it, date.

**Deletes: nothing. The port drops the delete rule.**

The vault deletes because `raw/` is an **inbox**: captures arrive from outside
(Web Clipper, a session reaching in), and an inbox that never empties makes the
next arrival invisible. **The harness's `.brain/raw/` is not an inbox.** Its
contents are produced by the repo's own commands, in-repo, and are already tracked
in git beside the code they describe. Nothing arrives; nothing needs clearing.

Git-recoverability is not the argument either way — both trees are git repos, and
the vault leans on that explicitly. The decisive difference is the **strip
manifest**. `.brain/raw` is stripped at release (§5.1). Deleting a capture after
distillation would leave the only surviving copy of a `/research` output as a
paragraph in a wiki page plus a blob in the *private* dev line's history — a line
the public template never sees. §5.5's prize is that instance documents stop
shipping *silently*; deleting them converts "does not ship" into "does not exist
for anyone reading the public line." That is a worse trade than the one the vault
is making.

And the harness has a check the vault does not: `status: processed` plus a
`distilled-into:` link is sufficient here **because `lint-graph.sh` already warns
on a dangling target** (§4.1). The vault deletes partly because nothing there
verifies the citation resolves.

**What is lost by not deleting**, stated rather than waved away:

- The queue-emptying property. `.brain/raw/` grows without bound and the
  frontmatter `status` field becomes the *only* thing separating pending from
  done. If a capture lands with no `status`, it is invisible to the pass forever.
  Check 1 in §8.4 exists solely to close that.
- The load signal must therefore count **`status: unprocessed` captures**, never
  "files in `raw/`". Those two numbers diverge permanently here and are the same
  number in the vault.
- One rule disappears: with nothing deleted, the vault's foundational-document
  exception has nothing to except. Net rule count is unchanged.

**Never.** Run git in any form. Edit an existing capture's body. Auto-merge a
contradiction. Write outside `.brain/`. Touch `.logic-loom/memory/` or the vault's
`_agent/memory/`. **Author or restamp a `.brain/index/` pointer entry** — §4.2
forbids an automated restamp because a restamp is the human act of having read the
diff; authoring one is the same act and gets the same refusal.

**Idempotent** (Principle IV): a second run over a `processed` capture is a no-op.

### 8.4 Health — how anyone knows the pass ran

**The stated instinct — queue depth as the health signal — is the right shape and
the wrong reading, and the vault's own record shows why.**

Queue depth answers *"is there a backlog?"* It cannot answer *"did the pass run?"*,
because the two states that matter produce an identical reading: a pass that ran
and cleared the queue, and a pass nobody ever installed over a repo where nobody
captured anything, **both read zero**. In the vault that is not a hypothetical —
depth has read zero on eight of the last ten runs (§8.1). If depth were the health
signal, the vault would have looked equally healthy on a day the pass ran and on a
day it had been silently uninstalled.

Depth is a **load** signal. The failure §7.1 names is **silence**. They are
different measurements and the design needs both.

**Port the log.** `.brain/DISTILL-LOG.md`, append-only, one dated entry per run
**including a zero-op run** — the vault's own stated reason: a one-line healthy
entry is what makes a later break visible by contrast. Liveness is then the age of
the newest entry, which is exact, needs no knowledge of scheduling, and cannot be
faked by an empty queue.

Three signals, three deliberately different treatments:

| Signal | Question | Mechanism | Verdict |
|---|---|---|---|
| **Record integrity** | Does the routine's own record hold together? | `.logic-loom/scripts/bash/check-brain-record.sh`, CI, beside `check-generated-freshness.sh` | **FAIL-CLOSED** |
| **Liveness** | Did the pass run recently? | preflight advisory | **surface, never block** |
| **Load** | Is there a backlog? | same advisory | **surface, never block** |

**Why only the first is a gate.** A fail-closed CI gate must assert something the
change in front of it can be responsible for. *"The log says run 2026-09-04
promoted capture X into page Y, and page Y does not exist"* is a broken record —
deterministic, and never a false alarm on an unrelated PR. *"You have not distilled
in 40 days"* is not caused by the PR it would block; gating on it blocks unrelated
work, and the trained response is to bypass. That is the false-positive fatigue
§4.3 already names as the kill risk, and the self-disabling gate §4.2 already
refuses to build. A customer who never adopts the routine would otherwise inherit
a permanently red build — the fastest possible route to the gate being deleted.

**`check-brain-record.sh` — five deterministic checks, no git mutation, writes
nothing:**

1. Every `.brain/raw/**` file has a parseable frontmatter `status` of
   `unprocessed` or `processed`. *(An unparseable one is invisible to the pass —
   the silent-skip class §8.3 introduced by not deleting.)*
2. Every `processed` capture carries `distilled-into:` naming a `.brain/wiki/` page
   that exists, **or** `discarded: "<reason>"`. Neither one present = a claim
   nothing backs.
3. Every `.brain/wiki/**` page has a non-empty `sources:`.
4. Every promoted-form entry in `DISTILL-LOG.md` names a wiki page that exists.
5. If `.brain/wiki/` is non-empty, `DISTILL-LOG.md` exists.

On an empty or absent `.brain/`, every check is vacuous and the script exits 0 — a
**live gate, not a dead one**, the property §5.2 already engineered for.

**The advisory** rides `governance-preflight.sh`, the existing `UserPromptSubmit`
hook that already injects memory and domain context. Thresholds live in
`.logic-loom/config/brain.conf`, one key each, no wildcard — the `gate-policy.conf`
posture. Calibrated against this repo's real rate (~13 instance documents in ~3
months, arriving in bursts):

- **Load:** warn above **5 unprocessed captures** *or* an **oldest unprocessed
  older than 21 days**. Five is more than one burst; 21 days is three capture
  cycles.
- **Liveness:** warn when the newest log entry is **older than 30 days** *and* at
  least one unprocessed capture exists. **The conjunction is the whole point** — a
  quiet month over an empty queue is not a fault, and warning about it is exactly
  the nagging that gets an advisory tuned out.
- **Silent when there are no unprocessed captures and no log.** An unadopted
  routine must make no noise. Same structural-silence discipline
  `check-dev-branch-base.sh` uses to stay quiet in a customer clone.
- **Anti-nag:** reuse that hook's once-per-`(repo-root, state)` dedupe key so the
  notice fires once per session, not once per prompt.

One honest limit, in §4.3's register: the advisory tells Claude, via
`additionalContext`, and Claude tells the human. It is a nudge in a context
window, not a red build. That is the correct strength for a habit signal and it is
also its ceiling — §8.7 says what happens when it is ignored.

### 8.5 What ships to a cloner

Delta on top of §5.1's five manifest lines:

```
plugins/loom-orchestrator/commands/distill.md                  ships
plugins/loom-orchestrator/skills/distillation-pass/SKILL.md    ships
.logic-loom/scripts/bash/check-brain-record.sh                 ships
.logic-loom/config/brain.conf                                  ships (thresholds, defaults)
.logic-loom/templates/distill-schedule-prompt.md               ships  ← the optional scheduler prompt
.brain/README.md                                               ships as a stub (§5.1)
.brain/DISTILL-LOG.md                                          STRIPPED — one new manifest line
```

One manifest line more than §5.1 assumed. §5.4's honest count of 25 becomes **26 —
net −2**. §5.4 already argued the line count is not the prize; this makes it
smaller again and changes nothing about §5.5, which is.

**`/initialize-project` does exactly two things, and neither is scaffolding.**

1. Ask one question: *"Run the distillation routine on a schedule, or invoke
   `/distill` by hand?"* If scheduled, **print** the contents of
   `.logic-loom/templates/distill-schedule-prompt.md` and tell the user to install
   it themselves, via `/schedule` or their own cron.
   **It must not install it.** `~/.claude/scheduled-tasks/` is the user's tree and
   CLAUDE.md § *Harness ↔ user boundary* forbids the harness writing there;
   `init-project.sh`'s existing footprint discipline (creates `web/`, removes
   maintainer CI, touches nothing user-level) is the precedent.
2. Nothing else. **No `raw/`, `wiki/` or `index/` directories** — §5.2's rule
   stands: a layer is created the first time there is something to put in it.

**Day one, for a customer with no vault and no distillation habit.** They clone,
run init, answer "by hand" — and then nothing happens. `.brain/` holds one README.
`check-brain-record.sh` runs in CI and passes vacuously. The advisory is silent.

The first thing that changes is the first time they run `/research` or
`/cross-check`: the output lands in `.brain/raw/research/` with
`status: unprocessed`. **That redirect is the only behaviour change they get for
free, and it costs them nothing** — the file would have been written anyway, and
now it is written somewhere that does not ship. If they never type `/distill`, they
have what they would have had regardless: a folder of research outputs, in one
place. When the sixth one piles up, one line of advisory mentions the command
exists.

**The routine is opt-in at the point of value, not at the point of setup.** That
is the only shape a customer with no distillation habit adopts, and it is the
reason none of this is presented as a step in initialization.

### 8.6 Designed for extraction

The stopgap is the **invoker and the storage**, never the contract. Three layers:

1. **The contract — portable, and the thing to protect.** Capture frontmatter
   (`status`, `distilled-into`, `discarded`, `sources`), the wiki page shape, the
   four promotion outcomes, the log entry grammar. All of it lives in
   `plugins/loom-orchestrator/skills/distillation-pass/SKILL.md` and
   `.brain/README.md` as **prose and data, never as parsing logic**. A centralized
   product reads the same frontmatter off the same files with none of this repo's
   code.
2. **The invoker — replaceable, and expected to be replaced.** `/distill`. A future
   product substitutes its own scheduler pointed at the repo. Nothing else moves,
   because `/distill` is a prompt, not an engine.
3. **Repo-local by necessity — does not extract, and should not try.**
   `check-brain-record.sh` is a CI gate on *this* repo's tracked files and a remote
   product cannot fail this repo's build. The strip-manifest lines are release
   plumbing, per-repo by construction (§5.4). The preflight advisory rides a hook,
   and hooks are the Claude Code adapter, not the portable policy layer (CLAUDE.md
   § *Portability*).

**Concretely, on the day the product exists:** `/distill` becomes a thin "the
product owns this; last run `<date>`", `DISTILL-LOG.md` becomes the product's write
target instead of the command's, and `check-brain-record.sh` keeps running
unchanged — it validates the record, and it does not care who wrote it. Nothing in
`.brain/raw/` or `.brain/wiki/` changes shape.

**The one discipline that keeps that true: no script may ever parse a
`.brain/wiki/` page's body.** `check-brain-record.sh` reads frontmatter and file
existence only. The moment a gate depends on prose structure, the contract stops
being portable — and §1's Test A flips the entire tree into "something parses it",
which is a different design.

### 8.7 What it does not solve

Everything in §7.2 stands. Added:

- **The routine can itself become the unsustained thing, and this is the likeliest
  failure.** A `/distill` nobody types is §7.1 one level up, and the health signal
  is a notice rather than a gate — someone who ignores a line of advisory text for
  six weeks arrives exactly where §7.1 warns: a `wiki/` of launch-week pages still
  asserting confidently.

  What makes that survivable rather than fatal is that **the degraded state is
  honest**. `raw/` is free (§7.1). The advisory is silent while `wiki/` is empty. A
  `.brain/` holding `raw/` and no `wiki/` is not stale — it is a filing cabinet,
  and a filing cabinet with an empty index makes no claims. So the commitment being
  made is: *if `/distill` is never run, we keep §5.5's prize, get none of the
  `wiki/` benefit, and nothing lies.* If that floor were not acceptable, the
  routine should not be built.
- **The scheduler is the unenforceable half.** It lives in the user's tree, runs
  only while the app is open, and **nothing in the repo can verify it exists**. The
  log's age is the only evidence, and a user who never installed it simply has an
  old log, which the advisory reports honestly. There is no fix for this inside the
  harness ↔ user boundary, and pretending otherwise would be the "looks enforced,
  isn't" failure CLAUDE.md already declined for `amendments.md`.
- **The pass is an LLM exercising judgment.** It can merge two things that should
  have stayed apart or manufacture a near-duplicate. The vault's answers — search
  before writing, never auto-merge a contradiction — both port, and neither is
  verifiable by anything.
- **Meaning drift in `wiki/` pages** (§4.3) is untouched. Wiki pages are still not
  gated and must not pretend to be.
- **A capture nobody wrote** stays invisible (§7.2). The pass promotes; it does not
  notice absence.

### 8.8 What I recommend not building

1. **No delete-after-merge.** §8.3.
2. **No installed scheduler.** Print the prompt; the user installs it. §8.5.
3. **No automated pointer-entry authoring or restamping.** §4.2's refusal extends
   to the pass unchanged.
4. **No `claim:` / `assumption:` / `ready_for_contra:`.** §2 already declined them;
   six weeks on, the vault's own consumer (the Contrarian Loop) is still unbuilt.
   Do not ship fields nothing reads.
5. **No second contradiction store.** The vault writes contradictions into its run
   log; do the same in `DISTILL-LOG.md`. Do not build an analogue of
   `_agent/contra/`.
6. **Build in this order, and treat the first three as the deliverable.** Redirect
   command output into `.brain/raw/` with `status: unprocessed`; add
   `check-brain-record.sh` before any capture exists (§6's 1b lesson — the gate goes
   in before there is drift to argue with); add the advisory. **Only then write
   `/distill`.** The first three are §5.5's prize and are worth doing on their own
   even if the pass is never written — the same standalone discipline §6 applies to
   Phase 1.

---

## 9. Amendments after implementation (2026-08-26)

This spec is a design record, not a live contract, and four things landed
differently from what it says above. Recorded here rather than edited in place,
because the reasoning that changed is the part worth keeping.

### 9.1 There IS a `.brain/memory/` layer, and it is the default

§2's table and §7.3 both decline a `memory/` layer, on the grounds that a
maintainer's external knowledge store already held this project's memory and two
stores for one subject is the one-fact-one-file violation the layer exists to
prevent. **That premise is withdrawn.** The direction of the relationship was
inverted: the project brain is self-contained and an external store reads *it*.
The project never reaches out to anyone's directory.

So `.brain/memory/` exists, and `memory_backend = repo` is the shipped default.
The reasoning §7.3 used still holds — one subject, one store — it simply resolves
the other way now that the store is in-repo.

### 9.2 The external-path memory backend is deleted

A three-way `memory_backend` briefly shipped, the third option being an absolute
path the operator configured, plus the key that named it. It is deleted outright, not
deprecated and not commented out: a config key naming a directory that exists on
one machine is one person's setup shipped as a product feature, and a dead
config key is a claim about a capability that does not exist. Two backends
remain — `repo` (default) and `project`.

Naming note, because §8 leans on the word throughout: `.brain/` **is** this
project's vault — same structure, same raw/distilled discipline, same
one-fact-one-file rule, scoped to one project. "Brain" is the name, not a
different model. What was removed is the pointer to somebody *else's* vault.

### 9.3 The migration is DETECTION, not resolution

Flipping the default strands an existing project's memory in the old location. A
LEGACY-AWARE DEFAULT was designed for this — probe for a non-empty legacy store
and hold the default there — and was **built and then removed on review**. It
fails four ways, one of them fatal:

- `REPO_ROOT` comes from the script's own location, so the `project` slug is the
  *worktree's* path. The probe resolves `project` in the main checkout and `repo`
  in a worktree of the same project: two stores, neither aware of the other. The
  swarm pack is worktree-based, so that is the normal path.
- A moved or renamed repo changes the slug, so the probe finds nothing, resolves
  `repo`, and orphans the store **without firing the notice** — the notice was
  conditioned on the probe that just failed. Silent exactly when it matters most.
- It turns a reviewable one-line config diff into a filesystem side effect with
  no diff anywhere.
- CI and a laptop disagree by construction, so any test asserting a resolved path
  has two right answers.

Resolution is therefore a pure function of `(env, conf)`. The stranding is
surfaced by `check-brain-signals.sh` in the preflight advisory — file count and
both paths, every session, until the user moves the files or answers `project`.
It never blocks and never moves anyone's files. Verified against this repo:
22 files, both paths named.

Second-order fix from the same review: the BM25 index directory is now keyed to
the resolved backend. It stores repo-relative paths and recorded nothing about
which memory directory they came from, so a backend change would have served
stale hits from the previous store — plausible-looking wrong answers in a
retrieval layer, the hardest class to notice.

### 9.4 §8.8.6 deliverable #1 is done, and the gate is actually in CI

Capture is wired. `/cross-check` writes its report to
`.brain/raw/reviews/<id>-<slug>/`, and `/research` writes its final report as a
single self-contained capture at `.brain/raw/research/<id>-<slug>.md`. Both carry
`status: unprocessed`.

`/research`'s working intermediates (vote JSONs, per-researcher drafts,
`claims.json`) deliberately stay in the gitignored `.docs/research/<id>-<slug>/`.
That split is not a compromise; it is this repo's own stated rule from
`.gitignore`: **track only what a human opens**. The cost, stated rather than
waved away: the capture is TRACKED where research output never was — roughly one
markdown report of tens of KB per run (comparable instance documents in
`.docs/reports/` run ~25 KB), on a command run a handful of times a quarter, so
well under a megabyte a year — and the vote JSONs exist only per-machine.
`.brain/raw` is a wholesale strip entry, so none of it reaches the template.

Separately: §8.4 and CLAUDE.md both said `check-brain-record.sh` runs in CI
"beside `check-generated-freshness.sh`". It did not. The *test suite* for the
gate was wired into `plugin-tests.yml`; the gate itself was not. It is now. A doc
claim nothing backs is the same defect class this spec spends §8 removing, one
level up.
