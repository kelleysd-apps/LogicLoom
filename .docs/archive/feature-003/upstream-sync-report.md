# Feature 003: Upstream Sync Report

**Purpose**: Document all changes made in Notion-Project that should be synced back to sdd-agentic-framework
**Generated**: 2025-12-18
**Feature**: 003-governance-browser-enhancement
**Upstream Repo**: sdd-agentic-framework (currently at v2.1.2)

---

## Summary

This report documents all enhancements made beyond the current sdd-agentic-framework release that should be incorporated into the upstream framework.

---

## 1. Constitution Update (v1.5.0 → v1.6.0)

### File: `.specify/memory/constitution.md`

**Changes:**
- Version bumped from 1.5.0 to 1.6.0
- Added **Principle XV: File and Folder Organization**
- Updated total principles from 14 to 15
- Updated Manual Review Checklist to include file organization

**New Principle XV Content:**
```markdown
### Principle XV: File and Folder Organization

**Mandate**: All file and folder management MUST follow established project conventions and directory structure.

**Requirements**:
- Files MUST be created in appropriate directories per project structure
- Directory structure defined in CLAUDE.md is the SINGLE SOURCE OF TRUTH
- Parent directories MUST exist before creating files
- No duplicate files with different names for same purpose
- Follow naming conventions consistently
- Understand codebase structure before creating new files

**Pre-Creation Checklist** (MANDATORY before ANY file/folder creation):
1. Read CLAUDE.md - Review directory structure section
2. Verify parent directory exists - Use `ls` or Glob to confirm
3. Check for existing similar file - Search for files with similar purpose
4. Confirm naming convention - Match existing patterns in directory
5. Validate placement - Ensure correct category/department
6. Document purpose - If new pattern, document in appropriate place

**Naming Conventions**:
| File Type | Convention | Example |
|-----------|------------|---------|
| Feature specs | `###-feature-name/` | `003-governance-browser-enhancement/` |
| Agent files | `{role}.md` | `notion-analyst.md` |
| Shell scripts | `kebab-case.sh` | `constitutional-check.sh` |
| Config files | `lowercase.ext` | `refinement.conf` |
| Templates | `{type}-template.md` | `spec-template.md` |

