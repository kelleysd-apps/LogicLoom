# LogicLoom issue draft — Clarify the harness ↔ product boundary; support products with their own toolchain

> **Status:** draft for hand-off to the LogicLoom framework team.
> **Filed from:** the `msdh` project (a LogicLoom clone being turned into a Next.js product).
> **Type:** architecture / documentation / DX.
> **Severity:** medium — does not block work, but forces every consumer to invent their own answer to "where does my product code go?"

## Summary

LogicLoom conflates **the harness** (the governance framework) and **the product** (the app a team builds with it) at a single repo root with a single dependency graph. For simple products this is fine. For a product with its own toolchain — e.g. a **Next.js / Vercel** app that needs its own `package.json`, build scripts, and `node_modules` — there is **no documented, clean place for product code**, and the one convention that exists collides with the framework's own files.

## Observed (in framework `v6.3.1`, constitution `v3.2.0`)

1. **One root `package.json`, owned by the framework.** It is `logic-loom` with jest/devDeps and scripts targeting `.claude/**` and `.logic-loom/**` (i.e. it tests the *framework*).
2. **`init-project.sh` repurposes that same file in place.** It `cp package.json package.json.backup` then `sed`-renames `name` / `description` / `author` to the product's, and archives `README.md → FRAMEWORK_README.md`. It does **not** scaffold or relocate any product app — so after init, the "product" package is still the framework's jest setup with a renamed `name`.
3. **The only product-code convention is buried and conflicting.** `.docs/policies/file-structure-policy.md` (header: `Effective Date: TBD`) places product code in **`src/` at the repo root**, sharing the framework's own root `package.json` and `tests/`. There is no mention of products that carry their own framework/toolchain.
4. **The main entry docs are silent.** `README.md`, `CLAUDE.md`, and `START_HERE.md` describe `.logic-loom/`, `.claude/`, `plugins/`, `features/`, `specs/`, `.docs/` — but never say where a product's application source lives, or whether the root `package.json` / `tests/` belong to the framework or the product.

## Impact

- **Ambiguous identity:** after `init-project.sh`, it is unclear whether the repo "is" the framework or the product; the root package answers "both," which is true of neither.
- **Toolchain collision:** a Next.js (or any non-trivial) app cannot cleanly share one root `package.json` with the framework's jest/devDeps, nor live under `src/` without its own package. Consumers are forced to improvise.
- **No separation guarantee:** nothing documents that product dependencies must not be merged into the framework package, so drift toward an unmaintainable monolith is the path of least resistance.

## What this project did (a workaround, not a fix)

The `msdh` build keeps the **framework pristine at the repo root** (did **not** run `init-project.sh`'s rename) and isolates the **product in `web/`** with its own `package.json` / `node_modules` / build. Governance artifacts still use the documented `features/<name>/` convention. This keeps the boundary crisp but **diverges from the (under-documented) `src/`-at-root convention** — which is the core of this issue.

## Proposals (for the team's consideration)

1. **Document a first-class "product workspace" convention** distinct from the framework root — e.g. `web/` for a single app or `apps/<name>/` for several — each with its own `package.json`. State explicitly that the root `package.json` / `tests/` are **framework-owned**.
2. **Make `init-project.sh` scaffold or relocate, not rename-in-place.** Either generate a product workspace, or move the framework package aside (`framework.package.json`) so the product's package can own the root unambiguously.
3. **Surface the harness-vs-product distinction in the entry docs** (`README.md`, `CLAUDE.md`, `START_HERE.md`), not only in a `TBD` policy file.
4. **Clarify ownership of `tests/`.** Today it holds framework contract/integration tests; a product needs its own test root. Document the split (e.g. framework tests under `.logic-loom/tests/` or similar).

## Acceptance criteria

- A new consumer can read the entry docs and know, without guessing, exactly where their product's code and dependencies belong relative to the framework.
- A product with its own toolchain (Next.js/Vercel) can be initialized without its `package.json` colliding with the framework's.
- The root `package.json` and `tests/` have a single, documented owner.
