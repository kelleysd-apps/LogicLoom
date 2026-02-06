#!/usr/bin/env bash
# Setup planning scaffolding for a feature
# NOTE: DS-STAR verification removed - verification happens in skill AFTER content generation
set -e
JSON_MODE=false
for arg in "$@"; do case "$arg" in --json) JSON_MODE=true ;; --help|-h) echo "Usage: $0 [--json]"; exit 0 ;; esac; done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
eval $(get_feature_paths)
check_feature_branch "$CURRENT_BRANCH" || exit 1
mkdir -p "$FEATURE_DIR"
TEMPLATE="$REPO_ROOT/.specify/templates/plan-template.md"
[[ -f "$TEMPLATE" ]] && cp "$TEMPLATE" "$IMPL_PLAN"

# NOTE: DS-STAR verification is now handled by the unified-specification skill
# AFTER the AI generates the actual plan content. This script only scaffolds.
echo ""
echo "=========================================="
echo "Planning scaffolding complete"
echo "=========================================="
echo "Feature dir: $FEATURE_DIR"
echo "Plan file: $IMPL_PLAN (template copied)"
echo ""
echo "Next: AI will generate plan content, then DS-STAR verification runs"
echo "=========================================="
echo ""

if $JSON_MODE; then
  printf '{"FEATURE_SPEC":"%s","IMPL_PLAN":"%s","SPECS_DIR":"%s","BRANCH":"%s"}\n' \
    "$FEATURE_SPEC" "$IMPL_PLAN" "$FEATURE_DIR" "$CURRENT_BRANCH"
else
  echo "FEATURE_SPEC: $FEATURE_SPEC"; echo "IMPL_PLAN: $IMPL_PLAN"; echo "SPECS_DIR: $FEATURE_DIR"; echo "BRANCH: $CURRENT_BRANCH"
fi
