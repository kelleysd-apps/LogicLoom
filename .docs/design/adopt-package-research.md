# Adopting LogicLoom into an existing project — distribution research

**Status:** research and recommendation only. No repo file changed except this one. No git mutation run.
**Repo:** `/Users/bkelley/kelleysd-apps/LogicLoom` @ `dev-main`, v6.5.0.
**Date:** 2026-08-26. External facts checked today are marked with how they were checked.

---

## 0. The recommendation in one page

**Build it.** But the distribution question is the easy half, and the answer is
boring: **a public npm package, `npx`-invoked, with the harness tree vendored
inside it.** The hard half — the half worth the research — is that **the harness
is not currently installable into an existing repo at all**, and roughly a third
of the prerequisite work is repairing that, not building a CLI.

| Question | Answer | Confidence |
|---|---|---|
| 1. Mechanism | Public npm registry, `npx`. Not GitHub Packages, not `curl \| bash` | High — see §2 |
| 2. Shape | **Self-contained** (vendored payload), not a fetcher | High — see §3 |
| 3. Versioning | Package version **is** the harness version, byte-identical | High — see §4 |
| 4. Release path | New workflow on `release: published` — the human's Publish click is the gate | Medium — see §5 |
| 5. Prerequisites | 14 items, 4 of them blocking | See §6 — **the substance of this document** |

**The single most important finding.** The brief guessed that "something in the
harness assumes it was `git clone`d" would be the thing that bites. It is, but
not in the way expected. The `.git`/remote/sync-ref assumptions are mostly fine.
What actually bites is that **`main`'s tree is not a payload — it is a whole
repository**, and eight of its root files collide head-on with any real project:
`package.json`, `tests/`, `.gitignore`, `README.md`, `CLAUDE.md`, `.mcp.json`,
`.editorconfig`, `.gitattributes`. Copying `main` into an existing repo does not
adopt LogicLoom; it vandalises the project.

**The finding that makes it tractable.** Two of those three worst collisions turn
out not to be collisions at all:

- **`package.json` and `tests/` are not load-bearing at runtime.** I grepped every
  hook and script for readers of the root `package.json`: the only consumers are
  `bump-version.sh` (stripped at release) and `constitutional-check.sh:404`, which
  merely tests *whether a dependency manifest exists* and records a skip if not.
  Nothing reads `tests/` at runtime. **So the adopt payload simply omits both**,
  and the jest-glob/coverage collision that `init-project.sh:299` can only warn
  about in prose disappears by construction.
- **`CLAUDE.md` never has to be touched.** Claude Code loads every `.md` under
  `.claude/rules/`; a rules file with no `paths:` frontmatter is "loaded at launch
  with the same priority as `.claude/CLAUDE.md`" (docs.claude.com/…/memory,
  fetched 2026-08-26). So the harness's operating instructions install as
  *new files* in `.claude/rules/`, colliding with nothing and reversible by
  deleting them. The adopter's own `CLAUDE.md` is never opened.

That leaves exactly **one** genuine merge problem — `.claude/settings.json`, which
carries the hook wiring — plus an append-a-marked-block problem in `.gitignore`.
Two merges, both small, both well-understood. That is a buildable scope.

---

## 1. What the ask actually is

`README.md:18` says `git clone <your-repo-url> logic-loom`. That is not a
soft-pedalled instruction for an empty directory — it is the *only* documented
install path, and every downstream mechanism is built on it. A slash command
cannot fix this: a project without LogicLoom has no `/adopt` to run. That framing
in the brief is correct and settles the mechanism question before it starts.

So the deliverable is an **out-of-repo bootstrapper**: something a developer runs
from inside their own project, which is a git repo they already care about,
that leaves the repo better and never leaves it broken.

### The prior art is in this repo already

`/scaffold-environments` (LOOM-0025) solved this exact shape and its skill states
the problem better than I would:

> **The target is an EXISTING repository.** Greenfield is the easy case and the
> rare one.
> — `plugins/loom-maintenance/skills/environment-scaffolding/SKILL.md`

Its five invariants are the right contract for `/adopt`, unchanged:

1. **Detect, never assume.** Anything undeterminable is reported `unknown`.
2. **Propose a delta, not a layout.**
3. **Never overwrite.** No `--force`. A marker distinguishes *our* file
   (idempotent no-op) from *theirs* (conflict, hands off).
4. **Per-file opt-in.** `--apply` requires `--only=…`.
5. **Declining costs nothing.** `--plan` writes no file.

Its detection also already refuses to shell out to git, reading refs straight off
`.git/HEAD`, `.git/refs/**` and `packed-refs` — provably non-mutating, and it works
under `subagent-git-guard.sh`. **Reuse this wholesale.** The adopt CLI's detect
phase is a port of `detect-environment-topology.sh`, not a new invention.

This matters for the estimate: it means the risky, opinionated part of the design
is already written down, argued, and shipped.

---

## 2. Distribution mechanism

### Recommendation: public npm registry, `npx`-invoked

```
npx logic-loom-adopt          # or: npx @logicloom/adopt
```

### "npm is against the grain for a bash harness" — it isn't, in practice

The brief flags this honestly and it deserves a direct answer rather than a
shrug. Three reasons it does not matter here:

**a. The adopter provably already has npm.** This is the decisive one. LogicLoom's
own `.logic-loom/scripts/setup.sh:134` installs Claude Code with
`npm install -g @anthropic-ai/claude-code`, and root `package.json` declares
`"engines": {"node": ">=18.0.0", "npm": ">=9.0.0"}`. Anyone who can run the
harness at all has node and npm, because that is how Claude Code itself is
distributed. `npx` adds no new dependency — it uses the one already required.

**b. There is a clean precedent for an all-bash npm package.** `bats@1.13.0` is
31 files and **entirely bash** — `bin/bats` (`#!/usr/bin/env bash`), 8 executables
under `libexec/bats-core/`, 8 `.bash` libraries under `lib/bats-core/`, no
JavaScript at all. Verified by downloading and unpacking the tarball
(2026-08-26). So "an npm package that ships shell scripts" is not a novel or
strained thing; it is an established shape with a widely used exemplar.

**c. The executable bit is a solved problem, and I can now say how.** Two
independent checks (2026-08-26):

- *Source:* npm's `bin-links` `lib/fix-bin.js` chmods every `bin` target to
  `0o777 & ~umask` and rewrites a CRLF shebang to LF.
