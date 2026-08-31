---
name: architecture-dev-main-template-split
description: SINGLE-PUBLIC-REPO release model (dev-main public + sanitized main) + foundational VISION.md peer-to-constitution + constitution v3.2.0
metadata:
  node_type: memory
  type: project
  originSessionId: 2604835d-e3d8-4e1f-a18e-127b13f2e9a5
---

Decided + built 2026-06-15 (branch `loom-migration`). Extends
[[architecture-v6-2-native-primitives]].

**⚠️ TOPOLOGY SUPERSEDED 2026-06-16 → SINGLE PUBLIC REPO. Repo RENAMED to
`kelleysd-apps/LogicLoom` 2026-06-17 (was `sdd-agentic-framework`; GitHub
redirects the old URL; local origin re-pointed; `isTemplate:true`, PUBLIC).**
The original two-repo plan (private dev + a SEPARATE public template repo
`logic-loom-template`) was REPLACED. User chose: keep THIS repo public;
`dev-main` is the publicly-visible dev mainline (pushed to origin — accepted that
its history + markers are public); `main` is the clean customer-facing template
line advanced ONLY by `promote-to-main.yml` snapshots. All shipping refs repointed
sdd-agentic-framework→LogicLoom (framework-upstream.conf, init-project.sh,
package.json, loom-governance plugin.json); promote stamps via `github.repository`
so it auto-tracks renames.

**Release-CI handling (decided 2026-06-17):** in single-repo, `promote-to-main.yml`
MUST live on the default branch (main) to be workflow_dispatch-able, so it can NO
LONGER be promote-time-stripped (would break our own CI release). It SHIPS on main
(marker-free; resolves repo via github.repository; runs maintainer scripts from a
dev-main checkout). The marker-bearing SCRIPTS (strip-harness-dev/leak-guard.sh/
manifest/history-scrub + now sanitize-for-template.sh + sanitization-audit.sh) stay
promote-stripped. A CUSTOMER's copy is cleaned at /initialize-project time instead:
`project-initialization` skill Step 7 + init-project.sh remove
`.github/workflows/{promote-to-main,leak-guard}.yml` (committed 4392ba6).
RESOLVED (leak-guard email): markers moved to repo variable `vars.LEAK_MARKERS`
(fail-closed; set out of band); leak-guard.yml genericized + made STRICT (no path
excludes). So the public file no longer contains the email/ioun-ai.

**KEY LESSON (adversarial verify caught a real leak the 7/7 audit MASKED).** The
build's own `sanitization-audit.sh` passed 7/7 while `sanitization-audit.sh` ITSELF
was SHIPPING — because (a) it was never in the strip manifest and (b) its Check 1
`grep -v "sanitization-audit.sh"` EXCLUDES ITSELF. It carried the full origin
provenance (ioun-ai, /workspaces/ioun-ai, prior product stack/tiers). A
multi-agent Workflow re-scan of the BUILT tree (4 independent lenses) flagged it +
`sanitize-for-template.sh` + a `bkelley` username in retro/SKILL.md. FIX (commit
700651f + 4bcab0f): both scripts added to manifest; build reordered (sanitize
BEFORE strip; audit/scrub run from preserved /tmp copy so all maintainer scripts
can be stripped); retro slug de-identified; branding "SDD Framework"→LogicLoom;
deleted stale esm-fix doc; fixed dangling sanitization-audit/CHANGELOG refs in
finalize + constitution_update_checklist; stale FR-707 "mandatory 4-step"→lean/
strict; dev date-stamps→TBD. TAKEAWAY: never trust a sanitizer's own pass alone —
adversarially re-verify the BUILT artifact with independent agents before any
public release.

