#!/usr/bin/env bash
# promote-gate.sh — THE GATE for the three-command promotion lifecycle.
#
# WHAT IT DOES: reads `.logic-loom/config/environments.conf`, decides whether a
# promotion INTO a named environment is allowed to proceed, and — if it is —
# performs the confirmation whose strength the declaration asked for. It then
# prints the PRODUCT-owned deploy seam command for a human to run.
#
# WHAT IT DOES NOT DO, EVER:
#   - deploy anything, or invoke the `deploy` seam
#   - run git (no rev-parse, no merge-base, no checkout, no tag) — Principle VI
#   - call a cloud or CI provider API
#   - run a migration, a seed, a teardown, or a rollback
#   - read, write, or touch a secret
#
# It is a GATE and a CONFIRMATION, nothing else. Every step that actually
# changes a deployed system is behind the `deploy` seam, which the product owns
# and the harness never inspects (environment-promotion-policy.md § 8, § 10).
#
# HOUSE STYLE — FAIL CLOSED WITH A TYPED REASON (policy § 4.2). Anything this
# script cannot evaluate is a REFUSAL that prints (a) why it could not evaluate
# and (b) which override exists, if one does. It never passes optimistically.
#
# ─────────────────────────────────────────────────────────────────────────────
# USAGE
#   promote-gate.sh --to <env> [options]
#
#   --to <env>                    REQUIRED. The environment being promoted INTO.
#   --stage <label>               Human label for messages (dev|staging|prod).
#   --default-confirm <value>     Fallback confirmation strength when the target
#                                 environment declares no `confirm`. One of
#                                 none | prompt | typed:<PHRASE>. The DECLARED
#                                 value always wins — this is only the fallback.
#   --commit <sha-or-ref>         The commit being promoted. Required whenever
#                                 --require-rehearsal is set (the rehearsal
#                                 contract cannot be evaluated without it).
#   --from-ref <ref>              Informational: the branch/worktree being
#                                 promoted from. Recorded in the verdict only.
#   --yes                         Skip a `prompt` confirmation (automation).
#                                 It CANNOT skip a `typed:` confirmation, by
#                                 construction — policy § 4.3.
#   --require-rehearsal           Enforce the rehearsal contract (policy § 6.1)
#                                 against the predecessor environment.
#   --max-rehearsal-age-days N    Staleness bound (default 14, or
#                                 $LOOM_REHEARSAL_MAX_AGE_DAYS).
#   --allow-out-of-order "<why>"  Override the predecessor check ONLY. A
#                                 non-empty reason is REQUIRED and is echoed
#                                 into the verdict.
#   --allow-stale-rehearsal "<why>"
#                                 Override the rehearsal STALENESS BOUND ONLY.
#                                 It cannot override an absent, failed, or
#                                 unevaluable rehearsal. Narrow by design
#                                 (policy § 4.3: scope an override to one check,
#                                 never to the confirmation step).
#   --root DIR                    Repository root (default: inferred).
#   --conf PATH                   Declaration path (default:
#                                 $LOOM_ENVIRONMENTS_CONF, else
#                                 <root>/.logic-loom/config/environments.conf).
#   --state-dir DIR               Promotion state (default:
#                                 $LOOM_PROMOTION_STATE_DIR, else
#                                 <root>/.logic-loom/state).
#
# EXIT CODES
#   0  gate CLEARED — the operator may run the deploy seam
#   1  gate REFUSED — a typed reason was printed
#   2  usage error
#   3  NOTHING DECLARED — no environments.conf declaration; not a failure, a
#      state. The caller points the user at /scaffold-environments.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

TO=""; STAGE=""; DEFAULT_CONFIRM=""; COMMIT=""; FROM_REF=""
YES=0; REQUIRE_REHEARSAL=0; MAX_AGE=""
ALLOW_OOO=""; ALLOW_OOO_SET=0
ALLOW_STALE=""; ALLOW_STALE_SET=0
ROOT=""; CONF=""; STATE_DIR=""

