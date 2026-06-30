# Cross-reference — exploration findings vs. the Cosmos production codebase

- Date: 2026-06-29
- Investigators: 4 (read-only, against `/Users/bkelley/kelleysd-apps/cosmos-2`)
- Companion to: [harness-product-boundary.md](harness-product-boundary.md)
- Subject: **cosmos** — a massive polyglot product (Tauri + Vite + React + Python + Deno + Cloudflare Workers + Supabase) built on this framework, used as a natural experiment for the harness↔product boundary.

## Topline

Cosmos is **strong, real-world confirmation of the two material collisions** the exploration predicted — and it confirms them *the hard way*, by patching them in production. It hit the `.gitignore specs/*/` collision and disabled the rule to save **~801 tracked spec files**; it hit the test-runner/root-`package.json` collision and **could not keep the framework's jest at the root** — it replaced the entire root package with product-owned `vitest`. Cosmos also independently validates the exploration's "**don't rename framework-named artifacts**" caution: its framework folder name is referenced **~493 times across ~130 files / 55 plugins**, making any rename a mass-migration.

**One correction to the raw agent output:** the claim that "the governance floor fails under product pressure" is **not supported** — it is a *vintage artifact*. Cosmos forked from a **pre-LogicLoom** version (constitution v3.0.0, framework folder `.specify`, sync-ref frozen at an old commit) **before the hardened hook floor existed**, and never synced. Cosmos is therefore *silent* on whether the current floor survives a product workspace — not evidence against it. What it *does* validly surface is narrower and useful: governance protection is keyed to **hardcoded directory names**, so a fork on a different framework-folder name has zero overlap with current protections.

## Vintage caveat (read this before trusting any "cosmos lacks X" claim)

Cosmos is an **early hard-fork**, not a current clone. Established by two independent investigators:

- Constitution frozen at **v3.0.0** (2026-01-13, customized 2026-02-17); current framework is **v3.2.0**. Cosmos never pulled v3.1.0 or v3.2.0. (`.specify/memory/constitution.md`)
- Framework core lives in **`.specify/`** (the original spec-kit name) — it was **never renamed** to `.logic-loom/`. The `.cosmos/` dir is *not* the framework; it is a single product file, `.cosmos/agent-protocol.toml`. (Cosmos-A, Cosmos-C agree at file level.)
- `.sdd-sync-ref` = `c6092b0…`, an old ancestor; **no upstream remote configured**; `/update-framework` never operationally run → **stranded**, two minor versions behind. (Cosmos-C)

**Consequence:** Cosmos predates the hook-enforced floor (`git-safety-gate`, `subagent-git-guard`, `protect-governance-files`, `freeze-write-scope`, `worktree-port-namespace` — all added in the v6.x line, mid-2026). Its absence of those hooks reflects *when it forked*, not *what product pressure does to the floor*. Treat "cosmos has only 1 wired hook" as **out-of-scope for the floor-survival question**.

## Validation scorecard

