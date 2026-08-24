#!/usr/bin/env bash
# scaffold-environments.sh — OPT-IN scaffolding for the environment-promotion
# methodology (.docs/policies/environment-promotion-policy.md).
#
# WHAT IT IS: a planner that reads what a repository ALREADY has, proposes a
# DELTA, and — only when the user names each target explicitly — writes a small
# set of declaration, gate, and placeholder files.
#
# WHAT IT IS NOT, AND WILL NOT BECOME: a deployment engine. It writes no cloud
# or CI-provider deploy logic, no secret values, no migration runner, no seed or
# teardown script, and no rollback mechanism. Those are the product's
# (environment-promotion-policy.md § 8 and § 10; Principle V). If a future
# change to this file starts running a deployment, that change is wrong.
#
# THE CRUX — IT MUST ADOPT INTO AN EXISTING PROJECT. A repository that already
# has branches, CI, and a deployed environment is the NORMAL case. So:
#   1. it DETECTS (via detect-environment-topology.sh) and never assumes;
#   2. it proposes a delta, not a layout — a project that already has a
#      `staging` branch is never told to create one;
#   3. it NEVER overwrites. Anything it would write, it names first, and a file
#      that already exists is left alone — always, with no --force;
#   4. it CREATES NO BRANCH, and runs no git at all;
#   5. declining leaves the tree byte-identical, because --plan writes nothing.
#
# Usage:
#   scaffold-environments.sh [--root DIR] [--plan]
#   scaffold-environments.sh [--root DIR] --apply --only=TARGET[,TARGET...]
#
#   --plan            (default) print the proposal. WRITES NOTHING.
#   --apply           write. REQUIRES --only; there is no "apply everything"
#                     by omission. Per-target opt-in is the point.
#   --only=a,b,c      targets to write. `--only=all` writes every PROPOSED
#                     target (never a `present` or `conflict` one).
#   --deploy-dir DIR  where the product-owned seams go (default: scripts/deploy)
#   --quiet           suppress the narrative; keep the target table
#
# Targets:
#   envconf             append an environment declaration to environments.conf
#   ci-guard            a branch-boundary CI check for the production branch
#   checklist           a promotion checklist doc capturing the portable patterns
#   deploy-stubs        a commented deploy-seam placeholder per environment
#   branch-base-check   the default-branch-trap guard for this topology
#
# Exit: 0 = planned or applied successfully (including "nothing to do")
#       1 = a requested target could not be written (conflict / unmet condition)
#       2 = usage error
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

ROOT=""; MODE="plan"; ONLY=""; DEPLOY_DIR="scripts/deploy"; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)        ROOT="${2:-}"; shift 2 || true ;;
    --root=*)      ROOT="${1#--root=}"; shift ;;
    --plan)        MODE="plan"; shift ;;
    --apply)       MODE="apply"; shift ;;
    --only)        ONLY="${2:-}"; shift 2 || true ;;
    --only=*)      ONLY="${1#--only=}"; shift ;;
    --deploy-dir)  DEPLOY_DIR="${2:-}"; shift 2 || true ;;
    --deploy-dir=*) DEPLOY_DIR="${1#--deploy-dir=}"; shift ;;
    --quiet|-q)    QUIET=1; shift ;;
    -h|--help)     sed -n '2,45p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

if [ "$MODE" = "apply" ] && [ -z "$ONLY" ]; then
  cat >&2 <<'EOF'
ERROR: --apply requires --only=TARGET[,TARGET...].

REASON: every file this command writes is opted into individually, by name.
There is deliberately no "apply everything by omission" — a scaffolder that
writes whatever it felt like is how an existing project acquires files nobody
chose. Run with --plan first, read the table, then name the targets you want.
Use --only=all to accept every PROPOSED target (never a conflicting one).
EOF
  exit 2
fi

_sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "$ROOT" ] || ROOT="$(cd "$_sd/../../.." && pwd)"
if [ ! -d "$ROOT" ]; then echo "ERROR: --root is not a directory: '$ROOT'" >&2; exit 2; fi
ROOT="$(cd "$ROOT" && pwd)"

DETECT="$_sd/detect-environment-topology.sh"
TMPL_DIR="$_sd/../../templates/environment-promotion"
if [ ! -f "$DETECT" ]; then echo "ERROR: detector not found at '$DETECT'" >&2; exit 2; fi
if [ ! -d "$TMPL_DIR" ]; then echo "ERROR: templates not found at '$TMPL_DIR'" >&2; exit 2; fi
TMPL_DIR="$(cd "$TMPL_DIR" && pwd)"