usage() { sed -n '2,70p' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --to)              TO="${2:-}"; shift 2 || true ;;
    --to=*)            TO="${1#--to=}"; shift ;;
    --stage)           STAGE="${2:-}"; shift 2 || true ;;
    --stage=*)         STAGE="${1#--stage=}"; shift ;;
    --default-confirm) DEFAULT_CONFIRM="${2:-}"; shift 2 || true ;;
    --default-confirm=*) DEFAULT_CONFIRM="${1#--default-confirm=}"; shift ;;
    --commit)          COMMIT="${2:-}"; shift 2 || true ;;
    --commit=*)        COMMIT="${1#--commit=}"; shift ;;
    --from-ref)        FROM_REF="${2:-}"; shift 2 || true ;;
    --from-ref=*)      FROM_REF="${1#--from-ref=}"; shift ;;
    --yes|-y)          YES=1; shift ;;
    --require-rehearsal) REQUIRE_REHEARSAL=1; shift ;;
    --max-rehearsal-age-days) MAX_AGE="${2:-}"; shift 2 || true ;;
    --max-rehearsal-age-days=*) MAX_AGE="${1#--max-rehearsal-age-days=}"; shift ;;
    --allow-out-of-order)   ALLOW_OOO="${2:-}"; ALLOW_OOO_SET=1; shift 2 || true ;;
    --allow-out-of-order=*) ALLOW_OOO="${1#--allow-out-of-order=}"; ALLOW_OOO_SET=1; shift ;;
    --allow-stale-rehearsal)   ALLOW_STALE="${2:-}"; ALLOW_STALE_SET=1; shift 2 || true ;;
    --allow-stale-rehearsal=*) ALLOW_STALE="${1#--allow-stale-rehearsal=}"; ALLOW_STALE_SET=1; shift ;;
    --root)      ROOT="${2:-}"; shift 2 || true ;;
    --root=*)    ROOT="${1#--root=}"; shift ;;
    --conf)      CONF="${2:-}"; shift 2 || true ;;
    --conf=*)    CONF="${1#--conf=}"; shift ;;
    --state-dir) STATE_DIR="${2:-}"; shift 2 || true ;;
    --state-dir=*) STATE_DIR="${1#--state-dir=}"; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) printf 'ERROR: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

_sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "$ROOT" ] || ROOT="$(cd "$_sd/../../.." && pwd)"
[ -n "$CONF" ] || CONF="${LOOM_ENVIRONMENTS_CONF:-$ROOT/.logic-loom/config/environments.conf}"
[ -n "$STATE_DIR" ] || STATE_DIR="${LOOM_PROMOTION_STATE_DIR:-$ROOT/.logic-loom/state}"
[ -n "$MAX_AGE" ] || MAX_AGE="${LOOM_REHEARSAL_MAX_AGE_DAYS:-14}"
[ -n "$STAGE" ] || STAGE="$TO"

LEDGER="$STATE_DIR/promotion-ledger.tsv"

if [ -z "$TO" ]; then
  printf 'ERROR: --to <env> is required.\n' >&2
  exit 2
fi
case "$MAX_AGE" in
  ''|*[!0-9]*) printf 'ERROR: --max-rehearsal-age-days must be a whole number, got %s\n' "$MAX_AGE" >&2; exit 2 ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
