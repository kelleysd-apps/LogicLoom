---
name: file-organization
description: |
  Validates and enforces file creation rules, folder structure, and naming conventions.

  Use this skill BEFORE creating any new file or folder to ensure:
  1. Parent directory exists and is appropriate
  2. File/folder name follows conventions
  3. Correct template is used
  4. No duplicate files created
  5. Structure matches framework standards

  Triggered by: Any file creation, folder creation, or structure change

  This is a PREVENTIVE skill - validates BEFORE action, not after.
allowed-tools: Read, Glob, Grep, Bash
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---

# File Organization Skill

## Purpose

This skill enforces the file structure policy and naming conventions defined in `.docs/policies/file-structure-policy.md`. It MUST be consulted before creating files or folders.

## Pre-Creation Validation Protocol

### Step 1: Determine Content Type

Identify what type of content is being created:

| Content Type | Location Pattern | Template |
|--------------|------------------|----------|
| Agent definition | `plugins/[plugin]/agents/` | `agent-template.md` |
| Agent memory | `.docs/agents/[dept]/[agent]/` | N/A (structure) |
| Skill | `plugins/[plugin]/skills/[skill]/` | `skill-template.md` |
| Command | `.claude/commands/` | N/A |
| Policy | `.docs/policies/` | N/A |
| Feature spec | `specs/###-[name]/` | `spec-template.md` |
| Plan | `specs/###-[name]/` | `plan-template.md` |
| Tasks | `specs/###-[name]/` | `tasks-template.md` |
| Source code | `src/` or project-specific | Per language |
| Test | `tests/` | Per framework |

### Step 2: Verify Parent Directory

**BEFORE creating any file**:

```bash
# Check if parent directory exists
ls [parent-directory]

# If not exists and creation is appropriate:
mkdir -p [parent-directory]
```

**Directory Appropriateness Check**:
```
Is the parent directory one of these approved locations?

plugins/[plugin-name]/agents/
plugins/[plugin-name]/skills/[skill-name]/
.claude/commands/
.docs/agents/[department]/[agent-name]/[context|knowledge|decisions|performance]/
.docs/policies/
.docs/features/
specs/###-[feature-name]/
src/[project-structure]/
tests/[unit|integration|contract]/
```

If NOT in an approved location, **STOP and verify** the location is correct.

### Step 3: Check for Existing File

**NEVER create a file without checking first**:

```bash
# Check if file already exists
ls [full-file-path]

# Or use Read tool
Read: [full-file-path]
```

**If file exists**:
- Use **Edit** tool to modify, not Write
- Do NOT create a new file with different name

### Step 4: Validate Naming Convention

**File Naming Patterns**:

| Type | Pattern | Valid Example | Invalid Example |
|------|---------|---------------|-----------------|
| Agent | `[role]-[function].md` | `constitutional-governance-agent.md` | `ConstitutionalGovernanceAgent.md` |
| Skill folder | `[skill-name]/` | `domain-detection/` | `DomainDetection/` |
| Skill file | `SKILL.md` | `SKILL.md` | `skill.md`, `README.md` |
| Policy | `[topic]-policy.md` | `testing-policy.md` | `TestingPolicy.md` |
| Agent memory | `[agent]-[type].md` | `team-synthesizer-context.md` | `context.md` |
| Feature dir | `###-[name]/` | `001-user-auth/` | `user-auth/` |
| Python test | `test_[name].py` | `test_user_service.py` | `TestUserService.py` |

**Validation Rules**:
- Use **kebab-case** for directories and markdown files
- Use **snake_case** for Python files
- Use **camelCase** for JavaScript/TypeScript files
- Feature directories MUST have 3-digit prefix
- Agent files MUST be in plugin agent directories (only 11 agents remain in v5.0)

### Step 5: Apply Template (If Applicable)

**Check for template**:

```bash
ls .specify/templates/
```

**Available Templates**:
- `agent-template.md` - New agent definitions
- `skill-template.md` - New skills
- `spec-template.md` - Feature specifications
- `plan-template.md` - Implementation plans
- `tasks-template.md` - Task lists
- `prd-template.md` - Product requirements

**If template exists**: Copy and modify, don't create from scratch.

### Step 6: Create with Absolute Path

**ALWAYS use absolute paths from repository root**:

```
CORRECT: /workspaces/project/plugins/sdd-specification/agents/new-agent.md
WRONG:   agents/new-agent.md
WRONG:   ./plugins/sdd-specification/agents/new-agent.md
```

## Validation Checklist

Before creating ANY file, confirm:

```
[ ] Content type identified
[ ] Parent directory exists (or created)
[ ] No existing file with same name
[ ] Name follows convention for type
[ ] Template used if available
[ ] Absolute path from repo root
[ ] File is actually needed (not duplicate)
```

## Directory Creation Protocol

