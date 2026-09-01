# LogicLoom in kori-beta — what to expect, and what to adjust

**For:** the kori-beta team
**From:** LogicLoom maintainers
**Date:** 2026-09-01 (revised — four items shipped since the first draft)
**Your install:** `logicloom@6.6.1`, Node 22.23.2, targets `harness + gitignore + rules + hooks`

---

## Short version

The install itself was clean — 393 files written, 0 skipped, 0 failed, and none
of your own files touched. Everything the receipt claims is on disk. The
governance hooks work.

Seven things were wrong or missing, all found by auditing **your** install.
**Six are now fixed upstream** and reach you on your next upgrade — including the
domain briefs, which is the one that mattered most for a React Native project.
One remains open, and it needs nothing from you.

**You already fixed the worst one yourselves.** More on that below — you were
right, and we have made the same change upstream.

---

## What we verified is working

Checked directly against your repository, not assumed:

- **Every path the receipt claims exists.** 282 files, 109 directories, 2 merge
  targets — nothing missing.
- **The governance floor fires.** A subagent `git push` is denied; a main-agent
  push asks for approval; a subagent write to `.claude/settings.json` is denied.
  Four matcher groups registered across `SessionStart`, `UserPromptSubmit`,
  `PreToolUse`.
- **The harness is functional** — `constitutional-check.sh` exits 0.
- **Your files are untouched.** Only `TODO.md` shows modified, which predates
  the install. Your `.gitignore` keeps all 69 of its original lines
  intact; our fenced block starts at line 70.
- **The uninstall procedure is safe.** All 281 recorded files carry a `sha256`,
  and both merge targets are correctly excluded from the delete list, so
  following it cannot destroy files you own.

---

## 1. The plugin agents did not load — you already fixed this

**You were right.** Your commit `5cc2267` *"Bridge the plugin agents into
.claude/agents so they actually load"* is the correct diagnosis and the correct
fix, arrived at independently.

Five agents — `subagent-architect`, `prd-specialist`, `team-synthesizer`,
`framework-sync-agent`, `memory-context-agent` — were declared in
`plugins/*/.claude-plugin/plugin.json` and never loaded, because nothing
registers a `plugins/` tree as a Claude Code marketplace. `/create-plugin` and
`/create-agent` both dispatch `subagent-architect` by name, so they were silently
getting a generic agent with none of the declared model tier or tool
restrictions.

**Upstream now does what you did** (LogicLoom `LOOM-0052`): all five live in
`.claude/agents/`. `constitutional-governance-agent` stays in the plugin — it is
hook-injected and works as designed.

**What to do on your next upgrade:** you will end up with our copies in
`.claude/agents/` and your bridged copies already there. The installer never
overwrites a file it did not create, so **yours win and ours are skipped** — no
conflict, no data loss.

One cleanup is yours to do, because the installer never deletes anything: the
stale copies still sitting in `plugins/*/agents/` will never load and will
confuse the next person who reads them. Once you are on a version with
LOOM-0052, delete these five:

```
plugins/loom-creation/agents/subagent-architect.md
plugins/loom-creation/agents/prd-specialist.md
plugins/loom-orchestrator/agents/team-synthesizer.md
plugins/loom-maintenance/agents/framework-sync-agent.md
plugins/loom-memory/agents/memory-context-agent.md
```

Keep `plugins/loom-governance/agents/constitutional-governance-agent.md`.

---

## 2. The domain briefs assume a React/Next.js web app — this one is about you

**Status: FIXED upstream (`LOOM-0053`). Was affecting you; reaches you on upgrade.**

Three of the four domain briefs hardcode a stack that is not yours:

| Brief | Assumes | Ownership it claims |
|---|---|---|
| `frontend.md` | React, Next.js, Vue, Angular | `src/components/**`, `src/pages/**`, `src/styles/**` |
| `testing.md` | Jest, Vitest, Cypress, Playwright | `cypress/**`, `playwright/**` |
| `backend.md` | — | `src/api/**`, `src/services/**`, `src/routes/**` |

