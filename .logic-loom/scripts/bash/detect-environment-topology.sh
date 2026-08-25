#!/usr/bin/env bash
# detect-environment-topology.sh — READ-ONLY detection of what a repository
# ALREADY has, before any environment-promotion scaffolding is proposed.
#
# WHY THIS EXISTS: the normal case for adopting LogicLoom is an EXISTING
# repository that already has branches, CI, and possibly a deployed environment.
# Scaffolding that assumes a blank tree will propose a `staging` branch to a
# project that has had one for two years. This script's whole job is to make the
# proposal a DELTA rather than a layout. Detect; never assume.
#
# WHAT IT DOES NOT DO, EVER: write a file, create a branch, run git, touch the
# network, or invoke anything. It is read-only by construction.
#
# IT DOES NOT SHELL OUT TO GIT — deliberately. Refs are read straight off the
# filesystem (.git/HEAD, .git/refs/**, .git/packed-refs, .git/worktrees/*). Three
# reasons: (a) it is provably non-mutating, with no argument-parsing surface for
# a mutation to hide in; (b) it works under LogicLoom's subagent-git-guard, which
# denies mutating git to a subagent; (c) it makes the detector testable against a
# hand-built .git directory, so its fixtures need no repository.
#
# The cost is stated plainly: this reads git's on-disk format, not git's opinion.
# It handles loose refs, packed-refs, symbolic HEAD, a detached HEAD, and a
# linked worktree's `gitdir:` pointer file. It does NOT handle a bare repository
# with an unusual layout, `core.worktree` indirection, or a ref stored anywhere
# else. On anything it cannot read it reports `unknown` — it never guesses.
# (Fail closed with a typed reason: environment-promotion-policy.md § 4.2.)
#
# Usage: detect-environment-topology.sh [--root DIR] [--format report|kv]
#   --root DIR   repository root (default: walk up from this script)
#   --format kv  machine-readable `key=value` lines for the scaffolder
#
# Exit: 0 always, unless usage is wrong (2) or --root is unreadable (2).
#       "I could not determine X" is reported as `unknown`, not as failure —
#       the CALLER decides what an unknown means for its proposal.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

ROOT=""; FORMAT="report"
while [ $# -gt 0 ]; do
  case "$1" in
    --root)     ROOT="${2:-}"; shift 2 || true ;;
    --root=*)   ROOT="${1#--root=}"; shift ;;
    --format)   FORMAT="${2:-}"; shift 2 || true ;;
    --format=*) FORMAT="${1#--format=}"; shift ;;
    -h|--help)  sed -n '2,33p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

case "$FORMAT" in
  report|kv) ;;
  *) echo "ERROR: --format must be 'report' or 'kv' (got '$FORMAT')" >&2; exit 2 ;;
esac

_sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "$ROOT" ] || ROOT="$(cd "$_sd/../../.." && pwd)"
if [ ! -d "$ROOT" ]; then
  echo "ERROR: --root is not a directory: '$ROOT'" >&2; exit 2
fi
ROOT="$(cd "$ROOT" && pwd)"

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ── locate the git directory ─────────────────────────────────────────────────
# `.git` is normally a directory. In a linked worktree it is a FILE containing
# `gitdir: <path>`; that path is the worktree's private dir, whose refs/ is
# nearly empty — the shared refs live in its `commondir`. Resolve both.
GITDIR=""; COMMONDIR=""; GIT_DETECT="none"
if [ -d "$ROOT/.git" ]; then
  GITDIR="$ROOT/.git"; COMMONDIR="$GITDIR"; GIT_DETECT="dir"
