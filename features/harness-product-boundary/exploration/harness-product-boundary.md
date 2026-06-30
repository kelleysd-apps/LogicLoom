# Exploration — harness↔product boundary

- Date: 2026-06-29
- Investigators: 5 (read-only swarm-explore)
- Active feature: harness-product-boundary
- Grounding issue: [.docs/reviews/LOGICLOOM_ISSUE_harness-product-boundary.md](../../../.docs/reviews/LOGICLOOM_ISSUE_harness-product-boundary.md) (reviewed + verified accurate vs v6.3.1)

## Topline

**Adopt a first-class product-workspace convention — `web/` (single app) / `apps/<name>/` (monorepo), framework stays at the repo root — and make `init-project.sh` scaffold (not rename-in-place).** The governance floor *already* accommodates this with **zero hook changes** (the freeze/owns model is path-agnostic, and `worktree-port-namespace.sh` already provisions a product web/api/db dev stack). The competing "relocate the framework `package.json`" idea (proposal #2's stronger variant) is **rejected**: it breaks `init-project.sh` and `bump-version.sh` for no benefit Option A doesn't already deliver. Exploration also surfaced **two collisions the original issue missed** — both *silent* data hazards: the root jest `testMatch` glob runs product tests under framework coverage gates, and `.gitignore`'s `specs/*/` rule drops product specs on commit.

## Key findings

- **The filed issue is accurate on all three counts.** The `src/`-at-root convention is (a) *buried* in an unratified policy (`.docs/policies/file-structure-policy.md:4` stamped `Effective Date: TBD`), (b) *self-contradictory* — single-project says `src/` at root (`file-structure-policy.md:224-230`) while web-app says `backend/src/`+`frontend/src/` two levels deep (`file-structure-policy.md:235-246`) with no decision rule, and (c) *absent from every entry doc* — `CLAUDE.md`, `README.md`, `START_HERE.md`, `VISION.md` are all silent (grep returns nothing).
- **The `src/` convention is "doubly-asserted" only in non-entry surfaces.** It appears in the README that `init-project.sh:135` *generates* and in the `owns:` examples at `.logic-loom/templates/plan-template.md:62-94` — but a reader of the shipped entry docs never sees it. So the convention is simultaneously over-asserted (in operational files) and invisible (where onboarding happens).
- **NEW collision #1 — jest `testMatch` glob (silent).** Root `package.json:40` sets `testMatch: ["**/tests/**/*.test.js"]`, which spans the whole repo. Product tests under `src/tests/`, `web/tests/`, or `apps/*/tests/` are **silently swept into `npm test`**, mixed with framework contract/integration suites, and forced under the global 80% coverage threshold (`package.json:49-57`). No error — just wrong behavior. This collision hits `src/`-at-root *and* a naive `web/` equally, so it must be fixed regardless of the chosen convention.
- **NEW collision #2 — `.gitignore specs/*/` (silent data loss).** `.gitignore:84-86` ignores `specs/*/` (keeping only `README.md`/`.gitkeep`). A product using the SDD-waterfall pack (`/specification`) writes specs into `specs/###-name/` — which **vanish on commit and never reach a clone**. `features/` is not ignored and is the safe home.
- **The framework-owned root surface is well-defined.** Root `package.json` (jest, devDeps, `collectCoverageFrom → .claude/** + .logic-loom/**`, `directories.test: tests`, `main: index.js` — a nonexistent stub), `tests/` (contract/integration/unit/fixtures + `tests/run_all_tests.sh` with hard-coded paths), and the governance dirs (`.claude/`, `.logic-loom/`, `plugins/loom-*`) are unambiguously framework-owned. A product must not share `package.json` or `tests/`.
- **The governance floor needs ZERO hook changes to support a product workspace.** `freeze-write-scope.sh` resolves `owns:`/`freeze:` as literal globs over realpath-canonicalized, repo-relative paths (`freeze-write-scope.sh:240-320`) — a task can own `web/app/page.tsx` or `apps/api/**` today. `protect-governance-files.sh` protects only the governance surface (`.claude/`, `.logic-loom/`, `plugins/loom-governance/`), never product code (`governance-verdicts.sh:77-88`). `guard-dangerous-commands.sh`, the preflight hook, and `settings.json` are all path-agnostic.
- **`worktree-port-namespace.sh` is latent product-app support — strong evidence product apps were anticipated.** It already computes and exports `PORT_BASE`/`WEB_PORT`/`API_PORT`/`DB_PORT` and writes `.loom-worktree-env` (`worktree-port-namespace.sh:68-92`), provisioning a collision-free **web + API + database** dev stack across parallel worktrees — with no assumption about where product code lives.
- **Distribution feasibility is decisive.** *Option A* (add a product workspace, framework `package.json` stays at root) is **SAFE across all machinery** — `init-project.sh`, the 4 workflows, `template-strip`, `bump-version.sh`, `/update-framework` — **zero changes required**. *Option B* (relocate framework package → `framework.package.json`, product owns root) **breaks** `init-project.sh:49-65` (sed rename silently no-matches → template ships branded `logic-loom`) and `bump-version.sh:48` (hard-coded `package.json` stamp site → exits 1). Reject Option B.
- **Prior-art verdict: subdir-app wins; framework-as-npm-dep fails the floor test.** Subdir-app is floor-preserving, toolchain-isolated, upstream-sync-friendly, low-complexity, and an idiomatic Next.js/Vercel fit. Shipping LogicLoom as an npm dependency **destroys the floor**: Claude Code reads `.claude/settings.json` from the *repo root*, not `node_modules/`, so the hooks never wire; and `/update-framework` is a git-fetch+diff flow, not an npm-semver flow (`framework-upstream.conf`, `update-framework.md`). npm/pnpm workspaces are a conditional runner-up (only if root `package.json` forbids product deps AND `owns:` stays literal-path); submodule/subtree and devcontainer-only separation were both rejected.

## Per-slice summaries

### Slice 1 — Framework-owned root surface inventory + collision map
Produced the authoritative manifest of framework-owned root items and a per-item collision map vs `src/`/`web/`/`apps/`. Hardest collisions: the jest `testMatch` glob (silently runs product tests under framework coverage gates), `tests/` being hard-coded in `run_all_tests.sh` + `directories.test`, and `.gitignore specs/*/` silently dropping product specs. `.claude/`, `.logic-loom/`, `plugins/` do not collide (no subdir lookup from product code).

### Slice 2 — Distribution / cloner / init machinery coupling
Traced every hard-coded root assumption across `init-project.sh`, the 4 GitHub workflows, `template-strip-manifest.txt`, `bump-version.sh`, and `/update-framework`. Breakage matrix verdict: **Option A safe everywhere (zero changes); Option B breaks `init-project.sh` sed-rename and `bump-version.sh` version-stamp.** Recommends scaffold-don't-relocate, framework keeps the root package as its own version/test/dep declaration.

### Slice 3 — Convention & policy surface
Confirmed the issue accurate on all three counts with a full conflict table. The only authoritative statement is an unratified (`Effective Date: TBD`), self-contradictory policy; entry docs are silent; the `src/` convention survives only in the init-generated README and plan-template examples — surfaces a new user doesn't read before they need the answer.

### Slice 4 — Governance/hook & worktree implications
Hook-by-hook audit: every enforcement mechanism is path-agnostic; a product workspace at `web/` or `apps/<name>/` needs **no hook or template change**. Characterized `worktree-port-namespace.sh` as already-built product-dev-stack infrastructure (WEB/API/DB ports), evidence the framework half-anticipated this. Only follow-ups are documentation.

### Slice 5 — Prior art / workspace patterns
Scored five patterns. Subdir-app is the clear winner; npm/pnpm workspaces a risky conditional runner-up; framework-as-npm-dep fails the root-anchored-floor test catastrophically; submodule/subtree and devcontainer-only were rejected for complexity/fragility. Distribution-as-git-template (not npm) is the load-bearing constraint that decides it.

## Open questions

- **Default scaffold shape.** `web/` for single-app vs `apps/<name>/` for monorepo is agreed — but should `init-project.sh` scaffold one by default, prompt the user, or just create an empty product-workspace stub + doc? (Slice 5 leans scaffold `web/`; a generic stub avoids over-fitting to Next.js.)
- **How opinionated should the scaffold be?** Generating a full Next.js `web/package.json` may overreach for non-Next products. A minimal product-workspace stub + a documented convention may be safer than an opinionated framework-specific scaffold.
- **The jest `testMatch` fix is needed regardless of convention.** Options: scope `testMatch`/`roots` to the framework's `tests/` only, or add `testPathIgnorePatterns` for `web/`/`apps/`/`src/`. This is a real latent bug — decide independently of the workspace question.
- **Is `.gitignore specs/*/` intentional or a bug?** If the SDD-waterfall pack is a supported path, product specs silently disappearing is a defect. Reconcile: either un-ignore `specs/`, or document that product specs live in `features/` and `specs/` is framework-scratch only.
- **Ratify or rewrite `file-structure-policy.md`.** It's stamped `Effective Date: TBD` and self-contradicts (single-project `src/` vs web-app `backend/src/`+`frontend/src/`). This work should either ratify a corrected version or supersede it.
- **Residual tension between investigators.** Slice 1's "safest placement" still listed `src/`-at-root as acceptable; Slices 2/4/5 converge on a dedicated workspace *out of* root with `tests/` explicitly framework-owned. The workspace-subdir camp is stronger because `src/`-at-root still trips the jest glob collision — preserved here rather than collapsed.

## Files referenced

- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/package.json
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/tests/run_all_tests.sh
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.gitignore
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/init-project.sh
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.docs/policies/file-structure-policy.md
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.logic-loom/templates/plan-template.md
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.claude/hooks/freeze-write-scope.sh
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.claude/hooks/worktree-port-namespace.sh
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.claude/hooks/guard-dangerous-commands.sh
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.claude/settings.json
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/plugins/loom-governance/hooks/scripts/protect-governance-files.sh
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.logic-loom/lib/governance-verdicts.sh
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.logic-loom/scripts/bash/bump-version.sh
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.logic-loom/scripts/bash/template-strip-manifest.txt
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.github/workflows/promote-to-main.yml
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.github/workflows/release-tag.yml
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.github/workflows/plugin-tests.yml
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.logic-loom/config/framework-upstream.conf
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/plugins/loom-maintenance/commands/update-framework.md
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.docs/architecture/governance-threat-model.md
- /Users/bkelley/kelleysd-apps/sdd-agentic-framework/.logic-loom/memory/constitution.md
