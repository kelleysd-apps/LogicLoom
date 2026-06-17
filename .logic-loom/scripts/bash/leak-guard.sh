#!/bin/bash
# =============================================================================
# LogicLoom — leak guard (TRACKED-CONTENT harness-dev assertion)
# Purpose: READ-ONLY assertion that a tree is safe to publish to the customer
#          template `main`. Operates on GIT-TRACKED content (`git ls-files`),
#          never the working-tree filesystem — so a customer's regenerated
#          runtime state (gitignored memory tiers, logs, worktree env) can never
#          trip it, and a tracked `.gitkeep` under a stripped dir is preserved.
#
# Asserts four things on the tracked tree:
#   1. No tracked path matches a manifest STRIP entry (harness-dev paths absent).
#   2. The shipped VISION.md stub carries no harness-dev roadmap markers.
#   3. No tracked file contains a SENSITIVE identity marker (owner email,
#      ioun-ai, absolute /workspaces paths, the kelleysd.com private-repo path).
#   4. No shipped file carries dev-history NARRATIVE (changelogs, migration
#      provenance, dated stamps, build-stage refs) — the post-history-scrub gate
#      so the template reads as a fresh harness. KEEP zones (tests/policies/
#      framework-updater) excluded per the history-surface coverage note.
#   `warn:` manifest entries are surfaced as NON-FATAL warnings (deferred items).
#
# Exit 0 = clean. Exit 1 = leak. Manifest-driven (template-strip-manifest.txt).
# Used by: sanitization-audit.sh Check 7 (private repo)  — NOT shipped to public.
# =============================================================================
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT may be overridden via LOOM_AUDIT_ROOT so this guard can run from a
# PRESERVED copy (outside the tree) to audit a sanitized tree that has already
# stripped this very script + manifest. The manifest travels WITH the script.
REPO_ROOT="${LOOM_AUDIT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
MANIFEST="$SCRIPT_DIR/template-strip-manifest.txt"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
FAIL=0; WARN=0

[ -f "$MANIFEST" ] || { echo "FATAL: manifest not found: $MANIFEST"; exit 1; }
git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "FATAL: $REPO_ROOT is not a git work tree (leak-guard needs tracked content)"; exit 1; }

# Tracked paths that STILL EXIST on disk (the snapshot that would ship). A
# tracked path removed-from-disk by strip-harness-dev (a staged-or-pending
# deletion) is NOT a leak; an untracked regenerated runtime file is NOT tracked.
# So we assert against (git-tracked ∩ present-on-disk).
TRACKED="$(git -C "$REPO_ROOT" ls-files | while IFS= read -r _f; do [ -e "$REPO_ROOT/$_f" ] && printf '%s\n' "$_f"; done)"

# Harness-dev roadmap markers that must never appear in a shipped VISION.md stub.
VISION_MARKERS='loom-migration|PR #?56|north-star for the whole harness|brian@kelleysd\.com|freeze residual|410 / 9 suites|Hermes|Nous'

# Sensitive identity markers that must never reach the PUBLIC template (hard-fail).
# Deliberately narrow: genuinely confidential strings, not harmless branch names.
ID_MARKERS='brian@kelleysd\.com|ioun-ai|/workspaces/|kelleysd\.com/'

# Collect warn: paths so the global scan defers (not hard-fails) on them.
WARN_PATHS=()