- *Empirical:* `npm i bats@1.13.0` in a clean directory yields
  `-rwxr-xr-x node_modules/bats/libexec/bats-core/bats` — a file **not** named in
  `bin`, whose mode was preserved straight from the tarball.

**So modes survive the tarball; only `bin` targets get a guaranteed chmod. Pack
with the bits already set.** This is moot for LogicLoom anyway: I checked every
hook invocation in `.claude/settings.json` and all 12 are `"command": "bash <path>"`.
Not one relies on `+x`.

**d. The `bin` entrypoint should still be Node, and the reason is Windows.** npm's
docs are explicit that a `bin` file should start with `#!/usr/bin/env node`,
"otherwise, the scripts are started without the node executable". The Windows
`cmd` shim reads the shebang to pick an interpreter, so a `#!/usr/bin/env bash`
entrypoint resolves on Windows **only if bash is already on PATH** (Git Bash or
WSL). **That — not the exec bit — is the real portability cliff.** Making the
entrypoint a small Node script sidesteps it; the shell payload underneath is never
executed by npm, only copied.

### Why not the alternatives

| Option | Verdict | Reason |
|---|---|---|
| **GitHub Packages npm registry** | **Reject** | GitHub's own docs state: "You need an access token to publish, install, and delete private, internal, and public packages" (docs.github.com, working-with-the-npm-registry, fetched 2026-08-26). Requiring every adopter to configure a PAT and an `.npmrc` before they can try the tool destroys the "runs from anywhere with no prior install" property that is the entire point. |
| **`curl \| bash`** | **Reject** | No integrity or version pinning without building both yourself; requires hosting; and it buys nothing, because §2a shows npm is already present. Its usual justification — "the user may not have a package manager" — does not apply. |
| **`gh release download`** | **Reject as the primary path** | Requires `gh` installed and authenticated. Fine as a documented fallback for an air-gapped or npm-blocked environment; not the front door. |
| **Claude Code plugin marketplace** | **Reject as the mechanism — but steal one idea** | See the note below; this is more nuanced than a flat rejection and my first read of it was wrong. |
| **`npm init logic-loom`** | **Reject** | `npm init foo` resolves to `create-foo`, whose convention is *creating* a project. Adopting into an existing one under a `create-` name is a naming lie. |

### The marketplace, correctly stated

My first pass rejected this flatly on the grounds that plugins install at user
scope. That is half right, and the other half is worth having. Verified against
code.claude.com/docs/en/plugins and /plugin-marketplaces (2026-08-26):

- **Plugin *files* do install user-level.** Claude Code copies each installed
  plugin into `~/.claude/plugins/cache`. So a marketplace **cannot** scaffold
  `.logic-loom/` into a repository, and the rejection stands: the governance floor
  is in-repo hooks, and CLAUDE.md's "Harness ↔ user boundary" forbids writing to
  `~/.claude/`.
- **But *enablement* is repo-scoped and committable.** A repository can carry
  `extraKnownMarketplaces` and `enabledPlugins` in its own `.claude/settings.json`,
  and Claude Code adds the marketplace for a team member once they trust the
  project folder, with no separate prompt.

**The idea worth stealing:** those two keys are lines the adopt installer could
write into the settings merge it is already performing (PRE-7). That does not
replace the package — *something* still has to put the lines there, which is the
installer's whole job — but it is a real, repo-scoped hook for any future
LogicLoom capability that genuinely belongs in a plugin rather than in the tree.
**Out of scope for Phase 1; record it and move on.**

### What comparable tools actually do

The brief asked for specifics rather than generalities. All verified 2026-08-26;
several by unpacking the published tarball rather than reading marketing pages.

| Tool | Command | What the package contains | Bearing on LogicLoom |
|---|---|---|---|
| **shadcn/ui** | `npx shadcn@latest init` / `add` | `shadcn@4.19.0` is **140 KB, 27 files, all `dist/*.js`** — `"files": ["dist"]`. **No component source in the package.** The registry base `https://ui.shadcn.com/r` is baked in and env-overridable (`REGISTRY_URL`); `GET /r/styles/new-york/button.json` returns 200 anonymously with file content inlined. | The purest **fetcher**. Works because its payload is a growing catalogue nobody wants versioned into a CLI. LogicLoom's payload is a *fixed tree that must match a tag* — the opposite case. Instructive contrast, not a model. |
| **husky** | `npx husky init` | 7 files, 2.4 KB. **Does not write `.git/hooks`** — it sets `git config core.hooksPath .husky/_`. `init` **edits the consumer's `package.json`** to add `scripts.prepare`, sniffing existing tab-vs-2-space indentation to preserve formatting. | The closest precedent for **editing a file the user owns**. The indentation-sniffing is exactly the care level PRE-7's settings merge needs. |
| **ESLint** | `npm init @eslint/config@latest` | Generates `eslint.config.js`. Docs explicitly note it "assumes you already have a `package.json`". | Confirms adopt-into-existing is a normal, documented shape. |
| **Biome** | `npx @biomejs/biome init` | Generates `biome.json`. Binary arrives via per-platform `optionalDependencies`; **no install scripts**. | Precedent for shipping non-JS payload without `postinstall`. |
| **bats** | `npx bats` | **100% bash**, 31 files, `bin/bats` is `#!/usr/bin/env bash`. | The existence proof that §2's premise is fine. |
| **Deno** | `npm install -g deno` *(secondary path)* | Official npm package alongside the primary `curl \| sh`. Deno's own docs steer away: "The startup time of the Deno command gets affected if it's installed via npm." | A project that offers both and still prefers the script — for a startup-latency reason that does not apply to a one-shot installer. |

**The pattern that matters:** `shadcn init`, `biome init`, `npm init @eslint/config`,
and `husky init` are *all* plain `npx <pkg> <verb>` — **none** of them is
`create-*`. `create-*` is for empty directories. This independently confirms the
naming call below.

**On `npm init <initializer>`, since the brief asked:** `npm init foo` runs
`npm exec create-foo`; `npm init @usr/foo` runs `npm exec @usr/create-foo`; a bare
`npm init @usr` runs `npm exec @usr/create`. So scoped initializers do work — the
`create-` prefix goes *after* the scope. It is still the wrong convention here.

### On name shape

`npx logic-loom-adopt` (unscoped) is preferable to `npx @logicloom/adopt` for one
practical reason: an unscoped 404 proves the name is free, whereas a scoped 404
proves nothing about the scope (see §6, PRE-2). Unscoped also avoids
`--access public` on first publish.

---