MARKER="LOOM-SCAFFOLD-MARKER: environment-promotion"

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# ── detect ───────────────────────────────────────────────────────────────────
rc=0
DET="$(bash "$DETECT" --root "$ROOT" --format kv 2>/dev/null)" || rc=$?
if [ "$rc" -ne 0 ]; then
  echo "ERROR: detection failed (exit $rc) — refusing to propose anything." >&2
  echo "REASON: a proposal built on an unknown topology is a guess, and a guess" >&2
  echo "        that writes files is the failure this command exists to avoid." >&2
  exit 1
fi
kv() { printf '%s\n' "$DET" | sed -n "s|^$1=||p" | head -1; }

PROD_BRANCH="$(kv prod_branch)"
INTEG_BRANCH="$(kv integration_branch)"
STAGE_BRANCH="$(kv staging_branch)"
DEFAULT_BRANCH="$(kv default_branch)"
DEFAULT_TRAP="$(kv default_trap)"
CI_PROVIDER="$(kv ci_provider)"
ENV_CONF="$(kv env_conf_path)"
ENV_CONF_STATE="$(kv env_conf_state)"
ENV_CONF_NAMES="$(kv env_conf_names)"
ENV_WORKFLOWS="$(kv env_workflows)"

# A `|` in any substituted value would break the sed substitution below and the
# `|`-delimited plan records. Refuse rather than mangle (§ 4.2).
for _v in "$PROD_BRANCH" "$INTEG_BRANCH" "$STAGE_BRANCH" "$DEFAULT_BRANCH" "$DEPLOY_DIR"; do
  case "$_v" in
    *"|"*) echo "ERROR: a branch name or path contains '|', which this tool cannot safely substitute: '$_v'" >&2; exit 1 ;;
  esac
done

# ── the environment plan (roles → environments), from EXISTING branches only ─
# Nothing here invents a branch. A role with no branch produces no environment.
# Records: name|branch|promotes_from|requires_approval|confirm|seed
PLAN=""
prev=""
if [ -n "$INTEG_BRANCH" ]; then
  PLAN="${PLAN}dev|$INTEG_BRANCH||false|none|
"
  prev="dev"
fi
if [ -n "$STAGE_BRANCH" ]; then
  PLAN="${PLAN}staging|$STAGE_BRANCH|$prev|false|prompt|$DEPLOY_DIR/rehearsal-allowlist.txt
"
  prev="staging"
fi
if [ -n "$PROD_BRANCH" ]; then
  PLAN="${PLAN}prod|$PROD_BRANCH|$prev|true|typed:PROMOTE TO PRODUCTION|
"
fi
PLAN_NAMES="$(printf '%s\n' "$PLAN" | grep . | cut -d'|' -f1 | tr '\n' ' ' | sed 's/ $//')"
PLAN_COUNT="$(printf '%s\n' "$PLAN" | grep -c . 2>/dev/null || true)"
[ -n "$PLAN_COUNT" ] || PLAN_COUNT=0

# ── target paths ─────────────────────────────────────────────────────────────
P_ENVCONF="$ENV_CONF"
P_CIGUARD="$ROOT/.github/workflows/branch-boundary-guard.yml"
P_CHECKLIST="$ROOT/.docs/policies/promotion-checklist.md"
P_BASECHECK="$ROOT/$DEPLOY_DIR/check-branch-base.sh"

rel() { printf '%s' "${1#$ROOT/}"; }

# ── target status ────────────────────────────────────────────────────────────
# present  — exists AND carries our marker: idempotent no-op on a re-run
# conflict — exists WITHOUT our marker: someone else's file. Never clobbered.
# skip     — a precondition is unmet; the reason is always printed
# propose  — would be written
file_status() { # path -> present|conflict|absent
  if [ ! -e "$1" ]; then printf 'absent'; return; fi
  if grep -qF "$MARKER" "$1" 2>/dev/null; then printf 'present'; else printf 'conflict'; fi
}

S_ENVCONF=""; R_ENVCONF=""
if [ "$PLAN_COUNT" -eq 0 ]; then
  S_ENVCONF="skip"; R_ENVCONF="no production, integration, or staging branch was detected — there is nothing to declare, and no branch will be created to give it something"
elif [ ! -e "$P_ENVCONF" ]; then
  S_ENVCONF="propose"; R_ENVCONF="create the declaration file and add $PLAN_COUNT environment(s)"
elif grep -qF "$MARKER" "$P_ENVCONF" 2>/dev/null; then
  S_ENVCONF="present"; R_ENVCONF="already scaffolded — left exactly as-is"
