#!/usr/bin/env bash
# check-gh-telemetry.sh — DETECT AND INFORM. Never writes.
#
# GitHub CLI telemetry is opt-OUT (on by default since gh v2.91.0), and every
# LogicLoom project leans on `gh`. So the harness tells you once, with the exact
# command, and stops there.
#
# ── The boundary this script exists to respect ───────────────────────────────
# LogicLoom writes nothing outside the repository. `gh` telemetry is a per-USER,
# per-MACHINE setting living in ~/.config/gh/config.yml — the user's layer, not
# the harness's. See START_HERE.md § "Where do my personal preferences go?" and
# CLAUDE.md § "Harness ↔ user boundary".
#
# GitHub issue #55 originally proposed writing `telemetry: disabled` into the gh
# config AND appending `export GH_TELEMETRY=0` to ~/.zshrc / ~/.bashrc during
# setup. That was rejected: it reaches past ~/.claude/ into machine-wide shell
# configuration, and it justified itself with Principle VI (approval before
# anything leaves the machine) while itself being an unapproved write. Detection
# gets the same outcome for anyone who cares, with zero writes.
#
# ── Why this does NOT shell out to `gh config get telemetry` ─────────────────
# `gh config` can MATERIALIZE a default ~/.config/gh/config.yml when none
# exists. That is a write outside the repo — exactly what this script promises
# not to do. So presence is probed with `command -v` and the setting is read by
# parsing the config file directly. This script invokes no `gh` subcommand at
# all; grep the source and you will find none.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   check-gh-telemetry.sh              # notice mode: silent unless action is warranted
#   check-gh-telemetry.sh --status     # one machine-readable token on stdout
#   check-gh-telemetry.sh --verbose    # always explain what was found and why
#
# Statuses: gh-absent | opted-out-env | opted-out-config | enabled
#
# ALWAYS exits 0. This is informational; it must never fail or block setup —
# not when gh is missing, not when the config is unreadable, not ever.
#
# bash 3.2 safe: no associative arrays, no mapfile, no ${var,,}.
set -uo pipefail

MODE="notice"
case "${1:-}" in
  --status)  MODE="status" ;;
  --verbose) MODE="verbose" ;;
  --notice|"") MODE="notice" ;;
  -h|--help)
    sed -n '1,35p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    # Unknown flag: behave as notice rather than erroring. Informational tools
    # do not get to break someone's bootstrap over an argument typo.
    MODE="notice"
    ;;
esac

# Colors only on a TTY; setup logs and CI capture stay clean.
if [ -t 1 ]; then
  C_BLUE='\033[0;34m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[1;33m'; C_NC='\033[0m'
else
  C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_NC=''
fi

# ── Where gh keeps its config (read-only resolution) ─────────────────────────
gh_config_file() {
  if [ -n "${GH_CONFIG_DIR:-}" ]; then
    printf '%s\n' "${GH_CONFIG_DIR}/config.yml"
  elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
    printf '%s\n' "${XDG_CONFIG_HOME}/gh/config.yml"
  else
    printf '%s\n' "${HOME:-}/.config/gh/config.yml"
  fi
}

# ── Is an env var an explicit opt-out? ───────────────────────────────────────
# DO_NOT_TRACK is the cross-tool convention: set to anything truthy = opt out.
env_says_do_not_track() {
  case "${DO_NOT_TRACK:-}" in
    ""|0|false|FALSE|False|off|OFF|no|NO) return 1 ;;
    *) return 0 ;;
  esac
}
# GH_TELEMETRY is gh-specific; a falsy value is the opt-out.
env_says_gh_telemetry_off() {
  case "${GH_TELEMETRY:-}" in
    0|false|FALSE|False|off|OFF|no|NO|disabled|DISABLED) return 0 ;;
    *) return 1 ;;
  esac
}

# ── Read `telemetry:` out of config.yml without invoking gh ──────────────────
# Top-level key only, comments and inline comments stripped. Any read failure
# yields the empty string, which the caller treats as "not set".
config_telemetry_value() {
  local f="$1"
  [ -n "$f" ] || return 0
  [ -f "$f" ] || return 0
  [ -r "$f" ] || return 0
  grep -E '^[[:space:]]*telemetry[[:space:]]*:' "$f" 2>/dev/null \
    | head -1 \
    | sed -E 's/^[[:space:]]*telemetry[[:space:]]*:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//; s/^"//; s/"$//' \
    || true
}

CONFIG_FILE="$(gh_config_file)"
GH_PRESENT="no"
command -v gh >/dev/null 2>&1 && GH_PRESENT="yes"

STATUS="enabled"
DETAIL=""

if [ "$GH_PRESENT" != "yes" ]; then
  STATUS="gh-absent"
  DETAIL="GitHub CLI (gh) is not on PATH — nothing to report."
elif env_says_do_not_track; then
  STATUS="opted-out-env"
  DETAIL="DO_NOT_TRACK is set in this environment."
elif env_says_gh_telemetry_off; then
  STATUS="opted-out-env"
  DETAIL="GH_TELEMETRY is set to an opt-out value in this environment."
else
  TELEMETRY_VALUE="$(config_telemetry_value "$CONFIG_FILE")"
  case "$TELEMETRY_VALUE" in
    disabled|DISABLED|off|OFF|false|FALSE|0|no|NO)
      STATUS="opted-out-config"
      DETAIL="'telemetry: ${TELEMETRY_VALUE}' is set in ${CONFIG_FILE}."
      ;;
    "")
      STATUS="enabled"
      if [ -f "$CONFIG_FILE" ]; then
        DETAIL="No telemetry key in ${CONFIG_FILE}; gh telemetry defaults to ON."
      else
        DETAIL="No gh config file at ${CONFIG_FILE} yet; gh telemetry defaults to ON."
      fi
      ;;
    *)
      STATUS="enabled"
      DETAIL="'telemetry: ${TELEMETRY_VALUE}' in ${CONFIG_FILE} is not an opt-out value."
      ;;
  esac
fi

if [ "$MODE" = "status" ]; then
  printf '%s\n' "$STATUS"
  exit 0
fi

print_enabled_notice() {
  printf '%b\n' "${C_YELLOW}ℹ  GitHub CLI telemetry is currently ON for your user account.${C_NC}"
  printf '%s\n' "   ${DETAIL}"
  printf '%s\n' "   LogicLoom uses gh heavily, so you should know. It will NOT change this"
  printf '%s\n' "   for you — gh's config is yours, and the harness writes nothing outside"
  printf '%s\n' "   this repository. To opt out, run this yourself:"
  printf '%b\n' "     ${C_GREEN}gh config set telemetry disabled${C_NC}"
  printf '%s\n' "   Or, if you prefer an environment variable to a config change:"
  printf '%b\n' "     ${C_GREEN}export GH_TELEMETRY=0${C_NC}   (DO_NOT_TRACK=1 also works)"
  printf '%s\n' "   (Telemetry sends anonymous gh command-usage data to GitHub. The setting"
  printf '%s\n' "   lives in your gh config, not in this repository. Note gh EXTENSION"
  printf '%s\n' "   telemetry is per-extension and is not covered by either opt-out.)"
}

case "$STATUS" in
  enabled)
    print_enabled_notice
    ;;
  gh-absent)
    [ "$MODE" = "verbose" ] && printf '%b\n' "${C_BLUE}ℹ  ${DETAIL}${C_NC}"
    ;;
  opted-out-env|opted-out-config)
    [ "$MODE" = "verbose" ] && printf '%b\n' "${C_GREEN}✓${C_NC}  gh telemetry is already opted out. ${DETAIL}"
    ;;
esac

exit 0