| Exploration finding | Cosmos verdict | Evidence | Confidence |
|---|---|---|---|
| **Collision #2** — `.gitignore specs/*/` silently drops product specs | ✅ **VALIDATED (production fix)** | Cosmos `.gitignore:126-129` has `specs/*/` **commented out** with note *"Feature specs (tracked for worktree access)"*; ~801 spec files tracked across `038-*`, `039-*`, `041-*`, `_archive/` | **Very high** — undeniable, hard evidence |
| **Collision #1** — root test-runner glob can't host framework + product tests together | ✅ **VALIDATED (the sharper way)** | Cosmos could not keep framework jest at root; root `package.json:14` is product-owned `"test": "vitest"`, scoped `include: ["src/**/*.{test,spec}.{ts,tsx}"]` (`vitest.config.ts:11`). Framework jest config fully evicted | **High** — proves the root package can't serve both |
| **"Product needs a workspace separate from the framework root"** (core thesis) | ✅ **VALIDATED, with a twist** | Cosmos kept product at `src/`-at-root but had to make the **whole root package product-owned**, exiling framework contract tests to a bash-only runner (`tests/run_all_tests.sh`), detached from `npm test`/CI | **High** |
| **Reject relocating/renaming framework-named artifacts** (proposal #2 strong variant) | ✅ **STRONGLY VALIDATED** | `.specify` framework-folder name appears **~493 times** across ~130 shell files + 55 plugins + 420 `.claude/` refs; a rename is a mass-migration | **Very high** |
| **Keep the boundary clean so `/update-framework` stays operational** | ✅ **VALIDATED (cautionary)** | Cosmos hard-forked, never synced, stranded 2 minor versions behind; divergence is now manual-reconcile-only | **High** |
| **Slice-4: governance floor is path-agnostic / survives a product workspace** | ⚠️ **NOT TESTED (vintage)** — *not* challenged | Cosmos predates the floor; never wires freeze/owns, never uses `.loom-worktree-env`. Silent on the question, not counter-evidence | n/a |
| **`worktree-port-namespace` = exercised product-app support** | ⚠️ **NOT EXERCISED here** | Cosmos hardcodes ports (`vite.config.ts:33` → 1420; `supabase/config.toml` → 54321-54324); no `.loom-worktree-env`. But cosmos predates the hook | Low signal (vintage) |

## New findings cosmos surfaced (beyond the original exploration)

1. **"Product owns the root" has a concrete, recurring cost: framework tests fall out of `npm test`.** When cosmos took the root `package.json` for vitter/vitest, the framework's contract/integration suite (`tests/`) became reachable **only** via `bash tests/run_all_tests.sh` — not `npm test`, not default CI. A clone-and-`npm test` validates *product* tests but silently **skips framework-contract validation**. This is a direct argument **for the workspace-subdir model (Option A)**: keep the framework owning root `package.json` + `npm test`, give the product its own subdir/runner — the inverse of what cosmos was forced into.

2. **Governance protection is keyed to hardcoded directory literals.** `protect-governance-files` / `governance-verdicts.sh` protect the literal paths `.claude/`, `.logic-loom/`, `plugins/loom-governance/`. A downstream on a *different* framework-folder name (cosmos's `.specify/`) gets **zero** protection from the current rules — not because protection "eroded," but because the names don't match. **Hardening idea:** derive the protected-path set from a single canonical variable (e.g. read the framework-folder name from one config) so a rebrand can't silently unprotect the core. This pairs naturally with the boundary work.

3. **The divergence footprint of a real product is large and entirely manual.** Cosmos carries ~11 root-level config divergences to coexist (vitest, split tsconfig, `pyproject.toml`, `deno.lock`, `deny.toml`, Cargo, Supabase, expanded `.mcp.json`, …). None merge cleanly with framework updates. A documented product-workspace convention would *contain* most of these inside the workspace subdir, shrinking the reconcile surface against upstream.

4. **`init-project.sh` is already deprecated in cosmos** (points to `/initialize-project`). Real-world signal that the rename-in-place init flow didn't serve a real product — consistent with the exploration's "scaffold, don't rename" recommendation.

## Does cosmos change the recommendation? — No; it strengthens Option A

The exploration recommended: **product workspace (`web/` / `apps/<name>/`), framework stays at root, init scaffolds (not relocates).** Cosmos is the counterfactual — it did the *opposite* (product seized the root) and paid for it: framework tests exiled from `npm test`, a permanent `.gitignore` divergence, ~11 manual config reconciliation points, and a stranded fork. Every cost cosmos absorbed is a cost the workspace-subdir model **avoids**:

- Framework keeps root `package.json` + `npm test` + contract coverage → no exile.
- Product `package.json`/`node_modules`/test runner live in the workspace subdir → no root collision, no jest↔vitest fight.
- `.gitignore` ships correct for both (the specs fix below) → no perpetual divergence.

The two collisions, though, are **urgent regardless of which convention is adopted**, because they bite any product on the current root:

- **Fix specs gitignore now.** Cosmos lost (would have lost) ~801 files to it. Either un-ignore `specs/`, or document that product specs live under `features/`/the workspace and `specs/` is framework-scratch only. This is a defect, not a preference.
- **Fix the test glob now.** Scope the framework's jest `testMatch`/`roots` to the framework's own `tests/`, or add `testPathIgnorePatterns` for product/workspace paths — so a product that stays on jest isn't swept under framework coverage gates.

## Implications for the folder/brand rename request (deferred this session)

Cosmos is the cautionary tale for renaming framework-named artifacts: the framework-folder name (`.specify`) is welded into ~493 call sites. **Two distinct rename axes — keep them separate:**

- **The OS project-folder name** (`sdd-agentic-framework/` → `LogicLoom/`): cheap and safe on disk (this repo has a single git worktree; no worktree pointers break). The only real hazard is doing it *out from under a live session* (cwd + path-scoped memory key). Held this session by choice; do it from a terminal outside the folder, then reopen at the new path.
- **The framework-folder / package identity** (`.logic-loom/`, package `name: logic-loom`): **do NOT churn this.** Cosmos shows the cost is a mass-migration and, worse, governance protection silently stops matching. Keep the canonical framework identity stable; rebrand the *product*, never the governance core.

## Open questions (updated by cosmos evidence)

- **Make the protected-path set rename-safe.** Should `protect-governance-files`/`governance-verdicts.sh` derive the framework-folder name from one canonical config var instead of hardcoded `.logic-loom/` literals, so a downstream rebrand can't silently unprotect the core? (New, cosmos-driven.)
- **Framework-test reachability under a product workspace.** If the product owns its own workspace runner, confirm framework `tests/` stays under root `npm test` + CI — i.e., explicitly *don't* repeat cosmos's exile. Document the two test roots.
- **Specs home, settled.** Un-ignore `specs/`, or canonicalize product specs under `features/`/workspace and mark `specs/` framework-scratch? Cosmos's 801-file save makes this a release-blocker-class decision.
- **Migration note for early forks.** Cosmos is stranded 2 minor versions back on `.specify`. Out of scope for this feature, but worth a one-line acknowledgement that pre-LogicLoom forks have no clean `/update-framework` path.

## Files referenced (cosmos-2)

- /Users/bkelley/kelleysd-apps/cosmos-2/package.json
- /Users/bkelley/kelleysd-apps/cosmos-2/vitest.config.ts
- /Users/bkelley/kelleysd-apps/cosmos-2/vite.config.ts
- /Users/bkelley/kelleysd-apps/cosmos-2/.gitignore
- /Users/bkelley/kelleysd-apps/cosmos-2/specs/
- /Users/bkelley/kelleysd-apps/cosmos-2/tests/run_all_tests.sh
- /Users/bkelley/kelleysd-apps/cosmos-2/supabase/config.toml
- /Users/bkelley/kelleysd-apps/cosmos-2/.specify/memory/constitution.md
- /Users/bkelley/kelleysd-apps/cosmos-2/.sdd-sync-ref
- /Users/bkelley/kelleysd-apps/cosmos-2/.claude/settings.json
- /Users/bkelley/kelleysd-apps/cosmos-2/.cosmos/agent-protocol.toml
- /Users/bkelley/kelleysd-apps/cosmos-2/init-project.sh
