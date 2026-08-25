# Changelog

All notable changes to LogicLoom (formerly the SDD Agent Framework) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [6.5.0] - 2026-08-25

Covers the `dev-main` line since v6.4.1 (2026-08-13 → 2026-08-24). Four threads:
**user-tunable approval gating** (the harness's interruption budget becomes the
user's, with a floor that refuses to be silenced), the **environment-promotion
methodology** (declaration, validator, scaffolding, and a three-command lifecycle
that gates and confirms but deploys nothing), a **Level-0 backlog SSOT** for
cross-cutting work, and a long run of **governance-floor hardening and
doc-versus-reality corrections** — several of which found that a passing check
was proving nothing.

### Added — user-tunable approval gating

- **`.logic-loom/config/gate-policy.conf`** — live, commented per operation.
  Governance previously answered one question ("does this change the repo?"), so
  `git commit -m "wip"` and `git push --force` produced the same prompt. The
  second question — "is that change worth interrupting you?" — is now the user's,
  answered per operation with `ask` or `silent`. Default posture is `balanced`;
  `/initialize-project` offers `strict` / `balanced` / `minimal`, all three
  rendered from **one** definition shared by `init-project.sh`, the command doc,
  and the contract test.
- **A floor that is not tunable** — push, history rewriting, repo admin, secret
  write and auth refuse a `silent` setting with a typed reason rather than
  ignoring it. Three more are not config keys at all: governance-file writes, the
  dangerous-command guard, and subagent git/gh. Membership test: *a wrong answer
  leaves the repository, or a credential, somewhere a revert cannot reach.*
  `gate-policy.conf` is itself protected, so a subagent cannot rewrite the policy
  and then act under it. Floor verified across 32 combinations (five floor
  operations × four configs × eight permission modes); zero breaches. There is no
  wildcard and no "silence everything" line, by design.
- **Permission-mode awareness**, with its two claims graded differently.
  `permission_mode` **is** present in real hook payloads — verified in this
  repo's own audit log. That the host auto-approves an `ask` under
  `bypassPermissions` was derived by reading a minified binary: plausible,
  **unobserved**, and the sole justification for weakening a guard. So the
  mechanism ships and the weakening does not — `mode.bypassPermissions` defaults
  to **enforce**; relaxing it is one documented line. `dontAsk` and `auto` stay
  enforcing deliberately.
- **`.logic-loom/config/project.conf`** — project identity (`project_slug`,
  `project_name`, `id_prefix`; optional `repo`), read by
  `validate-project-identity.sh`. Kept out of `architecture.conf` so an upstream
  bump never conflicts with the line a fork must keep. Ships **unstamped**
  (`__UNSET__`) so no cloner inherits our slug. Nothing enforces it; the
  validator says so and exits 0.

### Added — environment promotion (declaration and lifecycle; no deploy engine)

- **`.docs/policies/environment-promotion-policy.md`** — the methodology, written
  down. Every claim carries its evidence grade (**VERIFIED / RECOMMENDED /
  UNSOLVED**). States plainly what a green rehearsal does *not* prove: no
  automated end-to-end test drives the artifact against the live environment, so
  "it deployed" and "it was proven to work" are different claims. Two items are
  recorded as **UNSOLVED and must not be copied as patterns** — schema-drift
  detection between deployed environments, and cross-environment secret-value
  parity.
- **`.logic-loom/config/environments.conf` + `validate-environments.sh`** — a
  declaration of environments, the branch each tracks, whether promotion needs
  approval, the promotion order, and the **`deploy` seam the product owns**. The
  validator reads and checks (cycles, missing predecessors, duplicate names,
  unknown keys); it never invokes the seam, never runs git, never writes, and
  exits 0 when the file is absent. Ships **fully commented out** — an active
  default would assert a branch topology a cloner does not have — with a contract
  assertion that no uncommented declaration can ship.
- **`/scaffold-environments`** (`loom-maintenance`) — adopts the methodology into
  a new *or existing* project: detects what the repo already has by reading git
  refs off the filesystem (it invokes no git), proposes a delta, and writes only
  what the user names.
- **`/promote-dev` → `/promote-staging` → `/promote-prod`** (`loom-maintenance`,
  `promotion-lifecycle` skill) — the escalating-confirm ladder made operable.
  Dev and staging prompt and are skippable; prod demands a **typed exact phrase**
  with no flag, environment variable, or non-interactive path past it (`--yes` is
  read and reported as ignored). Confirmation strength resolves from the target
  environment's declared `confirm` first, then the command default — so a project
  can raise dev or lower prod, with a loud note when it is weaker than the ladder
  recommends. The boundary holds and is asserted: no cloud or CI call, no deploy
  command, no migration, seed, teardown, secret or rollback, and **no git**.
  Distinct from the maintainer-only `/promote`, which is untouched and still
  stripped by exact path.
- **The rehearsal contract separates verified from trusted**, because the harness
  runs no git and has no CI API. *Verified*: the attestation exists, reports
  success, parses, is inside the staleness bound, and names a matching or covered
  commit. *Trusted*: that a rehearsal actually ran, that it passed, and that the
  commit is genuinely an ancestor. A rebuilt staging branch makes the rehearsed
  commit the merge's **second** parent, so a seam that writes the merge head
  writes a plausible wrong answer this gate will accept — stated in the refusal
  text rather than left implicit. An unparseable date refuses rather than
  assuming recent.

### Added — Level-0 backlog SSOT

- **`.logic-loom/memory/todos.md` + `.logic-loom/memory/backlog.md`** — the todo
  policy declared a three-level SSOT whose top level was empty and which had no
  slot for cross-cutting harness maintenance, so the real worklist accumulated in
  `.docs/reports/` and `VISION.md` Open Threads: the two least parseable sources,
  and respectively stripped and stubbed at release. Now two files, one grammar
  (normative in `backlog.md`), one parser, one linter, one id space. Todos answer
  "what am I doing"; backlog answers "what should I bring up later". Items carry
  a visible minted id (`LOOM-0042`); status lives in a `status:` tag, not the
  checkbox. The next id is **derived, never stored** (`lint-backlog.sh
  --next-id`) — a stored counter goes silently wrong the moment an item lands in
  the other file.
- **`build-backlog-index.sh`** → `.logic-loom/backlog-index.json`, deliberately
  **untracked and gitignored** (a machine intermediate no human opens has no
  committed copy that could disagree with its sources). Duplicate ids and
  unparseable items are **fatal**: exit 3, nothing written, prior index untouched
  — a consumer must never be unable to distinguish "no such item" from "the
  collector dropped it". `blocked_on` accepts `external:<reason>` so an item can
  say *why* it is stuck, not merely that it is.
- **`artifacts/backlog-dashboard.html`** — a self-contained offline snapshot
  (a `file://` page has an opaque origin and cannot fetch a sibling JSON, so the
  page says on its face that it is a snapshot). **Tracked** and stripped at
  promote, paid for by `check-generated-freshness.sh`, which regenerates and
  fails if the committed copy differs — wired into CI, naming the exact
  remediation command. Timestamps are normalised on both sides so it cannot
  false-fail; a check that always fails gets disabled, which is worse than no
  check.

### Added — governance floor

- **Subagent read-only git allowlist** — the guarantee changes from *subagents
  never touch git* to *subagents never **mutate** git*. Built allowlist-first
  rather than as a mutation classifier: a classifier's failure mode is a silent
  subagent mutation, an allowlist's is a loud false deny. `gh` stays denied to
  subagents wholesale, including reads.
- **`gh` mutations and worktree writes gated** for the main agent (`gh pr
  create|merge`, `gh workflow run`, `gh release`/`repo`/`secret`/`auth` writes,
  `git worktree add|remove|…`), plus two laundering vectors: `gh api` on any
  non-GET method, and `gh api -f/-F` which defaults to POST inside `gh` itself.
- **Forkable-but-unremovable protected-path set** — a fork that renames
  `.logic-loom/` got working git and freeze verdicts but a *silently* broken
  governance-file guard. Config can now only **add**: the built-in floor runs
  first and never reads config, the grammar has no negation or reset key, and
  half the floor is derived from the library's own file location so a renamed
  fork protects itself with zero configuration. 93-row table including eight
  distinct removal attempts; the floor held in all of them.
- **`check-gh-telemetry.sh`** — gh telemetry is opt-out by default and LogicLoom
  uses `gh` heavily, so setup **informs and stops there**. No offer, because an
  offer still ends with the harness writing outside the repo. The check invokes
  no `gh` subcommand at all (`gh config get` can *materialize* a config file),
  parses the config directly, and always exits 0.
- **CI: PRs into `main` are rejected from anything but a release branch**, and
  new prevention suites close the two classes behind the v6.4.0 leak — every
  tracked generated artifact must be declared (strip manifest or an explicit
  allow-to-ship list with a reason), and every history-scrub rule must match
  something. Both were proven to fail against a planted defect before being
  trusted; the second found **10 permanently dead rules**, deleted rather than
  excluded.
- **`.docs/policies/shell-idiom-policy.md`** — seven idioms, each traced to a real
  failure in this repo rather than to an abstraction, and
  **`plugins/MANIFEST-SCHEMA.md`** — the `.claude-plugin/plugin.json` schema,
  published where a plugin author already is.

### Fixed

- **The test suite failed assertions *because* they passed.** 204 sites across 22
  files asserted via `producer | grep -q` under `pipefail`: a matching `grep -q`
  exits immediately, the producer takes `SIGPIPE`, and `pipefail` propagates it.
  Measured, not estimated — 40 runs of one suite gave 22 pass / 18 fail. Six
  sites were worse than a flake (`| head -N` under `set -e` aborts the *whole*
  suite), and two of them sat inside assert helpers, so every assertion in those
  suites rode the race. Fixed with `grep -q PAT <<< "$VAR"`: a here-string is a
  temp file, so the race is structurally impossible rather than merely unlikely.
  Assertion counts verified identical against a pre-fix baseline, so nothing was
  silently dropped. Honest limit: this does not improve diagnosability.
- **Plugin `hooks.json` files never loaded — and the recorded reason was wrong.**
  Claude Code loads plugin hooks from *installed* plugins in `~/.claude/plugins/`;
  LogicLoom's in-repo tree qualifies nowhere, so the shape mismatch was never the
  blocker. Confirmed by observation (~98 subagent completions, zero growth in
  `subagent-activity.log`, whose one line dates from 2026-06-14) with a positive
  control proving the script itself works. **Deleted rather than repaired** —
  nothing consumed the log. The `loom-governance` *scripts* are untouched and
  still root-wired; that is the actual floor. Five tests that asserted the dead
  wiring exists now assert it is gone and that each guard is wired from
  `settings.json`.
- **The sandbox claim was backwards.** Host Bash sandboxing is **opt-in and off
  by default**, keyed on `sandbox.enabled`, which appears in neither settings
  file — verified by probe, not by reading docs. The threat model's residual #4
  was replaced with what the host provides, what it is not, and the note that
  `autoAllowBashIfSandboxed` defaults true, so enabling the sandbox and enabling
  auto-approval are the same decision unless explicitly set false. The shipped
  posture is **unsandboxed**.
- **`constitutional-check.sh` claimed more than it checked, six ways** — a
  success line naming a principle that could never fail; five `INFO` branches
  incrementing `PASS_COUNT` for an *absence*; Principle VI printing **nothing**
  when no git operations were found, so the only blocking check vanished from the
  summary; five principles scanning `src/` and `libs/`, which the harness↔product
  boundary says cannot exist; and Principle XVI searching at the wrong depth, so
  it reported "no plugin architecture" in a repo with eight manifests. Verdict
  goes from *12 passed / 5 warnings, arithmetic unverifiable* to *9 passed / 0
  failed / 2 warned / 5 skipped*, summing to 16 under a self-check. A stale
  duplicate copy under `plugins/loom-governance/scripts/` — frozen at
  constitution v1.6.0 and **shipping to every cloner** — was deleted.
- **Git checkpoints never worked, concealed by a dead assertion.**
  `local x=$(cmd)` resets `$?` to 0, so the test asserted `local`'s status;
  meanwhile `create_git_checkpoint` wrote pretty-printed JSON that
  `list_git_checkpoints` read line-by-line into `jq`. Records are now compact
  JSONL with `jq --arg` escaping, which also closes a latent corruption on any
  quote in an operation string.
- **Governance matching anchored at command position.** `grep
  --exclude-dir=.git` and `echo "check git status later"` were denied to
  subagents; `git stash list` and `git tag -l` prompted for approval. Two false
  *allows* closed as a side effect: bare `git branch newfeature`, and `rm
  .claude/hooks/x.sh` at the **start** of a line, which bypassed governance-file
  protection entirely.
- **`/promote` release path** — GitHub suppresses `pull_request` events for PRs
  opened with the built-in `GITHUB_TOKEN`, so when `promote-to-main.yml`
  *succeeded* at opening the release PR, neither `leak-guard` nor `plugin-tests`
  ran on it. The gap appeared only on the success path, which is why it survived
  two releases. The workflow no longer opens PRs at all and can no longer be made
  to; `/promote` now asserts that checks actually **reported** (counting
  `statusCheckRollup`) and requires `leak-guard` and `contract-tests` present by
  name and green.
- **Memory keyword search** — binary exclusion had been dropped in the ranking
  rewrite (invisible on macOS, where BSD `grep` prints nothing for a binary file;
  on GNU `grep` binary content could be selected and injected into a prompt); the
  50KB size filter ran *after* every file had already been read; and a colon in a
  filename corrupted the sort key. Also: ranking by match count rather than
  filesystem walk order.
- **Four contract suites ran nowhere** — not in the aggregate runner, not in CI —
  including the 149-assertion suite pinning the very behavior being changed. All
  four registered, and `test_suite_registration.sh` closes the class by asserting
  every suite is in the runner, every runner suite is in CI or on a documented
  exclusion list, and every CI step points at a file that exists. It registers
  itself.
- **`grep -c ... || echo 0`** produced the two-line string `0\n0`, breaking every
  numeric test downstream. Six instances found; five fixed (including
  `memory-log.sh`, which was emitting **invalid JSONL**). The sixth, in
  `governance-preflight.sh`, was on the protected surface and fixed separately.

### Changed

- **Two shipped policies described a repository that does not exist.**
  `branching-strategy-policy.md` prescribed GitFlow with a `develop` branch
  auto-deploying to a development environment, and `deployment-policy.md`
  asserted deployment was automatic on push to a `staging` branch. There is no
  `develop` and no `staging`. Both are now split three ways at the top —
  **ENFORCED** (the git-approval gate, the subagent git deny), **ASSUMED** (a
  mainline exists and work happens on branches; nothing checks it), and **YOUR
  CHOICE** (everything else) — mirroring the enforced-versus-followed honesty the
  threat model already uses. `dev-main` is deliberately still absent from the
  shipped policies: that topology exists only because LogicLoom is distributed as
  a template, and documenting it for a cloner would relocate the defect rather
  than fix it.
- **The evaluator is advisory, and now says so.** `evaluator-protocol.md` v0.1
  specified no gate semantics at all while a VISION thread asked to harden a
  hard-gate contract nobody had written. Answered rather than built (v0.2): the
  evaluator produces findings; it does not gate, block, or fail a workflow. The
  tradeoff is stated rather than sold — an ignored finding is indistinguishable
  from no finding, so the mitigation (surfacing plus a written report) makes the
  loss *auditable, not prevented*. What buys that cost is that a gate over
  subjective model judgement running on a flaky browser MCP would block real work
  on a wrong opinion, and the predictable response is a bypass flag.
- **Project amendments stay followed-not-enforced, by choice.** Wiring
  `amendments.md` into `governance-preflight.sh` was considered and declined: a
  loader would make mandates *look* enforced without making them enforced — the
  hook floor still would not consult a mandate — which is the phantom-gate
  failure the threat model exists to name. Recorded as decided rather than
  pending across the constitution, `CLAUDE.md`/`AGENTS.md`, and the threat model.
- **Marketplace residue cleared** from the command bridge, the context file, and
  `loom-orchestrator`'s manifest keywords. No live reference to
  `sdd-marketplace`, `marketplace.json`, or any registry URL remains. Scope stops
  short of externalising the eight in-repo plugins — `loom-governance` *is* the
  hook floor and Principle XVI requires every plugin to depend on it — which is a
  constitutional amendment still pending a maintainer decision.
- **`loom-maintenance` plugin manifest → 1.1.0** and its description rewritten;
  it gained four commands (`/scaffold-environments`, `/promote-dev`,
  `/promote-staging`, `/promote-prod`) and two skills (`environment-scaffolding`,
  `promotion-lifecycle`).

### Known gaps

- Nothing loads `.logic-loom/memory/amendments.md`. Mandates are followed because
  `CLAUDE.md` and `AGENTS.md` say to read them, not because anything fails
  closed. Deliberate (see above), not an oversight.
- `environments.conf`, `project.conf`, and the promotion ladder are all
  **declaration and guidance**. No hook reads any of them; the validators are
  read-only and exit 0 on an absent file. `requires_approval` is a statement your
  CI or your reviewer is expected to honour — the harness will not notice a
  deviation.
- One assertion in `test_update_framework.sh` ends in `|| true` and therefore can
  never fail. Found, recorded, not fixed. That suite is also the one documented CI
  exclusion (live network I/O, no timeout).

## [6.4.1] - 2026-08-13

A patch release fixing the **update path**. Clones of v6.3.1 and v6.4.0 could not
run `/update-framework` at all; this release repairs those baselines
automatically, documents the failure by its literal error string, and adds the CI
assertion that would have caught it at merge time.

### Fixed

- **`/update-framework` failed with "`.sdd-sync-ref` is NOT reachable from
  upstream main"** for clones of v6.3.1 and v6.4.0. Those releases' PRs were
  **squash-merged**, which discards the single-parent sanitized snapshot commit
  that `.sdd-sync-ref` names. Customers fetch only `refs/heads/main`, so the
  recorded baseline was unresolvable in their clone and the update exited 3.
  Root cause was a **settings conflict**: branch protection on `main` required
  linear history, which forbids the merge commit the release design depends on.
  Repo settings corrected — merge commits allowed; squash and rebase merging
  disabled.

### Added

- **Automatic repair of the broken baselines** —
  `plugins/loom-maintenance/scripts/extract-proposals.sh` now detects the two known-bad
  baseline SHAs, remaps each to its equivalent commit on `main` (re-verifying
  reachability before accepting the remap), and continues the update, so no
  changes are skipped.
- **`KNOWN_ISSUES.md`** at the repo root, a pointer from `README.md`, and an
  expanded **"Broken sync baseline"** section in
  `.docs/guides/FRAMEWORK_SYNC_GUIDE.md` — all keyed on the literal error string
  (`.sdd-sync-ref is NOT reachable from upstream main`) so a search finds them.
- **Release-time prevention gate** — `.github/workflows/release-tag.yml` now
  asserts the snapshot commit is an ancestor of `main`'s HEAD
  (`git merge-base --is-ancestor`) **before** creating the tag, and fails the
  release loudly (naming cause, impact, and remedy) if a future promotion is
  squash- or rebase-merged.

### Changed

- The **non-remappable error path** now states explicitly that the generic
  re-baseline adopts nothing and **permanently skips** the intervening changes,
  and offers the version-specific fix first.

## [6.4.0] - 2026-08-12

Covers the `dev-main` line since v6.3.1 (2026-06-24 → 2026-08-12). Three threads:
the **orchestrator + worker ladder** (making delegation actually bind, not just be
documented), the **project graph convention** (a text-first, deterministic
code+docs graph — no engine, no daemon), and a round of **governance / CI floor
hardening**. Plus the harness↔product and harness↔user boundaries written down.

### Added — orchestrator + worker ladder

- **Frontier orchestrator role** (`.logic-loom/config/models.conf`): a
  *model-agnostic-but-frontier* orchestrator tier — `FRONTIER_MODEL`
  (`claude-fable-5`) with a documented `FRONTIER_FALLBACK` (`claude-opus-4-8`)
  so the role survives a quota/availability gap. Both targets are Anthropic; the
  orchestrator never runs on a non-Claude model.
- **Two project agents** (`.claude/agents/`, deliberately *not* plugin agents —
  plugin agents lose `hooks`/`mcpServers`/`permissionMode`):
  `deep-reasoner` (opus, effort `high`) for architecture and hard debugging, and
  `fast-worker` (sonnet, effort `medium`) for boilerplate, tests, and routine
  edits.
- **`.docs/architecture/orchestrator-worker-ladder.md`** — the ladder, its
  economics, and the dispatch policy (reasoning → `deep-reasoner`; mechanical →
  `fast-worker`; correctness-critical + scrutiny-inviting → also `/cross-check`).
  Non-Claude models remain advisory-only; the ladder adds no non-Claude workers.
- **`.docs/architecture/model-selection-policy.md`** — canonical model-selection
  policy consolidating a four-surface audit (frontmatter executables, the
  cross-provider verification layer, config/scripts/schemas, documentation prose).
- **`.docs/architecture/orchestration-hook-enforcement.md`** — why an
  orchestration policy written in `CLAUDE.md` stops binding as a session grows
  (it is loaded once, at position zero) and the two hook patterns that fix it:
  `UserPromptSubmit` policy re-injection and a delegation nudge keyed on the
  `agent_id` discriminator. Includes exempt-recon carve-outs, threshold-not-
  tripwire tuning, a fail-safe posture (emit context, never a decision), and a
  **surface-portability** section that marks each claim with its verification
  level (confirmed-from-docs vs. explicitly undocumented).
- **Per-provider model selection for `/research`**: `--openai-model`,
  `--gemini-model`, `--claude-model`, resolved **flag → env → config default**.
  `models.conf` gains an "Advisory cross-provider models" block as the single
  documented source of each provider's default (`gpt-5.5`,
  `gemini-3.1-pro-preview`), shared with `/cross-check` via the same
  `CROSS_CHECK_*_MODEL` overrides. The advisory + read-only boundary is unchanged.