`database.md` is stack-neutral and fits fine.

You are React Native / Expo with Supabase Edge Functions in Deno. None of those
frameworks, none of that layout.

**The impact is advisory only, and we want to be precise about that** because an
early draft of our own report got it wrong. `freeze-write-scope.sh` resolves
`owns:` and `freeze:` from a marker file or `features/<name>/plan.md` — it has
**zero** references to domain briefs. Write-scope enforcement is unaffected.

What IS affected: swarm and team workers get primed with the wrong frameworks,
the wrong test runner, and file-ownership guidance pointing at directories you do
not have.

**What changed.** All seven briefs are now stack-neutral — the framework names
and the `src/**` ownership are gone, leaving the durable guidance about what each
domain owns and what good looks like. None of the seven was already neutral;
`database.md` was closest and still claimed `src/db/**`.

**Your adaptation point is an overlay**, not an edit to shipped files:

```
.logic-loom/domain-briefs/frontend.md      # your words, appended after ours
.logic-loom/domain-briefs/testing.md
```

`get_domain_brief` appends your overlay after the shipped brief, so your
description of Expo, your test runner, and your real directory layout comes last
and wins. Because it is a separate file, `/update-framework` will not fight it —
which editing the shipped briefs would have.

The shipped `.logic-loom/domain-briefs/README.md` carries a worked example, and
we wrote that example against React Native / Expo / Supabase-Deno because yours
was the case that prompted this. We would still like to see what you actually
write.

---

## 3. `.brain/` never installed

**Status: fixed upstream (`LOOM-0048`).**

`.brain/` is the project knowledge layer — `raw/` captures, distilled `wiki/`
pages, `index/`, and durable `memory/`. You got none of it, not even the README
that explains the contract. Worse, `/initialize-project` instructs the agent that
"`.brain/` keeps just its README.md" — a file the npm path never installed, so
the command was reasoning about something absent.

Cause: the payload excluded `.brain` wholesale as "our record", but the release
strip had already reduced it to a stubbed README. The exclusion threw away safe
structure rather than protecting content.

Fixed: `.brain/README.md` now ships — one file, byte-identical to the template,
with none of our content. Reaches you on upgrade.

**Nothing to do.** If you want the knowledge layer before then, create
`.brain/{raw,wiki,index,memory}/` and read the README once it arrives.

---

## 4. No backlog dashboard, and nothing told you one was possible

**Status: FIXED upstream (`LOOM-0049`).**

You have `todos.md` and `backlog.md` (correctly stubbed — zero LogicLoom items,
zero references to our work) and both dashboard generators. What you did not get:
the `artifacts/` directory, its convention document, the freshness gate, or any
instruction that the generators exist.

**You can build one right now.** We did, in your repo, to prove it works:

```bash
bash .logic-loom/scripts/bash/build-backlog-index.sh
bash .logic-loom/scripts/bash/build-backlog-dashboard.sh
open artifacts/backlog-dashboard.html
```

That produced a working 11.8 KB dashboard from your own backlog. **We left it
there** — `artifacts/backlog-dashboard.html` in your repo is ours, generated
during that check. Delete it if you would rather start clean.

**What you get on upgrade.** `artifacts/` ships with its convention README, the
freshness gate ships, and a `SessionStart` hook regenerates the dashboard so it
tracks your todos and backlog as they change. The regeneration is a no-op when
nothing changed, so it will not dirty your tree.

The dashboard also renders your **open GitHub issues live** — fetched when you
open the file, never baked in, so the tracked artifact stays deterministic and
the freshness gate keeps its meaning.

One thing to set: the issues panel reads `repo = <owner>/<repo>` from
`.logic-loom/config/project.conf`. Without it the panel says so plainly rather
than sitting empty. Deliberately not derived from your git remote — that is not
deterministic across forks and mirrors, and it broke our own gate when we tried.

---

## 5. `.github/workflows` — deliberate, but we owe you the methodology

**Status: open upstream (`LOOM-0050`).**

