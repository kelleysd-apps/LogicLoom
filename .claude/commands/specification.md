---
description: Unified specification workflow - generates all SDD artifacts (spec, plan, tasks) in one command.
---

# /specification Command

**Skill**: `sdd-workflow/unified-specification`
**Version**: 1.0.0

## Usage

```
/specification <feature-description> [options]
```

## Description

Unified command that consolidates the entire SDD specification workflow into a single execution:
- **Phase 1**: Generate `spec.md` (requirements, user stories, acceptance criteria)
- **Phase 2**: Generate `plan.md` + `research.md` + `data-model.md` + `contracts/` + `quickstart.md`
- **Phase 3**: Generate `tasks.md` (numbered, dependency-ordered, parallel-marked)

**Replaces**: `/specify` → `/plan` → `/tasks`

## Options

| Option | Description |
|--------|-------------|
| `--branch <name>` | Create or use specific branch |
| `--resume` | Resume interrupted workflow |
| `--phase <spec\|plan\|tasks>` | Start from specific phase |
| `--skip-validation` | Skip quality gates (warning issued) |

## Examples

```bash
# Basic usage
/specification "Build user authentication with email and password"

# Resume interrupted workflow
/specification --resume

# Start from planning phase (spec must exist)
/specification "feature" --phase plan
```

## Output

Creates 7 artifacts in `specs/<branch>/`:
- `spec.md` - Feature specification
- `plan.md` - Implementation plan
- `research.md` - Technical research
- `data-model.md` - Entity definitions
- `contracts/` - API contracts
- `quickstart.md` - Test scenarios
- `tasks.md` - Implementation tasks

## Quality Gates

| Phase | Threshold | Action on Failure |
|-------|-----------|-------------------|
| Specification | 90% | Refine or proceed with warning |
| Plan | 85% | Refine or proceed with warning |
| Tasks | Coverage check | Ensure all contracts/entities have tasks |

## Constitutional Compliance

- **Principle VI**: Branch creation requires user approval
- **Principle VIII**: All artifacts synchronized
- **Principle X**: Orchestrates existing skills

## Deprecation Notice

This command **replaces** the sequential workflow:
- `/specify` - Now deprecated (use `/specification`)
- `/plan` - Now deprecated (use `/specification`)
- `/tasks` - Now deprecated (use `/specification`)

Old commands remain available with deprecation warnings for 6 months.

---

**Activate Skill**: When this command is invoked, activate the `unified-specification` skill at `.claude/skills/sdd-workflow/unified-specification/SKILL.md`
