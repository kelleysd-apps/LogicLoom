# CLAUDE.md — split analysis and recommendation

**Status**: analysis, not a decision. Nothing in the repo was changed to produce it.
**Date**: 2026-08-27
**Occasion**: `packaging/adopt/payload-manifest.txt:258` carries
`defer: CLAUDE.md :: split into .claude/rules/*.md per PRE-7 — not yet authored`,
and the manifest grammar makes every `defer:` row block every apply.
**Scope note**: this document deliberately separates two questions the framing
merges — *what the adopt payload ships* (blocking) and *whether this repo's own
`CLAUDE.md` should be refactored* (not blocking). The answers are different.

---

## 0. Verification of the load-path claim

The research (`.docs/design/adopt-package-research.md:44-48`, § PRE-7) rests on:
rules files without `paths:` frontmatter load at launch at the same priority as
`.claude/CLAUDE.md`. The instruction was to verify this on this machine rather
than take it from documentation. Three independent checks, with what each does
and does not establish.

**Check 1 — a rules file is loaded into this session, verbatim (CONFIRMS the
user scope).** `/Users/bkelley/.claude/rules/ai-os-vault.md` exists on disk
(1,565 bytes, no YAML frontmatter — its first line is `# Personal knowledge
vault`). Its full text is present in this agent's own context, in the `claudeMd`
block, labelled *"user's private global instructions for all projects"*, sitting
between `~/.claude/CLAUDE.md` and the project `CLAUDE.md`. That is direct
observation of the loader's output, not a documentation claim: an unconditional
`.md` in a `rules/` directory loads at launch, at CLAUDE.md priority, in
CLAUDE.md's position.