### Added — project graph convention

- **`/graph` command + `project-graph` skill** (`loom-orchestrator`) — regenerate
  and query a project-wide code+docs graph, emit a visual export, and lint it.
  Deterministic and text-first: it walks a git-tracked JSONL manifest with `jq`.
  No graph engine, no daemon, no default LLM extraction pass, and every mechanism
  fails open (warn, never block).
- **`.logic-loom/graph/graph-bridge.jsonl`** — the git-tracked bridge manifest
  (Anthropic memory-server shape), generated by
  `.logic-loom/scripts/bash/build-graph-bridge.sh`, with
  `.logic-loom/scripts/bash/lint-graph.sh` as the orphan/edge linter.
- **`.docs/architecture/project-graph-convention.md`** — the normative federated
  model: knowledge/docs in the markdown itself (Obsidian-readable), code in an
  **opt-in, per-product** code-graph MCP with a `ctags + rg` text floor, joined by
  the git-tracked bridge. The merged code+docs graph is an **export**, never a
  store. Ships an `.obsidian/` config *template* (`.logic-loom/templates/obsidian/`),
  not an installed app.

### Added — boundaries, written down

- **Harness ↔ product boundary** (`.docs/policies/file-structure-policy.md`
  § Product Workspace): the framework owns the repo root (root `package.json`,
  root `tests/`, `.claude/`, `.logic-loom/`, `plugins/`); product application code
  lives in its own workspace — `web/` for a single app, `apps/<name>/` for a
  monorepo — with its own `package.json`, `node_modules`, build, and test runner.
  A product `src/` at the repo root trips the framework's jest-glob and coverage
  gates. Backed by `tests/contract/test_product_workspace_boundary.sh`.