## 3. What the package contains: self-contained, not fetcher

**Recommendation: vendor the payload.** Argued rather than asserted:

**Size is a non-issue.** Measured today: `origin/main` is **358 files, 2.82 MB**
(`git ls-tree -r -l origin/main`). The adopt payload is a strict *subset* of that
(§6, PRE-5 removes `tests/`, `package.json`, and the workflows), so under 2.5 MB.
That is an unremarkable npm tarball. The fetcher's only real advantage — package
size — does not exist at this scale.

**Offline and determinism.** A vendored package works behind a proxy, in CI, and
in an air-gapped clone-and-carry. A fetcher adds a second network dependency at
run time. The rate-limit exposure is now measured rather than assumed
(2026-08-26): **anonymous `api.github.com` is 60 requests/hour, keyed to the
originating IP address, not the user** — confirmed both in docs.github.com's REST
rate-limits page and empirically (`GET /rate_limit` anonymously returned
`{"limit": 60, "remaining": 60}`). "Keyed to IP" is the sharp edge: one
corporate NAT exhausts the budget for everyone behind it, and the resulting
failure is opaque.

Two mitigations exist, and they are worth recording even though the
recommendation is not to need them:

- `codeload.github.com` and `raw.githubusercontent.com` publish **no numeric
  limit** and return **no `x-ratelimit-*` headers** (checked anonymously; both
  200). Only undocumented abuse detection applies.
- Resolving "latest" via `https://github.com/<org>/<repo>/releases/latest/download/<asset>`
  is a **302 redirect, never an API call**, so it consumes none of the 60/hr —
  the trick starship's installer uses. An installer that instead calls
  `GET /repos/:o/:r/releases/latest` burns one of 60 per IP per hour, which is
  why NAT'd users hit "API rate limit exceeded" on such tools.

**If the fetcher shape is ever revisited, use the redirect form.** But the
vendored package needs neither.

**Version coherence is by construction.** With a fetcher, "package v6.6.0 fetched
tag v6.6.0" is a runtime hope. Vendored, the package *is* the tree. There is no
drift to reason about, which is the whole of the brief's question 2 tail.

**The decisive argument is `.sdd-sync-ref`.** This is where a fetcher gets
genuinely dangerous, and it is worth spelling out because the repo has been
burned by it twice already.

`/update-framework` does not use a git remote. `extract-proposals.sh:100` fetches
upstream ad-hoc into `refs/loom-upstream/main`, then `:156` guards:

```
if ! git -C "$REPO_ROOT" cat-file -e "${sync_ref}^{commit}" 2>/dev/null \
   || ! git -C "$REPO_ROOT" merge-base --is-ancestor "$sync_ref" "$LOOM_UPSTREAM_REF" 2>/dev/null; then
```

If `.sdd-sync-ref` names a commit that is not an ancestor of upstream `main`, this
exits 3 and **the adopter can never update again**. That is precisely what shipped
in v6.3.1 and v6.4.0 — both stamped a release-branch SHA that a squash-merge
discarded — and it needed a hardcoded two-entry remap table
(`extract-proposals.sh:127-138`) plus a `KNOWN_ISSUES.md` entry to recover from.

Verified today, the current state is correct and self-healing:
`origin/main:.sdd-sync-ref` = `28ef9d8`, and `git log -1 28ef9d8` is
`release: v6.5.0 sanitized template` — a commit on `main`. **A payload built from
a release tag carries a provably-reachable sync-ref for free.** A fetcher that
assembled a payload from `dev-main`, or from a tarball, or from anything other
than the tagged snapshot, would reintroduce the v6.3.1 failure for every adopter
simultaneously.

**Verdict: vendored, and the payload source is the release tag on `main`.** Not
`dev-main`, not a fetch. This also answers the brief's "which branch" question
(§6, PRE-4) with a mechanism rather than a preference.

---

## 4. Versioning

**Recommendation: the package version is the harness version. Identical. Always.**

The package ships the tree; a different number would be a lie about what is
inside. There is no independent-versioning story that survives the question
"which harness does `logic-loom-adopt@1.2.0` install?".

**Does it become another stamp site?** Yes — but not in the way the brief
assumes, and this is a real design constraint rather than a bookkeeping note.

First, a correction to the brief's count. `bump-version.sh` stamps **13 sites
across 9 files**, not 12 across 9. Counting the `SITES` list at
`bump-version.sh:32-50`: `architecture.conf` ×4, then `CLAUDE.md`, `AGENTS.md`,
`README.md`, `TEMPLATE_INIT.md`, `sanitize-for-template.sh`,
`governance-threat-model.md`, `package.json`, `MANIFEST-SCHEMA.md` ×1 each.
Worth confirming, because a wrong baseline hides an off-by-one when a 14th lands.

Second, the constraint. `bump-version.sh` is itself **stripped at release**
(`template-strip-manifest.txt` lists it under "Release DRIVER"), and so is
anything else maintainer-only. So the package's own manifest cannot live on
`main` unless you are willing to ship it to customers. That gives a three-way
choice, and the third option is the good one:

- **(a) Ship the packaging directory on `main`.** Simple, but every adopter
  inherits a `packaging/` tree that has nothing to do with their project. Rejected
  for the same reason the four maintainer workflows are stripped.
- **(b) Publish from `dev-main` by `workflow_dispatch`.** Loses the tag as the
  source of truth and reintroduces the sync-ref hazard from §3. Rejected.
- **(c) Payload from the tag, manifest from `dev-main`.** ✅ **Recommended.**

Option (c) is not a new mechanism — **`release-tag.yml` already does exactly
this.** Its draft-Release step reaches back to `dev-main` for `CHANGELOG.md`,
because the CHANGELOG is stripped from `main`, using a provenance trailer:

```
DEV=$(git log -1 --format=%B "$SNAP" \
        | sed -n -E 's/^Source-dev-main:[[:space:]]*([0-9a-f]{7,40}).*$/\1/p' | head -1)
```

The publish job uses the same trailer to read `packaging/adopt/**` from
`dev-main`, and takes the payload from the tag's tree. Version coherence is then
enforced structurally: the workflow derives the version from the tag it is
running on, so the manifest's version is *computed*, never stamped.

**Consequence: `packaging/adopt/package.json` should carry no version at all** —
or a `0.0.0-dev` placeholder the workflow overwrites. That way it is a 14th
*file*, but **not** a 14th stamp site, and `bump-version.sh` does not change.
That is the cheaper answer and it removes a whole class of half-bumped release.

