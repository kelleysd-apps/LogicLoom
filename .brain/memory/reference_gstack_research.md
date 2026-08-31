---
name: Garry Tan's gstack — cross-comparison findings
description: Reference distillation of research into Garry Tan's open-sourced "gstack" (March 12 2026, MIT) and which of its patterns are genuinely additive to the Loom migration vs which to skip. Loom and gstack converge on ~70% of architecture; only 4 patterns are worth folding in (office-hours, plan-review, retro, freeze/guard). Use this when amending the Loom migration plan or if user asks about gstack again.
type: reference
originSessionId: fa3efdd7-669a-41f1-a450-2f778bb4afde
---
# gstack vs Loom — Cross-Comparison Reference

## What gstack is

- **garrytan/gstack** — Claude Code skill pack, open-sourced 2026-03-12, MIT
- 23 skills + 8 power tools as markdown `SKILL.md` files
- Multi-CLI compatible (Claude Code, Codex, OpenCode, Cursor, Factory Droid, Slate, Kiro, Hermes)
- Canonical workflow: **Think → Plan → Build → Review → Test → Ship → Reflect**
- Core thesis: "structured prompts, not custom tooling, are the right abstraction layer"
- HN/TechCrunch critique consensus: pattern-level value real; LoC theatre + context bloat + embedded ads on the bundle itself. **Adopt patterns, not the bundle.**

## Convergence with Loom (~70%)

Already covered with no change needed:
- Markdown SKILL.md headless plugins (architectural philosophy match)
- `/review` (staff-engineer code review) → Loom's `/review-team` is stronger
- `/qa` (Playwright) → already in Loom plan
- `/cso` (security audit) → covered by /review-team security reviewer
- `/ship` → covered by `/git-push`
- `/investigate` → covered by `/swarm explore` mode
- `/learn` + `gbrain` → covered by sdd-memory plugin
- `gstack-model-benchmark` → covered by `/research` tribunal
- `gstack-analytics` → covered by RL dashboard
- Self-update via `/gstack-upgrade` → covered by `/update-framework`

## Four genuinely additive patterns (worth integrating)

| Pattern | Description | Effort | Slot |
|---|---|---|---|
| **`/office-hours` style 6-question gate** | Force the model to populate 6 forcing-questions from vision.md before writing the broad PRD | Trivial | Inside `/create-prd` (Stage 7) |
| **`/plan-review` orchestrator** | Parallel CEO + Eng (+ optional Design) reviewers run on `plan.md` before `/swarm implement` is allowed; mirror of `/review-team` but for plans | Medium | NEW stage between plan-mode and /swarm |
| **`/retro` weekly retrospective** | Reads `features/<name>/sprints/`, git log, RL metrics; produces sprint retro markdown that feeds back into sdd-memory | Low | NEW stage post-`/git-push` |
| **`/freeze` / `/guard` directory locks** | Hook-level write-scope enforcement; readers from plan-as-DAG file-ownership nodes; `/swarm implement` workers cannot write outside their declared scope | Trivial-Low | Stage 11 (hooks) — synergistic with plan-as-DAG |

## Patterns to explicitly skip

- The 23-skill bundle wholesale (context bloat, overlapping prompts, embedded ads)
- `/land-and-deploy`, `/canary`, `/document-release` — out of Loom's framework remit
- Browser automation primitives (`$B`, `/setup-browser-cookies`, `/pair-agent`) — Playwright-MCP covers 80%
- `gbrain` MCP — sdd-memory + deferred Letta tier is a more principled path
- `/codex` cross-CLI as a hard dep — keep optional; undermines "Opus 4.6/4.7 is the primary brain" thesis
- "Cognitive gearing" / role-played personas as architecture — Loom already learned this lesson (commit 7b6bb69, 14 agents → skills)
- LoC-as-success metric

## Stress-test outcome on "does Opus 4.6/4.7 actually need this scaffolding?"

- **Plan interrogation (office-hours)** → YES, mild scaffolding helps; model otherwise rushes to code
- **Plan review** → YES, external review catches scope drift before /swarm implement consumes tokens
- **Role-played personas during generation** → NO, modern Opus doesn't benefit from "you are the QA engineer" framing
- **File-scope locks (freeze)** → YES, especially in parallel waves where prompts alone are brittle

## Open questions surfaced by research (not yet decided)

1. Plan-review depth: single skill with internal reviewers vs parallel-Task architecture
2. Codex CLI peer-review hard dep — yes/no
3. office-hours placement — inside /create-prd vs standalone /clarify
4. /freeze enforcement — hook-level (constitutional) vs prompt-level (brittle)
5. Whether to adopt gstack's "Think → Plan → Build → Review → Test → Ship → Reflect" naming

## Key sources

- github.com/garrytan/gstack
- gstacks.org
- ycombinator.com/library/OW-inside-garry-tan-s-ai-coding-setup
- TechCrunch (2026-03-17): "Why Garry Tan's Claude Code Setup Has Gotten Love and Hate"
- Augment Code (2026-04-07): "Garry Tan open-sources gstack — what developers should know"
- HN thread id=47418576
- MindStudio + SitePoint + AI Builder Club + Epsilla + DevStyler + Awesome Agents (community analyses)