elif [ -n "$ENV_CONF_NAMES" ]; then
  S_ENVCONF="conflict"; R_ENVCONF="this project already declares environments ($ENV_CONF_NAMES) — yours, not ours; nothing will be appended"
else
  S_ENVCONF="propose"; R_ENVCONF="append $PLAN_COUNT environment(s) below the file's own 'YOUR DECLARATIONS' line"
fi

S_CIGUARD=""; R_CIGUARD=""
ALLOWED_ALTS=""
[ -n "$INTEG_BRANCH" ] && ALLOWED_ALTS="$INTEG_BRANCH"
if [ -n "$STAGE_BRANCH" ]; then
  if [ -n "$ALLOWED_ALTS" ]; then ALLOWED_ALTS="$ALLOWED_ALTS|$STAGE_BRANCH"; else ALLOWED_ALTS="$STAGE_BRANCH"; fi
fi
if [ -z "$PROD_BRANCH" ]; then
  S_CIGUARD="skip"; R_CIGUARD="no production branch detected — there is no boundary to guard"
elif [ -z "$ALLOWED_ALTS" ]; then
  S_CIGUARD="skip"; R_CIGUARD="no integration or staging branch exists, so '$PROD_BRANCH' legitimately takes feature branches directly; a guard here would fail every PR you open"
else
  case "$CI_PROVIDER" in
    github-actions|github-actions-empty|none)
      S_CIGUARD="$(file_status "$P_CIGUARD")"
      case "$S_CIGUARD" in
        absent)
          S_CIGUARD="propose"
          R_CIGUARD="fail any PR into '$PROD_BRANCH' whose head is not $ALLOWED_ALTS"
          # No CI at all was detected, so writing a GitHub Actions workflow IS an
          # assumption. Surface it rather than make it silently: this target is
          # opted into by name like every other, and the reason line is where the
          # user gets to decline it.
          [ "$CI_PROVIDER" = "none" ] && R_CIGUARD="$R_CIGUARD — NOTE: no CI provider was detected, and this writes a GITHUB ACTIONS workflow. Decline this target if you use another provider; the pattern to port is in .docs/policies/environment-promotion-policy.md § 3"
          ;;
        present)  R_CIGUARD="already scaffolded — left exactly as-is" ;;
        conflict) R_CIGUARD="a file of that name already exists and is not ours — it will not be touched" ;;
      esac ;;
    *)
      S_CIGUARD="skip"
      R_CIGUARD="CI provider detected as '$CI_PROVIDER'; this scaffolder only knows how to write a GitHub Actions workflow. The pattern is in .docs/policies/environment-promotion-policy.md § 3 — port it by hand rather than let this tool guess at your provider's syntax" ;;
  esac
fi

S_CHECKLIST="$(file_status "$P_CHECKLIST")"; R_CHECKLIST=""
case "$S_CHECKLIST" in
  absent)   S_CHECKLIST="propose"; R_CHECKLIST="the portable patterns, written against this repository's branches" ;;
  present)  R_CHECKLIST="already scaffolded — left exactly as-is" ;;
  conflict) R_CHECKLIST="a promotion checklist already exists and is not ours — it will not be touched" ;;
esac

S_BASECHECK=""; R_BASECHECK=""
if [ -z "$INTEG_BRANCH" ]; then
  S_BASECHECK="skip"; R_BASECHECK="no integration branch detected, so \"branch off the default\" has nothing to get wrong here yet"
elif [ "$DEFAULT_BRANCH" = "unknown" ]; then
  S_BASECHECK="skip"; R_BASECHECK="the default branch could not be determined, and a guard generated against a guessed arrangement would be worse than none (fail closed)"
else
  S_BASECHECK="$(file_status "$P_BASECHECK")"
  case "$S_BASECHECK" in
    absent)   S_BASECHECK="propose"; R_BASECHECK="assert a new branch's base is '$INTEG_BRANCH', with the remedy this topology actually needs" ;;
    present)  R_BASECHECK="already scaffolded — left exactly as-is" ;;
    conflict) R_BASECHECK="a file of that name already exists and is not ours — it will not be touched" ;;
  esac
fi

# deploy-stubs: one file per planned environment; the target is `propose` if ANY
# stub is missing, and each individual stub is still checked before writing.
S_STUBS=""; R_STUBS=""; STUB_MISSING=0; STUB_CONFLICT=0; STUB_PRESENT=0
if [ "$PLAN_COUNT" -eq 0 ]; then
  S_STUBS="skip"; R_STUBS="no environments planned, so there is no seam to stub"
