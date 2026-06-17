#!/bin/bash

# =============================================================================
# LogicLoom Template Sanitization (v6.1)
# Purpose: Strip project/dev-specific artifacts so the branch is a clean template
#          for cloning. The framework README is PRESERVED (it is the GitHub-facing
#          explainer); the README→project swap happens later, at user-init time,
#          in init-project.sh.
# Usage:   bash .logic-loom/scripts/bash/sanitize-for-template.sh
# Audit:   bash .logic-loom/scripts/bash/sanitization-audit.sh   (non-destructive)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
REMOVED=0
removed() { echo -e "${GREEN}  ✅ $1${NC}"; REMOVED=$((REMOVED+1)); }

echo "============================================"
echo "  LogicLoom Template Sanitization v6.1"
echo "============================================"
echo ""

# -----------------------------------------------------------------------------
echo -e "${BLUE}[1/6] Removing per-project feature workspaces...${NC}"
# SDD waterfall specs (specs/###-name) and swarm features (features/<name>)
for d in specs/[0-9]*-* features/*/; do
  [ -d "$d" ] || continue
  case "$d" in features/) continue;; esac
  rm -rf "$d"; removed "Removed $d"
done
mkdir -p specs features
[ -f specs/.gitkeep ] || echo "# SDD waterfall specs (specs/###-name) are created per project" > specs/.gitkeep
[ -f features/.gitkeep ] || echo "# Swarm feature workspaces (features/<name>) are created per project" > features/.gitkeep

# -----------------------------------------------------------------------------
echo -e "${BLUE}[2/6] Removing project/dev documentation artifacts...${NC}"
# Dev-time docs that describe building THIS framework — not useful in a template.
# Framework docs (architecture/, guides/, policies/, governance/, design/,
# references/, troubleshooting/, agents/) are KEPT.
for dir in .docs/reports .docs/plans .docs/reviews .docs/history; do
  if [ -d "$dir" ]; then
    # Preserve dir-purpose README.md + .gitkeep; remove project/dev artifacts.
    find "$dir" -type f ! -name '.gitkeep' ! -name 'README.md' -delete 2>/dev/null || true
    [ -f "$dir/README.md" ] || echo "# Generated/dev docs live here (removed from template)" > "$dir/.gitkeep"
    removed "Cleared $dir/"
  fi
done

# -----------------------------------------------------------------------------
echo -e "${BLUE}[3/6] Cleaning build/test artifacts...${NC}"
for art in node_modules coverage .jest .nyc_output dist build; do
  [ -e "$art" ] && { rm -rf "$art"; removed "Removed $art"; }
done

# -----------------------------------------------------------------------------
echo -e "${BLUE}[4/6] Cleaning audit logs + generated state...${NC}"
for d in .docs/audit .docs/governance/audit; do
  if [ -d "$d" ]; then
    find "$d" -type f ! -name '.gitkeep' -delete 2>/dev/null || true
    echo "# Audit logs are generated at runtime" > "$d/.gitkeep"
    removed "Cleared $d/"
  fi
done
# Stray per-worktree + session state
rm -f .loom-worktree-env .loom-active-feature 2>/dev/null || true

# -----------------------------------------------------------------------------
echo -e "${BLUE}[5/6] Removing temporary files...${NC}"
find . -name '.DS_Store' -type f -delete 2>/dev/null || true
find . -name 'Thumbs.db' -type f -delete 2>/dev/null || true
find . -maxdepth 1 -name '*.patch' -type f -delete 2>/dev/null || true
rm -f README.md.backup 2>/dev/null || true

# -----------------------------------------------------------------------------
echo -e "${BLUE}[6/6] Writing template initialization pointer...${NC}"
# NOTE: README.md is intentionally PRESERVED — it is the LogicLoom framework
# explainer shown on GitHub. Cloners run init-project.sh, which archives it to
# FRAMEWORK_README.md and scaffolds a project-specific README.
cat > TEMPLATE_INIT.md <<'EOF'
# Initializing LogicLoom for your project

You are looking at the **LogicLoom framework template**. `README.md` describes the
framework itself. To turn this into your own project:

```bash
bash init-project.sh
```

That script:
- archives the framework `README.md` → `FRAMEWORK_README.md`,
- scaffolds a project-specific `README.md`,
- verifies prerequisites (Node.js, Git, Claude Code) and wires `.claude/` hooks,
- syncs plugin commands into `.claude/commands/`.

Then open Claude Code in the repo and pick a workflow pack (none is privileged):

- **Swarm** (exploratory): `/swarm explore` → `/create-prd` → plan mode →
  `/plan-review` → `/swarm implement` → `/review-team` → `/git-push`
- **SDD waterfall** (well-specified): `/specification` → `/build-team` /
  `/fullstack-team` → `/finalize`

See `START_HERE.md` for the full walkthrough and `CLAUDE.md` for governance.

**Framework**: LogicLoom v6.2.0 · **Constitution**: v3.2.0 (16 principles) ·
**Architecture**: governance core + interchangeable workflow packs
EOF
removed "Created TEMPLATE_INIT.md"

# -----------------------------------------------------------------------------
echo ""
echo "============================================"
echo "  Sanitization Complete"
echo "============================================"
echo ""
echo -e "${GREEN}✅ Items removed/reset: ${REMOVED}${NC}"
echo ""
echo -e "${YELLOW}Preserved:${NC} README.md (framework explainer), all framework docs,"
echo "           constitution, plugins, hooks, tests."
echo ""
echo "Next steps:"
echo "  1. Run: bash .logic-loom/scripts/bash/sanitization-audit.sh"
echo "  2. Review TEMPLATE_INIT.md"
echo "  3. Commit the sanitized template"
echo ""
