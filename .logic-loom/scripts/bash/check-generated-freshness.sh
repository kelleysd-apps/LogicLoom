#!/usr/bin/env bash
# check-generated-freshness.sh — FAIL-CLOSED staleness gate for the repo's
# git-TRACKED generated artifacts.
#
# Regenerates each tracked derived artifact into a scratch directory and fails if
# the committed copy differs. Writes NOTHING into the repo. Runs NO git that
# mutates anything. Exit 0 = every tracked artifact is current.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS EXISTS
# ─────────────────────────────────────────────────────────────────────────────
# A tracked derived artifact diverges from its sources the moment someone edits a
# source without regenerating. This repo has been bitten by that class three
# times (dead scrub rules, four orphaned test suites, a manifest advertising a
# stripped command). Two of those three had a WARN-ONLY lint pointed at them and
# still shipped — a warning is a suggestion, and drift accumulates behind it.
# The only mechanism that holds is regenerate-and-diff, failing the build.
#
# So: tracking a derived artifact is allowed here ONLY while this gate covers it.
# If you add a tracked generated file, add it to this script in the same change.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY A SEPARATE SCRIPT AND NOT A `--check` MODE ON EACH GENERATOR
# ─────────────────────────────────────────────────────────────────────────────
# build-backlog-dashboard.sh is FAIL-OPEN by explicit contract — it documents "a
# viewer generator must not gate a workflow" and exits 0 on a missing index. A
# `--check` mode would put fail-CLOSED behaviour inside a fail-OPEN tool, and the
# next reader could not tell from the exit code which contract was in force. It would
# also duplicate the normalisation logic below in two places, in two languages of
# artifact (HTML, JSONL), with no shared test.
#
# One gate, one command for a contributor, one CI step, one place to add the
# next artifact.
#
# ─────────────────────────────────────────────────────────────────────────────
# THE TIMESTAMP PROBLEM, AND WHAT THIS GATE DOES ABOUT IT
# ─────────────────────────────────────────────────────────────────────────────
# The dashboard carries a `generated_at` ISO-8601 UTC stamp. It is not minted by
# the dashboard generator — it is CARRIED FROM THE INDEX, which the gate must
# also regenerate, so the regenerated side's stamp is "now" while the committed
# side's stamp is "whenever it was last regenerated". A naive byte-diff would
# therefore fail on EVERY run, always, for a reason that has nothing to do with
# staleness. That is the false-failure this gate has to design out.
#
# Three options were available:
#
#   (a) FREEZE the regenerated side only (SOURCE_DATE_EPOCH, which
#       build-backlog-index.sh already honours). Insufficient alone: the
#       COMMITTED file was produced by a normal run and carries a real stamp, so
#       the two sides still differ. Freezing fixes reproducibility of the
#       regenerated side; it does not make the pair comparable.
#   (b) EXCLUDE the generated_at LINE. Rejected: the stamp appears in the page
#       more than once (the header fact line AND the inlined index snapshot), the
#       page is not line-oriented HTML, and a line-based exclusion silently stops
#       matching the moment the emitter's formatting changes — a gate that
#       quietly compares less than it claims to.
#   (c) NORMALISE the FIELD on BOTH sides — replace every ISO-8601 UTC timestamp
#       with a fixed placeholder in the regenerated copy and in a scratch copy of
#       the committed file, then diff. Location-independent, format-independent,
#       and symmetric.
#
# This gate does (c), and ALSO (a) — belt and braces, for different reasons:
#   * (c) is what makes the comparison correct. It is applied IDENTICALLY to both
#     sides, so the only way the diff can fail is a genuine content difference.
#   * (a) is what makes the scratch index reproducible for a human debugging a
#     failure: two runs of the gate produce byte-identical scratch files, so
#     `diff` output is about the artifact and not about the clock.
#
# Known and accepted narrowing: a backlog item whose TITLE literally contains an
# ISO-8601 UTC timestamp would have that substring normalised too — on both
# sides, so it cannot cause a FALSE FAILURE; it can only make the gate blind to a
# change confined to that one substring. That is a strictly smaller blind spot
# than option (b), which is blind to whole lines.
#
# graph-bridge.jsonl needs none of this: it has no timestamp and no per-run
# variable at all, so it is compared BYTE-FOR-BYTE with no normalisation.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHAT IS CHECKED — AND HOW THE SET IS DERIVED (read before editing)
# ─────────────────────────────────────────────────────────────────────────────
# This gate knows HOW to check two artifact classes:
#
#   artifacts/backlog-dashboard.html    (build-backlog-index.sh -> build-backlog-dashboard.sh)
#   .logic-loom/graph/graph-bridge.jsonl (build-graph-bridge.sh)
#
# WHETHER either is checked is NOT hardcoded. It is derived from the GIT INDEX of
# the tree the gate is running in: an artifact is checked if and only if it is
# GIT-TRACKED here. Everything below follows from that one rule.
#
# WHY (this replaced an unconditional demand that shipped and broke customers):
# the gate used to assert both paths exist, full stop. The template-strip
# manifest removes `artifacts` and `.logic-loom/graph` WHOLESALE, so on a
# sanitized customer tree the gate demanded two files that the release had
# deliberately deleted — every cloner's first push went red on a gate they did
# not write. Deriving from the index gives all three properties at once:
#
#   * DEV LINE — both artifacts are tracked, so both are checked, fail-closed.
#     Nothing is weakened: the rot this gate exists to catch is caught exactly as
#     before. See "absent but tracked" below, which is the teeth.
#   * SANITIZED TREE — neither is tracked (the strip removed them from the index),
#     so there is nothing to check and the gate exits 0 saying so.
#   * A CUSTOMER'S OWN ARTIFACTS — a cloner who runs `/graph build` or the backlog
#     generators and COMMITS the result has made those paths tracked, so this gate
#     starts covering THEIR artifacts with no configuration. They inherit a live
#     gate, not a dead one.
#
# THE HOLE THIS MUST NOT BECOME: "if it is missing, skip". A path that is ABSENT
# FROM DISK but PRESENT IN THE INDEX is the exact rot case — someone deleted or
# never regenerated a tracked artifact — and it still FAILS, loudly.
#
# ─────────────────────────────────────────────────────────────────────────────
# THE GATE MUST NOT BE ABLE TO TURN ITSELF OFF  (this is the teeth)
# ─────────────────────────────────────────────────────────────────────────────
# Deriving the checked set from the index answers "what should I check", but on
# its own it does NOT assert that the answer stays non-empty. An earlier version
# of this header claimed untracking was "a deliberate, reviewable `git rm`". That
# was an ASSUMPTION, enforced nowhere, and it was wrong. Reproduced:
#
#     printf '\n<!-- ROT -->\n' >> artifacts/backlog-dashboard.html
#     git rm --cached artifacts/backlog-dashboard.html
#     check-generated-freshness.sh        # -> exit 0, "nothing to check"
#
# Rotten file still on disk, gate green. A `git rm --cached`, a merge that drops
# an index entry, a stray .gitignore line, or a bug in the strip script all reach
# that same place: the rot-catching purpose gone, build green, nobody told.
#
# So the tracked set is now ASSERTED, conditionally on the KIND of tree:
#
#   MAINTAINER tree (dev-main / a maintainer checkout) — every artifact this
#     gate knows about MUST be tracked. Untracked = HARD FAILURE naming the path
#     and how to restore it. On this line both artifacts are tracked by
#     construction, so "untracked" can only mean something went wrong.
#
#   SANITIZED tree (a promoted / customer clone) — untracked is the NORMAL,
#     CORRECT state: the strip manifest removes `artifacts` and
#     `.logic-loom/graph` wholesale. Skip, exit 0, exactly as before.
#
# WHY THAT SPLIT IS SAFE FOR "A CUSTOMER GENERATED IT BUT HAS NOT COMMITTED IT":
# that customer is, by definition, on a SANITIZED tree — they are working from
# the promoted template, where none of the maintainer-only marker files exist —
# so their branch of the rule is "skip, exit 0" and they are never failed. Their
# freshly generated, uncommitted artifact is untracked, which on their tree means
# "no committed copy to be stale", which is true. The moment they COMMIT it, it
# becomes tracked and this gate starts covering it, with no configuration. The
# only population the assertion can fire on is one that is holding the harness's
# own maintainer tooling — i.e. us, and forks of the dev line, where the
# artifacts arrive tracked and staying tracked is the contract.
#
# WHICH KIND OF TREE is not decided here: it is the shared answer from
# tests/lib/tree-provenance.sh (`loom_tree_kind`), the same one the six
# strip-aware contract suites use, so "maintainer vs sanitized" is computed once
# and the same way everywhere. An `inconsistent` tree is a hard failure there and
# a hard failure here — never a skip.
#
# LAYERING, ACKNOWLEDGED: tests/lib/ is a test directory being sourced by a
# production script. That is a wart. The helper is really governance plumbing and
# would sit better at .logic-loom/lib/tree-provenance.sh with tests/lib/ left as
# a thin re-source shim for the suites. It is NOT moved in this change (the file
# is owned elsewhere right now, and moving it would touch all six suites). It
# does ship — `tests/**` is an explicit ship line in the strip manifest — so the
# dependency is satisfiable on both sides of the release.
#
# IF THE HELPER IS ABSENT (someone pruned tests/): provenance is `unknown`. The
# gate then falls back to ONE tighten-only signal — the presence of
# .logic-loom/scripts/bash/template-strip-manifest.txt, which the strip removes —
# and treats that as maintainer. If even that is absent, an untracked artifact is
# skipped WITH A LOUD WARNING saying the tracked-set assertion could not be
# enforced. Not a silent pass, and deliberately not a hard failure: `tests/` is
# the customer's to prune, and turning a pruned test directory into a red build
# on a customer's first push is the exact blocker class this gate already shipped
# once.
#
# ─────────────────────────────────────────────────────────────────────────────
# SPARSE CHECKOUT — the gate's INPUTS go missing, so the whole run REFUSES
# ─────────────────────────────────────────────────────────────────────────────
# There are TWO ways a sparse checkout breaks this gate, and only one of them is
# about the artifact itself.
#
#   (i)  THE ARTIFACT IS EXCLUDED. `git sparse-checkout set` that omits
#        `artifacts/` leaves the index entry in place with the SKIP-WORKTREE bit
#        set and no file on disk. Read naively that is "tracked but missing from
#        the tree" — the rot case — and the gate would fail a healthy checkout.
#
#   (ii) THE ARTIFACT'S SOURCES ARE EXCLUDED. Both artifacts here are derived
#        from a corpus spread across the whole repo. Drop part of that corpus
#        from the work tree and regeneration legitimately produces DIFFERENT
#        output from the committed copy — so the gate reports STALE on a tree
#        where nothing has rotted. This is the half that was missed the first
#        time (an `artifacts/`-excluding sparse checkout still went red, on the
#        graph bridge, for exactly this reason).
#
# The gate handles (ii) by REFUSING THE ENTIRE RUN — exit 1, no artifact
# checked — whenever `core.sparseCheckout` is true. It cannot answer its own
# question on such a tree: a diff between the committed artifact and a
# regeneration from a deliberately-thinned corpus tells you nothing about
# staleness, because the two inputs were never the same corpus.
#
# WHY NOT PER-ARTIFACT SOURCE SETS (the rejected option). The tempting
# refinement is to declare each artifact's source inputs and skip only the
# artifacts whose sources are sparse-excluded, keeping the check alive for the
# rest. It was rejected on the actual source sets, not on taste:
#
#   * graph-bridge.jsonl's source set IS THE WHOLE WORK TREE. Its corpus is
#     `.docs/`, `features/`, `specs/` and five root markdown files — already
#     most of the repo — but the `mentions` edge is emitted for a backtick-quoted
#     path only IF THAT PATH EXISTS ON DISK (build-graph-bridge.sh, pass 2b; the
#     same working-tree dependence recorded in the graph section below). Any path
#     anywhere in the repo can therefore change this artifact's bytes by being
#     absent. A truthful declaration for it is "every file", which makes "are all
#     its sources present?" identical to "is this checkout non-sparse?" — the
#     precise question option (a) already asks, reached via a declaration file,
#     a parser, and a way to get them out of sync with the generators.
#   * The dashboard is enumerable (`.logic-loom/memory/todos.md`,
#     `backlog.md`, `features/*/plan.md`, `specs/*/tasks.md`) but is a GLOB set,
#     not a fixed one: a sparse checkout excluding `features/` silently removes
#     inputs without removing any declared path, so declaration-matching would
#     pass while the corpus is short — answering wrongly, the one outcome ranked
#     worst here.
#
#   So the per-artifact machinery buys exactly one extra green: a sparse checkout
#   that excludes `artifacts/` AND NOTHING ELSE. That single case is already
#   covered by (i) below, which needs no declarations at all. Per-artifact source
#   declarations would belong beside the generator that consumes them — a
#   `# sources:` contract in each build-*.sh, read by this gate — NOT in a new
#   config file; but on this evidence they earn nothing, so none is added.
#
# WHY REFUSING IS NOT THE "CUSTOMER'S FIRST PUSH GOES RED" BUG AGAIN. That bug
# fired on a state the release DID TO the customer (the strip removed files the
# gate demanded). A sparse checkout is a state THE USER DELIBERATELY CONFIGURED,
# with one documented command to leave it, named in the refusal message. And the
# posture matches the no-git case below: when the gate cannot see its inputs it
# says so rather than guessing, because a fail-closed gate that guesses is a gate
# that has stopped meaning anything.
#
# (i) is STILL handled, and is not redundant, because `git update-index
# --skip-worktree <path>` sets the bit on ONE path WITHOUT setting
# core.sparseCheckout — the corpus is fully present, other artifacts remain
# genuinely checkable, and only the artifact whose own file was hidden must be
# skipped. `git ls-files -v` reports such an entry with a status letter of `S`
# (skip-worktree) or `s` (skip-worktree AND assume-unchanged), so those entries
# are detected and SKIPPED with a message saying why.
#
# ─────────────────────────────────────────────────────────────────────────────
# KNOWN AND ACCEPTED CONTRACT LIMIT: THIS GATE REQUIRES A GIT CHECKOUT
# ─────────────────────────────────────────────────────────────────────────────
# A tree unpacked from a `git archive` tarball or GitHub's "Download ZIP" has no
# .git directory and therefore no index, so the gate cannot read the tracked set
# and REFUSES (exit 1, with the diagnostic below). That is accepted, not a bug to
# paper over: the alternative is to guess the tracked set on precisely the tree
# where the evidence is missing, and a fail-closed gate that guesses is a gate
# that stops meaning anything. It is also not reachable from CI —
# `actions/checkout` produces a real index at both fetch-depth 0 and 1 — so the
# limit costs a tarball user a clear error message and costs the release nothing.
#
# WHY NOT READ THE STRIP MANIFEST INSTEAD: the manifest
# (.logic-loom/scripts/bash/template-strip-manifest.txt) is ITSELF stripped
# (manifest line 87), so it does not exist on the tree where the question is
# asked. Any manifest-based rule would have to fall back to guessing on precisely
# the tree it was meant to serve. The git index is present in every tree that has
# a git checkout, on both sides of the release.
#
# NO GIT / NO WORK TREE: the gate cannot answer its own question, so it REFUSES —
# exit 1 with a diagnostic, never a silent pass. A staleness gate that cannot see
# the index has no basis for saying "fresh", and failing toward asking is the only
# posture consistent with fail-closed.
#
# NOT checked, on purpose: .logic-loom/backlog-index.json. It is gitignored — a
# machine intermediate with no standalone reader. Untracked, so the rule above
# already excludes it; there is no committed copy to be stale.
#
# Usage:
#   check-generated-freshness.sh [ROOT] [--only dashboard|graph]
# Exit: 0 fresh (or nothing tracked to check) · 1 stale, a known artifact
#       untracked on a maintainer tree, a required generator/tool missing, the
#       tracked set is undeterminable (no git / no work tree), or the checkout is
#       sparse so the artifacts' sources may be absent · 2 usage error.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