# Output helpers. A refusal ALWAYS carries a reason and, where one exists, the
# override. This is the single most reusable pattern in the policy (§ 4.2) and
# it is the only shape a failure takes in this file.
# ─────────────────────────────────────────────────────────────────────────────
say() { printf '%s\n' "$*"; }
refuse() { # reason [override-line...]
  printf '\n'
  printf 'REFUSED: promotion into %s is not cleared.\n' "'$TO'"
  printf '  WHY: %s\n' "$1"
  shift
  while [ $# -gt 0 ]; do printf '  %s\n' "$1"; shift; done
  printf '  Nothing was deployed. No git command was run.\n'
  exit 1
}

say "═══════════════════════════════════════════════════════════"
say "  Promotion gate — into '$TO'${STAGE:+ (stage: $STAGE)}"
say "═══════════════════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# 0. The declaration must exist, be readable, and be VALID.
# ─────────────────────────────────────────────────────────────────────────────
if [ ! -f "$CONF" ]; then
  say ""
  say "NOTHING DECLARED: no environment declaration at"
  say "  $CONF"
  say ""
  say "This is not a failure — a project that deploys nowhere is a valid project"
  say "(Principle V). But a promotion gate has nothing to evaluate, so it will not"
  say "guess a topology on your behalf."
  say ""
  say "  Next step:  /scaffold-environments"
  say "              (detects the branches you already have, proposes a delta,"
  say "               and writes only what you name — it deploys nothing)"
  say ""
  say "Nothing was deployed. No git command was run. No file was written."
  exit 3
fi
if [ ! -r "$CONF" ]; then
  refuse "the environment declaration exists but is not readable: $CONF" \
         "OVERRIDE: none. Fix the file permissions; an unreadable gate input is unevaluable, so it fails closed."
fi

VALIDATOR="$_sd/validate-environments.sh"
if [ -x "$VALIDATOR" ] || [ -f "$VALIDATOR" ]; then
  if ! VOUT="$(bash "$VALIDATOR" "$CONF" --root "$ROOT" --quiet 2>&1)"; then
    refuse "the environment declaration is not valid, so no promotion order can be trusted." \
           "VALIDATOR SAID:" \
           "$(printf '%s' "$VOUT" | sed 's/^/    /')" \
           "OVERRIDE: none. Fix the declaration, then re-run."
  fi
else
  refuse "the declaration validator is missing at $VALIDATOR — the declaration cannot be checked for coherence." \
         "OVERRIDE: none. Restore the validator; an unevaluable gate fails closed."
fi

# ─────────────────────────────────────────────────────────────────────────────
# 1. Parse the declaration. Same grammar and same posture as
#    validate-environments.sh: parsed as TEXT, never sourced, never evaluated.
# ─────────────────────────────────────────────────────────────────────────────
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

NAMES=""
RECORDS=""      # name|branch|promotes_from|requires_approval|deploy|seed|confirm
cur_name=""; cur_branch=""; cur_from=""; cur_appr=""; cur_deploy=""
cur_seed=""; cur_confirm=""

flush_record() {
  [ -n "$cur_name" ] || return 0
  RECORDS="${RECORDS}${cur_name}|${cur_branch}|${cur_from}|${cur_appr}|${cur_deploy}|${cur_seed}|${cur_confirm}
"
  cur_branch=""; cur_from=""; cur_appr=""; cur_deploy=""; cur_seed=""; cur_confirm=""
}

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%%#*}"
  line="$(trim "$line")"
  [ -n "$line" ] || continue
  case "$line" in *=*) ;; *) continue ;; esac
  key="$(trim "${line%%=*}")"
  val="$(trim "${line#*=}")"
  case "$key" in
    environment)
      flush_record
      cur_name="$val"
      NAMES="${NAMES}${val}
"
      ;;
    branch)                   cur_branch="$val" ;;
    promotes_from)            cur_from="$val" ;;
    requires_approval)        cur_appr="$val" ;;
    deploy)                   cur_deploy="$val" ;;
    rehearsal_seed_allowlist) cur_seed="$val" ;;
    confirm)                  cur_confirm="$val" ;;
  esac
done < "$CONF"
flush_record

NAMES="$(printf '%s' "$NAMES" | grep . || true)"
RECORDS="$(printf '%s' "$RECORDS" | grep . || true)"

if [ -z "$RECORDS" ]; then
  say ""
  say "NOTHING DECLARED: $CONF exists, but declares no environment."
  say "(The shipped file is a worked example with every block commented out — that"
  say " is deliberate. Principle V: do not stand up a three-environment chain"
  say " before one environment is proven in use.)"
  say ""
  say "  Next step:  /scaffold-environments"
  say ""
  say "Nothing was deployed. No git command was run. No file was written."
  exit 3
fi

record_of() { printf '%s\n' "$RECORDS" | grep "^$1|" | head -1; }
fld() { printf '%s' "$1" | cut -d'|' -f"$2"; }

REC="$(record_of "$TO")"
if [ -z "$REC" ]; then
  refuse "environment '$TO' is not declared in $CONF." \
         "DECLARED: $(printf '%s' "$NAMES" | tr '\n' ' ')" \
         "OVERRIDE: none. Declare it (or run /scaffold-environments) — the gate will not promote into an environment it cannot read the rules for."
