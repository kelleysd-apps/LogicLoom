#!/usr/bin/env bash
# Install the LogicLoom off-host git-approval adapter into THIS repository, so
# Principle VI (no autonomous git mutation) is enforced on a non-Claude host.
# Idempotent. Two layers:
#   1. pre-push hook (via core.hooksPath) — gates pushes (most dangerous op).
#   2. PATH git-wrapper (opt-in) — gates ALL git invocations.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

chmod +x "$DIR/git-approval-gate.sh" "$DIR/githooks/pre-push" "$DIR/bin/git" 2>/dev/null || true

# Layer 1: pre-push hook via core.hooksPath (relative to repo root when possible).
if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
  root="$(git rev-parse --show-toplevel)"
  rel="${DIR#"$root"/}/githooks"
  git config core.hooksPath "$rel"
  echo "✅ pre-push gate installed (core.hooksPath = $rel)"
else
  echo "⚠  not a git repo (or git missing) — skipped core.hooksPath; copy githooks/pre-push into .git/hooks manually."
fi

cat <<EOF

Optional (full coverage — gate ALL git, not just push): prepend the wrapper to PATH
in your shell profile or the host's agent config:

  export PATH="$DIR/bin:\$PATH"

Approve a mutation explicitly with:  LOOM_GIT_APPROVED=1 git <cmd>
Verify enforcement:                  bash tests/contract/test_git_adapter.sh
EOF