**Check 2 — the binary treats `.claude/rules/` as a memory path across scopes
(SUPPORTS the project scope).** The installed CLI
(`/Users/bkelley/.local/share/claude/versions/2.1.200`) contains the
`claudeMdExcludes` setting description verbatim: *"Glob patterns or absolute
paths of CLAUDE.md files to exclude from loading… Only applies to User,
**Project**, and Local memory types"*, with `"**/some-dir/.claude/rules/**"` given
as an example pattern. A directory is only excludable from loading if it is
loaded. It also contains the strings `CLAUDE.md/rules files:` and `No CLAUDE.md/rules
files found` — the loader's own listing treats the two as one class.

**Check 3 — the primary documentation, re-fetched independently (CONFIRMS both,
and adds a mechanism the research under-uses).** `code.claude.com/docs/en/memory`,
fetched 2026-08-27, states: *"Place markdown files in your project's
`.claude/rules/` directory… All `.md` files are discovered recursively"* and
*"Rules without `paths` frontmatter are loaded at launch with the same priority
as `.claude/CLAUDE.md`."*

**What I could not verify, and why it matters.** I could not run the decisive
end-to-end test — a throwaway git repo with a marker token in
`.claude/rules/probe.md`, queried headlessly — because `claude -p` in this
sandbox returns `Not logged in`. So *project-scoped* `.claude/rules/` loading is
established by Checks 2 and 3, not by direct observation; only the *user* scope
was observed directly. This is a small gap and it points the same way, but it is
a gap. **The maintainer can close it in ninety seconds** from a logged-in shell:

```bash
d=$(mktemp -d); mkdir -p "$d/.claude/rules"; cd "$d"; git init -q .
printf 'The secret project rule token is ZORBLAX-7741.\n' > .claude/rules/probe.md
claude -p "What is the secret project rule token? Reply with only the token, or NONE."
```

`ZORBLAX-7741` confirms it. `NONE` invalidates PRE-7 and this whole document.
In an interactive session the equivalent is `/context` → **Memory files**.

**The claim holds. But the research read half the mechanism.** `paths:`
frontmatter is not merely an absent field that leaves a rule unconditional — it
is a *third loading tier*, and it is the tier that answers question 2 below.
Confirmed in the same doc: *"Path-scoped rules trigger when Claude reads files
matching the pattern, not on every tool use."* PRE-7 mentions `paths:` only to
say LogicLoom's files won't have it. That is a missed lever, and Phase 2 below
spends it.

Three further facts from the same fetch, each of which changes an obvious plan:

- **`@path` imports do not reduce context.** *"Splitting into `@path` imports
  helps organization but doesn't reduce context, since imported files load at
  launch."* Any split-by-import proposal is pure churn — rule it out now.
- **The 200-line target is the documentation's own number.** *"target under 200
  lines per CLAUDE.md file. Longer files consume more context and reduce
  adherence."* This repo's file is 860 lines, 4.3× the guidance.
- **User rules load before project rules.** So a LogicLoom-installed project rule
  cannot silently pre-empt an adopter's personal rules; theirs are read first,
  ours after. That is the correct order for a harness.

---

## 1. Section-by-section classification

860 lines, 51,860 bytes. Line ranges are heading-to-next-heading.

I use four kinds. Three are from the framing; I split "harness instruction" in
two, because the distinction between *an obligation that must be in force before
the model touches anything* and *an obligation that only bites inside one file
class* is precisely what `paths:` frontmatter buys, and collapsing them throws
the lever away.

- **FACT** — repo-specific. True of this repo only. Useless or actively wrong in
  an adopter's repo.
- **OBLIGATION-ALWAYS** — a standing rule whose violation is not cheaply
  undone, so it must be loaded before the first tool call.
- **OBLIGATION-SCOPED** — a standing rule that only applies while touching one
  identifiable file class. Correct home: a `paths:`-scoped rule.
- **REFERENCE** — an inventory or table consulted on demand, not obeyed.
- **NARRATIVE** — orientation read once.

| Lines | Section | Kind | Belongs |
|---|---|---|---|
| 1-16 | Title, brand, framework-folder, core-vs-packs preamble | NARRATIVE + FACT | CLAUDE.md (short); adopter version rewritten, not copied |
| 17-32 | Core + Workflow Packs (READ FIRST) | OBLIGATION-ALWAYS | **Ships.** `rules/logicloom-workflow.md` |
| 33-56 | Model & provider boundary | OBLIGATION-ALWAYS | **Ships.** Tandem-test content (`superseded stance`, `AGENTS.md Tier 1`) — see §4 |
| 57-75 | Orchestration primitives (ride native) | OBLIGATION-ALWAYS | **Ships**, condensed ~8 lines. The "what was removed" paragraph is FACT — drop it |
| 76-81 | Governance intro | OBLIGATION-ALWAYS | **Ships.** `rules/logicloom-governance.md` |
| 82-105 | Hook enforcement table | OBLIGATION-ALWAYS | **Ships.** Paths stay valid — the payload installs the same trees |
| 106-113 | Standing policies (incl. Cross-Check Disposition) | OBLIGATION-ALWAYS | **Ships verbatim.** The single highest-value block in the file |
| 114-124 | Governance modes (lean/strict) | OBLIGATION-ALWAYS | **Ships** |
| 125-145 | Gate policy | OBLIGATION-ALWAYS | **Ships**, condensed. The five-operation floor is the load-bearing half |
| 146-184 | Swarm pack + loop diagram | REFERENCE | `.docs/` (already ships). Cite from the rule; do not load |
| 185-203 | Per-feature folder layout | REFERENCE | `features/README.md` — already exists and already ships |
| 204-221 | Command reference — Swarm | REFERENCE | `.docs/`. Commands self-describe via `/help` and their own SKILL.md |
| 222-245 | Command reference — SDD + tooling | REFERENCE | `.docs/` |
| 246-274 | Command reference — Environment promotion | REFERENCE | `.docs/policies/environment-promotion-policy.md` — cited there already |
| 275-285 | Constitution Principles pointer | OBLIGATION-ALWAYS | **Ships.** The "read the constitution first" instruction is the whole value |
| 286-296 | Critical Principles quick reference | OBLIGATION-ALWAYS | **Ships.** Four rows, high density |
| 297-345 | Project amendments (49 lines of adjudication doctrine) | REFERENCE | `.docs/`. Explicitly *"followed, not enforced — and nothing loads it"*. Forty-nine loaded lines about a file most repos will not have |
| 346-387 | LogicLoom Hooks — full path table | REFERENCE | `.docs/architecture/`. Duplicates 82-105's enforcement claims at path granularity |
| 388-413 | MCP Server Configuration | FACT | Drop from payload. Docker/marketplace inventory, no obligation |
| 414-443 | Plugin Registry | FACT **and parsed** | Stays in this repo's CLAUDE.md — `test_bash32_floor.sh` parses it. See §4 |
| 444-454 | Plugin command bridge | REFERENCE | `.docs/` |
| 455-535 | Key Architecture / Directory structure (81 lines) | REFERENCE + FACT | `.docs/architecture/loom-architecture.md`. Largest single block; `/doctor` targets exactly this |
| 536-554 | Workflow scripts table | REFERENCE | `.docs/` |
| 555-564 | File Creation Rules (Principle XV) | OBLIGATION-ALWAYS | **Ships** |
| 565-582 | Harness ↔ product boundary | OBLIGATION-SCOPED | **Ships.** Candidate for `paths: ["web/**","apps/**","package.json"]` |
| 583-609 | Harness ↔ user boundary | OBLIGATION-ALWAYS | **Ships**, condensed to ~8 lines. "Never write `~/.claude/`" is the rule; the versioning-personal-config paragraph is advice |
| 610-623 | Naming conventions | REFERENCE | `.docs/policies/file-structure-policy.md` — already the cited source |
| 624-633 | Task hierarchy | REFERENCE | `.docs/` |
| 634-644 | Task tool rules (CRITICAL) | OBLIGATION-ALWAYS | **Ships** |
| 645-729 | Project Knowledge Layer `.brain/` (85 lines) | REFERENCE + NARRATIVE | `.brain/README.md` — named in the text as the contract. Most of this block is provenance ("the default changed", "considered and declined") |
| 730-750 | AI Model Selection | OBLIGATION-ALWAYS (top 6 lines) + REFERENCE (tier table) | Ship the "select by tier keyword, never a pinned string" rule; the table is `models.conf` |
| 751-781 | Orchestrator + worker ladder | FACT | Drop from payload. Names `.claude/agents/*.md` files the payload does not install |
| 782-791 | Distribution & Cloner Support | FACT | Drop. `/update-framework` and `.sdd-sync-ref` are clone-path, not adopt-path |
| 792-826 | Additional Documentation (See Also) | REFERENCE | Rewrite as a short pointer list in the rules file |
| 827-843 | What changed in v6.2 / v6.1 | FACT | **Delete outright.** This is CHANGELOG.md's job. Zero consumers (§4) |
| 844-860 | Footer / version stamp | FACT **and stamped** | Stays in this repo's CLAUDE.md — `bump-version.sh:42`. See §4 |

**Totals.** OBLIGATION (either kind): ~196 lines across twelve blocks.
REFERENCE: ~415 lines. FACT/NARRATIVE: ~249 lines. **About 23% of the file is
the part an adopter must have loaded.** That ratio is the finding this whole
analysis turns on, and it is why §5 recommends authoring rather than splitting:
you cannot get from 860 lines to 196 by moving section boundaries around — the
remaining 664 lines have to be *not written* for the new audience, and most of
them are not merely surplus but false in an adopter's repo (our version stamp,
our plugin table, our branch topology, our `.brain/` history).

---

## 2. The question that decides the split: `rules/` vs `.docs/`

**The framing's premise is correct and I would sharpen it.** `.claude/rules/`
without `paths:` loads unconditionally at CLAUDE.md priority. Moving 800 lines of
reference material there does not reduce context cost — it is exactly
context-neutral in bytes and *worse in effect*, for two reasons the framing names
one of:

1. **A reader can skip; a loader cannot.** A human consulting an 860-line file
   reads a heading and jumps. The model pays for every line before the first
   token of the user's actual request.
2. **Splitting destroys the ordering that made skipping cheap.** Within one file
   the reference tables sit after the obligations, so a model that stops reading
   early stops in the right place. Across eight sibling files there is no such
   order — the documentation is explicit that all `.md` under `rules/` are
   discovered recursively and concatenated, and warns that *"if two rules
   contradict each other, Claude may pick one arbitrarily."* Splitting raises the
   contradiction surface while lowering nothing.

**So is `rules/` for instructions only? Not quite — that is a two-way answer to a
three-way question.** The correct rule is a test, not a location:

> **If the model never reads this, what breaks?**
>
> - *It does something irreversible, or violates a governance floor* →
>   **always-loaded**: `CLAUDE.md` or an unconditional `rules/*.md`.
> - *It does the wrong thing, but only while touching one identifiable file
>   class* → **`paths:`-scoped rule.** Costs nothing until a matching file is
>   read.
> - *It asks, or looks it up, and is right a moment later* → **`.docs/`, or a
>   skill.** The documentation's own guidance: *"For task-specific instructions
>   that don't need to be in context all the time, use skills instead."*

Applied to this file, the middle tier is not hypothetical. Three blocks are
textbook path-scoped rules, and all three are currently paid for on every prompt
in every session:

| Content | Fires when | Cost today |
|---|---|---|
| bash 3.2 floor (`.docs/policies/shell-idiom-policy.md`, summarised at 792-826) | `paths: ["**/*.sh"]` | loaded always |
| Harness ↔ product boundary (565-582) | `paths: ["web/**","apps/**","package.json"]` | loaded always |
| Plugin-First / plugin authoring (414-454) | `paths: ["plugins/**"]` | loaded always |