- **Harness ↔ user boundary** — a new section in `CLAUDE.md` and
  "Where do my personal preferences go?" in `START_HERE.md`, plus a pointer step
  in `/initialize-project`: **LogicLoom never writes to `~/.claude/`.** The
  harness governs this repo only; persona and working preferences belong in the
  user's own global config, which should stay out of git.
- **`START_HERE.md`** — onboarding walkthrough of a first feature via the swarm
  pack, with the SDD waterfall pack documented as the equal alternative.

### Added — exploration & design records

- `features/code-knowledge-graph/exploration/` — the build-vs-buy record behind
  the graph convention (`graph-design.md`, `project-graph-design.md`,
  `graph-stack-decision.md`: build a lightweight deterministic git-tracked text
  graph; adopt no third-party graph stack into the default path).
- `features/harness-product-boundary/exploration/` — the silent root-collision
  failure modes the product-workspace rule exists to prevent.
- `features/modular-harness/exploration/` — thin-core / layered-config design
  notes (`modular-harness-design.md`, `unified-architecture.md`).

### Changed

- **`VISION.md` rewritten to v2.0** — restated as a living product north-star:
  *a constitutional-governance-focused, workflow-agnostic development harness that
  ENHANCES the flagship model*, adding only what does not decay as models improve
  (governance, safety, observability, cost discipline, file-ownership) while
  riding **on** Claude Code's native orchestration. "Be the durable floor and the
  value-on-top, not the engine."