# --- Pass 1: manifest entries -----------------------------------------------
while IFS= read -r raw; do
  line="${raw%%#*}"
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -z "$line" ] && continue

  # stub: <path>  -> must exist clean (markers checked below if tracked)
  if [[ "$line" == stub:* ]]; then
    target="$(printf '%s' "${line#stub:}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    f="$REPO_ROOT/$target"
    if [ -f "$f" ] && grep -qiE "$VISION_MARKERS" "$f"; then
      echo -e "${RED}LEAK${NC}: $target carries harness-dev markers (must be the clean stub)"
      grep -niE "$VISION_MARKERS" "$f" | head -3 | sed 's/^/     /'
      FAIL=1
    fi
    continue
  fi

  # warn: <glob>  -> non-fatal; flag if tracked
  if [[ "$line" == warn:* ]]; then
    pat="$(printf '%s' "${line#warn:}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    WARN_PATHS+=("$pat")
    hit=0
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      case "$f" in $pat|$pat/*) hit=1; break ;; esac
    done <<EOF
$TRACKED
EOF
    if [ "$hit" -eq 1 ]; then
      echo -e "${YELLOW}WARN${NC}: deferred path still tracked: $pat (decide ship-scrubbed vs strip)"
      WARN=1
    fi
    continue
  fi

  # plain strip entry -> assert ABSENT from tracked content
  leaks=""
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in $line|$line/*) leaks="$leaks$f
" ;; esac
  done <<EOF
$TRACKED
EOF
  if [ -n "$leaks" ]; then
    echo -e "${RED}LEAK${NC}: harness-dev path present (tracked): $line"
    printf '%s' "$leaks" | head -5 | sed 's/^/     /'
    FAIL=1
  fi
done < "$MANIFEST"

# --- Pass 2: global sensitive-identity-marker scan over tracked files --------
# Exclude the release plumbing + sanitize tooling (they legitimately contain
# marker examples and are themselves stripped from the public snapshot) and any
# deferred warn: paths (surfaced separately above).
EXCLUDES=(
  ":(exclude).logic-loom/scripts/bash/leak-guard.sh"
  ":(exclude).logic-loom/scripts/bash/template-strip-manifest.txt"
  ":(exclude).logic-loom/scripts/bash/strip-harness-dev.sh"
  ":(exclude).logic-loom/scripts/bash/sanitize-for-template.sh"
  ":(exclude).logic-loom/scripts/bash/sanitization-audit.sh"
  ":(exclude).github/workflows/promote-to-main.yml"
  ":(exclude).github/workflows/leak-guard.yml"
  ":(exclude).logic-loom/scripts/bash/history-scrub.sh"
  ":(exclude).logic-loom/scripts/bash/history-scrub-rules.json"
  ":(exclude).docs/troubleshooting/*"
)
for p in "${WARN_PATHS[@]}"; do EXCLUDES+=(":(exclude)$p" ":(exclude)$p/**"); done

id_hits="$(git -C "$REPO_ROOT" grep -nIE "$ID_MARKERS" -- . "${EXCLUDES[@]}" 2>/dev/null)"
if [ -n "$id_hits" ]; then
  echo -e "${RED}LEAK${NC}: sensitive identity marker(s) in tracked content:"
  printf '%s\n' "$id_hits" | head -15 | sed 's/^/     /'
  FAIL=1
fi

# --- Pass 3: dev-history NARRATIVE scan (template must read as a fresh harness) ---
# Post-scrub gate: assert development-PROCESS history was scrubbed from SHIPPED
# files (changelogs, migration provenance, dated stamps, OUR build-stage refs).
# Markers are kept literal here so the gate is dependency-free (like ID_MARKERS);
# they mirror history-scrub-rules.json's leakGuardHistoryMarkers. KEEP zones are
# excluded per the history-surface coverage note: tests (current-state regression
# guards that name removed subsystems), policies (effective-date metadata),
# framework-updater (illustrative release examples) — plus the plumbing (EXCLUDES).
# Runs meaningfully POST-scrub; on un-stripped dev-main it will (correctly) flag
# the live history, exactly like the strip-path checks above.
HISTORY_MARKERS='What changed in v|What was removed \(not replaced\)|## Version History|Changes Summary \(v3|Migration source|loom-migration|DS-STAR|gstack-D|Loom migration, Stage|Stage 8 integrator|\(Stage 9|Stage 11|Stage 13|Stage-5 addition|retargeted in Stage|created in Stages|\*\*Last Updated\*\*: 20|\*\*Created\*\*: 20|Sprint 3 Task|\(NEW - Sprint|[Rr]emoval [Tt]arget: v|Plugin-First Architecture v4|Skill-Based Delegation v5|Plugin-First v4|Feature 003|introduced in v5.0.0|preserved from v5.0.0|preserves the v5.0.0|from v5.0.0|deferred to v0.2|deferred from v0.1|were converted to enhanced skills|RL telemetry was removed|\(legacy\)'
HIST_EXCLUDES=(
  "${EXCLUDES[@]}"
  ":(exclude)tests/*"
  ":(exclude).docs/policies/*"
  ":(exclude)plugins/loom-maintenance/skills/framework-updater/*"
  ":(exclude)plugins/loom-maintenance/scripts/extract-proposals.sh"
)
for p in "${WARN_PATHS[@]}"; do HIST_EXCLUDES+=(":(exclude)$p" ":(exclude)$p/**"); done
hist_hits="$(git -C "$REPO_ROOT" grep -nIE "$HISTORY_MARKERS" -- . "${HIST_EXCLUDES[@]}" 2>/dev/null)"
if [ -n "$hist_hits" ]; then
  echo -e "${RED}LEAK${NC}: dev-history narrative in shipped content (run history-scrub.sh):"
  printf '%s\n' "$hist_hits" | head -20 | sed 's/^/     /'
  FAIL=1
fi

# --- Verdict ----------------------------------------------------------------
if [ "$FAIL" -eq 0 ]; then
  if [ "$WARN" -eq 1 ]; then
    echo -e "${GREEN}leak-guard: clean${NC} (no harness-dev artifacts; deferred warnings above)"
  else
    echo -e "${GREEN}leak-guard: clean${NC} (no harness-dev artifacts present)"
  fi
fi
exit $FAIL