ROOT=""; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only)   ONLY="${2:-}"; shift 2 || true ;;
    --only=*) ONLY="${1#--only=}"; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    -*) echo "usage: $(basename "$0") [ROOT] [--only dashboard|graph]" >&2; exit 2 ;;
    *)  [ -z "$ROOT" ] && ROOT="$1"; shift ;;
  esac
done
case "$ONLY" in ""|dashboard|graph) ;; *)
  echo "usage: --only takes 'dashboard' or 'graph'" >&2; exit 2 ;;
esac

if [ -z "$ROOT" ]; then
  _sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(cd "$_sd/../../.." && pwd)"   # scripts/bash -> .logic-loom -> repo root
fi
[ -d "$ROOT" ] || { echo "ERROR: root '$ROOT' is not a directory" >&2; exit 2; }

SCRIPTS="$ROOT/.logic-loom/scripts/bash"
TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t loomfresh)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

FAILED=0
CHECKED=0        # how many artifacts this run actually examined
TOOL_BROKE=0     # a GENERATOR failed, as opposed to an artifact being stale

# ── The tracked set is the source of truth for WHAT to check ────────────────
# See the header. No git, or not a work tree -> REFUSE (exit 1). We cannot
# distinguish "stripped on purpose" from "deleted and never regenerated" without
# the index, and guessing in a fail-closed gate is how a gate stops meaning
# anything.
if ! command -v git >/dev/null 2>&1; then
  echo "❌ REFUSING: git is not available, so the tracked set cannot be read." >&2
  echo "   This gate decides WHAT to check from the git index (see the header)." >&2
  echo "   Install git, or run this from a git checkout." >&2
  exit 1
