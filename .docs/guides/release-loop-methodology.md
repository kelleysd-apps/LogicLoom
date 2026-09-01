# The dev-line → sanitized-release-line methodology

**Version**: 1.0.0
**Effective Date**: 2026-09-01
**Authority**: companion to `.docs/policies/environment-promotion-policy.md` —
same voice, same evidence grading, same honesty about what is enforced versus
what is followed.
**Audience**: an adopter who wants to build their own version of the pattern
LogicLoom uses to release itself. This guide is READ material, not shipped
machinery — see § 6.

---

## Purpose

LogicLoom releases itself with a two-line branch model: a development line
that carries everything, including material that must never reach a
downstream consumer, and a release line that a downstream consumer actually
clones or `npm install`s. The gap between those two lines is not closed by
convention — it is closed by a build, gated by an audit, and recorded by a
single-parent commit whose shape makes the gap provable rather than merely
asserted.

This document describes that pattern in prose so you can build your own
version of it for your own project. It names what the two lines are for, why
the snapshot commit is single-parent, what a sanitization audit actually has
to check, and what a version-pointer file like `.sdd-sync-ref` buys an update
mechanism. **LogicLoom ships none of this as reusable machinery.** The
workflow that does it for our own repository is maintainer-only and is
deliberately excluded from every payload — a template clone gets it removed by
`/initialize-project`, and the npm adopt payload never included it (see § 6).
What you get from this guide is the shape, not the script.

---

## Evidence grading — read the labels

Same three labels `environment-promotion-policy.md` uses, because the claims
in this document carry the same kind of weight and deserve the same caveat:

| Label | Meaning |
|---|---|
| **VERIFIED** | Observed running in LogicLoom's own release pipeline. Not aspirational. |
| **RECOMMENDED** | A pattern worth adopting that LogicLoom's own pipeline does not fully generalize either — a target shape, not a guarantee. |
| **UNSOLVED** | A known gap in the pattern itself. Do not copy it forward as a design choice. |

A reader who treats every claim below as equally load-bearing will build the
wrong thing. Read the label before the sentence.

---

## 1. Why two branch lines, not one

**VERIFIED — this is the actual reason LogicLoom has this problem at all.**
A development line accumulates things a released consumer must never see:
internal history, credentials-adjacent scratch files, design documents that
name real infrastructure, work-in-progress that names people or unreleased
plans. None of that is a defect in the development line — it is supposed to
be there, because a development line's job is to let people work honestly.
The release line's job is different: it is the *only* thing a downstream
consumer ever reads, so anything reachable from it — including through git
history, not just the working tree — is a promise you are making to a
stranger.

A single branch cannot honor both jobs at once. Sanitizing a shared branch in
place would mean either scrubbing the development line as you go (which
defeats the point of having one) or trusting a human to remember what to
scrub on every merge into the release line (which does not scale past the
first missed reminder). Two lines exist so that sanitization is a
**publication step**, run once per release, rather than a standing tax on
every commit.

**RECOMMENDED for your project.** If you have no material that a
released-line reader must never see — no internal-only design docs, no
scratch credentials, nothing that would embarrass or expose you if someone
ran `git log -p` on your public history — you do not need this pattern at
all. One branch is the right answer for most projects. Reach for a second
line only when the material that must not travel is real, not hypothetical.

---

## 2. What the snapshot build actually has to do

**VERIFIED.** Four steps, in this order, and the order is load-bearing:

1. **Strip.** Remove entire paths that must never exist on the release line —
   maintainer-only scripts, internal design records, anything a
   strip-manifest names outright. This is a *removal* step: the release
   line's working tree, after this step, simply does not contain those
   paths.
2. **Sanitize.** Rewrite what remains — replace real identifiers,
   organization names, internal URLs, and machine-specific paths with
   placeholders or generic values. This is a *rewrite* step: paths survive,
   content changes.
3. **Audit.** Re-scan the stripped-and-sanitized tree and fail the build if
   anything the first two steps should have caught is still present. The
   audit runs **twice** in LogicLoom's own pipeline — once against the
   unsanitized development line (to catch a problem at its source, where a
   human can fix it directly) and once against the sanitized output (to
   prove the fix actually worked) — and the second pass is the one that can
   block a release. A step that only *removes and rewrites* without a
   step that *checks its own output* is trusting the first two steps never
   to have a gap, which is not a bet worth making twice a month.
4. **Compose.** Build the release-line commit from the audited tree. This is
   where the single-parent property (§ 3) gets set, and it has to happen
   *after* the audit, not before — composing first and auditing the compose
   result is equivalent, but auditing the intermediate stripped-and-sanitized
   tree before it becomes a commit gives you one more chance to abort before
   anything is written to the release line at all.

**RECOMMENDED for your project.** Your audit does not need seven checks —
LogicLoom's has that many because it accumulated them one incident at a time,
and § 7 of `environment-promotion-policy.md` makes the same point about not
inheriting an incident history you have not had yet. Start with the checks
that map to material you actually have (a marker string for your
organization's internal name is the cheapest one to write and the first one
worth having), and add more the way LogicLoom did: after something almost
leaked and you write the check that would have caught it.

---

## 3. Why the release commit is single-parent

**VERIFIED, and the sharpest edge in the whole pattern.** The release-line
commit's *only* git parent is the previous release-line commit. The
development line is never a git parent of it — not via a merge commit, not
via any ancestry relationship at all. Provenance (which development-line
commit produced this release) is recorded as a **string** in the commit
message trailer, never as an object reference.

