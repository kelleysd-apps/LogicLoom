# Plugin Testing Requirements

All plugins MUST meet these testing standards before merge.

This document is for people working inside a checkout of the LogicLoom
repository itself — every `tests/contract/...` / `tests/integration/...` command
below assumes that checkout. `tests/` is deliberately not installed into a
project that has adopted LogicLoom, so these commands are not available there.

## Required Tests

### 1. Manifest Validation (Automated)

Every plugin manifest (`plugin.json`) must pass:

```bash
# Run from repo root
bash tests/contract/plugins/test_plugin_lifecycle.sh
```

**Checks**:
- Valid JSON syntax
- Required fields: `name`, `version`, `description`, `dependencies`
- `loom-governance` in dependencies
- `name` uses the `loom-` prefix (legacy exception: `sdd-specification`)

### 2. Skill Structure Validation

Each skill directory must contain:
- `SKILL.md` with valid YAML frontmatter (`name`, `description`, `allowed-tools`)
- Content describing the skill's procedural steps

### 3. Agent Structure Validation

Each agent file must contain:
- YAML frontmatter with `name`, `description`, `tools`, `model`
- Agent behavioral guidelines

### 4. Hook Validation (if applicable)

Plugins with hooks must:
- Have `hooks/hooks.json` with valid structure
- Reference scripts that exist and are executable
- Specify valid event types (`UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`)

## Test Categories

### Contract Tests (Required for all PRs)

```bash
# Full plugin lifecycle tests
bash tests/contract/plugins/test_plugin_lifecycle.sh

# Expected: 53/53 passing (may increase as plugins are added)
```

### Integration Tests (Required for core/orchestration plugins)

```bash
# Framework integration tests
bash tests/integration/test_plugin_integration.sh
```

### Domain Brief Tests (Required when adding/changing a domain)

Domains are briefs in the `plugins/loom-governance/domain-briefs/` registry, not
plugins. Validate them via the `get_domain_brief` contract test:

```bash
# Exercises get_domain_brief over the domain-brief registry
bash tests/contract/test_memory_search.sh
```

## Writing Tests for New Plugins

Use the contract test pattern:

```bash
#!/usr/bin/env bash
set -euo pipefail

PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if eval "$condition"; then
    echo "  ✅ PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  ❌ FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# Your tests here
assert "Plugin has manifest" "[ -f plugins/your-plugin/.claude-plugin/plugin.json ]"
assert "Manifest is valid JSON" "python3 -c 'import json; json.load(open(\"plugins/your-plugin/.claude-plugin/plugin.json\"))'"

echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
```

## CI Pipeline

The GitHub Actions workflow (`.github/workflows/plugin-tests.yml`) runs:
1. Contract tests on every PR
2. Manifest validation on every push
3. Constitutional compliance check on main branch merges

## Coverage Targets

| Test Type | Target | Blocking? |
|-----------|--------|-----------|
| Contract (manifest) | 100% plugins | ✅ Yes |
| Skill structure | 100% skills | ✅ Yes |
| Agent structure | 100% agents | ✅ Yes |
| Hook validation | 100% hooks | ✅ Yes |
| Integration | 80%+ | ⚠️ Warning |
| E2E (swarm) | 50%+ | ❌ Not yet |