fi
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ REFUSING: '$ROOT' is not inside a git work tree." >&2
  echo "   This gate decides WHAT to check from the git index (see the header)." >&2
  echo "   Point it at a checkout: check-generated-freshness.sh <repo-root>" >&2
  echo "   (A 'Download ZIP' / 'git archive' tree has no index — known, accepted" >&2
  echo "    contract limit; see the header. Clone instead.)" >&2
  exit 1
fi

# ── SPARSE CHECKOUT -> REFUSE THE WHOLE RUN ──────────────────────────────────
# See "SPARSE CHECKOUT" in the header. A sparse checkout thins the work tree, and
# BOTH artifacts here are derived from a corpus spread across it — so a
# regeneration is built from a different corpus than the committed copy was, and
# the resulting diff carries no information about staleness. Refuse rather than
# report a red the reader would have to learn to ignore, or a green the gate has
# not earned.
#
# `core.sparseCheckout=true` is the authoritative switch: `git sparse-checkout
# init/set` sets it (cone and non-cone, sparse-index included), and git ignores
# .git/info/sparse-checkout entirely without it. A single-path `git update-index
# --skip-worktree` does NOT set it — that case is handled per-artifact below, and
# deliberately still runs, because there the corpus is intact.
#
# This is checked BEFORE tree provenance: a sparse checkout can also hide the
# maintainer marker files and produce an `inconsistent` verdict, and "your
# checkout is sparse" is the accurate diagnosis of that, not "your tree is
# corrupt". `--only` does not bypass it — the reason applies to every artifact.
#
# READ IT AS A BOOLEAN, NOT AS THE STRING "true". git accepts `true`, `1`, `yes`,
# `on` (and their case variants) as the same boolean, and `git sparse-checkout
# init` is not the only way the key gets set — a hand-edited .git/config or a
# tool writing `core.sparseCheckout = 1` is just as authoritative to git. A
# literal string compare read that as NOT sparse and the whole-tree refusal never
# fired, so the gate went on to regenerate from a thinned corpus and exit 0 on a
# stale artifact. `--bool` makes git canonicalise the value; anything git calls
# true is true here.
sparse_checkout_enabled() {
  [ "$(git -C "$ROOT" config --bool --get core.sparseCheckout 2>/dev/null)" = "true" ]
}

