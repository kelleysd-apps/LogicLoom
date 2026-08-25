#!/usr/bin/env bash
# promotion-record.sh — append one promotion outcome to the promotion ledger.
#
# The ledger is the ONLY thing the three promotion commands write. It exists so
# that `promotes_from` can be ENFORCED rather than merely declared: the gate
# refuses to promote into an environment whose predecessor has no successful
# entry here.
#
# WHAT IT DOES NOT DO: deploy, invoke a seam, run git, call a provider API, run a
# migration or a seed, or touch a secret. It appends a line to a TSV file.
#
# THE OUTCOME IS REPORTED, NOT OBSERVED. The harness does not run your deploy, so
# it cannot see whether it worked. Whoever (or whatever) ran the seam reports the
# result here. A ledger entry is therefore an ATTESTATION, exactly like the
# rehearsal attestation the gate reads — trustworthy to the degree the thing
# writing it is. That is stated rather than papered over.
#
# LEDGER FORMAT — tab-separated, append-only, one line per outcome:
#   <iso8601-utc>	<environment>	<commit>	<status>	<actor>	<note>
# Tabs are stripped from every field on write, so the columns cannot shift.
#
# USAGE
#   promotion-record.sh --env <name> --status success|failure [options]
#     --commit <sha>     the commit that was promoted (recorded verbatim)
#     --note "<text>"    free text; required for a failure, so a red line in the
#                        ledger is never mute
#     --actor <who>      defaults to $USER, else 'unknown'
#     --root DIR         repository root (default: inferred)
#     --state-dir DIR    default: $LOOM_PROMOTION_STATE_DIR, else <root>/.logic-loom/state
#     --list             print the ledger and exit (writes nothing)
#
# EXIT: 0 recorded (or listed), 1 refused, 2 usage error.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

ENVN=""; STATUS=""; COMMIT=""; NOTE=""; ACTOR=""; ROOT=""; STATE_DIR=""; LIST=0

usage() { sed -n '2,30p' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --env)        ENVN="${2:-}"; shift 2 || true ;;
    --env=*)      ENVN="${1#--env=}"; shift ;;
    --status)     STATUS="${2:-}"; shift 2 || true ;;
    --status=*)   STATUS="${1#--status=}"; shift ;;
    --commit)     COMMIT="${2:-}"; shift 2 || true ;;
    --commit=*)   COMMIT="${1#--commit=}"; shift ;;
    --note)       NOTE="${2:-}"; shift 2 || true ;;
    --note=*)     NOTE="${1#--note=}"; shift ;;
    --actor)      ACTOR="${2:-}"; shift 2 || true ;;
    --actor=*)    ACTOR="${1#--actor=}"; shift ;;
    --root)       ROOT="${2:-}"; shift 2 || true ;;
    --root=*)     ROOT="${1#--root=}"; shift ;;
    --state-dir)  STATE_DIR="${2:-}"; shift 2 || true ;;
    --state-dir=*) STATE_DIR="${1#--state-dir=}"; shift ;;
    --list)       LIST=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) printf 'ERROR: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

_sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "$ROOT" ] || ROOT="$(cd "$_sd/../../.." && pwd)"
[ -n "$STATE_DIR" ] || STATE_DIR="${LOOM_PROMOTION_STATE_DIR:-$ROOT/.logic-loom/state}"
LEDGER="$STATE_DIR/promotion-ledger.tsv"

if [ "$LIST" -eq 1 ]; then
  if [ ! -f "$LEDGER" ]; then
    printf 'promotion ledger: none yet at %s — nothing has been promoted.\n' "$LEDGER"
    exit 0
  fi
  printf 'promotion ledger: %s\n\n' "$LEDGER"
  printf 'WHEN\tENVIRONMENT\tCOMMIT\tSTATUS\tACTOR\tNOTE\n'
  cat "$LEDGER"
  exit 0
fi

refuse() {
  printf 'REFUSED: nothing was recorded.\n' >&2
  printf '  WHY: %s\n' "$1" >&2
  shift
  while [ $# -gt 0 ]; do printf '  %s\n' "$1" >&2; shift; done
  exit 1
}

[ -n "$ENVN" ] || { printf 'ERROR: --env <name> is required.\n' >&2; exit 2; }
case "$ENVN" in
  *[!A-Za-z0-9_-]*) refuse "invalid environment name '$ENVN' (allowed: A-Z a-z 0-9 _ -)." ;;
esac
case "$STATUS" in
  success|failure) ;;
  "") printf 'ERROR: --status success|failure is required.\n' >&2; exit 2 ;;
  *)  refuse "--status must be 'success' or 'failure', got '$STATUS'." \
             "There is no third state. A promotion whose outcome is unknown is a FAILURE until someone establishes otherwise (policy § 4.2)." ;;
esac
if [ "$STATUS" = "failure" ] && [ -z "$NOTE" ]; then
  refuse "a failure needs a --note." \
         "A red line in the ledger with no reason is the failure mode policy § 4.2 exists to prevent: a verdict nobody can act on." \
         "FIX: --note \"<what broke, and where to look>\"" \
         "ALSO: policy § 4.5 — keep the rehearsal environment ALIVE on a failed production promotion. It is the diagnostic diff between 'the rehearsal passed' and 'production failed'."
fi
[ -n "$ACTOR" ] || ACTOR="${USER:-unknown}"
[ -n "$COMMIT" ] || COMMIT="-"

# Strip tabs and newlines so a field can never shift a column.
clean() { printf '%s' "$1" | tr '\t\n' '  '; }

if ! mkdir -p "$STATE_DIR" 2>/dev/null; then
  refuse "could not create the promotion state directory: $STATE_DIR"
fi
WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LINE="$(printf '%s\t%s\t%s\t%s\t%s\t%s' \
  "$WHEN" "$(clean "$ENVN")" "$(clean "$COMMIT")" "$STATUS" "$(clean "$ACTOR")" "$(clean "$NOTE")")"

if ! printf '%s\n' "$LINE" >> "$LEDGER" 2>/dev/null; then
  refuse "could not append to the promotion ledger: $LEDGER"
fi

printf 'Recorded in %s\n' "$LEDGER"
printf '  %s\n' "$(printf '%s' "$LINE" | tr '\t' ' ')"
if [ "$STATUS" = "success" ]; then
  printf '\nThe next stage that promotes_from '\''%s'\'' will now pass its predecessor check.\n' "$ENVN"
  printf 'This records a REPORTED outcome: the harness did not run your deploy and did not observe it.\n'
  printf '"It deployed" and "it was proven to work" are different claims (policy § 6.3).\n'
fi
exit 0