We exclude `.github/` wholesale and we intend to keep doing so: those workflows
are our release loop, they name our topology, and we will not write into your CI
uninvited.

The consequence is that you were never *offered* the methodology either.
`/initialize-project` skips CI entirely for an adopted repo.

Coming: the workflows ship as templates under
`.logic-loom/templates/workflows/`, and `/initialize-project` offers to install
and adapt them. Install, edit, or decline — your `.github/` stays yours.

---

## 6. Two documentation defects that will mislead you

**Status: FIXED upstream (`LOOM-0054`, `LOOM-0056`).**

**The bash-4 claim is wrong, and it understates your protection.**
`.claude/rules/logicloom-governance.md:38` — a file you installed — says the
dangerous-command guard "needs bash 4+; fails open otherwise". That is false. The
guard enforces on stock macOS bash 3.2; its own source says so, and says falling
through is "NOT a failure". If you concluded you were unguarded on macOS, you
were not.

**Roughly ten `.docs/` links point at files that do not exist.** The one most
likely to bite: `.docs/architecture/project-graph-convention.md` gives a worked
example citing `plugins/loom-git/skills/git-push/SKILL.md`. The real path is
`git-push-workflow`. Copying that example produces a dangling graph edge.

---

## Also worth knowing: `architecture.conf` counts are false

`.logic-loom/config/architecture.conf` declares 18 plugins, 11 agents, 19
commands, 28 test suites. Actual: 8, 8, 24, 47. Release tooling re-stamps only
the version keys, so the file looks maintained while the rest is years stale, and
the installer copied it to you verbatim.

**Nothing reads these keys** — only prose and the version bumper. It was false
metadata, not false behaviour.

**Fixed (`LOOM-0055`) by deleting them**, not by correcting them: a number nothing
derives is a number that drifts, which is how they got four years stale. Until you
upgrade, do not build anything on those numbers.

---

## Summary table

| # | Item | Status | Your action |
|---|---|---|---|
| 1 | Plugin agents did not load | **Fixed** (LOOM-0052) | Delete 5 stale `plugins/*/agents/` files after upgrade |
| 2 | Domain briefs assumed React/Next | **Fixed** (LOOM-0053) | Write overlays in `.logic-loom/domain-briefs/` — tell us what you write |
| 3 | `.brain/` missing | **Fixed** (LOOM-0048) | None |
| 4 | No dashboard | **Fixed** (LOOM-0049) | Build one now, or wait for upgrade; set `repo` in `project.conf` |
| 5 | No CI templates | **In progress** (LOOM-0050) | None; the three CI gates plus a written guide are coming |
| 6 | Wrong bash-4 claim, dead doc links | **Fixed** (LOOM-0054/0056) | Ignore the bash-4 line until you upgrade |
| 7 | Compliance check pushed agents to the dead location | **Fixed** (LOOM-0057) | None — see below |
| — | `architecture.conf` counts false | **Fixed** (LOOM-0055) | Do not trust those numbers until you upgrade |

### 7. Our own compliance check was making this worse

Worth knowing because it explains why the agent problem survived so long:
`constitutional-check.sh` warned that anything in `.claude/agents/` was a "legacy
agent file" and told authors to put agents in `plugins/*/agents/` — the one
directory that never loads. The check was rewarding the placement that breaks and
penalising the one that works, which is exactly the placement your commit
`5cc2267` chose.

If you ran `constitutional-check.sh` and saw your bridged agents flagged as
legacy, that warning was wrong and you were right to ignore it. Fixed upstream:
the check now flags agents under `plugins/*/agents/` as unreachable instead.

---

## Questions worth sending back

1. **The domain briefs** — what does a correct `frontend.md` look like for RN +
   Expo? That is the single most useful thing you could send us.
2. **Did anything else silently not work?** The agent-loading defect went
   unnoticed because nothing asserted the agents were reachable. If something
   feels absent rather than broken, that is the shape of the next one.
3. **Was the uninstall procedure legible?** It is the reversal path and we have
   never watched anyone actually read it.