**What breaks if they drift anyway:** an adopter installs `@6.6.0`, gets a v6.5.0
tree, and `/update-framework` then computes proposals against the wrong baseline —
silently, because the sync-ref would still be *reachable*, just wrong. This
failure is quieter than the v6.3.1 one and therefore worse. Deriving the version
from the tag is what makes it unrepresentable.

---

## 5. The release path

### Recommendation: a new `publish-adopt.yml`, triggered on `release: published`

The brief's constraint is real and correctly stated: a `push`-triggered workflow
runs the file **at the pushed commit**, which is why `release-tag.yml`'s own
header says its draft-Release step "did not and cannot run for v6.5.0". Any new
workflow inherits the same one-release-later property.

**Why `release: published` and not the existing `release-tag.yml` job:**

`release-tag.yml` creates a **draft**. A draft is explicitly not published — its
own notice says "It is NOT published — review the notes and hit Publish". If the
package were published in that same job, an unreviewed package would go public
while the human-facing Release was still sitting in draft. That is an inconsistency
you would have to explain in every incident.

Hooking `release: published` reuses the gate that already exists: **the
maintainer's Publish click.** No new confirmation surface, no new typed phrase,
no new state. That is the cheapest correct design.

**Ref semantics, checked today.** For the `release` event, GitHub's docs give
`GITHUB_REF` as "Tag ref of release `refs/tags/<tag_name>`" (docs.github.com,
events-that-trigger-workflows, fetched 2026-08-26). LogicLoom's tag points at the
sanitized snapshot commit `C1`, which is on `main`. So the workflow file version
used is the snapshot's copy — the same one-release-later property as
`release-tag.yml`, and consistent with it.

**UNVERIFIED:** the docs' general note "This event will only trigger a workflow run
if the workflow file exists on the default branch" is *absent* from the `release`
section, and the docs do not resolve whether it applies. This is moot for
LogicLoom — the tag is on `main`, which *is* the default branch, so both readings
are satisfied — but do not restate it as settled elsewhere. Confirm by cutting a
throwaway pre-release and observing whether the job appears.

**Consequence — a fifth workflow enters the tandem.** `publish-adopt.yml` must
ship on `main` (to be present at the tag) and must be removed from a customer's
project, exactly like `release-tag.yml`. That is not optional bookkeeping: it is
enforced. `tests/contract/test_shipped_gates_vs_strip.sh:429-464` asserts that
**three** paths remove **exactly** the same four workflows:

```
EXPECTED_WF="branch-topology-guard.yml
leak-guard.yml
promote-to-main.yml
release-tag.yml"
```

against `init-project.sh`, `project-initialization/SKILL.md`, and
`initialize-project.md`. Adding a fifth workflow without updating all four
locations fails CI. This is the test working as designed — the comment above it
records that the removal "used to exist in only two of the three", and customers
had every PR into `main` rejected as a result.

---

## 6. Prerequisites — what must be true before a line is written

Ordered. **Blocking** items must be resolved before design freezes; the rest can
land during Phase 1.

### PRE-1 · Decide the payload boundary — **BLOCKING, and it is a product decision**

This is the one that needs the maintainer, not research. `main` is 358 files; the
payload is a subset, and *which* subset determines what "LogicLoom adopted" means.

My recommendation, with the evidence for each:

| Path | Ship? | Evidence |
|---|---|---|
| `.logic-loom/`, `plugins/`, `.claude/hooks/`, `.claude/commands/`, `.claude/context/` | **Yes** | The harness itself |
| `.sdd-sync-ref` | **Yes** | `/update-framework` baseline; correct-by-construction from the tag (§3) |
| `AGENTS.md` | **Yes**, renamed | See PRE-6 |
| `.claude/settings.json` | **Merge**, never copy | The only genuine merge (PRE-7) |
| `.gitignore` | **Append a marked block** | Only the harness-specific half (PRE-8) |
| `package.json` | **No** | Verified: no runtime reader. Only `bump-version.sh` (stripped) and `constitutional-check.sh:404`, which merely detects presence |
| `tests/` | **No** | Verified: 0 `*.test.js`, 38 `*.sh`; no hook or command references `tests/`. Tests the *harness*, which the adopter did not modify |
| `.github/workflows/**` | **No** (all five) | Four are maintainer-only and one — `branch-topology-guard.yml` — actively breaks the project (PRE-3) |
| `README.md`, `START_HERE.md`, `TEMPLATE_INIT.md`, `KNOWN_ISSUES.md`, `init-project.sh`, `fix-line-endings.sh` | **No** | Template-clone onboarding; meaningless mid-project |
| `.mcp.json`, `.editorconfig`, `.gitattributes`, `.pylintrc`, `.env.example` | **No** | Opinionated project config, none load-bearing |
| `VISION.md` | **No** | Ships as a stub for `/initialize-project` to fill; an adopter has their own product direction |
| `features/`, `specs/` (`.gitkeep` only) | **Yes** | Workflow packs write here |
| `.docs/policies/`, `.docs/architecture/` | **Yes** | Contract docs the shipped scripts cite by path |

**STATUS (2026-08-27): encoded as a reviewable proposal, not a settled decision.**
The table above is now `packaging/adopt/payload-manifest.txt` — same rows,
verb-per-line grammar, evidence inline, one file to edit to overrule it.
`tests/contract/test_adopt_payload_manifest.sh` holds the boundary. Re-deriving
each row against the repo changed six of them:

1. **`tests/` — the evidence line above is wrong.** "no hook or command
   references `tests/`" is false. Three *shipped* surfaces invoke the suite by
   path: `plugins/loom-git/commands/finalize.md:30`,
   `plugins/loom-git/skills/finalize/SKILL.md:45`, and
   `plugins/loom-maintenance/skills/framework-updater/SKILL.md:210`, all
   `bash tests/run_all_tests.sh`. The decision (exclude) stands; the named limit
   grows — `/finalize` and `/update-framework` will point an adopter at a suite
   that is not there. Fix the call sites or ship the suite before Phase 1 closes.
2. **`features/`, `specs/` are not `.gitkeep` only.** Each also tracks a
   `README.md`, and `features/README.md` is cited by name from CLAUDE.md's
   "See Also". Ship all four files.
3. **`.claude/agents/` was missing from the table** and is load-bearing —
   `constitutional-check.sh:662` scans it, `create-agent.sh:17` writes into it,
   `create-skill-command.sh:329` resolves out of it. Include.