if sparse_checkout_enabled; then
  echo "❌ REFUSING: '$ROOT' is a SPARSE CHECKOUT (core.sparseCheckout=true)." >&2
  echo "" >&2
  echo "   This gate verifies a generated artifact by REGENERATING it from its" >&2
  echo "   sources and diffing. A sparse checkout removes part of the work tree," >&2
  echo "   and both artifacts it knows about are derived from a corpus spread" >&2
  echo "   across that tree (the markdown corpus for the graph bridge; todos.md," >&2
  echo "   backlog.md, features/*/plan.md and specs/*/tasks.md for the dashboard)." >&2
  echo "   With inputs missing, a regeneration legitimately differs from the" >&2
  echo "   committed copy — so a diff here cannot tell staleness from sparseness." >&2
  echo "" >&2
  echo "   It refuses rather than guess in either direction: a red would be false" >&2
  echo "   on a healthy tree, and a green would be unearned." >&2
  echo "" >&2
  echo "   Run it in a full checkout. From this one:" >&2
  echo "" >&2
  echo "     git sparse-checkout disable   # then re-run this gate" >&2
  echo "" >&2
  echo "   Or let CI cover it — actions/checkout is never sparse by default." >&2
  exit 1
fi

# ── WHICH KIND OF TREE ────────────────────────────────────────────────────────
# See "THE GATE MUST NOT BE ABLE TO TURN ITSELF OFF" in the header. maintainer |
# sanitized | unknown. `inconsistent` never survives this block.
PROVENANCE_HELPER="$ROOT/tests/lib/tree-provenance.sh"
TREE_KIND="unknown"
if [ -f "$PROVENANCE_HELPER" ]; then
  # shellcheck source=/dev/null
  . "$PROVENANCE_HELPER"
  TREE_KIND="$(loom_tree_kind "$ROOT")"
  if [ "$TREE_KIND" = "inconsistent" ]; then
    loom_require_consistent_tree "$ROOT" || true
    echo "❌ REFUSING: cannot tell a maintainer tree from a sanitized one, so the" >&2
    echo "   'known artifacts must stay tracked' assertion has no defined answer." >&2
    exit 1
  fi