fi

T_BRANCH="$(fld "$REC" 2)"
T_FROM="$(fld "$REC" 3)"
T_APPROVAL="$(fld "$REC" 4)"; [ -n "$T_APPROVAL" ] || T_APPROVAL="false"
T_DEPLOY="$(fld "$REC" 5)"
T_SEED="$(fld "$REC" 6)"
T_CONFIRM_DECLARED="$(fld "$REC" 7)"

say ""
say "Target:        $TO"
say "  branch:      ${T_BRANCH:-<none declared>}"
say "  promotes_from: ${T_FROM:-<start of chain>}"
say "  requires_approval: $T_APPROVAL"
[ -n "$FROM_REF" ] && say "  promoting from ref: $FROM_REF"
[ -n "$COMMIT" ]   && say "  commit:      $COMMIT"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Confirmation strength — the DECLARATION is the source of truth.
#    The per-command default is only a fallback for an environment that declares
#    no `confirm`. That is what makes the ladder configurable instead of
#    hardcoded (policy § 4.3, § 9).
# ─────────────────────────────────────────────────────────────────────────────
CONFIRM=""; CONFIRM_SOURCE=""
if [ -n "$T_CONFIRM_DECLARED" ]; then
  CONFIRM="$T_CONFIRM_DECLARED"
  CONFIRM_SOURCE="declared in environments.conf"
elif [ -n "$DEFAULT_CONFIRM" ]; then
  CONFIRM="$DEFAULT_CONFIRM"
  CONFIRM_SOURCE="command default for stage '$STAGE' (no 'confirm' declared for '$TO')"
else
  CONFIRM="none"
  CONFIRM_SOURCE="fallback (no declaration, no command default)"
fi

case "$CONFIRM" in
  none|prompt) ;;
  typed:?*)    ;;
  *) refuse "confirmation strength '$CONFIRM' is not one of none | prompt | typed:<PHRASE> (source: $CONFIRM_SOURCE)." \
            "OVERRIDE: none. An unevaluable confirmation is not downgraded to a weaker one — it fails closed." ;;
esac

say "  confirm:     $CONFIRM  ($CONFIRM_SOURCE)"

# A production-scale stage whose declaration LOWERS the bar is honoured — the
# declaration is the source of truth and the user is allowed to change it — but
# it is never silent. Saying nothing here is how a production promotion quietly
# becomes a keystroke.
if [ "$STAGE" = "prod" ] || [ "$STAGE" = "production" ]; then
  case "$CONFIRM" in
    typed:*) ;;
    *) say "  NOTE: '$TO' declares confirm = '$CONFIRM', which is weaker than the"
       say "        typed-phrase default this stage would otherwise use. Honoured"
       say "        because the declaration is the source of truth — but recorded"
       say "        loudly (policy § 4.3: production blast radius wants a typed phrase)." ;;
  esac
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. Promotion ORDER — enforced from `promotes_from`, read off the ledger.
# ─────────────────────────────────────────────────────────────────────────────
say ""
say "── Promotion order ──"
if [ -z "$T_FROM" ]; then
  say "  '$TO' is the start of the chain — no predecessor to check."
