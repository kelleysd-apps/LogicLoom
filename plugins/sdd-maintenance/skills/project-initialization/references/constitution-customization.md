# Constitution Customization Patterns

Reference for applying project-specific customizations to each constitutional principle.

## Common Customization Patterns

### Principle II (Test-First)
```markdown
**Project Customization** ([Project Name]):
- Test Framework: [from PRD Technical Constraints]
- Coverage Threshold: [from PRD, default 80%]
- E2E Strategy: [from PRD]
- Contract Testing: [from PRD]
```

### Principle III (Contract-First)
```markdown
**Project Customization** ([Project Name]):
- API Standard: [OpenAPI/GraphQL from PRD]
- Versioning: [from PRD]
- Contract Location: specs/[feature]/contracts/
```

### Principle X (Agent Delegation)
```markdown
**Project Customization** ([Project Name]):
- Custom Agents:
  - [agent-1]: [purpose]
  - [agent-2]: [purpose]
- Primary Domains: [from PRD analysis]
```

### Principle XII (Design System)
```markdown
**Project Customization** ([Project Name]):
- Design System: [name from PRD]
- WCAG Level: [from PRD, default AA]
- Responsive: [requirements from PRD]
```

### Principle XIII (Access Control)
```markdown
**Project Customization** ([Project Name]):
- Access Tiers: [from PRD]
- Gating Strategy: [from PRD]
```

## PRD-to-Domain Mapping

| PRD Section | Domain | Delegate To |
|-------------|--------|-------------|
| UI features | frontend | frontend-operations skill |
| API requirements | backend | api-design skill |
| Database schemas | database | schema-design skill |
| Security requirements | security | security-operations skill |
| Performance targets | performance | performance-operations skill |

## Agent Context Template

When creating agents from PRD, use this template:

```markdown
# [Agent Name] - Project Context

## Project: [Name]

### Project Overview
[Vision from PRD]

### Agent Scope for This Project
[Specific responsibilities from PRD]

### Key Constraints
- [Constraint 1 from PRD]
- [Constraint 2 from PRD]

### Success Criteria
- [From PRD success metrics relevant to this agent]

### Integration Points
- Works with: [other agents]
- Hands off to: [downstream agents]
```

## Error Recovery

### PRD Not Found
Run `/create-prd` first, then re-run `/initialize-project`.

### PRD Incomplete
Edit `.docs/prd/prd.md` to complete missing sections, then re-run.

### Constitution Conflict
Review PRD requirements, resolve conflict manually, then re-run.

### Rollback
```bash
cp .specify/memory/constitution.md.backup .specify/memory/constitution.md
```
Revert CLAUDE.md changes and delete incomplete agent files.