else
  while IFS='|' read -r n b f a c s; do
    [ -n "$n" ] || continue
    st="$(file_status "$ROOT/$DEPLOY_DIR/deploy-$n.sh")"
    case "$st" in
      absent)   STUB_MISSING=$((STUB_MISSING + 1)) ;;
      present)  STUB_PRESENT=$((STUB_PRESENT + 1)) ;;
      conflict) STUB_CONFLICT=$((STUB_CONFLICT + 1)) ;;
    esac
  done <<EOF
$PLAN
EOF
  if [ "$STUB_MISSING" -gt 0 ]; then
    S_STUBS="propose"; R_STUBS="$STUB_MISSING commented placeholder(s) under $DEPLOY_DIR/ — product-owned, never invoked by the harness"
    [ "$STUB_CONFLICT" -gt 0 ] && R_STUBS="$R_STUBS ($STUB_CONFLICT existing file(s) will be left alone)"
  elif [ "$STUB_CONFLICT" -gt 0 ]; then
    S_STUBS="conflict"; R_STUBS="$STUB_CONFLICT deploy script(s) already exist and are not ours — they will not be touched"
  else
    S_STUBS="present"; R_STUBS="already scaffolded — left exactly as-is"
  fi
fi

# ── narrative + table ────────────────────────────────────────────────────────
badge() {
  case "$1" in
    propose)  printf 'WOULD ADD ' ;;
    present)  printf 'ALREADY OK' ;;
    conflict) printf 'CONFLICT  ' ;;
    skip)     printf 'SKIP      ' ;;
    *)        printf '?         ' ;;
  esac
}

say ""
if [ "$MODE" = "plan" ]; then
  say "══ Environment promotion scaffolding — PROPOSAL (nothing has been written) ══"
else
  say "══ Environment promotion scaffolding — APPLYING (--only=$ONLY) ══"
fi
say ""
say "What this repository already has:"
say "  production branch    : ${PROD_BRANCH:-<none detected>}"
say "  integration branch   : ${INTEG_BRANCH:-<none detected>}"
say "  staging branch       : ${STAGE_BRANCH:-<none detected>}"
say "  default branch       : $DEFAULT_BRANCH"
say "  CI provider          : $CI_PROVIDER"
if [ -n "$ENV_WORKFLOWS" ]; then
  say "  existing env-ish CI  : $ENV_WORKFLOWS"
  say "                         (left alone — this command modifies no existing workflow)"
fi
say "  environments.conf    : $ENV_CONF_STATE${ENV_CONF_NAMES:+ ($ENV_CONF_NAMES)}"
say ""
say "NO BRANCH WILL BE CREATED. Roles above were matched against branches that"
say "already exist; a role reading <none detected> simply produces no environment."
say ""
if [ "$PLAN_COUNT" -gt 0 ]; then
  say "Environments it would declare ($PLAN_COUNT), in promotion order:"
  while IFS='|' read -r n b f a c s; do
    [ -n "$n" ] || continue
    from="start of chain"; [ -n "$f" ] && from="from '$f'"
    say "  - $n  → branch '$b'; $from; approval=$a; confirm=$c"
  done <<EOF
$PLAN
EOF
  say ""
fi
say "Targets:"
say "  [$(badge "$S_ENVCONF")] envconf            $(rel "$P_ENVCONF")"
say "                             $R_ENVCONF"
say "  [$(badge "$S_CIGUARD")] ci-guard           $(rel "$P_CIGUARD")"
say "                             $R_CIGUARD"
say "  [$(badge "$S_CHECKLIST")] checklist          $(rel "$P_CHECKLIST")"
say "                             $R_CHECKLIST"
say "  [$(badge "$S_STUBS")] deploy-stubs       $DEPLOY_DIR/deploy-<env>.sh"
say "                             $R_STUBS"
say "  [$(badge "$S_BASECHECK")] branch-base-check  $(rel "$P_BASECHECK")"
say "                             $R_BASECHECK"
say ""
say "Not written, ever: deploy logic, secret values, a migration runner, a seed"
say "or teardown script, or a rollback mechanism. Those are yours"
say "(.docs/policies/environment-promotion-policy.md § 8, § 10)."
say ""

if [ "$MODE" = "plan" ]; then
  say "Nothing was written. To adopt, name the targets you want:"
  say "  ./.logic-loom/scripts/bash/scaffold-environments.sh --apply --only=envconf,checklist"
  say "  ./.logic-loom/scripts/bash/scaffold-environments.sh --apply --only=all"
  say ""
  say "Declining costs nothing: --plan touches no file, so backing out here leaves"
  say "the tree byte-identical."
  exit 0
