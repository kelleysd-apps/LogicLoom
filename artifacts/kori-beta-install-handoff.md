# LogicLoom in kori-beta — what to expect, and what to adjust

**For:** the kori-beta team
**From:** LogicLoom maintainers
**Date:** 2026-08-31
**Your install:** `logicloom@6.6.1`, Node 22.23.2, targets `harness + gitignore + rules + hooks`

---

## Short version

The install itself was clean — 393 files written, 0 skipped, 0 failed, and none
of your own files touched. Everything the receipt claims is on disk. The
governance hooks work.

Six things are wrong or missing, all found by auditing **your** install. Four are
already fixed upstream and reach you on your next upgrade. Two need a decision
from you, and one of those matters specifically because you are a React Native
project.

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

**Status: open upstream (`LOOM-0053`). Affects you today.**

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

**What you can do now:** the briefs are plain markdown at
`plugins/loom-governance/domain-briefs/`. Edit them to describe your actual
stack. Nothing validates their content, so there is no schema to satisfy — just
make them true. We would genuinely like to see what you write; it will inform
the adaptation point we build.

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

**Status: in progress upstream (`LOOM-0049`).**

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

Coming: `artifacts/` ships properly, the freshness gate ships, and the dashboard
renders your open GitHub issues live — fetched when you open the file, so the
tracked artifact stays deterministic.

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

**Status: open upstream (`LOOM-0054`, `LOOM-0056`).**

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

**Nothing reads these keys** — only prose and the version bumper. It is false
metadata, not false behaviour. Do not build anything on those numbers. Tracked
upstream as `LOOM-0055`.

---

## Summary table

| # | Item | Status | Your action |
|---|---|---|---|
| 1 | Plugin agents did not load | **Fixed upstream** | Delete 5 stale `plugins/*/agents/` files after upgrade |
| 2 | Domain briefs assume React/Next | **Open** | Edit the briefs for RN/Expo/Deno — tell us what you write |
| 3 | `.brain/` missing | **Fixed upstream** | None |
| 4 | No dashboard | **In progress** | Build one now with the two commands above |
| 5 | No CI templates | **Open** | None; templates are coming |
| 6 | Wrong bash-4 claim, dead doc links | **Open** | Ignore the bash-4 line; verify `.docs` paths before relying on them |
| — | `architecture.conf` counts false | **Open** | Do not trust those numbers |

---

## Questions worth sending back

1. **The domain briefs** — what does a correct `frontend.md` look like for RN +
   Expo? That is the single most useful thing you could send us.
2. **Did anything else silently not work?** The agent-loading defect went
   unnoticed because nothing asserted the agents were reachable. If something
   feels absent rather than broken, that is the shape of the next one.
3. **Was the uninstall procedure legible?** It is the reversal path and we have
   never watched anyone actually read it.