**What I would measure, and with what.** The documentation names three
instruments and I would use all three, in this order:

1. **`/context` → Memory files** — the authoritative list of what actually loaded
   this session, with sizes. This is the before/after number. Take it once now,
   once after each migration step. It is also the per-step verification gate in
   §6: if a step's rule file does not appear, the step failed and is reverted.
2. **The `InstructionsLoaded` hook** — documented as logging *"exactly which
   instruction files are loaded, when they load, and why… useful for debugging
   path-specific rules."* This is the only way to prove a `paths:` rule actually
   fires rather than silently never matching. Run it across a week of real
   sessions.
3. **`/doctor`'s CLAUDE.md trim check** (requires v2.1.206+; this machine runs
   2.1.200, so **it must be upgraded before this is available**) — it *"cuts
   content Claude can derive from the codebase, such as directory layouts,
   dependency lists, and architecture overviews, and keeps pitfalls, rationale,
   and conventions that differ from tool defaults."* That is, independently, the
   same cut §1 arrives at: lines 455-535 (directory structure) and the command
   tables are exactly what it targets. Running it is a free second opinion on
   this analysis, from a tool with no stake in it.

The decision rule I would hold myself to afterwards: **a `paths:` rule that fires
in every session should have been unconditional; a `paths:` rule that never fires
in a month should have been `.docs/`.** Both are visible in the
`InstructionsLoaded` log and in nothing else.