elif [ -f "$ROOT/.logic-loom/scripts/bash/template-strip-manifest.txt" ]; then
  # Tighten-only fallback: the strip manifest is itself stripped, so its presence
  # can only mean a maintainer tree. Deliberate, one-directional duplication of
  # one marker — it can turn the assertion ON, never off.
  TREE_KIND="maintainer"
fi

# index_flag <repo-relative-path> — the `git ls-files -v` status letter for the
# path's index entry, or "" when it has none.
#   H  = cached (ordinary tracked entry)
#   S  = skip-worktree           }  sparse checkout / manual skip-worktree:
#   s  = skip-worktree + assume-unchanged }  tracked, legitimately not on disk
index_flag() {
  git -C "$ROOT" ls-files -v -- "$1" 2>/dev/null | head -1 | cut -c1
}

# (sparse_checkout_enabled is defined above, next to the run-level refusal.)

# artifact_state <repo-relative-path> -> echoes one of:
#   tracked | sparse | untracked
# Deliberately index-based, not filesystem-based: a tracked path whose file is
# missing from disk must still answer `tracked` here, because that is the rot
# case the gate exists to catch. `sparse` is the one legitimate exception.
artifact_state() {
  local f
  f="$(index_flag "$1")"
  case "$f" in
    S|s)
      # skip-worktree/assume-unchanged says "git is not looking at the work tree
      # copy". That is the SPARSE case only when the file is genuinely NOT on
      # disk. `git update-index --skip-worktree <path>` on an ordinary full
      # checkout sets the same flag with the file still present — and treating
      # that as `sparse` handed anyone a one-command opt-out of this gate: flag
      # the artifact, let it rot, ship a stale committed copy behind a green
      # exit 0. So the flag alone is not the test; ABSENCE FROM DISK is.
      #
      # When the file IS on disk, every input this gate needs is present, so it
      # falls through to the normal regenerate-and-diff. The flag changes what
      # git stages; it does not change whether the committed bytes are current,
      # and current is the only thing being asked.
      if [ -e "$ROOT/$1" ]; then echo "tracked"; else echo "sparse"; fi
      return ;;
    "")  ;;
    *)   echo "tracked"; return ;;
  esac
  # No index entry. Under a sparse INDEX the entry may be collapsed into a
  # sparse-directory entry, so "no entry for the file" is not proof of untracked.
  #
  # UNREACHABLE BY CONSTRUCTION as the file now stands: the run-level guard above
  # exits 1 on core.sparseCheckout=true, so control never gets here with it set.
  # Kept deliberately as defence-in-depth — if that guard is ever narrowed (say,
  # to refuse only when a specific corpus root is excluded), this line is what
  # stops a sparse-index tree from being misread as UNTRACKED and hard-failing
  # the maintainer assertion. It can only turn a failure into a skip in a state
  # that is already a refusal, never a real staleness into a pass.
  if sparse_checkout_enabled; then echo "sparse"; else echo "untracked"; fi
}