fi

# ── apply ────────────────────────────────────────────────────────────────────
want() { # target-id -> 0 if requested
  case ",$ONLY," in
    *,all,*) return 0 ;;
    *",$1,"*) return 0 ;;
  esac
  return 1
}

# Validate the requested target names before writing anything: a typo'd target
# must not silently write a partial set.
for t in $(printf '%s' "$ONLY" | tr ',' ' '); do
  case "$t" in
    all|envconf|ci-guard|checklist|deploy-stubs|branch-base-check) ;;
    "") ;;
    *) echo "ERROR: unknown target '$t'. Valid: envconf, ci-guard, checklist, deploy-stubs, branch-base-check, all" >&2; exit 2 ;;
  esac
done

WROTE=0; REFUSED=0

# Scratch space for template rendering. Never inside the template directory —
# that lives in the LogicLoom install and must be treated as read-only.
SCRATCH="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/loom-scaffold.$$")"
mkdir -p "$SCRATCH" 2>/dev/null || true
trap 'rm -rf "$SCRATCH"' EXIT

wrote() { printf 'wrote: %s\n' "$1"; WROTE=$((WROTE + 1)); }
# Apply-phase outcomes are NOT narrative and are never suppressed by --quiet.
# "I did nothing, and here is why" is the whole answer on an idempotent re-run;
# hiding it behind a verbosity flag would make a no-op indistinguishable from a
# silent failure.
note() { printf '%s\n' "$*"; }

# named TARGET — true only when the user typed this target LITERALLY. `--only=all`
# does not count. The distinction decides whether an unwritable target is an
# ERROR or a NOTE: asking for `ci-guard` by name and not getting it is a failed
# request; asking for `all` and not getting a target whose precondition is unmet
# is the correct outcome, and reporting it as a failure would train the reader
# to ignore a real refusal.
named() {
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}
# unwritable TARGET REASON
unwritable() {
  if named "$1"; then
    printf 'REFUSED: %s — %s\n' "$1" "$2" >&2
    REFUSED=$((REFUSED + 1))
  else
    note "not applicable: $1 — $2"
  fi
}

# render TEMPLATE OUTPUT KEY=VAL ...
#
# Substitution is LITERAL, via awk's index/substr — deliberately not sed. Two of
# the values that pass through here defeat sed outright: the allowed-head list
# is itself a regex alternation containing '|' (the obvious sed delimiter), and
# the checklist narratives contain '&', which sed expands to the whole match in
# a replacement. Either would corrupt a generated gate quietly. A literal
# replacement has no metacharacters to get wrong.
render() {
  local tmpl="$1"; local out="$2"; shift 2
  local tmp="$SCRATCH/render.$$"
  cp "$tmpl" "$tmp" || return 1
  local pair k v
  for pair in "$@"; do
    k="${pair%%=*}"; v="${pair#*=}"
    awk -v k="$k" -v v="$v" '
      {
        s = $0; out = ""
        while ((i = index(s, k)) > 0) {
          out = out substr(s, 1, i - 1) v
          s = substr(s, i + length(k))
        }
        print out s
      }' "$tmp" > "$tmp.n" || { rm -f "$tmp" "$tmp.n"; return 1; }
    mv "$tmp.n" "$tmp" || { rm -f "$tmp" "$tmp.n"; return 1; }
  done
  mv "$tmp" "$out"
}

ensure_dir() { [ -d "$1" ] || mkdir -p "$1"; }

# ── envconf ──────────────────────────────────────────────────────────────────
if want envconf; then
  case "$S_ENVCONF" in
    propose)
      ensure_dir "$(dirname "$P_ENVCONF")"
      {
        if [ ! -e "$P_ENVCONF" ]; then
          echo "# LogicLoom environment declaration"
          echo "# Grammar and full commentary: see the shipped template of this file in"
          echo "# .logic-loom/config/environments.conf upstream, or"
          echo "# .docs/policies/deployment-policy.md."
          echo ""
        fi
        echo ""
        echo "# ─────────────────────────────────────────────────────────────────────────"
        echo "# $MARKER"
        echo "#"
        echo "# Appended by /scaffold-environments from the branches this repository"
        echo "# ACTUALLY had at scaffold time. No branch was created. Nothing below is"
        echo "# enforced — no hook reads this file, and the harness deploys nothing."
        echo "# Validate with ./.logic-loom/scripts/bash/validate-environments.sh"
        echo "# Edit freely: the scaffolder will never rewrite a block it finds."
        echo "# ─────────────────────────────────────────────────────────────────────────"
        while IFS='|' read -r n b f a c s; do
          [ -n "$n" ] || continue
          echo ""
          echo "environment       = $n"
          echo "branch            = $b"
          [ -n "$f" ] && echo "promotes_from     = $f"
          echo "requires_approval = $a"
          echo "confirm           = $c"
          [ -n "$s" ] && echo "rehearsal_seed_allowlist = $s"
          echo "deploy            = $DEPLOY_DIR/deploy-$n.sh"
        done <<EOF
$PLAN
EOF
      } >> "$P_ENVCONF"
      wrote "$(rel "$P_ENVCONF")  (+$PLAN_COUNT environment block(s), appended)"
      ;;
    present) note "unchanged: $(rel "$P_ENVCONF") — already scaffolded, left byte-for-byte as-is" ;;
    conflict) unwritable "envconf" "$R_ENVCONF" ;;
    skip)     unwritable "envconf" "$R_ENVCONF" ;;
  esac