---

## 3. Adopter dilution — the numbers

The framing cited kori at 429 lines. **Measured: `kori-beta/CLAUDE.md` is 493
lines, 24,817 bytes.** The correction moves the number slightly in the framing's
favour, not against it. Five real adopter-shaped repos on this machine:

| Repo | Their `CLAUDE.md` | + LogicLoom 860 | Their share of loaded instructions |
|---|---|---|---|
| `kori-beta` | 493 lines / 24,817 B | 1,353 lines / 76,677 B | **32.4%** |
| `msdh` | 464 lines / — | 1,324 lines | 35.0% |
| `cosmos-2` | 612 lines | 1,472 lines | 41.6% |
| `leadbench` | 82 lines | 942 lines | **8.7%** |
| `kelleysd.com` | 858 lines | 1,718 lines | 49.9% |

By bytes, kori's product spec falls to **32.4%** of loaded instruction context —
close to the framing's 35% and comfortably a real dilution. At roughly 3.8 bytes
per token for table-dense markdown, LogicLoom's file is **~13,600 tokens** on
every prompt of every session, against kori's ~6,500.

**Two things make this worse than the headline, and both are worth stating.**

First, `leadbench` at 8.7% is the honest worst case and it is not an outlier —
it is what a small, healthy `CLAUDE.md` looks like. The dilution is inversely
proportional to how well the adopter has followed the 200-line guidance. **We
would penalise our best-behaved adopters hardest.**

Second, adding 860 lines to a 493-line file produces 1,353 lines — **6.8× the
documented 200-line target**, in a file class the documentation says *"Longer
files consume more context and reduce adherence."* We would not merely be
crowding out their rules; we would be pushing the whole loaded set into the
regime where the vendor says our own rules stop being followed reliably. **The
governance floor is the part we can least afford to have ignored.**

At the recommended payload of ~200 authored lines, kori's share is **71%**
(24,817 of 34,817 B), the combined file set is ~693 lines, and LogicLoom costs
roughly **2,600 tokens** a session instead of 13,600. That is the argument.
Everything else in this document is bookkeeping.

---

## 4. The upstream bill

What a split of *this repo's* `CLAUDE.md` actually costs. Grouped by whether the
breakage is loud (a test fails) or silent (a citation rots).

### Hard couplings — a test or script fails immediately