4. **`.claude/policies/tool-restrictions.json` was missing** and is read at
   runtime by `.logic-loom/lib/policy.sh:15`. Include. (`.claude/schemas/` has no
   reader — included anyway as cheap documentation; `.claude/statusline.sh` is
   excluded, reachable only via the `statusLine` key the merge does not touch.)
5. **`.logic-loom/` needs three carve-outs** the row omitted, contradicting PRE-5:
   `update-agent-context.sh` (CLAUDE.md truncation — now being deleted upstream),
   `check-generated-freshness.sh` (PRE-5's open decision, resolved: exclude — it
   regenerates an artifact the payload never ships), and `.logic-loom/tests/`.
6. **`CLAUDE.md` was absent from the table entirely.** PRE-7 answers it
   (`.claude/rules/` split), but that is authorship, not a copy — `.claude/rules/`
   does not exist yet. Recorded as a `defer:` line; the installer must refuse to
   run while it stands.

**Named limit:** dropping `tests/` means an adopter who later edits the harness
(via `/create-plugin`, say) has no local regression suite. That is the right
default — but say it in the adopt output, and point at cloning LogicLoom for
harness development.

### PRE-2 · npm identity — **BLOCKING**

**Checked today, 2026-08-26, by fetching `https://registry.npmjs.org/<name>`:**

| Name | Status | Meaning |
|---|---|---|
| `logic-loom` | **404** | Unpublished |
| `logicloom` | **404** | Unpublished |
| `logicloom-cli` | **404** | Unpublished |
| `create-logic-loom` | **404** | Unpublished |
| `create-logicloom` | **404** | Unpublished |
| `@logicloom/cli` | **404** | Unpublished |
| `@logic-loom/adopt` | **404** | Unpublished |
| `@kelleysd/test` | **404** | Unpublished |
| `husky`, `shadcn`, `@biomejs/biome`, `create-vite` *(controls)* | **200** | Method distinguishes taken from free |

The controls matter: a uniform 404 could have meant the method was broken. It
isn't.

**UNVERIFIED — and this is the trap:** a 404 on `@logicloom/cli` proves the
*package* is unpublished. It does **not** prove the **scope** `@logicloom` is
unclaimed — npm returns 404 for an unpublished package under someone else's org
too. Registry search returns zero packages under `@logicloom/`, `@logic-loom/`
and `@kelleysd/`, which again proves nothing published, not scope ownership.

**Two probes that do NOT work, recorded so nobody repeats them:**
`https://registry.npmjs.org/-/org/<name>/package` returns an empty body; and
`https://www.npmjs.com/org/<name>` returns **403 for every name, including
`loomhq`, a scope that demonstrably exists** — npmjs.com blocks non-browser
clients, so that probe is worthless.

**Confirm instead by:** `npm org ls logicloom` while authenticated (errors if you
are not a member), or attempt `npm publish --access public` and read the error —
**`E404 Scope not found` means available; `E403` means held by someone else.**
Both are maintainer actions, not mine to take.

**This is why I recommend the unscoped name.** `logic-loom-adopt` needs no org, no
`--access public`, and its availability is *provable* by the check above.

### PRE-3 · Confirm the four maintainer workflows are excluded — **BLOCKING**

Verified today: `git ls-tree -r --name-only origin/main .github/` returns all five
workflows. `branch-topology-guard.yml` is not merely noise — per
`update-framework.md` and `initialize-project` step 7, it "fails **every** PR into
`main` whose head branch is not `release/vX.Y.Z`". Shipping it into an adopter's
repo breaks their pull requests on day one.

`plugin-tests.yml` triggers on bare `on: push` / `on: pull_request` and runs the
harness's bash contract suite. With `tests/` excluded (PRE-1) it would fail
immediately. Exclude all five; revisit as an opt-in target later.

### PRE-4 · Confirm the payload source is a tag on `main`, never `dev-main` — **BLOCKING**

Settled by §3. Recording it as a prerequisite because it is the item most likely
to be "simplified" during implementation, and doing so silently breaks
`/update-framework` for every adopter at once. Encode it as a workflow assertion,
not a convention: the publish job should fail if `GITHUB_REF` is not
`refs/tags/v*`.

### PRE-5 · Repair or exclude the scripts that treat "whatever repo I'm in" as LogicLoom

This is the concrete answer to the brief's "does anything assume it was cloned".
Verified by direct read; each is a real hazard in a foreign repo.

**Exclude from the payload (destructive or nonsensical outside LogicLoom):**

- `strip-harness-dev.sh:35` — `TRACKED="$(git ls-files)"` then deletes/stubs
  matches. In an adopter's repo `git ls-files` is *their* corpus. Already stripped
  at release, so this is free — just confirm.
- `leak-guard.sh:37-44` — same `git ls-files` scan, for LogicLoom identity markers.
  Already stripped.
- `check-generated-freshness.sh:320` — refuses outside a git work tree and
  regenerates `artifacts/backlog-dashboard.html`, which the payload does not ship.
  **Not** currently stripped; needs a decision.
- `update-agent-context.sh` — **the sharpest edge, and I verified it.** Line 3
  `REPO_ROOT=$(git rev-parse --show-toplevel)` under `set -e`, and line 7
  `CLAUDE_FILE="$REPO_ROOT/CLAUDE.md"`. Its update-existing branch merges via
  python3, then falls through to an unconditional
  `mv "$temp_file" "$target_file" 2>/dev/null || true`, where `$temp_file` is an
  `mktemp` that branch never wrote to — **truncating `CLAUDE.md` to zero bytes.**
  It also has a latent path bug: it tests
  `-f "$REPO_ROOT/.logic-loom/templates/agent-file-template.md"` but copies
  `"$REPO_ROOT/templates/agent-file-template.md"`.
  **Mitigating fact, also verified:** nothing calls it. I grepped `.claude`,
  `.logic-loom`, `plugins`, `tests`, `.github` and the root docs — the only hits
  are a prose mention in `.claude/context/workflows.md:376` and its cache. So this
  is **latent, not live**. Exclude it from the payload; consider deleting it
  upstream as dead code.

**Accept as-is (verified graceful):**

- `check-dev-branch-base.sh` — runs no git at all, reads refs off the filesystem,
  and `:185` goes silent unless *both* `main` and `dev-main` exist. Structurally
  inert in an adopter's repo. This is the model the others should follow.
- `worktree-port-namespace.sh:43,54` — `|| emit_noop` on every git call.
- `extract-proposals.sh:148-154` — a missing sync-ref baselines at upstream tip,
  emits `[]`, exits 0.