**FIVE verification passes, each found a distinct class (loop-until-dry was essential):**
P1 sanitization-audit.sh/sanitize-for-template.sh shipping (audit self-exclusion). P2
`.claude/context/core.md` downstream consultancy identity (Brian Kelley/kelleysd.com)
+ LIVE Vercel Project/Org IDs auto-loaded as context. P3 `.claude/context/skills.md`
same class (Marketing/content-pipeline block). P4 (a) test_constitution.sh asserts
Version-History rows that history-scrub REMOVES → shipped CI red on first customer push;
(b) lowercase 'SDD framework' (case-sensitive sweep missed it). TWO RECURRING ROOT
CAUSES: (1) **`.claude/context/*.md` are STALE auto-generated artifacts** contaminated
from when this repo built the kelleysd.com site — re-grep ALL of them every release.
(2) **the promote GATE runs the contract suite against UN-stripped dev-main**, so
post-strip breakage (scrubbed content an assertion depends on) is invisible — MUST run
the 5 CI contract tests against the BUILT/stripped tree (added to pass-5 verifier;
RECOMMENDED: add a post-strip test-run step to promote-to-main.yml's release job).
ENV WARNING: this terminal mangles the literal token 'framework' in piped grep output —
verify 'framework' hits via Read/od, not raw echo. leak-guard email RESOLVED via
vars.LEAK_MARKERS (broadened to include Brian Kelley|Kelley AI|kelleysd.com|Vercel IDs).

**First `main` seed = ORPHAN ROOT (user chose 2026-06-17).** main becomes a single
pristine commit, NO prior history (not single-parent onto the old SDD baseline).
Requires FORCE-REPLACING main (cheap now: pre-tags/protection/clones). Landing
mechanism: build sanitized snapshot locally in a throwaway worktree (mirrors the
promote workflow; this is the BOOTSTRAP since promote-to-main.yml can't self-dispatch
until it's on main) → adversarial multi-agent verify → gated force-push to main → tag.

**LANDED 2026-06-17.** main = orphan v6.2.0 snapshot (tip `f18ec69` = C2 sync-ref →
`0e28655` C1 orphan, NO parent; release-bot committer so NO owner email in main's git
metadata; old baseline 50494f6 UNREACHABLE). Tag `v6.2.0` (lightweight) + GitHub Release
published (latest). 272 files, VISION stub, framework-upstream=kelleysd-apps/LogicLoom,
.sdd-sync-ref=0e28655. GitHub PR was IMPOSSIBLE (orphan = unrelated histories), so the
review was a pushed branch + manifest, landed via force-push. main is force-push-blocked
by a ruleset ('admin': non_fast_forward+deletion on DEFAULT_BRANCH, bypass=Admin) AND
classic protection (allow_force_pushes:false — a HARD block even enforce_admins:false
admins can't bypass). LANDING REQUIRED relaxing BOTH: disable ruleset enforcement + PUT
classic allow_force_pushes:true → force-push → restore both (verified field-by-field
EXACT). Captured originals to /tmp/loom-ruleset-*.json + /tmp/loom-main-protection.json
first. FAST-FOLLOW DONE on dev-main (ea6bdac, 2026-06-17): (1) v3.0.0/v3.1.0 CURRENT-version
stamps → v3.2.0 across governance scripts/docs (coupled governance-preflight.sh header ↔
test_plugin_command_bridge.sh:263 bumped together); (2) promote-to-main.yml release job
now runs the 5 customer-CI contract tests against the STRIPPED tree before compose.
Verified: stripped build 7/7, all 5 CI tests green on stripped tree, 0 stray current
stamps. These ship in the NEXT promotion (public main still v6.2.0 / f18ec69 until then).
(3) old tags v1.0.0–v5.1.1: user said LEAVE (cosmetic).

**OPEN — release-mechanics mismatch to resolve before the next (steady-state) promotion:**
main's CLASSIC protection has `required_linear_history:true` AND `allow_force_pushes:false`,
but the runbook (dev-main-template-split.md) says "require a MERGE COMMIT (disable
squash/rebase) so .sdd-sync-ref + v* tags stay reachable." These CONFLICT — linear history
forbids merge commits. Steady-state v6.2.1+ is SINGLE-PARENT onto main (shares history →
mergeable PR, NO force-push needed, unlike the orphan bootstrap), but the C1(snapshot)+
C2(sync-ref) 2-commit pattern + linear-history means the PR must merge via rebase/FF (NOT
merge commit); rebase rewrites SHAs which breaks the .sdd-sync-ref→C1 pointer. Resolve by
either (a) allow merge commits on main (disable required_linear_history) per the runbook,
or (b) keep linear history + rework the sync-ref so it survives rebase. Decide before
promoting v6.2.1. Customers consume `main` via "Use this
template" (clean, history-free) or fork. **The SINGLE-PARENT invariant is
unchanged and now MORE load-bearing** (intra-repo it's the only thing keeping
dev-main unreachable from main; parent = origin/main, dev-main only a
`Source-dev-main:` trailer string). Reworked in commit `ac626f7`:
`promote-to-main.yml` targets THIS repo's main via built-in `GITHUB_TOKEN` (no
PAT, no `PUBLIC_TEMPLATE_REPO`, no `public` remote); `framework-upstream.conf`
default → `kelleysd-apps/sdd-agentic-framework`; dead `logic-loom-template` URLs
repointed (package.json, init-project.sh). Binding sanitization gate = the
in-workflow 1-7 audit (GITHUB_TOKEN-opened PRs don't auto-trigger leak-guard.yml).
DONE this session: pushed dev-main to origin; retargeted PR #56 → dev-main; all
checks green (contract-tests ×2 + leak-guard). The paragraph below is the
HISTORICAL two-repo framing — read it as superseded.

**Branch/release model (ORIGINAL two-repo — SUPERSEDED, see above).** The
customer template `main` is PUBLIC, so `dev-main` (+ feature sub-branches) lives
in a SEPARATE PRIVATE repo and holds all harness-dev artifacts; `main` is a
sanitized, append-only snapshot customers clone as a template. The LOAD-BEARING
invariant: published commits are **SINGLE-PARENT** (parent = public main only;
dev-main sha recorded as a `Source-dev-main:` trailer string, NEVER a 2nd git
parent — a 2nd parent makes the entire unsanitized history reachable via
`git show <devsha>:`). dev-main never pushed to the public remote. The `release`
GitHub environment's required reviewers are the only human gate (Principle VI git
hooks do NOT run in GitHub Actions). Full runbook:
`.docs/guides/dev-main-template-split.md` (itself stripped from public).

**Foundational VISION (user's key clarification).** `VISION.md` is a distinct
artifact CLASS — exactly ONE per project, lives the life of the project, a PEER
to the constitution (constitution = *how*/floor; VISION = *what/why*/direction).
NOT a per-feature `features/<name>/vision.md`. Ships to public main as a clean
STUB (so constitution/CLAUDE/AGENTS references resolve on fresh clone);
`/initialize-project` Step 1.5 fills it from the PRD before constitution
customization. New template: `.logic-loom/templates/project-vision-template.md`.
**Constitution v3.2.0**: Preamble "Governance vs. direction" clause defers
new-project direction to VISION.md; floor stays supreme; no principle added
(numbering stable). Tandem-synced CLAUDE.md + AGENTS.md.

**Sanitization tooling (tracked-content model).** Three orthogonal layers:
sanitize-for-template.sh (per-project), sanitization-audit.sh Checks 1-6
(ioun-ai origin), and the NEW harness-dev layer: `template-strip-manifest.txt`
(SSOT) + `strip-harness-dev.sh` + `leak-guard.sh`, all operating on
`git ls-files ∩ exists-on-disk` (NOT filesystem globs — so a customer's
regenerated runtime never trips it, tracked .gitkeep survives). Manifest grammar:
plain=strip, `stub:`=replace with template, `warn:`=flag non-fatal (deferred).
The release plumbing strips ITSELF, so the post-strip audit runs from a PRESERVED
copy outside the tree via `LOOM_AUDIT_ROOT`. `sanitization-audit.sh --origin-only`
runs Checks 1-6 for the pre-strip gate; Check 7 (leak-guard) only post-strip.
Public backstop `.github/workflows/leak-guard.yml` is self-contained
(inline identity-marker grep, trusted from base ref — no script/manifest dep).

**Verified by local simulation** (throwaway worktree, strip→sanitize→audit):
7/7 clean; planted owner-email leak caught; release plumbing + .docs dev-record
stripped; VISION→stub. Full contract suite 413 assertions green; constitution
test updated to v3.2.0 (29/29).

**DS-STAR — RESOLVED (2026-06-15): FULLY REMOVED, not deferred.** A read-only
review (orphaned: no reachable command imports sdd.*; experimental: 1/37 tests,
heuristic "simulated" scoring; 33 hardcoded /workspaces paths so it can't run in
a clone) recommended strip; owner decided **full removal** — redundant with
native `/goal`,`/workflow`,`/loop`. Commit `ac7591e` deleted 61 files (src/sdd,
egg-info, .logic-loom/scripts/python, both finalize-feature.sh, pyproject +
requirements, refinement.conf, .docs/features/001-ds-star-multi, 13 tests) + 22
reference-cleanup edits. The `warn:` manifest entries are GONE; post-removal
sanitization sim is 7/7 with ZERO warns. (Also fixed earlier: 3 non-DS-STAR doc
leaks — 2 SKILLs + constitution_update_checklist — that used /workspaces/ioun-ai.)

**Open before first promotion** (gated, under SINGLE-PUBLIC-REPO model): set
branch protection on `main` (block force-push/delete, require leak-guard check,
require merge-commit so .sdd-sync-ref/v* tags stay reachable, restrict pushers) +
protect `dev-main`; configure the `release` environment's required reviewers
(the only human gate in CI). NO PAT / NO second repo needed — promote uses the
built-in GITHUB_TOKEN. After PR #56 merges into dev-main, run `promote-to-main.yml`
(`version: v6.2.x`) to bootstrap the first sanitized `main` snapshot. DONE
2026-06-16: dev-main pushed to origin, PR #56 retargeted main→dev-main, single-
repo rework committed (`ac626f7`) + pushed, checks green. (Superseded earlier
TODO items — separate repos / PUBLIC_TEMPLATE_REPO var / PUBLIC_REPO_TOKEN secret
/ `git remote set-url` — no longer apply.)