else
  if [ -z "$(record_of "$T_FROM")" ]; then
    refuse "'$TO' declares promotes_from = '$T_FROM', which is not a declared environment." \
           "OVERRIDE: none. Fix the declaration."
  fi
  PRED_OK=0; PRED_LINE=""
  if [ -f "$LEDGER" ]; then
    if [ ! -r "$LEDGER" ]; then
      refuse "the promotion ledger exists but is not readable: $LEDGER — predecessor state is unevaluable." \
             "OVERRIDE: --allow-out-of-order \"<reason>\" (records the reason in the verdict)."
    fi
    PRED_LINE="$(grep -E "	${T_FROM}	" "$LEDGER" 2>/dev/null | grep -E "	success	" | tail -1 || true)"
    [ -n "$PRED_LINE" ] && PRED_OK=1
  fi
  if [ "$PRED_OK" -eq 1 ]; then
    say "  predecessor '$T_FROM': promoted successfully"
    say "    ledger entry: $(printf '%s' "$PRED_LINE" | tr '\t' ' ')"
  elif [ "$ALLOW_OOO_SET" -eq 1 ]; then
    if [ -z "$(trim "$ALLOW_OOO")" ]; then
      refuse "--allow-out-of-order was passed with an empty reason." \
             "OVERRIDE: supply one — --allow-out-of-order \"<why this is safe>\". An unexplained override is not an override."
    fi
    say "  predecessor '$T_FROM': NOT promoted — OVERRIDDEN"
    say "    documented reason: $ALLOW_OOO"
  else
    refuse "promotion order violated — '$TO' promotes_from '$T_FROM', and there is no successful promotion of '$T_FROM' on record." \
           "LEDGER: $LEDGER $( [ -f "$LEDGER" ] && printf '(present, no success entry for %s)' "'$T_FROM'" || printf '(absent — nothing has been promoted yet)')" \
           "FIX: promote into '$T_FROM' first, then record it:" \
           "     .logic-loom/scripts/bash/promotion-record.sh --env $T_FROM --status success --commit <sha>" \
           "OVERRIDE: --allow-out-of-order \"<reason>\" — a non-empty reason is required and is echoed into the verdict."
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. The REHEARSAL CONTRACT (policy § 6.1) — only for a stage that asks for it.
#
#    WHAT THE HARNESS VERIFIES vs WHAT IT TAKES ON TRUST — stated plainly, because
#    the difference is the whole honesty of this gate:
#
#      VERIFIED HERE: that an attestation file exists, is readable, declares
#        status = success, carries a parseable completion timestamp inside the
#        staleness bound, names a rehearsed commit, and that the commit being
#        promoted is either that exact commit or one the attestation explicitly
#        lists under `covers_commits`.
#
#      TAKEN ON TRUST: that the rehearsal actually ran, that it actually passed,
#        and that `rehearsed_commit` really is an ANCESTOR of what is being
#        promoted. The harness runs no git and calls no CI API, so it cannot and
#        does not check ancestry itself. The product's rehearsal seam asserts it.
#
#      § 6.4 IS THE PRODUCT'S PROBLEM, AND IT MUST BE TOLD: a staging branch
#        rebuilt from production and re-merged means the commit actually
#        rehearsed is the merge's SECOND PARENT, not its head. A seam that writes
#        the merge head into `rehearsed_commit` writes a plausible wrong answer,
#        and this gate will accept it. If the seam cannot unambiguously identify
#        the rehearsed commit, it must write status = failure — not a guess.
# ─────────────────────────────────────────────────────────────────────────────
if [ "$REQUIRE_REHEARSAL" -eq 1 ]; then
  say ""
  say "── Rehearsal contract (policy § 6.1) ──"
  if [ -z "$T_FROM" ]; then
    refuse "the rehearsal contract was requested, but '$TO' declares no promotes_from — there is no rehearsal environment to check." \
           "OVERRIDE: none. Declare promotes_from for '$TO' (the rehearsal environment), or promote a stage that does not require a rehearsal."
  fi
  ATT="$STATE_DIR/rehearsal-$T_FROM.conf"
  if [ ! -f "$ATT" ]; then
    refuse "no rehearsal attestation for '$T_FROM'. A production promotion may not proceed on an absent rehearsal." \
           "LOOKED FOR: $ATT" \
           "WHO WRITES IT: your rehearsal/staging deploy seam, at the end of a rehearsal run. The harness never writes it and never runs a rehearsal." \
           "TEMPLATE: .logic-loom/templates/environment-promotion/rehearsal-attestation.conf.tmpl" \
           "OVERRIDE: none. --allow-stale-rehearsal overrides the AGE BOUND only; it cannot conjure a rehearsal that did not happen."
  fi
  if [ ! -r "$ATT" ]; then
    refuse "the rehearsal attestation exists but is not readable: $ATT" \
           "OVERRIDE: none. An unevaluable rehearsal fails closed."
  fi

  att_get() { # key -> value ('' if absent)
    local k="$1" l ky vl
    while IFS= read -r l || [ -n "$l" ]; do
      l="${l%%#*}"; l="$(trim "$l")"
      [ -n "$l" ] || continue
      case "$l" in *=*) ;; *) continue ;; esac
      ky="$(trim "${l%%=*}")"; vl="$(trim "${l#*=}")"
      [ "$ky" = "$k" ] && { printf '%s' "$vl"; return 0; }
    done < "$ATT"
    printf ''
  }

  A_STATUS="$(att_get status)"
  A_COMMIT="$(att_get rehearsed_commit)"
  A_WHEN="$(att_get completed_at)"
  A_COVERS="$(att_get covers_commits)"

  # (a) it must have SUCCEEDED
  case "$A_STATUS" in
    success) say "  status:            success" ;;
    "")      refuse "the rehearsal attestation at $ATT declares no 'status' — the rehearsal outcome is unevaluable." \
                    "OVERRIDE: none." ;;
    *)       refuse "the last rehearsal of '$T_FROM' did not succeed (status = '$A_STATUS')." \
                    "ATTESTATION: $ATT" \
                    "NOTE: policy § 4.5 — the rehearsal environment is deliberately kept ALIVE on failure. It is the diagnostic diff. Do not tear it down to tidy up." \
                    "OVERRIDE: none. Fix the rehearsal and re-run it." ;;
  esac

  # (b) it must be WITHIN THE STALENESS BOUND
  if [ -z "$A_WHEN" ]; then
    refuse "the rehearsal attestation at $ATT declares no 'completed_at' — its age is unevaluable." \
           "OVERRIDE: none. An unparseable date is exactly the case policy § 4.2 says must fail rather than pass optimistically."
  fi
  EPOCH=""
  if EPOCH="$(date -u -d "$A_WHEN" +%s 2>/dev/null)"; then :
  elif EPOCH="$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$A_WHEN" +%s 2>/dev/null)"; then :
  else EPOCH=""; fi
  case "$EPOCH" in ''|*[!0-9]*) EPOCH="" ;; esac
  if [ -z "$EPOCH" ]; then
    refuse "the rehearsal attestation's completed_at ('$A_WHEN') could not be parsed as a date on this host." \
           "EXPECTED: ISO-8601 UTC, e.g. 2026-08-22T14:03:00Z" \
           "OVERRIDE: none — an unparseable timestamp is unevaluable, not 'probably fine'. Fix the seam that wrote it."
  fi
  NOW="$(date -u +%s)"
  AGE_DAYS=$(( (NOW - EPOCH) / 86400 ))
  say "  completed_at:      $A_WHEN  (${AGE_DAYS}d ago; bound ${MAX_AGE}d)"
  if [ "$AGE_DAYS" -gt "$MAX_AGE" ]; then
    if [ "$ALLOW_STALE_SET" -eq 1 ]; then
      if [ -z "$(trim "$ALLOW_STALE")" ]; then
        refuse "--allow-stale-rehearsal was passed with an empty reason." \
               "OVERRIDE: supply one — --allow-stale-rehearsal \"<why this stale rehearsal is still representative>\"."
      fi
      say "  staleness:         EXCEEDED — OVERRIDDEN"
      say "    documented reason: $ALLOW_STALE"
    else
      refuse "the rehearsal of '$T_FROM' is stale: ${AGE_DAYS} days old, bound is ${MAX_AGE} days." \
             "ATTESTATION: $ATT" \
             "OVERRIDE: --allow-stale-rehearsal \"<reason>\" — this override is scoped to the STALENESS BOUND ALONE. It does not weaken the success check, the ancestry check, or the confirmation (policy § 4.3)."
    fi
  fi

  # (c) ANCESTRY — declared by the seam, never computed here.
  if [ -z "$A_COMMIT" ]; then
    refuse "the rehearsal attestation at $ATT names no 'rehearsed_commit' — ancestry is unevaluable." \
           "SEE: policy § 6.4 — for a staging branch rebuilt from production and re-merged, the commit actually rehearsed is the MERGE'S SECOND PARENT, not its head. A seam that cannot identify it unambiguously must write status = failure rather than guess." \
           "OVERRIDE: none."
  fi
  if [ -z "$COMMIT" ]; then
    refuse "no --commit was supplied, so the gate cannot check what is being promoted against what was rehearsed ('$A_COMMIT')." \
           "FIX: pass --commit <sha> naming the commit being promoted." \
           "OVERRIDE: none."
  fi
  ANC_OK=0
  [ "$COMMIT" = "$A_COMMIT" ] && ANC_OK=1
  if [ "$ANC_OK" -eq 0 ] && [ -n "$A_COVERS" ]; then
    for c in $A_COVERS; do
      [ "$c" = "$COMMIT" ] && { ANC_OK=1; break; }
    done
  fi
  if [ "$ANC_OK" -eq 0 ]; then
    refuse "the commit being promoted ('$COMMIT') is neither the rehearsed commit ('$A_COMMIT') nor listed in the attestation's 'covers_commits'." \
           "WHAT THE HARNESS CAN AND CANNOT DO: it runs no git, so it cannot compute ancestry. The rehearsal seam must DECLARE it — either by attesting the exact commit being promoted, or by listing it under covers_commits." \
           "SEE: policy § 6.4 (the rehearsed commit may be a merge's SECOND parent) and § 4.2 (an ambiguous ancestry check fails closed rather than guessing at a parent)." \
           "OVERRIDE: none. --allow-stale-rehearsal covers the age bound only."
  fi
  say "  rehearsed_commit:  $A_COMMIT  (matches the promotion target)"
  say ""
  say "  What this green rehearsal DOES NOT prove (policy § 6.3): no end-to-end test"
  say "  drove the built artifact against the live rehearsal environment. \"It deployed"
  say "  successfully\" and \"it was proven to work\" are different claims. Do not report"
  say "  the former as the latter."
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. The DEPLOY SEAM must exist. The harness names it and never inspects it.
# ─────────────────────────────────────────────────────────────────────────────
say ""
say "── Deploy seam ──"
if [ -z "$T_DEPLOY" ]; then
  refuse "environment '$TO' declares no 'deploy' seam, so there is nothing to hand the promotion to." \
         "FIX: add   deploy = <path/to/your/deploy-$TO.sh>   to the '$TO' block in $CONF" \
         "     or run /scaffold-environments to write a placeholder seam your product then owns." \
         "OVERRIDE: none. The harness ships no deploy logic and will not invent one."