- **CI gate coverage** (`.github/workflows/plugin-tests.yml`) — the workflow now
  runs 9 additional contract suites (governance hooks, policy matching,
  orchestration hook, memory search, spec 006 integration, git safety, policy
  validation, structured logging) so every suite gates PRs. Previously only 8 of
  14 ran, and the **Git Safety** suite — Principle VI enforcement — was not among
  them.
- The `paths:` allowlist was removed from that workflow so the framework-wide gate
  always runs; the allowlist had excluded `.logic-loom/lib/`, `.claude/hooks/`,
  `settings.json`, and the workflow file itself.
- `tests/run_all_tests.sh` now also runs the three suites CI already gated but the
  local runner was missing: product workspace boundary, model agnosticism, and
  graph bridge.
- `test_update_framework.sh` is excluded from CI (it still runs locally): it makes
  a live network `git fetch` via `extract-proposals.sh --dry-run` with no timeout,
  and its key assertion is suffixed `|| true`.

### Fixed

- **`guard-dangerous-commands.sh` no longer fails open on bash 3.2.** `policy.sh`
  and `logging.sh` are now bash-3.2 compatible, so the dangerous-command guard
  **enforces on stock macOS** with nothing to install. Bash version is no longer a
  fail-open condition; the re-exec into a bash 4+ binary is kept only as
  belt-and-braces, and falling through it is not a failure. The remaining
  fail-open paths are genuine infrastructure gaps (missing/unsourceable policy
  lib) — the other guards gate independently and fail **safe**.
- **Dangerous-command matching now happens at command position, not anywhere in
  the string.** Quoting a dangerous example inside a commit message, PR body, or
  doc no longer trips the guard. Covered by
  `tests/contract/test_policy_matching.sh`.
- **The test runner no longer hides crashed suites.** A suite that exits nonzero
  without emitting a parseable `Results: x/y` line has its assertions counted
  nowhere; those now gate the run (`CRASHED_SUITES`). Also closed the adjacent
  hole where a suite printing parseable passing results but exiting nonzero would
  not fail the run (`NONZERO_EXITS`).
- Executable bits restored (0644 → 0755) on `protect-governance-files.sh` and
  `subagent-git-guard.sh` — two hooks in the enforcement floor.

## [6.3.1] - 2026-06-24

**Release-tooling maintenance** (no customer-facing framework changes).

### Added
- Maintainer release driver: `/promote <version>` + `bump-version.sh` (coherent
  framework-version stamping with `set`/`--check`) — drives the dev-main→main
  promotion end to end and hands off at the green PR (main stays review-protected;
  no `--admin`). Maintainer-only; stripped from customer copies.
- `.github/workflows/release-tag.yml` — auto-tags `vX.Y.Z` when a release PR is
  merged to `main` (push-triggered, idempotent), so the maintainer never hand-tags.

### Changed
- `/initialize-project` now also strips `release-tag.yml` from a customer project;
  the `promote-to-main.yml` PR body documents the auto-tag.

## [6.3.0] - 2026-06-24

**Provider-portability program (Phases 1–3)** — a considered supersession of the
prior absolute "Claude-Code-native, NOT provider-portable" stance. POLICY now
travels to any host as model-followed rules; ENFORCEMENT stays Claude-Code
reference with a documented adapter contract (Phase 4, the orchestration-runtime
abstraction + identity rewrite, is gated and not in this changeset).

### Added (portability)
- **Cross-Check Disposition** — the primary agent now leans toward a decorrelated
  cross-provider review on verification-shaped asks (double-check / are-you-sure /
  red-team / peer-review …), the way ultracode self-orchestrates. Two layers:
  host-neutral prose in **AGENTS.md Tier 1** + **CLAUDE.md** (the floor that
  travels), and a Claude-Code **preflight nudge** (`governance-preflight.sh` +
  `verification-intent.conf`) with five over-fire guardrails and key-aware text.
  Fixed a latent preflight bug (domain detection ran on the truncated JSON
  envelope, false-firing on `cwd`/paths — now on the real prompt).
- **Provider-neutral AGENTS.md** — restructured into **Tier 1** (operating
  principles + disposition + neutral capability catalog, with an in-band
  "Enforcement reality" banner) and **Tier 2** (Claude Code host implementation).
- **Verdict-function seam** (`.logic-loom/lib/governance-verdicts.sh`) — the four
  enforcement guarantees' decision logic factored into shared pure-bash
  `allow|ask|deny` functions; the four Claude Code hooks now call them
  (behavior-preserving, `test_governance_hooks.sh` 23/23). Golden-fixture
  conformance test (`test_governance_verdicts.sh`, 28/28).
- **First non-Claude enforcement adapter** (`.logic-loom/adapters/`) — an
  off-host **git-approval gate** (pre-push hook + PATH `git` wrapper) that calls
  the same verdicts and enforces Principle VI on any POSIX-shell host; passes
  `test_git_adapter.sh` (13/13). Proves the L2 adapter contract is real.
- **Per-host wiring guide** (`.logic-loom/adapters/HOSTS.md`) — policy shim +
  enforcement install for Codex CLI / Cursor / Gemini CLI / Copilot / Aider.
- **Honest portability docs** — threat-model L1/L2/L3 model + enforced-vs-followed
  matrix + adapter-conformance contract; supersession recorded in CLAUDE.md +
  `models.conf`. Governance does NOT degrade gracefully off-host — enforcement is
  binary present/absent by host.