**Accept with a named limit:**

- `extract-proposals.sh:100` hardcodes `+refs/heads/main:...`, so an upstream whose
  default branch is not `main` fails. Fine for LogicLoom; note it.
- `common.sh:11` —
  `REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"`.
  From `.logic-loom/scripts/bash/`, `../..` is `.logic-loom/`, **not** the repo
  root — the fallback is off by one level and five other scripts copy it. It only
  works because `git rev-parse` normally wins. Harmless for a root install in a
  git repo (which is the only supported case), but it is a landmine if anyone ever
  tries a nested install. Worth fixing regardless; it is a one-line change.

### PRE-6 · Decide the `AGENTS.md` collision

`AGENTS.md` is an increasingly common cross-agent convention, so an adopter
plausibly has one. LogicLoom's is a registry with `**Version**: 6.5.0` — a
`bump-version.sh` stamp site, so it cannot simply be appended to theirs without
breaking the stamp.

Recommendation: install as `.logic-loom/AGENTS.md` and reference it from the
`.claude/rules/` file (PRE-7). Never write repo-root `AGENTS.md`.

### PRE-7 · Design the two merges

**`.claude/rules/` — the non-merge, and the best news in this document.** Verified
against code.claude.com/docs/en/memory (2026-08-26): rules files without `paths:`
frontmatter "are loaded at launch with the same priority as `.claude/CLAUDE.md`",
and CLAUDE.md supports `@path` imports (relative to the containing file, max depth
4). So harness instructions install as *new files* — e.g.
`.claude/rules/logicloom-governance.md`, `…-workflow.md` — and the adopter's
`CLAUDE.md` is never opened. Zero collision, trivially reversible.

Note the docs' guidance to target under 200 lines per file: the current
`CLAUDE.md` is far longer, so this is a split-and-condense job, not a copy. Budget
for it — this is content work, not scripting.

**`.claude/settings.json` — the one real merge.** The adopter may already have
hooks. All 12 LogicLoom entries are cwd-relative (`bash .logic-loom/…`,
`bash plugins/loom-governance/…`), which is correct for a root install and is the
reason nesting is unsupported. Requirements: additive merge into the existing
`hooks` object; a marker so a re-run is idempotent; and never remove an entry the
adopter added. Hooks compose most-restrictive, so adding LogicLoom's cannot weaken
theirs.

The precedent for the *care level* is husky's `init`, which edits the consumer's
`package.json` and sniffs the existing tab-vs-2-space indentation to avoid
reformatting a file it does not own. Match that: preserve the adopter's formatting,
touch only the keys you add.

This is also the file that would carry `extraKnownMarketplaces` /
`enabledPlugins` if the marketplace idea from §2 is ever taken up — one more
reason to build the merge properly rather than as a one-off JSON splice.

### PRE-8 · Split the `.gitignore`

Do not copy it. `origin/main:.gitignore` is 189 lines and its top third is
hostile to a real project — it ignores `package-lock.json`, `dist/`, `build/`,
`coverage/`, `.vscode/`. Its bottom two-thirds are harness-specific and necessary:
`.logic-loom/logs/…`, `.loom-memory-index/`, `plugins/loom-memory/working/`,
`.logic-loom/backlog-index.json`, `.logic-loom/state/`.

Append **only** the harness block, inside a marked fence. Note that
`tests/contract/test_backlog_index.sh:441-453` asserts the index is invisible to
`git status` under this ignore rule, so the block is load-bearing, not cosmetic.

### PRE-9 · Extend the workflow-removal tandem to five

Per §5. Update `init-project.sh:509`, `project-initialization/SKILL.md:295-298`,
`initialize-project.md`, **and** `EXPECTED_WF` in
`test_shipped_gates_vs_strip.sh:433-437`. All four in the same commit — the test
fails otherwise, which is the point.

### PRE-10 · Add the strip-manifest entry for `packaging/`

One line in `template-strip-manifest.txt`. Note its own warning: "**A MISSING
ENTRY SHIPS THE FILE VERBATIM.**"

### PRE-11 · Resolve the npm auth question — smaller than expected

**Checked today at docs.npmjs.com/trusted-publishers:** npm supports **trusted
publishing via OIDC from GitHub Actions**, using "short-lived,
cryptographically-signed tokens that are specific to your workflow and cannot be
extracted or reused". Requirements quoted: **npm CLI ≥ 11.5.1**, **Node ≥
22.14.0**, `permissions: id-token: write` in the workflow, and a trusted publisher
configured on npmjs.com naming org/user, repository, and **workflow filename**.

**So no long-lived npm token in repo secrets is needed** — which removes what the
brief reasonably assumed would be a prerequisite.

**UNVERIFIED, and it matters for sequencing:** the docs do not state whether
trusted publishing works for the *first ever* publish of a name that does not yet
exist. The configuration flow is described as visiting "your package settings",
which implies the package must exist first. **Recommended path that is correct
either way:** one manual `npm publish` from the maintainer's machine to create the
name, then configure the trusted publisher, then let CI handle every subsequent
release. Confirm the first-publish question by attempting to add a trusted
publisher for an unpublished name on npmjs.com.

**Three further constraints, all verified at the same page:**