fi

# ── ci-guard ─────────────────────────────────────────────────────────────────
if want ci-guard; then
  case "$S_CIGUARD" in
    propose)
      ensure_dir "$(dirname "$P_CIGUARD")"
      remedy_target="the integration branch"
      [ -n "$INTEG_BRANCH" ] && remedy_target="'$INTEG_BRANCH'"
      render "$TMPL_DIR/branch-boundary-guard.yml.tmpl" "$P_CIGUARD" \
        "__PROD_BRANCH__=$PROD_BRANCH" \
        "__ALLOWED_HEAD_ALTERNATIVES__=$ALLOWED_ALTS" \
        "__INTEGRATION_BRANCH_DISPLAY__=${INTEG_BRANCH:-(none detected)}" \
        "__STAGING_BRANCH_DISPLAY__=${STAGE_BRANCH:-(none detected)}" \
        "__REMEDY_TARGET__=$remedy_target"
      wrote "$(rel "$P_CIGUARD")"
      say "   NOTE: this gate only takes effect once it exists ON '$PROD_BRANCH' —"
      say "         for pull_request events GitHub evaluates the workflow from the"
      say "         base branch. Merge it there, or it never fires."
      ;;
    present) note "unchanged: $(rel "$P_CIGUARD") — already scaffolded, left byte-for-byte as-is" ;;
    conflict) unwritable "ci-guard" "$R_CIGUARD" ;;
    skip)     unwritable "ci-guard" "$R_CIGUARD" ;;
  esac
fi

# ── checklist ────────────────────────────────────────────────────────────────
if want checklist; then
  case "$S_CHECKLIST" in
    propose)
      ensure_dir "$(dirname "$P_CHECKLIST")"
      case "$DEFAULT_TRAP" in
        ok-default-is-integration)
          trap_narr="the default branch (\`$DEFAULT_BRANCH\`) IS the integration branch, which is the arrangement the methodology recommends. Tooling that resolves \"the default branch\" gets the right base — **provided the pointer is fresh**."
          trap_act="Keep \`origin/HEAD\` fresh: \`git remote set-head origin --auto\`. That is the whole fix, and it costs one command." ;;
        advise-set-default)
          trap_narr="the integration branch (\`$INTEG_BRANCH\`) is **not** the repository default (\`$DEFAULT_BRANCH\`). Tooling that bases a branch on \"the default\" will therefore start from the production line."
          trap_act="Either make \`$INTEG_BRANCH\` the repository default and run \`git remote set-head origin --auto\`, **or** decide deliberately to keep \`$DEFAULT_BRANCH\` as the default and require every tool to name \`$INTEG_BRANCH\` explicitly. Both are valid; leaving it undecided is not. \`$(rel "$P_BASECHECK")\` enforces whichever you chose." ;;
        n/a-no-integration)
          trap_narr="there is no integration branch, so \"branch off the default\" has nothing to get wrong yet. This section becomes live the day you add one."
          trap_act="Revisit this when an integration branch appears — re-run \`/scaffold-environments\` at that point." ;;
        *)
          trap_narr="the default branch could not be determined from this repository's refs, so no advice is offered here rather than a guess."
          trap_act="Determine the default branch, then re-run \`/scaffold-environments\`. Fail closed: an unverifiable arrangement gets no recommendation." ;;
      esac
      case "$S_BASECHECK" in
        propose|present) basecheck_display="$(rel "$P_BASECHECK")" ;;
        *)               basecheck_display="the branch-base check (not scaffolded — $R_BASECHECK)" ;;
      esac
      case "$S_CIGUARD" in
        propose|present) ci_status="Scaffolded at \`$(rel "$P_CIGUARD")\` — merge it to \`$PROD_BRANCH\` for it to fire." ;;
        conflict)        ci_status="A file already exists at \`$(rel "$P_CIGUARD")\`; it was not touched. Check it yourself against the three properties below." ;;
        *)               ci_status="NOT scaffolded — $R_CIGUARD. Build it yourself, or record that you deliberately have no such boundary." ;;
      esac
      if [ -n "$STAGE_BRANCH" ]; then
        REHEARSAL_TMP="$SCRATCH/rehearsal.$$"
        cat > "$REHEARSAL_TMP" <<REHEARSAL_EOF
