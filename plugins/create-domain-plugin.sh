#!/usr/bin/env bash
# Domain Plugin Scaffolding Script
# Usage: ./create-domain-plugin.sh <domain-name> <skills...> -- <agents...>
set -euo pipefail

DOMAIN="$1"; shift
SKILLS=(); AGENTS=()
MODE="skills"
for arg in "$@"; do
  if [ "$arg" = "--" ]; then MODE="agents"; continue; fi
  if [ "$MODE" = "skills" ]; then SKILLS+=("$arg"); else AGENTS+=("$arg"); fi
done

PLUGIN_DIR="sdd-domain-${DOMAIN}"
mkdir -p "${PLUGIN_DIR}"/{.claude-plugin,skills,agents}

# Create manifest
cat > "${PLUGIN_DIR}/.claude-plugin/plugin.json" << EOF
{
  "name": "sdd-domain-${DOMAIN}",
  "version": "1.0.0",
  "description": "SDD domain plugin for ${DOMAIN} operations — skills and agents for ${DOMAIN} development workflows.",
  "author": "kelleysd-apps",
  "license": "MIT",
  "keywords": ["sdd", "domain", "${DOMAIN}"],
  "dependencies": ["sdd-governance"],
  "rl_metrics": { "success_rate": 0.5, "selection_weight": 0.5, "invocation_count": 0, "avg_tokens": 0, "last_updated": "2026-02-06T00:00:00Z" }
}
EOF

# Create README
cat > "${PLUGIN_DIR}/README.md" << EOF
# sdd-domain-${DOMAIN}
Domain plugin for ${DOMAIN} development workflows.
## Skills: ${SKILLS[*]}
## Agents: ${AGENTS[*]}
EOF

echo "Created ${PLUGIN_DIR}"