**Added a governed cross-provider adversarial review flow** — the canonical path
for all adversarial / cross-check reviews. By default LogicLoom's reviewers are
Claude reviewing Claude (shared training lineage → shared blind spots); a
non-Claude lineage (Codex/GPT by default, Gemini pluggable) decorrelates the
review and catches the class of defects correlated reviewers structurally miss.

### Added
- **`cross-check` skill** (`plugins/loom-orchestrator/skills/cross-check/`): the
  shared machinery. A governed Claude subagent runs an external model over a
  target (diff / `plan.md` / `claims.json` / file scope) and returns structured
  findings. Two modes: **Mode A (API, default)** — artifact-scoped, zero agentic
  surface, reuses the `/research` cross-provider pattern; **Mode B (`--deep`,
  opt-in)** — read-only provider CLI (`codex exec --sandbox read-only`) for
  repo-wide exploration. The external model is strictly **advisory + read-only**:
  it emits findings; the governed Claude agent triages (`accept|reject|
  needs-investigation`) and owns all remediation. Never writes repo source, never
  runs git. Provider-pluggable (Codex/GPT default), key-gated, fails open to
  `unavailable` (never phantom-gates).
- **`/cross-check [target]` command** — the standalone ad-hoc entry point.
- **`/review-team` cross-provider adversary** — a 5th, key-gated reviewer slot
  (peer signal, not a hard gate). `--no-adversary` / `--adversary-deep` flags.
- **`/plan-review --adversary`** — optional cross-provider lens on the plan DAG.

### Changed
- `models.conf` provider-boundary note now names both verification-layer
  consumers (`/research` + `/cross-check`) and states the advisory/read-only
  invariant explicitly.
