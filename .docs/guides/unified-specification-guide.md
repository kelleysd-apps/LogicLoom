# Unified Specification Guide

**Command**: `/specification`
**Version**: 1.0.0

---

## Quick Start

```bash
# Generate complete specification workflow
/specification "Build a user authentication system with email and password"
```

This single command generates all 7 SDD artifacts in sequence.

---

## What It Does

The `/specification` command executes the complete SDD workflow:

```
Phase 1: Specification
└── spec.md (requirements, user stories, acceptance criteria)

Phase 2: Planning
├── research.md (technical decisions)
├── data-model.md (entity definitions)
├── contracts/ (API contracts)
├── quickstart.md (test scenarios)
└── plan.md (implementation approach)

Phase 3: Tasks
└── tasks.md (numbered, dependency-ordered tasks)
```

---

## Usage Examples

### Basic Usage

```bash
/specification "Build REST API for user management with CRUD operations"
```

### Resume Interrupted Workflow

```bash
/specification --resume
```

### Start from Specific Phase

```bash
# If spec.md already exists, start from planning
/specification "feature description" --phase plan
```

### Create New Branch

When prompted, you can choose to:
1. Work on current branch
2. Create a new feature branch (requires approval per Principle VI)

---

## Quality Gates

Each phase has a quality gate:

| Phase | Threshold | Action on Failure |
|-------|-----------|-------------------|
| Specification | 90% | Refine or proceed with warning |
| Planning | 85% | Refine or proceed with warning |
| Tasks | Coverage | All contracts/entities must have tasks |

If a quality gate fails, you'll see:
- Current score
- Specific recommendations
- Option to refine and retry

---

## Output

All artifacts are created in `specs/<branch-name>/`:

```
specs/your-branch/
├── spec.md           # Feature specification
├── plan.md           # Implementation plan
├── research.md       # Technical research
├── data-model.md     # Entity definitions
├── contracts/        # API contracts
│   └── *.md
├── quickstart.md     # Test scenarios
└── tasks.md          # Implementation tasks
```

---

## Workflow State

The workflow tracks its state in `specs/<branch>/.workflow-state.json`:

- **Resume**: If interrupted, use `--resume` to continue
- **State tracking**: Shows which phases completed
- **Quality scores**: Records validation results

---

# Wait for completion, verify spec.md
/plan
# Wait for completion, verify artifacts
/tasks
# Finally get tasks.md
```

### After (1 command, automated)

```bash
/specification "feature description"
# All 7 artifacts generated with quality gates
```

---

## Constitutional Compliance

- **Principle VI**: Branch creation requires explicit user approval
- **Principle VIII**: All documentation artifacts synchronized
- **Principle X**: Uses skills-first delegation pattern

---

## Troubleshooting

### Quality Gate Keeps Failing

1. Review the specific recommendations
2. Provide more detail in your feature description
3. Use `--skip-validation` to proceed (warning issued)

### Workflow Interrupted

1. Run `/specification --resume`
2. Workflow continues from last checkpoint

### State File Corrupted

1. Delete `specs/<branch>/.workflow-state.json`
2. Run workflow again from scratch

---

## Related

- [Git Push Guide](./git-push-guide.md)
- [SDD Workflow Overview](../workflows/sdd-overview.md)