skip_sparse() {
  echo "⏭  skip: $1 — this path is marked skip-worktree, so its absence from the"
  echo "   work tree is expected and is not staleness. (A whole-tree sparse"
  echo "   checkout refuses earlier; reaching here means the bit was set on this"
  echo "   path alone, e.g. \`git update-index --skip-worktree\`, with the rest of"
  echo "   the corpus intact — so the other artifacts are still checked.)"
}

skip_untracked() {
  echo "⏭  skip: $1 — not git-tracked in this tree, so there is no committed copy"
  echo "   to be stale. (Sanitized template trees strip it; a project that starts"
  echo "   tracking it is covered automatically on the next run.)"
  if [ "$TREE_KIND" = "unknown" ]; then
    echo "⚠️  WARNING: tree provenance is UNDETERMINABLE here (tests/lib/tree-provenance.sh"
    echo "   and .logic-loom/scripts/bash/template-strip-manifest.txt are both absent),"
    echo "   so this run could NOT enforce 'a maintainer tree must keep its generated"
    echo "   artifacts tracked'. If this is a maintainer checkout, restore that helper."
  fi
}

# fail_untracked_on_maintainer <rel-path> <regen commands...>
fail_untracked_on_maintainer() {
  local rel="$1"; shift
  echo ""
  echo "❌ NOT TRACKED: $rel is missing from the git index on a MAINTAINER tree."
  echo ""
  echo "  On this line that artifact is tracked BY CONTRACT — tracking it is the"
  echo "  only reason this gate can catch it going stale. An untracked copy means"
  echo "  the gate silently stopped checking it while a rotten file sat on disk."
  echo "  (\`git rm --cached\`, a merge that dropped the index entry, a stray"
  echo "  .gitignore line, or a strip-script bug all land here.)"
  echo ""
  echo "  Restore it — regenerate first so what you re-add is current:"
  echo ""
  local c
  for c in "$@"; do echo "    $c"; done
  echo "    git add $rel"
  echo ""
  echo "  If dropping it was intentional, it must ALSO be removed from this gate's"
  echo "  known-artifact list in the same change, with the reason recorded there."
  echo ""
  FAILED=1
}

# normalise_ts <in> <out> — replace every ISO-8601 UTC stamp with a placeholder.
# Applied to BOTH sides of the dashboard comparison; see the header.
normalise_ts() {
  sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/<TIMESTAMP>/g' \
    < "$1" > "$2"
}

