# Quickstart: Plugin-First Architecture (v4.0)

**Branch**: `004-plugin-first-architecture` | **Date**: 2026-02-06

---

## Phase 1 Quickstart: Governance Plugin PoC (v3.2.0)

### Step 1: Create the sdd-governance plugin structure
```bash
mkdir -p sdd-governance/.claude-plugin
mkdir -p sdd-governance/hooks/scripts
mkdir -p sdd-governance/skills/{message-preflight,constitutional-compliance,domain-detection}
mkdir -p sdd-governance/agents
mkdir -p sdd-governance/scripts
```

### Step 2: Create plugin manifest
```bash
# Create sdd-governance/.claude-plugin/plugin.json
# with name, version, description, rl_metrics
```

### Step 3: Migrate governance components
```bash
# Copy existing components into plugin structure:
# - hooks/user-prompt-submit/governance-preflight.cjs → hooks/scripts/
# - skills/validation/message-preflight/SKILL.md → skills/message-preflight/
# - skills/validation/constitutional-compliance/SKILL.md → skills/constitutional-compliance/
# - skills/validation/domain-detection/SKILL.md → skills/domain-detection/
# - agents/product/constitutional-governance-agent.md → agents/
# - scripts/bash/constitutional-check.sh → scripts/
```

### Step 4: Create hooks.json
```json
{
  "hooks": [
    {
      "event": "UserPromptSubmit",
      "matcher": {},
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/governance-preflight.cjs"
    },
    {
      "event": "PreToolUse",
      "matcher": { "tool_name": "Bash" },
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/git-safety-gate.sh"
    }
  ]
}
```

### Step 5: Install and validate
```bash
# Install the plugin locally
claude plugin install ./sdd-governance

# Verify it loaded
claude plugin list

# Test hot-swap
claude plugin disable sdd-governance  # Should warn: governance is protected
claude plugin enable sdd-governance   # Should confirm: already active

# Run a test prompt that triggers governance
# Expected: 4-step pre-flight check executes via plugin hook
```

### Step 6: Validate RL metrics tracking
```bash
# After several interactions, check plugin.json rl_metrics
# success_rate should be updating via PostToolUse hook
```

---

## Validation Checklist

- [ ] Plugin installs without errors
- [ ] Plugin hooks fire on UserPromptSubmit
- [ ] Pre-flight compliance check works identically to monolithic version
- [ ] Plugin can be disabled (with governance protection warning)
- [ ] Plugin RL metrics update after skill invocations
- [ ] Existing monolithic skills still work alongside plugin
- [ ] No token overhead increase >10%

---
