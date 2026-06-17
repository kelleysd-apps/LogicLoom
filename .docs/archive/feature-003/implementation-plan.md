# Feature 003: Upstream Sync Implementation Plan

**Generated**: 2025-12-19
**Branch**: dev-main
**Source**: feature-003-upstream-sync-report.md
**Status**: Ready for Implementation

---

## Analysis Summary

### Already Implemented ✅
1. Constitution v3.0.0 with Principle XV
2. CLAUDE.md updated with 15 principles references
3. Basic directory structure

### Missing Components ❌

**Critical Missing:**
- UserPromptSubmit hook system (2 files)
- Governance skill (1 file)
- Browser MCP integration (config update)
- Governance documentation (3+ files)
- Validation scripts (3 files)
- Constitutional check updates for Principle XV
- Refinement config updates for Principle XV
- Contract schemas and tests

---

## Implementation Plan

### Phase 1: Configuration Updates (Foundation)

**Priority**: HIGH
**Dependencies**: None
**Estimated Complexity**: Low

#### Task 1.1: Update refinement.conf
**File**: `.specify/config/refinement.conf`

**Changes**:
```bash
# Add after line 115 (Finalizer Configuration section):

# CONSTITUTIONAL PRINCIPLES (15 Total)

# Principle XV: File and Folder Organization
CHECK_FILE_ORGANIZATION=true
FILE_ORG_SEVERITY=error
```

**Validation**: Verify configuration loads without errors

---

#### Task 1.2: Update constitutional-check.sh
**File**: `.specify/scripts/bash/constitutional-check.sh`

**Changes**:
1. Update version reference comment to v1.6.0
2. Add Principle XV validation checks:
   - Spec directory naming convention (`###-feature-name`)
   - Agent files in department subdirectories
   - Skills in category/skill-name structure
3. Update totals from 14/14 to 15/15

**Validation**: Run script and verify 15 principles checked

---

#### Task 1.3: Update .mcp.json for Browser MCP
**File**: `.mcp.json`

**Changes**: Add browser MCP servers (keeping existing docker config)
```json
{
  "mcpServers": {
    "docker": {
      "command": "docker",
      "args": ["mcp", "gateway", "run"]
    },
    "browsermcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["browsermcp@latest"],
      "description": "Browser automation via Browser MCP extension"
    },
    "chrome-devtools": {
      "type": "stdio",
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest"],
      "description": "Chrome DevTools debugging via MCP"
    }
  }
}
```

**Validation**: Test MCP server connectivity

---

#### Task 1.4: Update settings.json with Hook Configuration
**File**: `.claude/settings.json`

**Changes**: Add hooks configuration (keeping existing agent and statusLine)
```json
{
  "agent": "constitutional-governance-agent",
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "./.claude/hooks/user-prompt-submit/governance-preflight.sh",
            "timeout": 5000
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "bash .claude/statusline.sh"
  }
}
```

**Validation**: Verify JSON syntax valid

**Note**: Hook will not execute until script created in Phase 2

---

### Phase 2: Hook System Implementation

**Priority**: HIGH
**Dependencies**: Phase 1 (settings.json update)
**Estimated Complexity**: Medium

#### Task 2.1: Create Hook Directory Structure
**Directories to Create**:
```
.claude/hooks/
└── user-prompt-submit/
```

**Validation**: Verify directories exist with `ls`

---

#### Task 2.2: Create governance-preflight.sh Hook
**File**: `.claude/hooks/user-prompt-submit/governance-preflight.sh`

**Requirements**:
- Read agent role from `.claude/settings.json`
- Create audit logs in `.docs/governance/audit/{date}/`
- Output JSON with `hookSpecificOutput.additionalContext`
- No git operations (Principle VI compliant)
- Work with or without `jq` (pure bash fallback)
- Must be executable (`chmod +x`)

**Template Structure**:
```bash
#!/usr/bin/env bash
# UserPromptSubmit Hook: Governance Preflight Check
# Constitutional Principle X enforcement
# Version: 1.0.0

# Input: JSON via stdin
# Output: JSON with additionalContext injection

# [Implementation to be sourced from Notion-Project]
```

**Validation**:
- Test with sample JSON input
- Verify audit log creation
- Confirm JSON output format

---

#### Task 2.3: Create Hook Documentation
**File**: `.claude/hooks/user-prompt-submit/README.md`

**Contents**:
- Hook purpose and behavior
- Input/output contract specification
- Configuration instructions
- Troubleshooting guide
- Example usage scenarios

**Validation**: Review for completeness

---

### Phase 3: Governance Skill