fail_header() {
  echo ""
  echo "❌ STALE: $1"
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# A GENERATOR'S OWN WORDS BEAT THIS GATE'S GUESS
# ─────────────────────────────────────────────────────────────────────────────
# Every generator invocation below captures BOTH its exit status and its stderr,
# and every failing branch prints them. That is not tidiness; it is the fix for a
# real CI failure. The graph builder was run as `... >/dev/null 2>&1`, so when it
# died the gate had exactly one fact left — no file on disk — and reported the
# only thing that fact could support: "the builder produced nothing". True,
# useless, and it read as staleness. The builder's exit code and stderr, which
# name the failing command, had been thrown away one line earlier.
#
# So: never `2>&1` a generator into /dev/null here, and never infer a cause from
# the absence of an output file when the tool that failed to write it was willing
# to say why.
show_tool_output() { # $1=label  $2=stderr file
  if [ -s "$2" ]; then
    echo "  ── $1 said: ─────────────────────────────────────────────"
    sed 's/^/  /' "$2" 2>/dev/null | head -40
    echo "  ─────────────────────────────────────────────────────────"
  else
    echo "  ($1 wrote nothing to stderr.)"
  fi
  echo ""
}

# ── 1. artifacts/backlog-dashboard.html ──────────────────────────────────────
if [ "$ONLY" = "" ] || [ "$ONLY" = "dashboard" ]; then
  DASH_REL="artifacts/backlog-dashboard.html"
  DASH="$ROOT/$DASH_REL"
  COLLECTOR="$SCRIPTS/build-backlog-index.sh"
  RENDERER="$SCRIPTS/build-backlog-dashboard.sh"

  # Tracked -> the whole block below runs unchanged, INCLUDING the "missing from
  # the tree" failure. Sparse-excluded -> skip. Untracked -> skip on a sanitized
  # tree, HARD FAIL on a maintainer one (see the header).
  DASH_STATE="$(artifact_state "$DASH_REL")"
  if [ "$DASH_STATE" = "sparse" ]; then
    skip_sparse "$DASH_REL"
  elif [ "$DASH_STATE" = "untracked" ] && [ "$TREE_KIND" = "maintainer" ]; then
    fail_untracked_on_maintainer "$DASH_REL" \
      "./.logic-loom/scripts/bash/build-backlog-index.sh" \
      "./.logic-loom/scripts/bash/build-backlog-dashboard.sh"
  elif [ "$DASH_STATE" = "untracked" ]; then
    skip_untracked "$DASH_REL"
  else
  CHECKED=$((CHECKED + 1))

  if [ ! -f "$COLLECTOR" ] || [ ! -f "$RENDERER" ]; then
    fail_header "$DASH_REL — its generator is missing"
    echo "  Expected both of:"
    echo "    $COLLECTOR"
    echo "    $RENDERER"
    FAILED=1
  elif [ ! -f "$DASH" ]; then
    fail_header "$DASH_REL — the tracked artifact is MISSING from the tree"
    echo "  This file is tracked and must be regenerated and committed. Run:"
    echo ""
    echo "    ./.logic-loom/scripts/bash/build-backlog-index.sh"
    echo "    ./.logic-loom/scripts/bash/build-backlog-dashboard.sh"
    echo ""
    FAILED=1
  else
    # SOURCE_DATE_EPOCH freezes the regenerated stamp -> reproducible scratch.
    SOURCE_DATE_EPOCH=0 bash "$COLLECTOR" "$ROOT" --out "$TMPD/index.json" \
      >/dev/null 2>"$TMPD/collector.err"
    crc=$?
    if [ "$crc" -ne 0 ] || [ ! -s "$TMPD/index.json" ]; then
      fail_header "$DASH_REL — the collector refused to build an index (exit $crc)"
      sed 's/^/  /' "$TMPD/collector.err" 2>/dev/null | head -30
      echo ""
      echo "  Fix the backlog sources first, then regenerate:"
      echo ""
      echo "    ./.logic-loom/scripts/bash/lint-backlog.sh"
      echo "    ./.logic-loom/scripts/bash/build-backlog-index.sh"
      echo "    ./.logic-loom/scripts/bash/build-backlog-dashboard.sh"
      echo ""
      FAILED=1
    else
      # Same rule as the graph builder below: keep the renderer's exit code and
      # stderr. `2>&1 >/dev/null` here used to throw away the only explanation of
      # an empty page.
      bash "$RENDERER" "$ROOT" --index "$TMPD/index.json" --out "$TMPD/dash.html" \
        >/dev/null 2>"$TMPD/renderer.err"
      rrc=$?
      if [ "$rrc" -ne 0 ] || [ ! -s "$TMPD/dash.html" ]; then
        fail_header "$DASH_REL — the renderer produced no page (exit $rrc)"
        show_tool_output "build-backlog-dashboard.sh" "$TMPD/renderer.err"
        TOOL_BROKE=1
        FAILED=1
      else
        normalise_ts "$TMPD/dash.html" "$TMPD/fresh.norm"
        normalise_ts "$DASH"           "$TMPD/committed.norm"
        if diff -q "$TMPD/committed.norm" "$TMPD/fresh.norm" >/dev/null 2>&1; then
          echo "✅ fresh: $DASH_REL"
        else
          fail_header "$DASH_REL differs from what its sources produce"
          echo "  The committed page no longer matches .logic-loom/memory/todos.md /"
          echo "  .logic-loom/memory/backlog.md, features/*/plan.md or specs/*/tasks.md."
          echo "  Regenerate and commit it:"
          echo ""
          echo "    ./.logic-loom/scripts/bash/build-backlog-index.sh"
          echo "    ./.logic-loom/scripts/bash/build-backlog-dashboard.sh"
          echo ""
          echo "  (The index is gitignored; only the dashboard is committed.)"
          echo "  First differing lines (committed < , regenerated > ), timestamps normalised:"
          diff "$TMPD/committed.norm" "$TMPD/fresh.norm" 2>/dev/null | head -20 | sed 's/^/    /'
          echo ""
          FAILED=1
        fi
      fi
    fi
  fi
  fi   # close the is_tracked guard
fi

# ── 2. .logic-loom/graph/graph-bridge.jsonl ──────────────────────────────────
# No timestamp, no per-run variable -> byte-for-byte, no normalisation.
#
# One residual, recorded so it is not rediscovered as a mystery: the generator
# emits a `mentions` edge only for a backtick-quoted path that EXISTS on disk, so
# its output depends on the working tree, not only on tracked content. A file
# that is present locally but absent from a CI checkout (i.e. gitignored) would
# make the two disagree. Audited at the time this gate was added: the only such
# node was artifacts/backlog-dashboard.html, which this same change made tracked,
# so the set is now empty. If this check ever fails ONLY in CI, that is the first
# thing to look for.
if [ "$ONLY" = "" ] || [ "$ONLY" = "graph" ]; then
  GB_REL=".logic-loom/graph/graph-bridge.jsonl"
  GB="$ROOT/$GB_REL"
  BUILDER="$SCRIPTS/build-graph-bridge.sh"

  # Same rule as the dashboard above: the index decides, not the filesystem.
  GB_STATE="$(artifact_state "$GB_REL")"
  if [ "$GB_STATE" = "sparse" ]; then
    skip_sparse "$GB_REL"
  elif [ "$GB_STATE" = "untracked" ] && [ "$TREE_KIND" = "maintainer" ]; then
    fail_untracked_on_maintainer "$GB_REL" \
      "./.logic-loom/scripts/bash/build-graph-bridge.sh --out .logic-loom/graph/graph-bridge.jsonl"
  elif [ "$GB_STATE" = "untracked" ]; then
    skip_untracked "$GB_REL"
  else
  CHECKED=$((CHECKED + 1))

  if [ ! -f "$BUILDER" ]; then
    fail_header "$GB_REL — build-graph-bridge.sh is missing"
    FAILED=1
  elif [ ! -f "$GB" ]; then
    fail_header "$GB_REL — the tracked artifact is MISSING from the tree"
    echo "  Regenerate and commit it:"
    echo ""
    echo "    ./.logic-loom/scripts/bash/build-graph-bridge.sh --out .logic-loom/graph/graph-bridge.jsonl"
    echo ""
    FAILED=1
  else
    bash "$BUILDER" "$ROOT" --out "$TMPD/graph-bridge.jsonl" \
      >/dev/null 2>"$TMPD/builder.err"
    brc=$?
    if [ "$brc" -ne 0 ]; then
      # The BUILDER broke. That is not staleness, and calling it staleness sends
      # the reader to regenerate-and-commit — which cannot work, because the tool
      # that would do the regenerating is the thing that failed.
      fail_header "$GB_REL — THE BUILDER FAILED (exit $brc); this is NOT a stale artifact"
      show_tool_output "build-graph-bridge.sh" "$TMPD/builder.err"
      TOOL_BROKE=1
      echo "  Fix the builder or its toolchain, then re-run this gate. Reproduce with:"
      echo ""
      echo "    bash .logic-loom/scripts/bash/build-graph-bridge.sh --out /dev/null"
      echo ""
      FAILED=1
    elif [ ! -f "$TMPD/graph-bridge.jsonl" ]; then
      # Exit 0 with no file. The builder's own contract forbids this — it either
      # writes the file or exits non-zero — so reaching here means the contract
      # was broken, not that the corpus was empty.
      fail_header "$GB_REL — the builder exited 0 but wrote no file (contract violation)"
      show_tool_output "build-graph-bridge.sh" "$TMPD/builder.err"
      TOOL_BROKE=1
      FAILED=1
    elif diff -q "$GB" "$TMPD/graph-bridge.jsonl" >/dev/null 2>&1; then
      echo "✅ fresh: $GB_REL"
      [ -s "$TMPD/builder.err" ] && show_tool_output "build-graph-bridge.sh (warnings)" "$TMPD/builder.err"
    else
      fail_header "$GB_REL differs from what the markdown corpus produces"
      echo "  A doc was added, moved, renamed or re-linked without rebuilding the"
      echo "  bridge. Regenerate and commit it:"
      echo ""
      echo "    ./.logic-loom/scripts/bash/build-graph-bridge.sh --out .logic-loom/graph/graph-bridge.jsonl"
      echo ""
      echo "  First differing lines (committed < , regenerated > ):"
      diff "$GB" "$TMPD/graph-bridge.jsonl" 2>/dev/null | head -20 | sed 's/^/    /'
      echo ""
      # A warning from the builder (e.g. python3 absent -> relative link edges
      # skipped) explains a diff that would otherwise look like real drift.
      [ -s "$TMPD/builder.err" ] && show_tool_output "build-graph-bridge.sh (warnings)" "$TMPD/builder.err"
      FAILED=1
    fi
  fi
  fi   # close the is_tracked guard
fi

if [ "$FAILED" -ne 0 ]; then
  echo "Generated-artifact freshness check FAILED."
  if [ "$TOOL_BROKE" -ne 0 ]; then
    # Do NOT tell the reader to regenerate-and-commit when the thing that would
    # do the regenerating is what failed. That advice sent people looking for a
    # stale doc when the actual fault was in the generator or its toolchain.
    echo "At least one GENERATOR failed — that is a broken tool, not a stale file."
    echo "Read its output above, fix that first; regenerating cannot help until you do."
  else
    echo "These files are tracked BECAUSE this gate keeps them honest — regenerate,"
    echo "then commit the result alongside the source change that caused the drift."
  fi
  exit 1
fi

if [ "$CHECKED" -eq 0 ]; then
  # Not a weaker pass — a correct one. Nothing in this tree's git index is a
  # generated artifact this gate knows how to check, so there is no committed
  # derived copy that could have drifted. A sanitized template clone is the
  # normal case; the gate turns itself on the moment a generated artifact is
  # committed here.
  echo "No git-tracked generated artifacts in this tree — nothing to check."
  exit 0
fi

echo "Generated-artifact freshness check passed."
exit 0