- **Self-hosted runners are explicitly excluded.** Supported CI is "GitHub Actions
  (GitHub-hosted runners), GitLab CI/CD Pipelines (GitLab.com shared runners), and
  CircleCI (CircleCI cloud)". LogicLoom's workflows are all `runs-on:
  ubuntu-latest`, so this is satisfied — but it forecloses moving the publish job
  to a self-hosted runner later.
- **The May 2026 cutover applies to you.** "Configurations created before May 20,
  2026 are automatically set to allow `npm publish` only… Configurations created
  after May 20, 2026 require you to explicitly select at least one allowed
  action." Any config created now must explicitly select the allowed action —
  omitting it is a silent misconfiguration, not an error at setup time.
- **The workflow filename is part of the binding.** Renaming `publish-adopt.yml`
  later breaks publishing until the trusted-publisher config is updated.

**Still UNVERIFIED:** whether classic automation tokens have been sunset in favour
of granular access tokens. Irrelevant if trusted publishing is used for everything
after the first manual publish, but confirm at docs.npmjs.com/about-access-tokens
if you need a token for that first publish.

### PRE-12 · Confirm the CI runner satisfies the npm/Node floor

**Verified in-repo (2026-08-27):** `.github/workflows/plugin-tests.yml:16` and
`.github/workflows/promote-to-main.yml:73` both pin `node-version: '20'`; root
`package.json:31-34` declares `engines.node >= 18.0.0`.

**VERIFIED 2026-08-27** against <https://docs.npmjs.com/trusted-publishers>, the
primary source, which states verbatim: *"Trusted publishing requires npm CLI
version 11.5.1 or later and Node version 22.14.0 or higher."* So the floor is
**Node ≥ 22.14.0 / npm CLI ≥ 11.5.1**.

**Also verified, and previously unrecorded — GitHub-hosted runners only.** The
same page states: *"Self-hosted runners are not currently supported but are
planned for future releases."* Every workflow in this repo is
`runs-on: ubuntu-latest`, so we satisfy this today. It is recorded because a
future move to self-hosted runners would break publishing silently — nothing
in-repo would flag it.

These figures will move. Re-check with:

```
curl -s https://docs.npmjs.com/trusted-publishers | grep -iE 'node|npm .?[0-9]+\.|self-hosted'
```

**Decision: do not bump the existing workflows.** Neither publishes, so raising
their floor for an unrelated reason is churn. The requirement is instead recorded
in the header of `packaging/adopt/payload-manifest.txt`, where whoever writes
`publish-adopt.yml` will be reading the payload boundary anyway;
`test_adopt_payload_manifest.sh` asserts that note still exists, still carries
its VERIFIED date and source URL, and still names a re-check command — so it can
neither be promoted to unsourced fact nor rot silently when npm moves the floor. The trap it closes:
`publish-adopt.yml` must carry its **own** `actions/setup-node`, because copying
a step from either existing workflow silently gives it Node 20.

### PRE-13 · Decide what the adopter runs *after* install

`/initialize-project` assumes a fresh template clone: it stamps `project.conf`,
rewrites `README.md`, scaffolds `web/`, and deletes workflows the payload never
shipped. Most of that is wrong for an adopter. Either gate those steps on a
detected-adoption marker, or give adopt its own narrower post-install step
(identity stamp + gate posture only). **Do not** point adopters at
`/initialize-project` as-is.

Specifically flagged: `init-project.sh:230-236` guards `mv README.md
FRAMEWORK_README.md` on `[ ! -f "FRAMEWORK_README.md" ]` but then runs
`cat > README.md` **unconditionally**. On a re-run, or where the adopter happens to
have a `FRAMEWORK_README.md`, their `README.md` is destroyed with no backup.
Verified by reading the lines. The adopt path must not inherit this.

### PRE-14 · Decide the uninstall story

Every file the installer writes should be listed in a manifest it leaves behind,
so removal is mechanical. The `/scaffold-environments` marker convention
(`LOOM-SCAFFOLD-MARKER:`) is the pattern; extend it rather than invent one. Decide
now — retrofitting an uninstall onto merged files is much harder than recording
what you wrote as you write it.

---

## 7. What this does not solve

Named plainly, in the house style, because a design that hides its limits gets
believed and then disappoints.

1. **It does not make governance portable.** The hook floor is the Claude Code
   reference adapter. Adoption installs hooks that work in Claude Code and nowhere
   else. An adopter using another agent gets *followed-only* policy, exactly as
   `governance-threat-model.md` already says.

2. **It does not merge philosophies.** A project with its own `CLAUDE.md`
   conventions now has two sets of instructions loaded simultaneously. The docs
   warn: "if two rules contradict each other, Claude may pick one arbitrarily."
   Nothing detects that. The adopt output should say so.

3. **It does not give the adopter the harness's own tests.** Consequence of PRE-1.
   They can adopt LogicLoom; they cannot verify LogicLoom without cloning it.

4. **It does not solve nested installation, and should not try.** All 12 hook
   commands are cwd-relative and the plugin guards resolve `$SCRIPT_DIR/../../../..`
   to reach `.logic-loom/lib/governance-verdicts.sh`. A monorepo that wants
   LogicLoom in one workspace only is out of scope. **Refuse loudly** rather than
   install something whose governance layer is silently inert — that failure mode
   is worse than not installing.

5. **It does not survive a hostile pre-existing `.claude/settings.json`.** Merge
   handles additive cases. An adopter with a conflicting `permissions.deny` or a
   hook that exits non-zero on every Bash call will fight the floor. Detect and
   report; do not resolve.

6. **It does not change `/update-framework`'s conflict burden.** An adopter who
   customises a governance file gets `conflict-review` on every future update,
   same as any cloner. Adoption arguably *increases* this, since adopters are more
   likely to customise.

7. **It does not address Windows, and the exposure is now precisely located.**
   Not the executable bit — that is solved (§2c). The cliff is that **the whole
   harness is bash**: every one of the 12 hooks is `bash <path>`, so LogicLoom on
   Windows already requires Git Bash or WSL, adoption or not. What adoption adds
   is a **line-ending** exposure: `START_HERE.md:333` carries a CRLF remediation
   for Windows clones, and npm's `bin-links` performs its `dos2Unix` fixup **only
   on `bin` targets** — not on the vendored payload. With no `init-project.sh`
   running afterwards to `sed -i 's/\r$//'`, a Windows adopter can end up with
   CRLF hook scripts that fail obscurely. Mitigate by packing LF-only and shipping
   the payload with a `.gitattributes`-independent guarantee, or state Windows as
   unsupported for adoption. **Currently untested and unclaimed.**

### The part I recommend not building

**Do not build a `--force` flag, and do not build conflict auto-resolution.**
`/scaffold-environments` deliberately has neither, and its skill states why: the
failure it prevents is "overwrite a hand-written deploy script with a
placeholder". The adopt CLI faces the same risk against higher-value files. If a
merge is ambiguous, print the delta and stop. The user has a git repo; they can
resolve it better than a heuristic can.

**Do not build the fetcher variant as an option.** Two code paths mean the rarely
used one is the broken one, and it is the one that reintroduces the sync-ref
hazard.

---

## 8. Phased estimate

Sized in maintainer-days at this repo's evident standard — argued decisions,
contract tests, docs updated in tandem. Not keystrokes.

| Phase | Scope | Est. | Delivers value alone? |
|---|---|---|---|
| **0 · Prerequisites** | PRE-1 through PRE-6, PRE-9, PRE-10. Decisions, exclusions, dead-code removal, tandem extension. **No CLI written.** | 1.5–2 d | **Yes** — see below |
| **1 · Local adopt, no publishing** | Node `bin` + detect/plan/apply, the two merges (PRE-7, PRE-8), payload assembly, marker manifest, uninstall list (PRE-14). Run via `npm pack` + local install. | 3–4 d | **Yes — this is the value phase** |
| **2 · Publish** | `packaging/adopt/`, `publish-adopt.yml` on `release: published`, trusted publisher (PRE-11), Node floor (PRE-12), first manual publish. | 1–1.5 d | No — plumbing for Phase 1 |
| **3 · Post-install + docs** | Adoption-aware initialize path (PRE-13), `README.md:18` rewritten, `START_HERE.md`, contract test for the payload boundary. | 1.5–2 d | Partly |

**Total: 7–9.5 maintainer-days.**

### Which phase delivers value alone

**Phase 1** — unambiguously. At its end you can adopt LogicLoom into a real
project by hand (`npm pack`, `npx ./logic-loom-adopt-*.tgz`), which is the entire
capability. Publishing is convenience.

**But Phase 0 also delivers alone, and this is the argument for doing it first
even if the package is never built.** It removes a dead script that truncates
`CLAUDE.md` if anyone ever calls it, fixes an off-by-one in the root-derivation
used by six scripts, corrects a documented stamp-site count, and forces the
payload-boundary decision into the open. Every one of those is a latent defect in
the harness *today*, independent of adoption.

### Recommended sequencing

Phase 0 → Phase 1 → **stop and adopt into one real project** → then 2 and 3. Do
not publish to npm before an adoption has actually been performed by hand. The
name is claimable at leisure; a bad first published version is not retractable
(npm unpublish is heavily restricted), and the payload-boundary decision in PRE-1
is exactly the kind that only survives contact with a real repository.

---

## 9. Verification ledger

**Verified first-hand today (2026-08-26):**

| Claim | How |
|---|---|
| `origin/main` = 358 files, 2.82 MB | `git ls-tree -r -l origin/main` |
| `main:.sdd-sync-ref` = `28ef9d8` = `release: v6.5.0 sanitized template` | `git show` + `git log -1` |
| All 12 hooks invoke via `bash <path>`; none need `+x` | `grep -c '"command": "bash '` on `main:.claude/settings.json` |
| `tests/` has 0 `*.test.js`, 38 `*.sh` | `find tests -name …` |
| Root `package.json` has no runtime reader | grep of `.claude/hooks`, `.logic-loom/scripts/bash`, `plugins/*/hooks`, `plugins/*/scripts` |
| `update-agent-context.sh` has no caller | grep of `.claude`, `.logic-loom`, `plugins`, `tests`, `.github`, root docs |
| `init-project.sh` unconditional `cat > README.md` | read of lines 228–240 |
| `bump-version.sh` = 13 sites / 9 files | read of `SITES` list, lines 32–50 |
| Tandem test asserts exactly four workflows | read of `test_shipped_gates_vs_strip.sh:429-464` |
| npm: 8 candidate names all 404; `husky`/`shadcn`/`@biomejs/biome`/`create-vite` all 200 | fetched `registry.npmjs.org/<name>` |
| npm trusted publishing / OIDC exists; npm ≥ 11.5.1, Node ≥ 22.14.0, `id-token: write`; self-hosted runners excluded; post-2026-05-20 configs must select an allowed action | fetched docs.npmjs.com/trusted-publishers |
| GitHub Packages: "You need an access token to publish, install, and delete private, internal, and public packages" | fetched docs.github.com working-with-the-npm-registry |
| `release` event `GITHUB_REF` = `refs/tags/<tag_name>` | fetched docs.github.com events-that-trigger-workflows |
| `.claude/rules/*.md` load at launch; CLAUDE.md `@path` imports, depth 4 | fetched code.claude.com/docs/en/memory |
| Claude Code plugins cache at `~/.claude/plugins/cache`; `extraKnownMarketplaces`/`enabledPlugins` are repo-scoped in `.claude/settings.json` | fetched code.claude.com/docs/en/plugins + /plugin-marketplaces |
| `shadcn@4.19.0` = 27 files, all `dist/`; registry fetched at run time from `ui.shadcn.com/r`, 200 anonymously | tarball unpacked + registry fetched |
| `bats@1.13.0` = 31 files, 100% bash; `libexec/…/bats` installs `-rwxr-xr-x` though not a `bin` target | tarball unpacked + `npm i` in a clean dir |
| npm `bin-links/lib/fix-bin.js` chmods `bin` targets to `0o777 & ~umask` and does CRLF→LF | source read |
| `husky@9.1.7` sets `core.hooksPath`, does not write `.git/hooks`; `init` edits consumer `package.json` preserving indentation | source read |
| anonymous `api.github.com` = 60 req/hr **per IP**; codeload/raw return no `x-ratelimit-*` headers; `releases/latest/download/` is a 302, not an API call | docs.github.com REST rate limits + anonymous requests |
| `npm init foo` → `create-foo`; `npm init @usr/foo` → `@usr/create-foo`; `npm init @usr` → `@usr/create` | docs.npmjs.com/cli/v11/commands/npm-init |

**UNVERIFIED — confirm before relying on:**

| Claim | How to confirm |
|---|---|
| npm **scope** `@logicloom` is unclaimed (only the *package* 404 is proven) | `npm org ls logicloom` while authenticated; or `npm publish --access public` and read the error — `E404 Scope not found` = available, `E403` = held |
| Trusted publishing works for a brand-new, never-published name | Attempt to add a trusted publisher for an unpublished name on npmjs.com; otherwise publish once manually, which the recommended sequencing does anyway |
| Whether a `release`-triggered workflow must also exist on the default branch | Cut a throwaway pre-release and observe. Moot here — the tag is on `main`, which is the default branch |
| Whether classic npm automation tokens are sunset in favour of granular tokens | docs.npmjs.com/about-access-tokens. Only matters for the one manual first publish |
| Contents of Biome's generated `biome.json` | Run `npx @biomejs/biome init` in a scratch dir. Cosmetic; affects nothing here |
| Windows CRLF behaviour for the *vendored* payload (npm's `dos2Unix` covers only `bin` targets) | `npm pack`, extract on Windows, inspect a `.sh` payload file's line endings |

---

**Bottom line.** The mechanism is npm/`npx`, vendored, versioned off the tag,
published on the Publish click. None of that is hard. What is hard — and what
should be done first, and is worth doing even if the package is never built — is
deciding what the payload *is*, and repairing the handful of scripts that
currently assume the repository they are standing in is LogicLoom's own.