**Priority**: HIGH
**Dependencies**: None (standalone documentation)
**Estimated Complexity**: Low

#### Task 3.1: Create Skill Directory Structure
**Directories to Create**:
```
.claude/skills/governance/
└── governance-preflight/
```

**Validation**: Verify directories exist

---

#### Task 3.2: Create Governance Preflight Skill
**File**: `.claude/skills/governance/governance-preflight/SKILL.md`

**Requirements**:
- YAML frontmatter with metadata
- Constitutional compliance checklist (all 15 principles)
- Agent delegation reference table
- Pre-commit validation checklist
- Governance decision guidelines
- Audit log format documentation

**Template Structure**:
```markdown
---
name: governance-preflight
category: governance
version: 1.0.0
description: Constitutional compliance and governance enforcement
author: SDD Framework
---

# Governance Preflight Skill

[Content to be sourced from Notion-Project]
```

**Validation**: Review YAML and content

---

### Phase 4: Governance Documentation

**Priority**: MEDIUM
**Dependencies**: Phase 2 (hook system for context)
**Estimated Complexity**: Medium

#### Task 4.1: Create Governance Directory
**Directory to Create**:
```
.docs/governance/
├── audit/          # Created by hook automatically
└── [docs files]
```

**Validation**: Verify directory structure

---

#### Task 4.2: Create Hybrid Architecture Documentation
**File**: `.docs/governance/hybrid-architecture.md`

**Contents**:
- 3-layer governance architecture diagram
- Layer responsibilities table (Hook → Skill → Agent)
- Decision flow sequence
- Performance characteristics
- When to use each layer

**Validation**: Review for accuracy

---

#### Task 4.3: Create Browser MCP Setup Guide
**File**: `.docs/governance/browser-mcp-setup.md`

**Contents**:
- Browser MCP installation guide
- Chrome extension setup steps
- Chrome DevTools debugging setup
- Configuration verification
- Troubleshooting common issues

**Validation**: Follow guide to verify accuracy

---

#### Task 4.4: Create Browser Automation Examples
**File**: `.docs/governance/browser-automation-examples.md`

**Contents**:
- 10 practical examples
- Navigation, forms, screenshots
- Console logs, network inspection
- Performance tracing
- Error handling patterns

**Validation**: Test at least 2 examples

---

### Phase 5: Validation Scripts

**Priority**: MEDIUM
**Dependencies**: Phase 2 (governance logs for metrics script)
**Estimated Complexity**: Medium

#### Task 5.1: Create cleanup-governance-logs.sh
**File**: `.specify/scripts/bash/cleanup-governance-logs.sh`

**Requirements**:
- Clean audit logs older than N days (configurable)
- Preserve last N sessions (configurable)
- Dry-run mode by default (`--force` flag for actual deletion)
- Log cleanup actions
- Constitutional Principle IV compliant (idempotent)

**Validation**:
- Test dry-run mode
- Test actual cleanup with `--force`
- Verify logs preserved correctly

---

#### Task 5.2: Create debug-hook.sh
**File**: `.specify/scripts/bash/debug-hook.sh`

**Requirements**:
- Test hook execution
- Validate JSON output format
- Check file permissions (executable bit)
- Verify settings.json configuration
- Test with sample input

**Validation**: Run against governance-preflight.sh hook

---

#### Task 5.3: Create governance-metrics.sh
**File**: `.specify/scripts/bash/governance-metrics.sh`

**Requirements**:
- Generate metrics report from audit logs
- Decision type breakdown (inject/block/approve/delegate)
- Layer distribution (hook/skill/agent)
- Markdown or text output (flag-controlled)
- Date range filtering

**Validation**: Run against test audit logs

---

### Phase 6: Contract Schemas and Tests

**Priority**: LOW (Nice to have, not blocking)
**Dependencies**: Phases 2-5 (systems to test)
**Estimated Complexity**: High

#### Task 6.1: Create Contract Schemas Directory
**Directory to Create**:
```
specs/003-governance-browser-enhancement/
└── contracts/
```

**Note**: Only create if implementing full feature spec workflow

---

#### Task 6.2: Create Contract Schemas (Optional)
**Files**:
- `specs/003-governance-browser-enhancement/contracts/user-prompt-submit-hook.yaml`
- `specs/003-governance-browser-enhancement/contracts/governance-audit-log.yaml`
- `specs/003-governance-browser-enhancement/contracts/settings-json-schema.yaml`
- `specs/003-governance-browser-enhancement/contracts/mcp-server-config.yaml`

**Validation**: Validate YAML syntax