fi
case "$T_DEPLOY" in
  /*) SEAM="$T_DEPLOY" ;;
  *)  SEAM="$ROOT/$T_DEPLOY" ;;
esac
if [ ! -f "$SEAM" ]; then
  refuse "the declared deploy seam for '$TO' does not exist." \
         "LOOKED FOR: $SEAM" \
         "DECLARED AS: deploy = $T_DEPLOY (in $CONF)" \
         "OVERRIDE: none. A promotion with no seam behind it would be a gate that cleared nothing."
fi
if [ ! -r "$SEAM" ]; then
  refuse "the declared deploy seam for '$TO' exists but is not readable." \
         "LOOKED FOR: $SEAM" \
         "OVERRIDE: none."
fi
if [ ! -x "$SEAM" ]; then
  refuse "the declared deploy seam for '$TO' exists but is not executable." \
         "LOOKED FOR: $SEAM" \
         "FIX: chmod +x $SEAM" \
         "OVERRIDE: none. The harness will not second-guess a seam it is told to hand off to."
fi
say "  $T_DEPLOY — present, executable, PRODUCT-OWNED."
say "  The harness never inspects it and never runs it."
if [ -n "$T_SEED" ]; then
  say "  rehearsal seed allowlist declared: $T_SEED"
  say "  (never read by the harness — your seed must ABORT on an empty or missing"
  say "   allowlist, never widen to 'copy everything'. Policy § 4.4.)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 6. CONFIRMATION — last, so a refusal above never costs the operator a keystroke.
# ─────────────────────────────────────────────────────────────────────────────
say ""
say "── Confirmation ──"

read_line() { # -> a line from stdin, or empty; returns 1 if nothing could be read
  local ans=""
  if IFS= read -r ans; then printf '%s' "$ans"; return 0; fi
  # A partial final line with no newline still counts.
  if [ -n "$ans" ]; then printf '%s' "$ans"; return 0; fi
  return 1
}

case "$CONFIRM" in
  none)
    say "  none required (declared strength: none)."
    ;;
  prompt)
    if [ "$YES" -eq 1 ]; then
      say "  skipped by --yes (a 'prompt' confirmation is skippable by design — policy § 4.3)."
    else
      printf '  Promote into %s? [y/N] ' "'$TO'"
      if ! ANS="$(read_line)"; then
        printf '\n'
        refuse "a yes/no confirmation was required but no input could be read (stdin is closed and this is not a terminal)." \
               "OVERRIDE: --yes, for automation that has already made this decision deliberately."
      fi
      printf '\n'
      case "$ANS" in
        y|Y|yes|Yes|YES) say "  confirmed." ;;
        *) refuse "not confirmed at the yes/no prompt (answer was '${ANS:-<empty>}')." \
                  "OVERRIDE: --yes, for automation." ;;
      esac
    fi
    ;;
  typed:*)
    PHRASE="${CONFIRM#typed:}"
    # THE SHARP EDGE (policy § 4.3). --yes is READ here and deliberately does not
    # act. There is no flag, environment variable, or non-interactive mode in this
    # script that skips a typed confirmation — the only way past it is to type the
    # phrase. Where an override is genuinely needed at production scale it is
    # scoped to one CHECK (see --allow-stale-rehearsal), never to this step.
    if [ "$YES" -eq 1 ]; then
      say "  NOTE: --yes was passed and is IGNORED here. A typed confirmation is not"
      say "        skippable by any flag (policy § 4.3). Type the phrase or stop."
    fi
    say "  This environment demands a TYPED EXACT PHRASE."
    if [ "$T_APPROVAL" = "true" ]; then
      say "  It also declares requires_approval = true — that is your CI/reviewer gate,"
      say "  and it is a separate obligation from this prompt. The harness enforces neither."
    fi
    printf '  Type exactly:  %s\n' "$PHRASE"
    printf '  > '
    if ! TYPED="$(read_line)"; then
      printf '\n'
      refuse "a typed confirmation was required but no input could be read (stdin is closed)." \
             "OVERRIDE: none. --yes does not bypass a typed confirmation, and nothing else does either."
    fi
    printf '\n'
    if [ -z "$TYPED" ]; then
      refuse "the typed confirmation was empty." \
             "REQUIRED PHRASE: $PHRASE" \
             "OVERRIDE: none."
    fi
    if [ "$TYPED" != "$PHRASE" ]; then
      refuse "the typed confirmation did not match exactly." \
             "REQUIRED PHRASE: $PHRASE" \
             "OVERRIDE: none. Re-run the command and type it exactly, or stop."
    fi
    say "  phrase matched."
    ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
# 7. Verdict. The gate CLEARED. It has still deployed nothing.
# ─────────────────────────────────────────────────────────────────────────────
say ""
say "═══════════════════════════════════════════════════════════"
say "  GATE CLEARED — promotion into '$TO' may proceed"
say "═══════════════════════════════════════════════════════════"
say ""
say "The harness has deployed NOTHING and run NO git command. What it did was"
say "evaluate the declared gate and take your confirmation. The deployment itself"
say "is yours, behind the seam:"
say ""
say "    $T_DEPLOY"
say ""
say "Order matters and is structural, not conventional: MIGRATE BEFORE DEPLOY, as a"
say "dependency edge in your pipeline graph, not as step order in a script (§ 4.1)."
say ""
say "When the seam finishes, record the outcome so the next stage's predecessor"
say "check can see it:"
say ""
say "    .logic-loom/scripts/bash/promotion-record.sh --env $TO --status success --commit ${COMMIT:-<sha>}"
say "    .logic-loom/scripts/bash/promotion-record.sh --env $TO --status failure --commit ${COMMIT:-<sha>} --note \"<what broke>\""
say ""
[ "$T_APPROVAL" = "true" ] && {
  say "REMINDER: '$TO' declares requires_approval = true. That is a CI/reviewer gate"
  say "the harness does not enforce and did not check. Honour it."
  say ""
}
say "REMINDER (Principle VI): any branch merge, tag, or push this promotion needs is"
say "a git mutation. It is surfaced for your approval individually and is never run"
say "autonomously — by this script or by the agent that invoked it."
exit 0