### Agent Memory Structure

When creating agent memory, create ALL required directories:

```bash
mkdir -p .docs/agents/[dept]/[agent-name]/context
mkdir -p .docs/agents/[dept]/[agent-name]/knowledge
mkdir -p .docs/agents/[dept]/[agent-name]/decisions
mkdir -p .docs/agents/[dept]/[agent-name]/decisions/tasks
mkdir -p .docs/agents/[dept]/[agent-name]/performance
```

Then create files with agent-prefixed names:
- `[agent-name]-context.md`
- `[agent-name]-knowledge.md`
- `[agent-name]-decisions.md`
- `[agent-name]-performance.md`

### Feature Specification Structure

When creating feature spec, create directory and minimum files:

```bash
mkdir -p specs/###-[feature-name]/contracts
```

Required files:
- `spec.md` (from spec-template.md)
- `plan.md` (from plan-template.md)
- `tasks.md` (from tasks-template.md)

### Skill Structure

When creating skill:

```bash
mkdir -p plugins/[plugin-name]/skills/[skill-name]
```

Required files:
- `SKILL.md` (from skill-template.md)

Optional:
- `reference.md`
- `examples.md`

## Common Violations

### 1. Creating Without Checking

```
VIOLATION: Write file without Read first
FIX: Always Read or ls before Write
```

### 2. Wrong Location

```
VIOLATION: Creating agent in .docs instead of plugins
FIX: Agents go in plugins/*/agents/, memory goes in .docs/agents/
```

### 3. Generic Names in Agent Dirs

```
VIOLATION: README.md in agent memory folder
FIX: Use [agent-name]-[type].md format
```

### 4. Missing Parent Directory

```
VIOLATION: Write to path with non-existent parent
FIX: mkdir -p [parent] first
```

### 5. Duplicate Content

```
VIOLATION: Creating new file with content similar to existing
FIX: Edit existing file instead
```

## Integration with Other Skills

### message-preflight

The message-preflight skill should invoke file-organization checks when:
- User requests file creation
- Agent plans to create files
- Structure changes are proposed

### constitutional-compliance

File creation must comply with:
- Principle VIII (Documentation Sync)
- Established project structure
- Naming conventions

## Quick Reference Commands

```bash
# Validate structure
find plugins/*/agents -type f -name "*.md" | head -20

# Check naming
ls -la .docs/agents/*/

# Find templates
ls .specify/templates/

# Check for duplicates
find . -name "[filename]" 2>/dev/null
```

## Output Format

After validation, report:

```
File Organization Check:
- Type: [content type]
- Location: [verified|created|INVALID]
- Name: [valid|INVALID - reason]
- Template: [applied|N/A]
- Existing: [no|yes - use Edit]
- Status: [PROCEED|STOP - reason]
```

## Policy Reference

Full policy: `.docs/policies/file-structure-policy.md`
Naming conventions: `.docs/policies/agent-file-naming-convention.md`
Agent creation: `.docs/policies/agent-creation-policy.md`

## RL Feedback Loop

After skill execution completes, the RL feedback mechanism updates metrics:

### Success Criteria
- Task completed without errors
- Output validated by verifier (if applicable)
- User satisfaction (implicit from follow-up)

### Feedback Collection
```
ON SKILL COMPLETION:
  1. Capture execution result (success/failure)
  2. Record token usage
  3. Calculate execution duration
  4. Update rl_metrics via EMA:
     - success_rate = 0.9 * old_rate + 0.1 * (1 if success else 0)
     - selection_weight = adjusted based on success_rate
  5. Log to .docs/rl-metrics/skill-performance.json
```

### Metrics Update Trigger
```python
# Pseudo-code for RL update
def update_rl_metrics(skill_name: str, success: bool, tokens: int):
    metrics = load_skill_metrics(skill_name)
    metrics['invocation_count'] += 1
    metrics['success_rate'] = 0.9 * metrics['success_rate'] + 0.1 * (1 if success else 0)
    metrics['avg_tokens'] = 0.9 * metrics['avg_tokens'] + 0.1 * tokens
    metrics['selection_weight'] = max(0.1, min(1.0, metrics['success_rate']))
    metrics['last_feedback'] = datetime.utcnow().isoformat()
    save_skill_metrics(skill_name, metrics)
```

## Verifier Integration

### Pre-Completion Validation
Before marking this skill as complete, invoke verifier validation:

```
VERIFIER_CHECK:
  1. Output format validation
  2. Constitutional compliance check
  3. Quality threshold verification
  4. Domain-specific validation rules
```

### Verifier Handoff
```json
{
  "skill": "file-organization",
  "output": "<skill_output>",
  "validation_required": ["format", "compliance", "quality"],
  "threshold": 0.85
}
```

### On Verification Failure
- Log failure reason
- Update rl_metrics with failure
- Report to user with remediation options