Your \`staging\` environment tracks \`$STAGE_BRANCH\` and declares
\`rehearsal_seed_allowlist = $DEPLOY_DIR/rehearsal-allowlist.txt\`.
**That allowlist file was not created.** It is yours, and the harness never
reads, parses, or validates it.

- [ ] The rehearsal environment is a **data-less fork of production** — its own
      database, auth schema, function runtime, endpoint. Not a shared slice of
      production, and not a production clone.
- [ ] Seeding is **two-tier**: reference/configuration tables cloned in full
      (rows that define product *behaviour*, containing no personal data), and
      per-account tables copied **only** for accounts on the explicit allowlist.
      Not a representative sample — a deliberately opted-in set.
- [ ] **The seed ABORTS on an empty or missing allowlist.** It must never
      degrade to "copy everything". That degradation is how production personal
      data lands in a lesser environment silently, and it is the
      highest-consequence input in the whole pipeline.
- [ ] The allowlist is small, and audited. It is the single biggest lever on how
      *realistic* versus how *safe* the rehearsal is, and it will not stay
      narrow by default.
- [ ] You picked **one** of allowlist-scoping or anonymization, deliberately, and
      wrote down which. They are two answers to the same question with different
      failure modes — anonymization risks an incomplete transform leaking a real
      identifier; allowlist-scoping copies real rows and depends on the allowlist
      staying narrow. Doing neither is the failure.
- [ ] **Teardown lives in the production release pipeline**, gated on every
      deploy step of that release succeeding — not in the rehearsal pipeline,
      and not on a schedule.
- [ ] **On a production failure, teardown is skipped on purpose.** The surviving
      environment is the diagnostic diff between "the rehearsal passed" and
      "production failed". The instinct to clean up the mess destroys the single
      most useful artifact the failure produced.
- [ ] You know whether your rehearsal environment is **reused** between cycles.
      "Per rehearsal" is usually the wrong mental model — data written during one
      rehearsal commonly survives into the next, and a fresh environment happens
      only on an explicit manual reset. "Per cycle, until reset" is the accurate
      framing.
- [ ] If the rehearsal pipeline writes to **any** production resource, that
      resource is named explicitly, here: ____________________________________
      The operating rule is absolute: **the rehearsal pipeline never writes to
      the production database.** Treat a second such resource as a change
      requiring review.
REHEARSAL_EOF
      else
        REHEARSAL_TMP="$SCRATCH/rehearsal.$$"
        cat > "$REHEARSAL_TMP" <<'REHEARSAL_EOF'
**No staging or rehearsal branch was detected in this repository, so no
rehearsal environment was declared and none was scaffolded.**

That is a legitimate end state, not a gap. Principle V (Progressive
Enhancement): do not stand up a three-environment promotion chain before one
environment is proven in use. One environment, or none, is a valid answer.

If you later add one, re-run `/scaffold-environments` and this section will be
regenerated with the full rehearsal checklist — data-less fork, two-tier seed,
the fail-closed allowlist, and teardown-on-success-only.
REHEARSAL_EOF
      fi
      render "$TMPL_DIR/promotion-checklist.md.tmpl" "$P_CHECKLIST" \
        "__PROD_BRANCH__=$PROD_BRANCH" \
        "__INTEGRATION_BRANCH_DISPLAY__=${INTEG_BRANCH:-none}" \
        "__STAGING_BRANCH_DISPLAY__=${STAGE_BRANCH:-none}" \
        "__ENV_NAMES_DISPLAY__=${PLAN_NAMES:-none}" \
        "__CI_GUARD_STATUS__=$ci_status" \
        "__TRAP_NARRATIVE__=$trap_narr" \
        "__TRAP_ACTION__=$trap_act" \
        "__BRANCH_BASE_CHECK_DISPLAY__=$basecheck_display"
      # multi-line injection: replace the placeholder LINE with the file body
      awk -v f="$REHEARSAL_TMP" '
        /__REHEARSAL_SECTION__/ { while ((getline l < f) > 0) print l; close(f); next }
        { print }
      ' "$P_CHECKLIST" > "$P_CHECKLIST.n" && mv "$P_CHECKLIST.n" "$P_CHECKLIST"
      rm -f "$REHEARSAL_TMP"
      wrote "$(rel "$P_CHECKLIST")"
      ;;
    present) note "unchanged: $(rel "$P_CHECKLIST") — already scaffolded, left byte-for-byte as-is" ;;
    conflict) unwritable "checklist" "$R_CHECKLIST" ;;
    skip)     unwritable "checklist" "$R_CHECKLIST" ;;
  esac
fi

# ── deploy-stubs ─────────────────────────────────────────────────────────────
if want deploy-stubs; then
  case "$S_STUBS" in
    propose|present)
      ensure_dir "$ROOT/$DEPLOY_DIR"
      while IFS='|' read -r n b f a c s; do
        [ -n "$n" ] || continue
        target="$ROOT/$DEPLOY_DIR/deploy-$n.sh"
        st="$(file_status "$target")"
        case "$st" in
          present)  note "unchanged: $(rel "$target") — already scaffolded, left byte-for-byte as-is" ; continue ;;
          conflict) printf 'REFUSED: %s — a file of that name already exists and is not ours; it was not touched\n' "$(rel "$target")" >&2; REFUSED=$((REFUSED + 1)); continue ;;
        esac
        if [ -n "$s" ]; then
          rnote="REHEARSAL SEED (§ 4.4). This environment declares rehearsal_seed_allowlist = $s. That file is YOURS and does not exist yet. Your seed must ABORT on an empty or missing allowlist — never degrade to copying everything. The harness never reads it."
        else
          rnote="This environment declares no rehearsal seed allowlist."
        fi
        render "$TMPL_DIR/deploy-seam.sh.tmpl" "$target" \
          "__ENV_NAME__=$n" \
          "__BRANCH__=$b" \
          "__CONFIRM__=$c" \
          "__CHECKLIST_PATH__=$(rel "$P_CHECKLIST")" \
          "__REHEARSAL_NOTE__=$rnote"
        chmod +x "$target" 2>/dev/null || true
        wrote "$(rel "$target")"
      done <<EOF
$PLAN
EOF
      ;;
    conflict) unwritable "deploy-stubs" "$R_STUBS" ;;
    skip)     unwritable "deploy-stubs" "$R_STUBS" ;;
  esac
fi

# ── branch-base-check ────────────────────────────────────────────────────────
if want branch-base-check; then
  case "$S_BASECHECK" in
    propose)
      ensure_dir "$(dirname "$P_BASECHECK")"
      if [ "$DEFAULT_TRAP" = "ok-default-is-integration" ]; then
        trap_mode="expect-default-is-integration"
      else
        trap_mode="expect-explicit-base"
      fi
      render "$TMPL_DIR/check-branch-base.sh.tmpl" "$P_BASECHECK" \
        "__INTEGRATION_BRANCH__=$INTEG_BRANCH" \
        "__DEFAULT_BRANCH__=$DEFAULT_BRANCH" \
        "__TRAP_MODE__=$trap_mode"
      chmod +x "$P_BASECHECK" 2>/dev/null || true
      wrote "$(rel "$P_BASECHECK")  (mode: $trap_mode)"
      ;;
    present) note "unchanged: $(rel "$P_BASECHECK") — already scaffolded, left byte-for-byte as-is" ;;
    conflict) unwritable "branch-base-check" "$R_BASECHECK" ;;
    skip)     unwritable "branch-base-check" "$R_BASECHECK" ;;
  esac
fi

say ""
if [ "$WROTE" -eq 0 ] && [ "$REFUSED" -eq 0 ]; then
  note "Nothing to do — every requested target was already in place, or not applicable"
  note "to this topology. No file was created, modified, or removed. This run is a"
  note "no-op, and re-running it will stay a no-op until your topology changes."
else
  note "Wrote $WROTE file(s); refused $REFUSED."
fi
if [ "$REFUSED" -gt 0 ]; then
  say ""
  say "Refusals above are deliberate and there is no --force. A scaffolder that"
  say "clobbers an existing file destroys work it cannot see. Move the file aside"
  say "and re-run if you want the scaffolded version."
  exit 1
fi
[ "$WROTE" -gt 0 ] && say "Validate the declaration: ./.logic-loom/scripts/bash/validate-environments.sh"
exit 0