| # | Consumer | What it does | Cost |
|---|---|---|---|
| 1 | `tests/contract/test_bash32_floor.sh:167-171, 232` | **Parses** `sed -n '/^## Plugin Registry/,/^## /p' CLAUDE.md` to derive which plugins are harness-owned and held to the bash 3.2 floor. Guarded both ways: a declared plugin with no directory fails, and an undeclared `loom-*`/`sdd-*` directory fails | **The only structural coupling.** Not a citation — a parser with a heading sentinel. Moving the table means editing the parser's path *and* reproducing `^## Plugin Registry` … `^## ` in the destination. **Recommendation: do not move it** |
| 2 | `.logic-loom/scripts/bash/bump-version.sh:42` | Stamps `**Framework**: logic-loom v<N>` by regex | Zero if the footer stays. `history-scrub-rules.json:80-81` independently pins the CLAUDE.md footer as *the* surviving version pointer after the template strip (CHANGELOG.md does not survive), so this footer is load-bearing twice over |
| 3 | `tests/contract/test_disposition_tandem.sh:29-45` | Five `grep`s: three verbatim Cross-Check Disposition sentences, plus `AGENTS.md Tier 1` and `superseded stance` | Content lives at 106-113 and 33-56 — **both are OBLIGATION-ALWAYS and both ship**. Either keep them in CLAUDE.md, or widen `$CLAUDE` to a file list. One-line test edit |
| 4 | `tests/contract/test_backlog_dashboard.sh:427-428, 446-447` | Greps `^artifacts/` and `artifacts/backlog-dashboard.html` inside the directory-structure block | Directly blocks moving 455-535, the single largest reference block. One-line test edit per assertion |
| 5 | `tests/contract/test_constitution.sh:70-71` | Greps `16 principles`, `XVI.*Plugin-First` | Content is OBLIGATION-ALWAYS; stays regardless |
| 6 | `tests/contract/test_product_workspace_boundary.sh:123` | Asserts CLAUDE.md surfaces the product workspace | Same |
| 7 | `tests/contract/test_brain_record.sh:578` | CLAUDE.md in a scanned root list | Cosmetic; new files should be added |
| 8 | `.logic-loom/scripts/bash/constitutional-check.sh:616` | Live `grep` of CLAUDE.md for model-selection keywords | Passes as long as 730-750 stays |

### Soft couplings — nothing fails; things rot

| # | Consumer | Exposure |
|---|---|---|
| 9 | `constitutional-check.sh` × 8 comment citations of *"CLAUDE.md § \<section name\>"* (lines 62, 87, 266, 344, 474, 531, 576, 658) | Section-name references in comments. Break **silently** — no test reads them. The most likely thing to rot |
| 10 | `.logic-loom/scripts/bash/build-graph-bridge.sh:140` | Corpus is `.docs features specs` **plus** five named root files including CLAUDE.md. **Moving reference material to `.docs/` keeps graph coverage for free; moving it to `.claude/rules/` silently drops it from the corpus** unless the loop is extended. A genuine argument for `.docs/` over `rules/`, independent of context cost |
| 11 | `.docs/policies/instruction-files-policy.md` (15 mentions) | The policy of record. Defines CLAUDE.md's contents list and the tandem matrix. **Must be amended by hand** — it is the document a future maintainer will trust over this one |
| 12 | 54 markdown files repo-wide cite `CLAUDE.md` | Almost all are prose "see CLAUDE.md", which stays valid while the file exists. Only the ~15 that cite a *named section* are exposed |
| 13 | `template-strip-manifest.txt:257`; `sanitize-for-template.sh:107`; `setup.sh:362` | Declare CLAUDE.md ships / point users at it. New files need rows or they will not ship |

### The bill in one line

**Deleting lines 827-843 (the two "What changed in v6.x" sections) costs
nothing — zero consumers, 18 lines, and CHANGELOG.md already holds it.** Moving
the directory-structure block costs two test edits. Moving the Plugin Registry
costs a parser rewrite and should not be done. Everything else in the file can
move for the price of one `grep` widening apiece. **The bill is small; it is the
*content authorship* that is expensive, and no test-editing plan reduces that.**

---

## 5. Recommendation

**Author the adopter's rules; do not split this repo's CLAUDE.md to produce
them. And keep the repo-side refactor small, separate, and optional.**

Three findings force this, in order of weight:

1. **Only ~23% of CLAUDE.md is what an adopter needs loaded** (§1). Splitting a
   file is a good way to get two halves; it is a bad way to get one-fifth. The
   other 664 lines are not surplus — a large fraction is *wrong* in an adopter's
   repo: our version stamp, our parsed plugin table, our branch topology, the
   `.brain/` default-change history, `/update-framework` and `.sdd-sync-ref`
   (clone-path machinery an npm adopter never touches, exactly as PRE-13 says of
   `/initialize-project`). Copy-then-subtract leaves those in until someone
   notices. **Authoring ~200 lines for a stranger's repo is less work, and less
   risk, than subtracting 664 from ours.**
2. **The blocking artifact and the repo's file have different audiences.** Ours
   is read by someone with the whole tree in front of them. Theirs is read by a
   model in a repo where `plugins/`, `features/`, `tests/` and `package.json` are
   *the adopter's*, not ours.
3. **The dilution argument only pays out at ~200 lines** (§3). A faithful split
   that preserved the reference tables in `rules/` would move kori from 32% to
   32% — the cost is identical whichever directory the bytes sit in.

### Recommended shape

**Payload (blocking).** Three authored files, ~200 lines total, sourced from
`packaging/adopt/payload/rules/` and `rename:`d into the adopter's
`.claude/rules/`. None carry `paths:` — all three are standing obligations.

| File | ~Lines | From (§1 rows) |
|---|---|---|
| `logicloom-governance.md` | 90 | 76-145, 275-296, 730-736 |
| `logicloom-workflow.md` | 60 | 17-75, 634-644 |
| `logicloom-file-rules.md` | 50 | 555-609, 792-826 (as pointers) |

Everything classified REFERENCE reaches the adopter already: `.docs/policies/`
and `.docs/architecture/` are `include:` rows today, `features/README.md` and
`.brain/README.md` ship with their trees. Nothing is lost — it stops being
*loaded*, which is the entire point.