---

#### Task 6.3: Create Contract Tests Directory
**Directory to Create**:
```
tests/contracts/
```

---

#### Task 6.4: Create Contract Tests (Optional)
**Files**:
- `tests/contracts/test_user_prompt_submit_hook.sh`
- `tests/contracts/test_governance_audit_log.sh`
- `tests/contracts/test_settings_json_schema.sh`
- `tests/contracts/test_mcp_server_config.sh`

**Validation**: Run all tests, ensure pass

---

## Implementation Order Recommendation

### Critical Path (Must Do)
```
Phase 1: Configuration Updates
  ├── refinement.conf update
  ├── constitutional-check.sh update
  ├── .mcp.json update
  └── settings.json update
       ↓
Phase 2: Hook System
  ├── Create directories
  ├── Create governance-preflight.sh
  └── Create hook README
       ↓
Phase 3: Governance Skill
  ├── Create directories
  └── Create SKILL.md
```

### Enhanced Path (Recommended)
```
Critical Path (Above)
       ↓
Phase 4: Documentation
  ├── hybrid-architecture.md
  ├── browser-mcp-setup.md
  └── browser-automation-examples.md
       ↓
Phase 5: Validation Scripts
  ├── cleanup-governance-logs.sh
  ├── debug-hook.sh
  └── governance-metrics.sh
```

### Complete Path (Full Feature)
```
Enhanced Path (Above)
       ↓
Phase 6: Contracts & Tests
  ├── Contract schemas
  └── Contract tests
```

---

## File Sourcing Strategy

### Option 1: Manual Recreation
- Use sync report as specification
- Recreate files based on documented requirements
- Test thoroughly

### Option 2: Source from Notion-Project
- If Notion-Project files available, copy directly
- Validate paths and references
- Adjust for framework differences

### Option 3: Hybrid Approach (Recommended)
- Copy working code from Notion-Project where available
- Recreate documentation fresh (may be outdated)
- Test all integrations

---

## Testing Strategy

### Per-Phase Testing
- **Phase 1**: Load configs, run constitutional-check.sh
- **Phase 2**: Execute hook with test input, verify logs
- **Phase 3**: Review skill documentation
- **Phase 4**: Follow setup guides, test examples
- **Phase 5**: Run validation scripts against test data
- **Phase 6**: Execute contract test suites

### Integration Testing
1. Trigger hook via Claude Code session
2. Verify audit log creation
3. Check governance skill accessibility
4. Test browser MCP functionality
5. Run all validation scripts
6. Verify constitutional compliance

---

## Risk Assessment

### Low Risk
- Configuration updates (reversible)
- Documentation creation (non-breaking)
- Validation scripts (standalone)

### Medium Risk
- Hook system (could affect Claude Code startup)
- settings.json changes (could break config)

### Mitigation
- Test in dev-main branch first
- Backup settings.json before changes
- Verify hook script is executable and valid JSON output
- Test hook with `debug-hook.sh` before committing

---

## Git Operations Protocol

**Per Constitutional Principle VI:**

All git operations REQUIRE explicit user approval:
- ❌ NO automatic commits
- ❌ NO automatic pushes
- ❌ NO automatic branch switching
- ✅ ASK before each git operation

**Recommended Commit Strategy**:
- One commit per phase (or logical grouping)
- Use conventional commit format
- Reference sync report in commit messages

---

## Success Criteria

### Phase 1 Complete
- [ ] All 4 config files updated
- [ ] constitutional-check.sh shows 15/15 principles
- [ ] No syntax errors in JSON/bash configs

### Phase 2 Complete
- [ ] Hook executes without errors
- [ ] Audit logs created in correct location
- [ ] JSON output validates

### Phase 3 Complete
- [ ] Skill documentation complete
- [ ] Accessible via `/governance-preflight` (if wired up)

### Phase 4 Complete
- [ ] All 3 documentation files created
- [ ] Browser MCP setup guide validated

### Phase 5 Complete
- [ ] All 3 validation scripts functional
- [ ] Scripts tested with real data

### Phase 6 Complete (Optional)
- [ ] Contract schemas valid YAML
- [ ] Contract tests pass

---

## Next Steps

1. **Review this plan** - Confirm approach and priorities
2. **Choose implementation path** - Critical/Enhanced/Complete
3. **Source decision** - Manual/Notion-Project/Hybrid
4. **Begin Phase 1** - Start with configuration updates
5. **Test incrementally** - Validate each phase before proceeding

---

*Generated from feature-003-upstream-sync-report.md on 2025-12-19*