**Compliance Check**:
- [ ] CLAUDE.md directory structure reviewed
- [ ] Parent directory verified to exist
- [ ] No duplicate files with similar purpose
- [ ] Naming convention matches existing patterns
- [ ] Placement follows project structure
- [ ] Pre-creation checklist completed
```

---

## 2. UserPromptSubmit Hook System

### New Directory: `.claude/hooks/user-prompt-submit/`

**Files to Add:**

#### `.claude/hooks/user-prompt-submit/governance-preflight.sh`
- Automatic governance context injection on every user message
- Reads agent role from `.claude/settings.json`
- Creates audit logs in `.docs/governance/audit/{date}/`
- Outputs JSON with `hookSpecificOutput.additionalContext`
- No git operations (Principle VI compliant)
- Works with or without `jq` (pure bash fallback)

#### `.claude/hooks/user-prompt-submit/README.md`
- Hook documentation
- Input/output contract
- Configuration instructions
- Troubleshooting guide

---

## 3. Governance Skill

### New Directory: `.claude/skills/governance/governance-preflight/`

**Files to Add:**

#### `.claude/skills/governance/governance-preflight/SKILL.md`
- YAML frontmatter with metadata
- Constitutional compliance checklist (all 15 principles)
- Agent delegation reference table
- Pre-commit validation checklist
- Governance decision guidelines
- Audit log format documentation

---

## 4. Settings.json Hook Configuration

### File: `.claude/settings.json`

**New Structure:**
```json
{
  "agent": "task-orchestrator",
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

---

## 5. Browser MCP Integration

### File: `.mcp.json`

**New Servers to Add:**
```json
{
  "mcpServers": {
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

---

## 6. Governance Audit Logging

### New Directory: `.docs/governance/audit/`

**Structure:**
```
.docs/governance/audit/
├── {YYYY-MM-DD}/
│   └── session-{session_id}.json
└── cleanup.log
```

**Audit Log Schema:**
```json
{
  "timestamp": "ISO-8601",
  "session_id": "string",
  "event_type": "governance_decision | agent_delegation | context_injection | message_blocked",
  "decision_type": "context_injection | block | approve | delegate | warn",
  "layer": "hook | skill | agent",
  "agent_role": "string",
  "input_summary": "first 100 chars only",
  "output": {
    "action": "string",
    "blocked": false,
    "reason": "string (if blocked)"
  },
  "constitutional_principles": ["X", "VI", "II"],
  "duration_ms": 45
}
```

---

## 7. New Governance Documentation

### New Directory: `.docs/governance/`

**Files to Add:**

#### `.docs/governance/hybrid-architecture.md`
- 3-layer governance architecture diagram
- Layer responsibilities table
- Decision flow sequence
- Performance characteristics
- When to use each layer

#### `.docs/governance/browser-mcp-setup.md`
- Browser MCP installation guide
- Chrome extension setup
- Chrome DevTools debugging setup
- Troubleshooting guide

#### `.docs/governance/browser-automation-examples.md`
- 10 practical examples
- Navigation, forms, screenshots
- Console logs, network inspection
- Performance tracing
- Error handling patterns

---

## 8. New Validation Scripts

### Directory: `.specify/scripts/bash/`

**Files to Add:**

#### `cleanup-governance-logs.sh`
- Cleans audit logs older than N days
- Preserves last N sessions
- Dry-run mode by default
- Logs cleanup actions

#### `debug-hook.sh`
- Tests hook execution
- Validates JSON output
- Checks file permissions
- Verifies settings.json configuration

#### `governance-metrics.sh`
- Generates metrics report from audit logs
- Decision type breakdown
- Layer distribution
- Markdown or text output

---

## 9. Updated Constitutional Check Script

### File: `.specify/scripts/bash/constitutional-check.sh`

**Changes:**
- Updated version reference to v1.6.0
- Added Principle XV check for file organization
- Updated totals from 14/14 to 15/15
- New checks:
  - Spec directory naming convention
  - Agent files in department subdirectories
  - Skills in category/skill-name structure

---

## 10. Updated Refinement Configuration

### File: `.specify/config/refinement.conf`

**Changes:**
```bash
# CONSTITUTIONAL PRINCIPLES (15 Total)  # Changed from 14

# Principle XV: File and Folder Organization
CHECK_FILE_ORGANIZATION=true
FILE_ORG_SEVERITY=error
```

---

## 11. Contract Schemas

### New Directory: `specs/003-governance-browser-enhancement/contracts/`

**Files (can be used as templates):**

#### `user-prompt-submit-hook.yaml`
- OpenAPI 3.0.3 schema for hook output
- HookInput and HookOutput schemas
- Exit code contract

#### `governance-audit-log.yaml`
- JSON Schema for audit log entries
- All required fields documented
- Examples included

#### `settings-json-schema.yaml`
- JSON Schema for hooks configuration
- All hook event types
- Validation rules

#### `mcp-server-config.yaml`
- JSON Schema for .mcp.json
- StdioServer and HttpServer types
- Browser MCP examples

---

## 12. Contract Tests

### New Directory: `tests/contracts/`

**Files to Add:**

#### `test_user_prompt_submit_hook.sh`
- 7 tests for hook output validation
- Tests existence, executable, JSON output, required fields

#### `test_governance_audit_log.sh`
- 9 tests for audit log schema
- Tests directory, log creation, required fields

#### `test_settings_json_schema.sh`
- 10 tests for settings.json hooks config
- Tests structure, hook type, command path, timeout

#### `test_mcp_server_config.sh`
- 12 tests for .mcp.json config
- Tests both browsermcp and chrome-devtools

---

## 13. CLAUDE.md Updates

### File: `CLAUDE.md`

**Changes:**
- Updated constitution version from v1.5.0 to v1.6.0
- Updated principle count from 14 to 15
- Updated principle categories:
  - "5 Workflow & Delegation Principles (X-XIV)" → "6 Workflow & Delegation Principles (X-XV)"
- Added "File Organization" to principle list
- Updated directory structure comments

---

## Quick Sync Checklist

For upstream sync, copy/update these files in order:

1. [ ] `.specify/memory/constitution.md` - Add Principle XV, bump to v1.6.0
2. [ ] `.specify/config/refinement.conf` - Add Principle XV config
3. [ ] `.specify/scripts/bash/constitutional-check.sh` - Add Principle XV check
4. [ ] `.claude/hooks/user-prompt-submit/governance-preflight.sh` - New file
5. [ ] `.claude/hooks/user-prompt-submit/README.md` - New file
6. [ ] `.claude/skills/governance/governance-preflight/SKILL.md` - New file
7. [ ] `.claude/settings.json` - Add hooks configuration (template)
8. [ ] `.mcp.json` - Add Browser MCP servers (template)
9. [ ] `.docs/governance/` - All new documentation files
10. [ ] `.specify/scripts/bash/cleanup-governance-logs.sh` - New file
11. [ ] `.specify/scripts/bash/debug-hook.sh` - New file
12. [ ] `.specify/scripts/bash/governance-metrics.sh` - New file
13. [ ] `tests/contracts/` - All contract test files
14. [ ] `CLAUDE.md` - Update all 14→15 references

---

## Version Recommendation

**Recommended upstream version**: v2.2.0 or v3.0.0

**Rationale**:
- Constitution change from 14→15 principles is significant
- New hook system is a major capability addition
- Browser MCP integration expands framework scope
- Could be considered breaking for existing projects expecting 14 principles

---

*Report generated as part of Feature 003 implementation*