- `governance-threat-model.md` documents a new residual (#5): Mode B trusts the
  *provider's* `--sandbox read-only` flag (a subprocess, hook-invisible) rather
  than LogicLoom's hooks — why Mode A is the default and Mode B is opt-in.
- `.env.example` documents the cross-check keys and the data-governance opt-in
  posture (enabling a provider sends the review target to that provider's API).

## [6.2.1] - 2026-06-15

**Removed the DS-STAR refinement subsystem.** The orphaned, experimental,
never-wired heuristic quality-gate is gone — Claude Code's native `/goal`,
`/workflow`, and `/loop` primitives cover the same ground.

### Removed
- The DS-STAR refinement subsystem (`src/sdd/` Python library + the Python
  agent/refinement wrappers, their tests, packaging, and
  `.logic-loom/config/refinement.conf`) — orphaned/experimental and redundant
  with native `/goal`, `/workflow`, and `/loop`. Earlier release notes
  (v6.1 / v6.2.0) described DS-STAR as "retained"; that is now superseded — it
  is fully removed.

## [6.2.0] - 2026-05-31

**Removed the dev-loop pack** (superseded by native `/workflow`, `/loop`, `/goal`);
orchestration now leans on Claude Code's native loop primitives. LogicLoom has
**two** workflow packs over the governance core — swarm and SDD waterfall.

### Removed
- The `loom-dev-loop` plugin and the `/dev-loop` command (`core-loop` skill):
  Claude Code now ships native `/workflow`, `/loop`, and `/goal` primitives that
  supersede the autonomous edit-test-debug loop, and dev-loop's runtime
  self-extension (gap detection → scaffold → register) was a governance
  liability. Plugin count: 9 → 8.
- The dev-loop subsystems that lived only inside that pack: the dev-loop tribunal
  voting / grading engine, scope-detector, quality-grading, termination-engine,
  RL-feedback engine, self-extension, and the dev-loop contract test suites.

### Unchanged
- `/research` and its jury-on-demand multi-LLM tribunal (in `loom-orchestrator`,
  self-contained) are **kept** — they are not part of dev-loop.
- The DS-STAR refinement subsystem and `.logic-loom/config/refinement.conf` are
  **retained**, decoupled from governance.

## [6.1.0] - 2026-05-28

**Opus 4.8 re-base + workflow-agnostic core.** Removed harness scaffolding made
redundant by flagship models, and reframed the framework around a governance core
with interchangeable workflow packs (no "primary"/"legacy" path).

### Changed — governance is hook-enforced
- Removed the mandatory per-message **4-step compliance ceremony** (FR-707). The
  `git-safety-gate` PreToolUse hook now forces an approval prompt on git mutations
  (real Principle VI enforcement) and is wired into `.claude/settings.json` with
  the dangerous-command guard.
- New `LOOM_GOVERNANCE_MODE` (`.logic-loom/config/governance.conf`): `lean`
  (default, flagship models) / `strict` (re-adds recitation for weaker models).
- Constitution → **v3.1.0**: LogicLoom identity; Principle X rewritten to
  "Delegation & Context Isolation"; Opus 4.8 default; dropped the `rl_metrics`
  manifest mandate.

### Changed — workflow-agnostic reframe
- Governance core + **interchangeable workflow packs** (swarm, SDD waterfall,
  dev-loop); none privileged. `vision.md` / `/plan-review` are swarm-pack-internal
  gates, not framework-level.
- Plugins renamed `sdd-*` → `loom-*`; **`sdd-specification` keeps its prefix**
  (it *is* the SDD workflow). 9 plugins.

### Removed
- The 7 `sdd-domain-*` plugins — collapsed into a governance-core **domain-brief
  registry** (`get_domain_brief`).
- RL telemetry (`rl_metrics` fields), the `sdd-marketplace` MCP, migration
  scaffolding. (DS-STAR refinement subsystem **retained**, just decoupled from
  mandatory governance. RL retained inside the `loom-dev-loop` pack by design.)

### Added
- `.logic-loom/config/models.conf` — role→model config (flagship Opus 4.8); no
  pinned version strings in agents/commands.
- Documented model/provider boundary: orchestration is Claude-Code-native
  (Anthropic-only); cross-provider models only at the delegated `/research` layer.

## [6.0.0] - 2026-05-27

**Major release**: LogicLoom rename + workflow modernization. Project renamed `sdd-agentic-framework` → `logic-loom` (brand: **LogicLoom**); `.specify/` → `.logic-loom/`. The rename disambiguates from the loom.com video platform.

### Renamed

- Project package: `sdd-agentic-framework` → `logic-loom`
- Brand: **LogicLoom**
- Framework directory: `.specify/` → `.logic-loom/` (all script and config paths updated)

### Added — LogicLoom primary workflow

- **`features/<feature-name>/` layout**: vision → exploration → research → PRD → plan → plan-review → sprints → retro (see `features/README.md`)
- **`/plan-review` skill** (loom-orchestrator): CEO + Eng reviewer verdict on `plan.md` — gates `/swarm implement`
- **`/retro` skill** (loom-orchestrator): post-feature learning capture
- **Vision-driven `/create-prd`**: auto-detects whether `vision.md` exists and routes to vision-driven or legacy PRD mode; office-hours forcing-questions gate
- **3 new hooks**:
  - `worktree-port-namespace` — deterministic per-worktree dev-server port ranges (no collision across parallel branches)
  - `context-cap-warn` — flags sessions approaching 800K of the 1M context window
  - `freeze-write-scope` — rejects swarm worker writes outside declared file ownership

### Changed — Workflow commands

- **`/swarm` — 3 modes**: `explore` (read-only investigations), `implement [sprint]` (per-sprint scope-bounded workers, file-ownership DAG enforced), `generic-legacy` (pre-LogicLoom behavior preserved)
- **`/review-team` — 4 reviewers** (was 3): added a **behavioral evaluator** that drives Playwright via chrome-devtools MCP to exercise actual UI/API behavior alongside security + quality + performance
- **`/research` — jury-on-demand**: picks 1-3 LLM judges per query type instead of always running the full tribunal. Pass `--judges all` for legacy 3-judge cross-validation
- **`/create-prd`** auto-detects vision-driven vs legacy mode

### Removed

- `mcp-servers/sdd-marketplace/` — LogicLoom no longer runs its own plugin marketplace
- RL telemetry infrastructure: `.logic-loom/scripts/bash/rl/`, `src/sdd/feedback/`, `src/sdd/metrics/`, `.docs/rl-metrics/`
- 5 stale internal scripts: `migrate-agent-to-skill`, `legacy-pattern-report`, `skill-coverage-audit`, `analyze-logs`, and `.specify/memory/agent-collaboration.md`

### Defers (third-party discovery)

LogicLoom is not in the marketplace business. External skill and plugin discovery defers to:

- **Anthropic Claude Code Plugin Marketplace** — canonical source for installable skills/plugins
- **Docker MCP Toolkit** — 310+ containerized MCP servers via `mcp-find`, `mcp-add`, `mcp-config-set`, `mcp-exec`

### v3 supplementary principle — Legacy-Tool Coexistence

Legacy SDD tools remain as alternative paths alongside the LogicLoom workflow:

- `/specification` (unified waterfall), `/specify`, `/plan`, `/tasks`
- DS-STAR verifiers and validators
- 7 domain plugins (frontend, backend, database, testing, security, devops, performance)
- `/build-team`, `/fullstack-team`, `/dev-loop`, `/finalize`

Pick the workflow that matches the problem shape.

## [5.0.0] - 2026-02-16

**Major release**: Agent Architecture Simplification + pre-release sanitization. 1,322/1,322 tests passing across 27 suites.

### Added

- **Spec 006**: Agent Architecture Simplification + Memory Enhancement specification
- **13 new contract test suites**: dev-loop (8 suites), plugin lifecycle, deprecation, marketplace (unit + E2E) — total 27 suites, 1,322 tests
- **Dev-loop libraries**: lifecycle.sh, tribunal-engine.sh, self-extension.sh — completing dev-loop plugin implementation
- **Multi-LLM tribunal research**: `/research` command with Claude, OpenAI, and Gemini independent research + tribunal voting

### Changed - Agent Architecture Simplification

- **22 agents reduced to 11**: Eliminated redundant "Claude talking to Claude" custom agents
- **14 agents converted to enhanced plugin SKILLS**: Domain knowledge moved from agent `.md` files to plugin `SKILL.md` files with Task Briefs
  - 7 domain specialists (frontend, backend, database, security, testing, performance, devops) → plugin skills
  - 4 orchestrators (task-orchestrator, swarm-coordinator, workflow-coordinator, specification-orchestrator) → orchestration skills
  - 3 specification agents (specification, planning, tasks) → unified specification skill
- **11 agents retained**: constitutional-governance-agent, team-synthesizer, prd-specialist, subagent-architect, auto-debug-agent, framework-sync-agent, memory-context-agent, dev-loop-orchestrator, debug-analyst, quality-assessor, tribunal-judge
- **Plugin manifests** now authoritative source for RL metrics (replaces deprecated `.claude/skill-index.json`)
- **Agent registry** at `.docs/agents/agent-registry.json` (replaces deprecated `.claude/agent-index.json`)

### Changed - Pre-Release Sanitization

- **All policies** updated from Constitution v1.6.0 to v3.0.0 (8 files)
- **architecture.conf** rewritten for v5.0: skill-based-delegation mode, correct counts (11 agents, 18 plugins, 19 commands)
- **sanitize-for-template.sh** rewritten for v5.0: accurate README/TEMPLATE_INIT generation
- **RL feedback system** updated: all `skill-index.json` references replaced with plugin manifests
- **Constitutional compliance skill** updated from v1.5.0 to v3.0.0 (added Principles XV-XVI)
- **All "14 principles" references** updated to "16 principles" across ~20 files

### Removed

- **14 custom agent definitions**: Replaced by enhanced plugin skills with Task Briefs
- **3 obsolete scripts**: `generate-skill-index.sh`, `discover-skills.sh`, `update-agents-to-constitution-v1.5.0.sh`
- **TEMPLATE_INIT.md**: Now generated dynamically by sanitize script
- **Empty `loom-orchestrator-hook/agents/` directory**

### Fixed

- Agent-collaboration-triggers: removed references to non-existent agents (full-stack-developer, structure-architect, theme-designer)
- Governance knowledge base: domain-agent mapping updated to domain-skill mapping
- Plugin manifests: specification plugin agents count 4→0 (converted to skills)
- Bridge manifest: command count consistency

## [4.1.1] - 2026-02-09

**Patch**: Tag-aware update framework. 266/266 tests passing.

### Added

- **Release tag awareness** in `extract-proposals.sh`: proposals now include `release_tag` field associating each change with its upstream release version
- `list_tags_in_range()`: discovers release tags between sync-ref and upstream/main
- `find_tag_for_file()`: maps each changed file to the release it belongs to
- `--dry-run` now shows release tags in range with dates
- Framework-updater skill updated to group proposals by release tag for per-release adoption
- 5 new tag-awareness contract tests (266/266 total)

## [4.1.0] - 2026-02-09

**Release**: Hook-Based Orchestration + Memory Context Injection + Additive Update Framework. 261/261 tests passing.

### Added - Hook-Based Orchestration (Feature 005)

- **Removed custom agent profile** from `settings.json` — Claude Code runs natively, augmented by hooks
- **`loom-orchestrator-hook` plugin**: Domain detection via `config/domains.conf`, orchestration guidance injected as `additionalContext`
- **`governance-preflight.sh` v3.0.0**: Refactored to provide domain analysis, agent recommendations, and constitutional reminders without constraining Claude Code
- Downstream projects customize `domains.conf` for their own agent registries

### Added - Memory Context Agent (Feature 005)

- **`loom-memory` plugin**: 3-tier memory search (working/recall/archival) with keyword extraction and relevance scoring
- **`memory-search.sh`**: Searches project knowledge (specs, architecture docs, session history, plugins) within 5-second hook timeout
- **`memory-log.sh`**: Observability logging for memory search operations (JSONL format)
- **`memory-context-agent`**: Haiku-model agent for lightweight context injection
- Graceful fallback when plugin not installed — hook continues without memory context

### Added - Additive Update Framework (Feature 005 / Issue #30)

- **`.sdd-sync-ref`**: Single commit hash tracking last upstream sync point
- **`extract-proposals.sh`**: Upstream-history-only diffing (`sync-ref..upstream/main`) — never compares downstream content against upstream
- **Enhancement proposals**: Each upstream change presented as independently accept/reject proposal
- **Framework-updater skill v3.0.0**: 10-step proposal-based adoption flow replacing old git-diff heuristics
- Supports selective adoption: accept new plugins without accepting governance changes, etc.

### Added - Test Infrastructure

- **261/261 tests passing** across 14 suites (up from 209/11)
- 3 new contract test suites: `test_orchestration_hook.sh` (19), `test_memory_search.sh` (19), `test_update_framework.sh` (14)
- Test output format standardized to `N/N passed, N failed` for parser compatibility

### Changed

- `settings.json`: Removed `"agent"` field — Claude Code is primary agent, augmented by hook-based governance
- CLAUDE.md: Replaced agent profile section with hook-based orchestration documentation
- AGENTS.md: 22 agents across 17 plugins (up from 21/15)
- Plugin Command Bridge: 19 commands synced (unchanged count)

## [4.0.0] - 2026-02-08

**Major release**: Plugin-First Architecture, loom-dev-loop plugin, Multi-LLM tribunal research, 209/209 tests passing.

### Added - Plugin-First Architecture (v4.1)

- **16 plugins**: loom-governance, sdd-specification, loom-orchestrator, loom-creation, loom-git, sdd-debug, loom-maintenance, loom-dev-loop, 7 domain plugins, sdd-domain-template
- **SDD Marketplace MCP Server**: 6 tools for plugin management (list, validate, search, install, update, publish)
- **Dynamic Plugin Command Bridge**: `sync-plugin-commands.sh` auto-syncs plugin commands to `.claude/commands/`
- **Constitution v3.0.0**: 16 enforceable principles including Principle XVI (Plugin-First Architecture)
- **19 slash commands** across 7 core plugins, all bridge-generated

### Added - loom-dev-loop Plugin (NEW)

Recursive autonomous dev-loop with council/tribunal methodology:

- **8 libraries** (5,448 lines): grading-engine, termination-engine, event-logger, tribunal-api, permissions-sandbox, scope-detector, rl-feedback-engine, sandbox
- **6 skills**: core-loop, tribunal-vote, scope-analysis, rl-feedback, session-report, self-extend
- **4 agents**: dev-loop-orchestrator, tribunal-judge, quality-assessor, debug-analyst
- **7 entity models**: DevLoopSession, QualityGrade, TerminationEvent, TribunalBallot, RLMetrics, ScopeAnalysis, GapAnalysis
- **Composite quality grading**: 6 metrics (test_pass_rate, coverage, lint, type_safety, security, build) + LLM-as-Judge
- **6-layer termination engine**: Success → Convergence → Budget → Max Iterations → Stuck → User Interrupt
- **L0-L3 permission tiers**: Read-only → Safe Write → Network/VCS → High-Risk
- **Self-extension**: Gap detection → scaffold plugin → quarantine validate → register
- **764 test assertions** across 11 test files (247 passing, 517 TDD awaiting wiring libs)

### Added - Multi-LLM Tribunal Research

- **`/research` command**: Multi-LLM triplicate research with tribunal cross-validation
- **3 LLM providers**: Claude (Perplexity MCP), OpenAI (GPT-4o API), Gemini (2.5 Pro API)
- **5-phase pipeline**: Parallel Research → Claim Extraction → Tribunal Voting → Quality Gate → Synthesis
- **Tribunal voting**: Claude (accuracy), OpenAI (sourcing), Gemini (relevance) with EMA-weighted scoring
- Consolidates former `/research` and `/research-team` into single command

### Added - Test Infrastructure

- **209/209 framework tests passing** across 11 suites (up from 172)
- Contract tests: plugin lifecycle, swarm lifecycle, RL metrics, constitution, deprecation, plugin command bridge
- Integration tests: marketplace MCP (E2E), git safety, policy validation, structured logging

### Changed

- All monolithic agents/skills/commands migrated to plugins (deprecated stubs remain for backward compat)
- `skill-index.json` deprecated (plugin manifests now source of truth)
- AGENTS.md rewritten for Plugin-First Architecture (25 agents across 16 plugins)
- Session-specific artifacts (research output, agent decisions/sessions, feature specs) excluded from main via .gitignore
- Opus 4.6 model references updated throughout

### Fixed

- Git safety checkpoint ID assertion (epoch timestamp format)
- Structured logging `wc -l` whitespace comparison on macOS
- Policy validation `parse_json` silent failure on malformed JSON
- Missing guard-dangerous-commands.sh hook
- Stale `/research-team` test references after consolidation
- Governance plugin manifest missing `dependencies` field

## [3.2.0] - 2026-02-05

### Fixed - Framework Architecture Review

- Issues #18-#23 resolved
- Opus 4.6 model references updated
- `/research` skill added to loom-orchestrator
- Unified `/specification` and `/git-push` commands with RL integration

## [3.1.1] - 2026-01-10

### Added - Debug Skill

**New `/debug` Command** - Systematic deployment troubleshooting workflow

This patch release adds a comprehensive debugging skill with a 10-step systematic workflow for diagnosing and resolving production issues, deployment failures, and runtime errors.

#### New Skill: `/debug`

- **Location**: `.claude/skills/technical/debug/SKILL.md` (668 lines)
- **Command**: `.claude/commands/debug.md` (75 lines)

**10-Step Workflow**:
1. **Issue Identification** - Gather context, understand symptom type
2. **Local Verification** - Isolate platform vs code issues (TypeScript, client build, Vercel build)
3. **Vercel-Specific Diagnostics** - Function limits, config, env vars, platform dependencies
4. **API Endpoint Diagnosis** - Debug 404/500 errors, routing patterns
5. **TypeScript Error Resolution** - exactOptionalPropertyTypes, index signatures
6. **Fix Implementation** - Apply targeted fixes with type safety
7. **Verification Process** - Clean build, test, deploy
8. **Regression Check** - Ensure no new issues introduced
9. **Completion Report** - Document root cause and verification results
10. **Iteration Handling** - Max 5 cycles before user escalation

**Specialized Diagnostics**:
- Vercel deployment failures (build errors, function count limits, 404 endpoints)
- TypeScript compilation errors (`exactOptionalPropertyTypes`, index signatures)
- Platform-specific dependency issues (`package-lock.json`, native modules)
- API endpoint errors (500 errors, timeouts, missing routes)
- Production runtime issues (environment variables, database connections)

**Automatic Delegation**:
- `backend-architect` - API architecture issues, system design
- `database-specialist` - Query optimization, schema issues
- `security-specialist` - Auth/authorization, vulnerabilities
- `devops-engineer` - CI/CD failures, infrastructure

**Trigger Keywords**: debug, fix, broken, not working, failing, deployment failed, build error, 404, 500 error, investigate, troubleshoot, diagnose

**Constitutional Compliance**:
- **Principle II**: Verify/add tests for bug fixes
- **Principle VI**: NO automatic git operations
- **Principle VIII**: Update docs when patterns discovered
- **Principle X**: Delegates to specialists when appropriate

#### New Skill Category: `technical/`

Introduces domain-specific technical procedures category, enabling future skills:
- `technical/api-contract-design/`
- `technical/test-first-development/`
- `technical/performance-optimization/`

#### Documentation Updates

- **CLAUDE.md**: Added `/debug` to Quick Command Reference table
- **Version**: v3.1.0 → v3.1.1
- **.claude/context/skills.md**: Debug skill entry with workflow steps and delegation points

#### Real-World Validation

Battle-tested patterns from production debugging:
- Vercel function count limit issues (consolidating endpoints)
- TypeScript `exactOptionalPropertyTypes` errors (conditional object building)
- Platform-specific dependencies (Windows vs Linux lockfiles)

**Total Lines Added**: 743 lines (668 SKILL.md + 75 debug.md)

---

## [2.0.0] - 2025-11-11

### Major Feature: DS-STAR Multi-Agent Enhancement (Feature 001)

This release integrates Google's proven DS-STAR multi-agent patterns into the SDD framework, bringing sophisticated quality gates, intelligent routing, and self-healing capabilities.

#### Added - DS-STAR Agent Library

- **VerificationAgent** (`src/sdd/agents/quality/verifier.py`)
  - Binary quality decisions (sufficient/insufficient) at each workflow stage
  - Specification completeness validation (≥0.90 threshold)
  - Plan quality validation (≥0.85 threshold, ≥0.90 spec alignment)
  - Blocks progression when quality insufficient
  - Provides actionable feedback for improvements

- **FinalizerAgent** (`src/sdd/agents/quality/finalizer.py`)
  - Pre-commit constitutional compliance validation
  - All 14 constitutional principles validation
  - Test coverage verification (≥80%)
  - Code style compliance (black, isort)
  - Documentation synchronization checks
  - No automatic git operations (Principle VI compliant)

- **RouterAgent** (`src/sdd/agents/architecture/router.py`)
  - Intelligent multi-agent task orchestration
  - Domain detection and agent selection
  - Dependency graph (DAG) execution planning
  - Parallel execution optimization
  - Routing decision audit trails

- **AutoDebugAgent** (`src/sdd/agents/engineering/autodebug.py`)
  - Automatic error repair with >70% fix rate target
  - <30 second debug iteration cycles
  - Common error pattern recognition
  - Self-healing code corrections

- **ContextAnalyzerAgent** (`src/sdd/agents/architecture/context_analyzer.py`)
  - Semantic codebase search with <2 second retrieval
  - Context intelligence and summarization
  - Codebase understanding for agent tasks

#### Added - Refinement Engine

- **Iterative Refinement Loop** (`src/sdd/refinement/engine.py`)
  - Up to 20 refinement rounds with configurable thresholds
  - Early stopping at 0.95 quality threshold
  - State persistence between iterations
  - Feedback accumulation across rounds
  - Graceful escalation to human when needed

- **Configuration System** (`.logic-loom/config/refinement.conf`)
  - `MAX_REFINEMENT_ROUNDS=20` - Maximum iteration limit
  - `EARLY_STOP_THRESHOLD=0.95` - High quality early exit
  - `SPEC_COMPLETENESS_THRESHOLD=0.90` - Specification requirement
  - `PLAN_QUALITY_THRESHOLD=0.85` - Plan requirement
  - `TEST_COVERAGE_THRESHOLD=0.80` - Code coverage requirement

#### Enhanced - Workflow Commands

- **`/specify` Command**
  - Automatic refinement loop after spec generation
  - Iterative improvement until quality threshold met
  - Actionable feedback for specification improvements
  - Human escalation when quality unachievable

- **`/plan` Command**
  - Automatic verification gate after plan generation
  - Quality blocking before task generation phase
  - Plan-to-spec alignment validation
  - Actionable feedback for plan improvements

- **`/finalize` Command** (NEW)
  - Pre-commit compliance validation
  - All 14 constitutional principles checked
  - Test and coverage verification
  - Code style and linting validation
  - Documentation synchronization checks
  - Manual git command suggestions (no auto-execution)

#### Added - Testing Infrastructure

- **Contract Tests** (39 tests, 100% pass rate)
  - VerificationAgent contract tests (13 tests)
  - FinalizerAgent contract tests (13 tests)
  - RouterAgent contract tests (13 tests)
  - Full interface validation coverage

- **Integration Tests** (37 tests)
  - End-to-end verification workflow tests
  - Multi-agent routing orchestration tests
  - Context intelligence tests
  - Refinement loop tests
  - Autodebug healing tests

#### Added - Documentation

- **Feature Specification** (`specs/001-ds-star-multi/`)
  - Complete DS-STAR implementation spec
  - Technical design documentation
  - API contracts and data models
  - Test scenarios and quickstart guide

- **Integration Guides**
  - DS-STAR integration guide
  - Implementation status tracking
  - Test results documentation
  - Production readiness report

#### Enhanced - Framework Features

- **Graceful Degradation**
  - Framework works without Python/DS-STAR components
  - Warning messages when components unavailable
  - Manual review recommendations
  - No workflow blocking

- **Performance Targets**
  - Context retrieval: <2 seconds
  - Debug iteration: <30 seconds
  - 3.5x task completion accuracy improvement (target)
  - >70% automatic fix rate (target)

### Changed

- Updated README.md with DS-STAR feature documentation
- Updated CLAUDE.md with DS-STAR workflow enhancements
- Enhanced directory structure with `src/sdd/` Python library
- Added `.docs/agents/shared/` for cross-agent state

### Breaking Changes

None - DS-STAR enhancements are fully backward compatible with graceful degradation.

---

## [1.2.0] - 2025-09-19

### Added
- **New Agents**
  - `testing-specialist` - Comprehensive QA and test automation specialist in quality department
  - `performance-engineer` - Performance analysis and optimization specialist in operations department

### Enhanced
- **Agent Creation Workflow**
  - Enforced constitutional requirement for subagent-architect delegation
  - Custom tool override capability for specific agent needs
  - Automatic department classification based on purpose keywords
  - Improved MCP access configuration per department

### Documentation
- Updated README.md with current agent inventory (9 agents across 5 departments)
- Added agent quick reference section
- Improved troubleshooting guide

## [1.1.0] - 2025-09-18

### Added
- **Core Agent Infrastructure**
  - Established 7 initial agents across 5 departments:
    - Architecture: `subagent-architect`, `backend-architect`
    - Engineering: `frontend-specialist`, `full-stack-developer`
    - Quality: `security-specialist`
    - Operations: `devops-engineer`
    - Data: `database-specialist`

- **Agent Management System**
  - Central agent registry (`/docs/agents/agent-registry.json`)
  - Audit logging for agent creation
  - Memory structure for agent context and knowledge
  - Department-based organization

- **Constitutional Framework**
  - Section X: Mandatory specialized agent delegation
  - Agent governance framework
  - Agent collaboration patterns
  - Department-specific tool and MCP access controls

### Enhanced
- **create-agent.sh Script**
  - Automated department assignment
  - Tool restriction by department
  - MCP server configuration
  - Registry and documentation auto-updates
  - Constitutional compliance validation

- **Workflow Automation**
  - `/create-agent` command with subagent-architect enforcement
  - Automatic CLAUDE.md updates
  - Agent file naming conventions
  - Memory structure initialization

### Changed
- **Git Operations Policy**
  - NO automatic git operations without explicit user approval
  - Branch creation requires user confirmation and naming preference
  - All commits, pushes, and merges need explicit permission

## [1.0.0] - 2025-09-17

### Initial Framework Release
- **Specification-Driven Development (SDD) Core**
  - Constitutional development principles
  - Library-First architecture mandate
  - Test-First Development (TDD) enforcement
  - Contract-driven integration patterns

- **Workflow Commands**
  - `/specify` - Feature specification creation
  - `/plan` - Implementation planning
  - `/tasks` - Task list generation
  - `/create-agent` - Agent creation (initial version)

- **Directory Structure**
  - `.logic-loom/` - Framework core with templates and scripts
  - `.claude/` - AI assistant configuration
  - `.docs/` - Project documentation and policies
  - `specs/` - Feature specifications directory

- **Templates**
  - Feature specification template
  - Implementation plan template (9-step process)
  - Task list generation template
  - Agent file template

### Based On
- GitHub's spec-kit framework
- Extended with AI governance and agent orchestration
- Enhanced workflow automation and memory management

## Pre-1.0.0

### Foundation
- Initial commit from SDD framework base
- Basic directory structure setup
- Core constitutional principles established
- Initial templates and scripts

---

## Upgrade Guide

### From 1.1.0 to 1.2.0
1. No breaking changes
2. New agents available: `testing-specialist` and `performance-engineer`
3. Review updated agent collaboration patterns for optimal usage

### From 1.0.0 to 1.1.0
1. Review constitutional Section X for mandatory agent delegation
2. Update any custom scripts to use Task tool for agent invocation
3. Ensure all Git operations request user approval

## Future Roadmap

### Planned Features
- [ ] Agent performance metrics and optimization
- [ ] Cross-agent workflow templates
- [ ] Enhanced MCP integration patterns
- [ ] Agent capability evolution tracking
- [ ] Automated agent selection based on task analysis

### Under Consideration
- Product department agents
- Multi-agent orchestration improvements
- Agent learning and adaptation features
- Workflow visualization tools