**Why `packaging/`, not this repo's `.claude/rules/`.** If the authored files
live at `.claude/rules/` here, they load in every session in this repo *in
addition to* CLAUDE.md, saying the same things in different words — precisely the
condition the documentation warns about (*"if two rules contradict each other,
Claude may pick one arbitrarily"*), applied to the governance floor. `packaging/`
is already a `template-strip-manifest.txt` entry, so it never reaches a customer,
and the manifest grammar already has `rename:`. One manifest row instead of a
repo-wide refactor.

**The cost of that choice, stated plainly.** The adopter's governance text and
ours can drift. Mitigation: extend `test_disposition_tandem.sh` from a pair to a
triple, so the three Cross-Check Disposition sentences must appear in `AGENTS.md`,
`CLAUDE.md`, **and** `packaging/adopt/payload/rules/logicloom-governance.md`.
That converts silent drift into a red test on the block that matters most. It
does not cover the rest, and I will not claim it does — the rest is
maintainer discipline, same as it is between CLAUDE.md and AGENTS.md today.

### Do less: what I recommend *against*

- **Do not move the Plugin Registry** (414-443). `test_bash32_floor.sh` parses it
  with a heading sentinel and fails closed in both directions. It is a contract
  living in a documentation file — ugly, working, and load-bearing. Leave it.
- **Do not move the version footer** (844-860). Two independent consumers.
- **Do not split CLAUDE.md into `@path` imports.** Documented as saving nothing.
- **Do not restructure the repo's CLAUDE.md as part of unblocking adopt.** It is
  a separate change with a separate risk profile and it should not ride along.

### Phase 2, optional and non-blocking

If the maintainer wants the ~13,600-token daily cost down in *this* repo, the
cheap, high-confidence moves — in descending value per unit of risk:

1. **Delete 827-843** (the two "What changed" sections). 18 lines, zero
   consumers, duplicates CHANGELOG.md. Free.
2. **Move 455-535 (directory structure, 81 lines) to
   `.docs/architecture/loom-architecture.md`**, leaving a three-line pointer.
   Costs two `grep` edits in `test_backlog_dashboard.sh`. Stays in the graph
   corpus (`.docs/` is already scanned). `/doctor` proposes this same cut
   independently — run it first and let it argue the case.
3. **Move 297-345 (amendments doctrine, 49 lines) to `.docs/`**, leaving the
   three-line rule *"read `amendments.md` if it exists; mandates are additive
   only."* The section says of itself that nothing loads it.
4. **Move 645-729 (`.brain/`, 85 lines) to `.brain/README.md`**, which the text
   already names as the contract. Leave the three-signal table and the
   protected-paths sentence.
5. **Convert the three OBLIGATION-SCOPED blocks to `paths:` rules** — only after
   an `InstructionsLoaded` log shows they fire when expected.

Steps 1-4 alone take 860 lines to roughly **625** and cost two test edits. That
is a real improvement and it is nowhere near 200; getting to 200 would mean
moving the Plugin Registry and the command tables, and the first of those is a
contract. **I would stop at step 4 and call it done.** This repo has taken the
"do less" answer before (the `amendments.md` loader, considered and declined) and
it was right both times.

---

## 6. Migration sequence

Each step is independently verifiable and revertible by `git revert` of one
commit. **No step depends on the next.** Steps 1-3 clear the blocker; 4 onward
are Phase 2 and may be dropped entirely.

| # | Step | Verified by | Reverts by |
|---|---|---|---|
| 0 | Run the ZORBLAX probe (§0) from a logged-in shell. Record the result in `payload-manifest.txt` | Token echoed | n/a — read-only |
| 1 | Author the three rules files under `packaging/adopt/payload/rules/`. Add a scratch repo, symlink them into its `.claude/rules/`, run `/context` | All three appear under **Memory files**; total under ~2,600 tokens | Delete the directory |
| 2 | Replace manifest line 258 with three `rename:` rows. `defer:` count goes to zero | `tests/contract/test_adopt_payload_manifest.sh` passes; the applier no longer refuses | One-line revert |
| 3 | Extend `test_disposition_tandem.sh` to assert the three Disposition sentences in the payload governance file | Test fails when a sentence is removed from any of the three files; passes otherwise | Revert the test |
| — | **Blocker cleared. Everything below is optional.** | | |
| 4 | Delete CLAUDE.md 827-843 | `npm test` green; `bump-version.sh --dry-run` still finds the footer | `git revert` |
| 5 | Upgrade Claude Code past v2.1.206; run `/doctor`'s trim check; record its proposal beside this document | A written proposal to compare against §1 | n/a |
| 6 | Move the directory-structure block to `.docs/architecture/`; edit the two `test_backlog_dashboard.sh` greps to point at the new path | Suite green; `build-graph-bridge.sh` still emits edges for the moved content | `git revert` |
| 7 | Move the amendments doctrine and the `.brain/` narrative, one commit each | Suite green after each | `git revert` |
| 8 | Add `InstructionsLoaded` logging; run a week; only then convert the three scoped blocks to `paths:` rules | Log shows each rule firing on its file class and not otherwise | `git revert` |

---

## 7. The minimum unblocking change

**Steps 1-3 above. Nothing else.** Concretely:

- Three new files under `packaging/adopt/payload/rules/`, ~200 lines total,
  **authored** — not extracted — from the twelve OBLIGATION-ALWAYS rows in §1.
- `payload-manifest.txt:258` — one `defer:` line replaced by three `rename:`
  rows, each `packaging/adopt/payload/rules/X.md :: .claude/rules/X.md`.
- One test widened (`test_disposition_tandem.sh`).

**This repo's `CLAUDE.md` is not modified at all.** No stamp site moves, no test
breaks, no citation rots, nothing leaves the graph corpus. The entire upstream
bill in §4 is deferred to Phase 2, where it is optional and where every row of it
can be declined.

Budget it as **content work, roughly half a day of authorship** — which is what
the manifest's own comment already says (*"Budget it as content work"*). What
this analysis adds is that the content should be **written for the adopter**
rather than **carved out of ours**, and that the repo-side refactor the framing
anticipated is a separate, smaller, and entirely optional job.

---

## 8. What I could not verify

- **Project-scoped `.claude/rules/` loading was not observed directly** — only
  the user scope was (§0, Check 1). Project scope rests on the binary's own
  settings text and the primary documentation. The one-command probe in §0
  closes it.
- **Token figures are estimates** at ~3.8 bytes/token for table-dense markdown.
  Byte and line counts are measured; token counts are not. `/context` gives the
  real number and is step 1's verification gate.
- **`/doctor`'s trim check was not run** — it requires v2.1.206+ and this machine
  runs 2.1.200.
- **No adopter has installed anything**, so the dilution figures in §3 are
  arithmetic on real files, not observed behaviour. The claim that adherence
  degrades past 200 lines is the vendor's, quoted, not independently measured
  here.
- **The three-file / ~200-line payload split is a proposal, not a draft.** The
  files do not exist; the line counts are targets.