Why this matters more than it looks like it should: git history is content.
`git show <sha>:<path>` reaches any blob reachable from any ancestor of the
commit you're standing on, including through a merge parent nobody looks at
directly. If the release-line commit had the development-line commit as a
parent — even via an otherwise-harmless merge — then every "stripped" file
would be one `git show` away from anyone who cloned the release line, because
the object is still in the repository's object database and still reachable
from a ref they can see. Stripping the *working tree* is not the same as
making the content *unreachable*. Only breaking the parent chain does that.

A trailer string breaks that chain on purpose: a reader can see which
development-line commit a release corresponds to (for support, for debugging,
for an update mechanism — see § 4) without that commit or anything it
touches being reachable from the release line's own history.

**RECOMMENDED for your project, without qualification.** This is the one
piece of this pattern that is not a judgment call. If you build a two-line
release model and skip this property, you have built something that *looks*
sanitized in the working tree while silently shipping the exact thing you
built the second line to avoid. Get this right before anything else in this
document.

---

## 4. What a version-pointer file buys an update mechanism

**VERIFIED.** LogicLoom's release line carries a small file
(`.sdd-sync-ref` in our own repository — the name is historical and not
significant) holding one thing: the development-line commit SHA that
produced the currently-released tree. An update command reads that pointer,
diffs the development line between the pointed-at SHA and its current tip,
and proposes only what changed in that window — not a diff against the whole
development history, which the release-line reader was never supposed to see
in the first place, and not a diff against nothing, which would propose
re-applying everything on every run.

The mechanism this buys you: **selective, incremental adoption of upstream
change**, computed from a real ancestry pointer rather than from a guess or a
full re-diff. Without the pointer, an update tool either has to diff against
the entire development history (exposing exactly what § 3 exists to hide) or
has no reliable way to know what "new since last time" means at all.

**RECOMMENDED for your project, conditionally.** You only need this if you
expect the release line to be updated more than once and want consumers to
be able to pull forward incrementally. A one-shot release with no update
story does not need a pointer file — it needs nothing more than the snapshot
itself. Add the pointer the moment you plan a second release.

---

## 5. What this pattern does not solve

**UNSOLVED, named so you do not copy the gap forward as if it were a design
choice.**

- **The audit is only as complete as its check list.** A sanitization audit
  proves the tree passes the checks that exist. It proves nothing about a
  leak shape nobody has written a check for yet. Treat every new incident as
  a new check, the way § 2 describes — never treat a clean audit run as proof
  the tree is clean in some absolute sense.
- **The human approval gate is the actual backstop, and it lives outside the
  build.** LogicLoom's own pipeline requires a human reviewer on the
  environment that can publish to the release line, precisely because CI
  hooks that gate local git operations do not run inside CI itself. If your
  release build runs unattended with no equivalent required-reviewer gate,
  the audit is the only thing standing between a bug in the strip/sanitize
  step and a public leak. That is a real risk, not a hypothetical one — say
  so in your own documentation rather than presenting the audit as
  sufficient on its own.
- **This pattern says nothing about what should be in each line.** That is a
  product decision unique to your project, the same way LOOM-0050's decision
  about which of LogicLoom's own workflows to template and which to withhold
  was a maintainer decision, not a derivation from this pattern.

---

## 6. What LogicLoom ships, and what it does not

**Nothing in this document is enforced by any hook, script, or CI job that
ships to an adopter.** This is prose methodology, the same posture
`environment-promotion-policy.md` takes for the environment-promotion
pattern it documents, and for the identical reason: the *pattern* travels:
the *machinery that implements it for LogicLoom's own repository* does not,
because that machinery names LogicLoom's own topology — our branch names,
our repository, our tag conventions, our version-pointer mechanics — and
installing it unasked into an adopter's `.github/` would be writing into
territory that is entirely theirs (see the CI-methodology offer step in
`/initialize-project`, which asks before writing anything there and writes
nothing if declined).

What LogicLoom *does* ship, adapted rather than copied verbatim, is three
narrower CI *gates* that a release line commonly wants regardless of whether
you build the full two-line pattern above — under
`.logic-loom/templates/workflows/`:

| Template | What it guards | Needs the full two-line pattern? |
|---|---|---|
| `plugin-tests.yml.template` | Your own test suite runs on push/PR | No — useful for any project |
| `leak-guard.yml.template` | PR content against a configured marker list | No — useful for any project with *any* string that must never be committed |
| `branch-topology-guard.yml.template` | PR provenance — head branch matches an allowed pattern | Yes — only meaningful if you have a real process the branch name is supposed to prove was followed |

`promote-to-main.yml`, `release-tag.yml`, and `publish-adopt.yml` — the
workflows that actually *run* LogicLoom's own build/audit/compose/publish
cycle — are **not** templated. They are maintainer-only in a way the three
gates above are not: they name our repository, our tag scheme, and our
version-pointer file directly, and adapting them file-by-file would produce
something that looks installable but silently assumes our topology in a
dozen small places. Use §§ 2–4 above to build your own version instead of
starting from ours.

---

## References

- `.docs/policies/environment-promotion-policy.md` — the sibling document
  for the deploy-time promotion problem (dev → staging → prod), same
  evidence-grading convention.
- `.logic-loom/templates/workflows/` — the three adapted CI gate templates
  this guide's § 6 table describes.
- `plugins/loom-maintenance/commands/initialize-project.md` — the
  "offer, adapt, never install unprompted" step that surfaces these
  templates to an adopter.

---

## Version History

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-09-01 | Initial version (LOOM-0050). |