elif [ -f "$ROOT/.git" ]; then
  _p="$(sed -n 's/^gitdir:[[:space:]]*//p' "$ROOT/.git" 2>/dev/null | head -1)"
  if [ -n "$_p" ]; then
    case "$_p" in /*) : ;; *) _p="$ROOT/$_p" ;; esac
    if [ -d "$_p" ]; then
      GITDIR="$_p"; GIT_DETECT="worktree"
      _c="$(sed -n '1p' "$_p/commondir" 2>/dev/null)"
      if [ -n "$_c" ]; then
        case "$_c" in /*) COMMONDIR="$_c" ;; *) COMMONDIR="$_p/$_c" ;; esac
      else
        COMMONDIR="$GITDIR"
      fi
    fi
  fi
fi
[ -n "$COMMONDIR" ] && [ -d "$COMMONDIR" ] || COMMONDIR="$GITDIR"

# ── branches ─────────────────────────────────────────────────────────────────
# Loose refs under refs/heads/**, plus packed-refs. Sorted + de-duplicated.
BRANCHES=""
if [ -n "$COMMONDIR" ]; then
  _loose=""
  if [ -d "$COMMONDIR/refs/heads" ]; then
    _loose="$(cd "$COMMONDIR/refs/heads" 2>/dev/null && find . -type f 2>/dev/null | sed 's|^\./||')"
  fi
  _packed=""
  if [ -f "$COMMONDIR/packed-refs" ]; then
    _packed="$(sed -n 's|^[0-9a-fA-F][0-9a-fA-F]*[[:space:]]\{1,\}refs/heads/||p' "$COMMONDIR/packed-refs" 2>/dev/null)"
  fi
  BRANCHES="$(printf '%s\n%s\n' "$_loose" "$_packed" | grep . | sort -u)"
fi
BRANCH_COUNT="$(printf '%s\n' "$BRANCHES" | grep -c . 2>/dev/null || true)"
[ -n "$BRANCH_COUNT" ] || BRANCH_COUNT=0

has_branch() { printf '%s\n' "$BRANCHES" | grep -qxF "$1"; }

# ── current branch ───────────────────────────────────────────────────────────
CURRENT_BRANCH="unknown"
if [ -n "$GITDIR" ] && [ -f "$GITDIR/HEAD" ]; then
  _h="$(sed -n '1p' "$GITDIR/HEAD" 2>/dev/null)"
  case "$_h" in
    "ref: refs/heads/"*) CURRENT_BRANCH="${_h#ref: refs/heads/}" ;;
    *) CURRENT_BRANCH="detached" ;;
  esac
fi

# ── default branch ───────────────────────────────────────────────────────────
# origin/HEAD is the pointer real tooling reads when it says "the default
# branch". It is written ONCE at clone time and goes stale silently thereafter
# (environment-promotion-policy.md § 2.1). Report where the answer came from, so
# the caller can say how much to trust it.
DEFAULT_BRANCH="unknown"; DEFAULT_SOURCE="none"
if [ -n "$COMMONDIR" ]; then
  if [ -f "$COMMONDIR/refs/remotes/origin/HEAD" ]; then
    _d="$(sed -n 's|^ref: refs/remotes/origin/||p' "$COMMONDIR/refs/remotes/origin/HEAD" 2>/dev/null | head -1)"
    if [ -n "$_d" ]; then DEFAULT_BRANCH="$_d"; DEFAULT_SOURCE="origin/HEAD"; fi
  fi
  # NOTE: a packed origin/HEAD is deliberately not consulted — packed-refs
  # stores resolved object ids, not the symbolic target, so the branch NAME is
  # not recoverable from it. Guessing one would be exactly the silent-wrong-base
  # failure § 2.1 describes. Fall through to a source that can be named.
  if [ "$DEFAULT_BRANCH" = "unknown" ] && [ -f "$COMMONDIR/config" ]; then
    _d="$(sed -n 's|^[[:space:]]*defaultBranch[[:space:]]*=[[:space:]]*||p' "$COMMONDIR/config" 2>/dev/null | head -1)"
    if [ -n "$_d" ]; then DEFAULT_BRANCH="$_d"; DEFAULT_SOURCE="init.defaultBranch"; fi
  fi
fi
if [ "$DEFAULT_BRANCH" = "unknown" ] && [ "$BRANCH_COUNT" = "1" ]; then
  DEFAULT_BRANCH="$(printf '%s\n' "$BRANCHES" | grep . | head -1)"; DEFAULT_SOURCE="sole-branch"
fi
if [ "$DEFAULT_BRANCH" = "unknown" ] && [ "$CURRENT_BRANCH" != "unknown" ] && [ "$CURRENT_BRANCH" != "detached" ]; then
  DEFAULT_BRANCH="$CURRENT_BRANCH"; DEFAULT_SOURCE="checked-out-HEAD"
fi

# ── role inference ───────────────────────────────────────────────────────────
# Only ever matches branches that ALREADY EXIST. This script proposes nothing
# and creates nothing; a role with no matching branch is reported empty, and the
# scaffolder must then omit that environment rather than invent a branch.
PROD_ALIASES="main master prod production release live"
INTEG_ALIASES="dev dev-main develop development integration next trunk"
STAGE_ALIASES="staging stage rehearsal preprod pre-prod uat qa"

first_match() { # aliases... -> first alias that is an existing branch
  local a
  for a in $1; do has_branch "$a" && { printf '%s' "$a"; return 0; }; done
  return 1
}

PROD_BRANCH=""; INTEG_BRANCH=""; STAGE_BRANCH=""
PROD_BRANCH="$(first_match "$PROD_ALIASES" || true)"
INTEG_BRANCH="$(first_match "$INTEG_ALIASES" || true)"
STAGE_BRANCH="$(first_match "$STAGE_ALIASES" || true)"

# If nothing matched the production aliases but the default branch is known,
# the default branch is the production line by definition of "default".
if [ -z "$PROD_BRANCH" ] && [ "$DEFAULT_BRANCH" != "unknown" ] && has_branch "$DEFAULT_BRANCH"; then
  PROD_BRANCH="$DEFAULT_BRANCH"
fi
# A branch cannot hold two roles.
[ "$INTEG_BRANCH" = "$PROD_BRANCH" ] && INTEG_BRANCH=""
[ "$STAGE_BRANCH" = "$PROD_BRANCH" ] && STAGE_BRANCH=""
[ -n "$STAGE_BRANCH" ] && [ "$STAGE_BRANCH" = "$INTEG_BRANCH" ] && STAGE_BRANCH=""

# ── the default-branch trap, evaluated for THIS topology ─────────────────────
# environment-promotion-policy.md § 2: the general fix (make the integration
# branch the repository default, keep origin/HEAD fresh) has a PRECONDITION —
# that you run an integration branch at all. LogicLoom itself is the worked
# counter-example where the fix is inapplicable. Classify, do not prescribe.
#   n/a-no-integration     no integration branch — the trap does not arise
#   ok-default-is-integration   already the recommended arrangement
#   advise-set-default     integration exists but is not the default (§ 2.1)
#   unknown                the default branch could not be determined
DEFAULT_TRAP="unknown"
if [ "$DEFAULT_BRANCH" = "unknown" ]; then
  DEFAULT_TRAP="unknown"
elif [ -z "$INTEG_BRANCH" ]; then
  DEFAULT_TRAP="n/a-no-integration"
elif [ "$DEFAULT_BRANCH" = "$INTEG_BRANCH" ]; then
  DEFAULT_TRAP="ok-default-is-integration"
else
  DEFAULT_TRAP="advise-set-default"
fi

# ── CI provider ──────────────────────────────────────────────────────────────
CI_PROVIDER="none"; CI_EVIDENCE=""
if [ -d "$ROOT/.github/workflows" ] && \
   [ -n "$(find "$ROOT/.github/workflows" -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | head -1)" ]; then
  CI_PROVIDER="github-actions"; CI_EVIDENCE=".github/workflows/"
elif [ -f "$ROOT/.gitlab-ci.yml" ]; then
  CI_PROVIDER="gitlab-ci"; CI_EVIDENCE=".gitlab-ci.yml"
elif [ -f "$ROOT/.circleci/config.yml" ]; then
  CI_PROVIDER="circleci"; CI_EVIDENCE=".circleci/config.yml"
elif [ -f "$ROOT/Jenkinsfile" ]; then
  CI_PROVIDER="jenkins"; CI_EVIDENCE="Jenkinsfile"
elif [ -f "$ROOT/azure-pipelines.yml" ]; then
  CI_PROVIDER="azure-pipelines"; CI_EVIDENCE="azure-pipelines.yml"
elif [ -d "$ROOT/.github" ]; then
  CI_PROVIDER="github-actions-empty"; CI_EVIDENCE=".github/ (no workflows yet)"
fi

# ── environment-ish workflows already present ────────────────────────────────
# Name-based only. A file called `deploy.yml` is evidence the user already has
# something; it is NOT evidence of what that something does. Reported so the
# proposal can say "you appear to already have this" instead of overwriting it.
ENV_WORKFLOWS=""
if [ -d "$ROOT/.github/workflows" ]; then
  ENV_WORKFLOWS="$(find "$ROOT/.github/workflows" -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null \
    | sed "s|^$ROOT/||" \
    | grep -Ei '(deploy|release|promot|stag|prod|environment|publish|topolog|boundar)' \
    | sort)"
fi
ENV_WORKFLOW_COUNT="$(printf '%s\n' "$ENV_WORKFLOWS" | grep -c . 2>/dev/null || true)"
[ -n "$ENV_WORKFLOW_COUNT" ] || ENV_WORKFLOW_COUNT=0

# ── existing environments.conf declaration ───────────────────────────────────
ENV_CONF="${LOOM_ENVIRONMENTS_CONF:-$ROOT/.logic-loom/config/environments.conf}"
ENV_CONF_STATE="absent"; ENV_CONF_NAMES=""
if [ -f "$ENV_CONF" ]; then
  ENV_CONF_NAMES="$(sed -n 's|^[[:space:]]*environment[[:space:]]*=[[:space:]]*||p' "$ENV_CONF" 2>/dev/null | sed 's|[[:space:]]*#.*$||' | sed 's|[[:space:]]*$||' | grep . | sort -u)"
  if [ -n "$ENV_CONF_NAMES" ]; then ENV_CONF_STATE="declared"; else ENV_CONF_STATE="present-empty"; fi
fi
ENV_CONF_COUNT="$(printf '%s\n' "$ENV_CONF_NAMES" | grep -c . 2>/dev/null || true)"
[ -n "$ENV_CONF_COUNT" ] || ENV_CONF_COUNT=0

# ── output ───────────────────────────────────────────────────────────────────
if [ "$FORMAT" = "kv" ]; then
  printf 'root=%s\n'                 "$ROOT"
  printf 'git_detect=%s\n'           "$GIT_DETECT"
  printf 'branch_count=%s\n'         "$BRANCH_COUNT"
  printf 'branches=%s\n'             "$(printf '%s\n' "$BRANCHES" | grep . | tr '\n' ' ' | sed 's/ $//')"
  printf 'current_branch=%s\n'       "$CURRENT_BRANCH"
  printf 'default_branch=%s\n'       "$DEFAULT_BRANCH"
  printf 'default_branch_source=%s\n' "$DEFAULT_SOURCE"
  printf 'prod_branch=%s\n'          "$PROD_BRANCH"
  printf 'integration_branch=%s\n'   "$INTEG_BRANCH"
  printf 'staging_branch=%s\n'       "$STAGE_BRANCH"
  printf 'default_trap=%s\n'         "$DEFAULT_TRAP"
  printf 'ci_provider=%s\n'          "$CI_PROVIDER"
  printf 'ci_evidence=%s\n'          "$CI_EVIDENCE"
  printf 'env_workflow_count=%s\n'   "$ENV_WORKFLOW_COUNT"
  printf 'env_workflows=%s\n'        "$(printf '%s\n' "$ENV_WORKFLOWS" | grep . | tr '\n' ' ' | sed 's/ $//')"
  printf 'env_conf_path=%s\n'        "$ENV_CONF"
  printf 'env_conf_state=%s\n'       "$ENV_CONF_STATE"
  printf 'env_conf_count=%s\n'       "$ENV_CONF_COUNT"
  printf 'env_conf_names=%s\n'       "$(printf '%s\n' "$ENV_CONF_NAMES" | grep . | tr '\n' ' ' | sed 's/ $//')"
  exit 0
fi

echo "Environment topology — DETECTED (nothing was written, no git was run)"
echo "  repository root       : $ROOT"
case "$GIT_DETECT" in
  none)     echo "  git metadata          : NOT FOUND — branch detection unavailable" ;;
  worktree) echo "  git metadata          : linked worktree (shared refs at $COMMONDIR)" ;;
  *)        echo "  git metadata          : $COMMONDIR" ;;
esac
echo ""
echo "  Branches present ($BRANCH_COUNT):"
if [ "$BRANCH_COUNT" -eq 0 ]; then
  echo "    (none readable)"
else
  printf '%s\n' "$BRANCHES" | grep . | sed 's/^/    - /'
fi
echo "  checked out           : $CURRENT_BRANCH"
echo "  default branch        : $DEFAULT_BRANCH   (source: $DEFAULT_SOURCE)"
echo ""
echo "  Inferred roles (existing branches only — no branch will be created):"
echo "    production          : ${PROD_BRANCH:-<none matched>}"
echo "    integration         : ${INTEG_BRANCH:-<none matched>}"
echo "    staging / rehearsal : ${STAGE_BRANCH:-<none matched>}"
echo ""
case "$DEFAULT_TRAP" in
  ok-default-is-integration)
    echo "  Default-branch trap   : OK — the default branch IS the integration branch," ;;
  advise-set-default)
    echo "  Default-branch trap   : ADVISORY — integration branch '$INTEG_BRANCH' is not the" ;;
  n/a-no-integration)
    echo "  Default-branch trap   : not applicable — no integration branch detected," ;;
  *)
    echo "  Default-branch trap   : UNKNOWN — the default branch could not be determined," ;;
esac
case "$DEFAULT_TRAP" in
  ok-default-is-integration) echo "                          which is the arrangement § 2.1 recommends." ;;
  advise-set-default)        echo "                          repository default ('$DEFAULT_BRANCH'). See § 2.1." ;;
  n/a-no-integration)        echo "                          so \"branch off the default\" has nothing to get wrong yet." ;;
  *)                         echo "                          so no advice is offered. Fail closed: § 4.2." ;;
esac
echo ""
echo "  CI provider           : $CI_PROVIDER${CI_EVIDENCE:+   ($CI_EVIDENCE)}"
echo "  Environment-ish CI    : $ENV_WORKFLOW_COUNT file(s) matched by name"
if [ "$ENV_WORKFLOW_COUNT" -gt 0 ]; then
  printf '%s\n' "$ENV_WORKFLOWS" | grep . | sed 's/^/    - /'
  echo "    (matched by FILENAME only — evidence you already have something,"
  echo "     not evidence of what it does. Nothing here will be modified.)"
fi
echo ""
echo "  environments.conf     : $ENV_CONF_STATE ($ENV_CONF_COUNT declared)"
if [ "$ENV_CONF_COUNT" -gt 0 ]; then
  printf '%s\n' "$ENV_CONF_NAMES" | grep . | sed 's/^/    - /'
fi
exit 0
