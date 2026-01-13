---
name: frontend-operations
version: 3.0.0
description: |
  Domain skill for frontend development operations including UI components, React, CSS,
  responsive design, and form handling. Routes to implementation-specialist agent for
  execution. Part of the skills-first architecture (FR-610).
category: domain
triggers:
  - "frontend"
  - "UI component"
  - "React"
  - "CSS"
  - "form"
  - "responsive"
  - "component"
  - "page layout"
allowed-tools:
  - Read
  - Write
  - Edit
  - MultiEdit
  - Bash
  - Grep
  - Glob
agent-invocations:
  - agent: implementation-specialist
    context-subset:
      - ui-requirements
      - design-system
      - component-specifications
      - styling-guidelines
    when: "frontend component or UI work is needed"
    timeout: 10m
composes:
  - skill: validation/message-preflight
    phase: pre-execution
  - skill: validation/domain-detection
    phase: analysis
progressive-disclosure:
  layer1:
    - name
    - description
    - triggers
    - category
    - version
    - rl_metrics
  layer2:
    - instructions
    - agent-invocations
    - composes
    - allowed-tools
  layer3:
    - examples
    - references
rl_metrics:
  success_rate: 0.5
  avg_tokens: 0
  avg_duration_ms: 0
  user_satisfaction: 0.5
  selection_weight: 0.5
  invocation_count: 0
---

# Frontend Operations Skill

## Overview

This skill handles all frontend development operations including React components,
UI layouts, CSS styling, form handling, and responsive design. It routes work to
the consolidated `implementation-specialist` agent.

## When to Use

Activate this skill when the user request involves:
- Creating React components
- UI/UX implementation
- CSS styling and layout
- Form handling and validation
- Responsive design
- Client-side state management
- Component testing

## Instructions

### Step 1: Analyze Frontend Requirements

Identify the specific frontend work needed:

1. **Component Creation**: New React component(s)
2. **Styling**: CSS, Tailwind, or styled-components
3. **Layout**: Page structure, grid, flexbox
4. **Forms**: Input handling, validation, submission
5. **State**: Local state, context, or state management

### Step 2: Prepare Context for Agent

Gather minimal required context:

```yaml
context-subset:
  - ui-requirements: What the UI should do and look like
  - design-system: Project's design system/tokens if any
  - component-specifications: Props, events, structure
  - styling-guidelines: CSS approach (Tailwind, modules, etc.)
```

### Step 3: Invoke Implementation Specialist

Delegate to `implementation-specialist` with:
- Clear component specifications
- Expected props and events
- Styling requirements
- Any integration points

### Step 4: Validate Output

Check agent output for:
- [ ] Component follows React best practices
- [ ] Proper TypeScript types (if applicable)
- [ ] Accessibility considerations (a11y)
- [ ] Responsive design implemented
- [ ] Tests included (Principle II)

## Context Requirements

| Field | Required | Description |
|-------|----------|-------------|
| ui-requirements | Yes | What the UI should accomplish |
| design-system | No | Design tokens, colors, spacing |
| component-specifications | Yes | Props, events, structure |
| styling-guidelines | No | CSS approach to use |

## Agent Invocation

```yaml
agent: implementation-specialist
merged-from:
  - frontend-specialist
  - full-stack-developer
skill-portfolio:
  - domain/frontend-operations
  - domain/backend-operations
  - orchestration/full-stack-feature
```

## Quality Checks

Before completing:
- [ ] Component renders without errors
- [ ] TypeScript compiles (if used)
- [ ] Accessibility attributes present
- [ ] Responsive breakpoints work
- [ ] Unit tests written (Principle II)

## Related Skills

- **domain/backend-operations**: For API integration
- **domain/testing-operations**: For test strategy
- **orchestration/full-stack-feature**: For full-stack work

## Constitutional Compliance

- **Principle II (Test-First)**: Tests required for components
- **Principle X (Delegation)**: Routes to implementation-specialist
- **Principle XII (Design System)**: Follows project design system
