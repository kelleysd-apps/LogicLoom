---
name: frontend-operations
version: 3.0.0
category: domain
description: Frontend development skill. Routes to implementation-specialist.
triggers: ["frontend", "UI component", "React", "CSS", "form", "responsive"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# Frontend Operations Skill

## Overview

Domain skill for frontend development including React components, UI layouts, CSS styling, form handling, and responsive design.

## When to Use

- Creating React components
- UI/UX implementation
- CSS styling and layout
- Form handling and validation
- Responsive design
- Client-side state management

## Configuration

### Allowed Tools
Read, Write, Edit, MultiEdit, Bash, Grep, Glob

### Agent Invocation

```yaml
agent: implementation-specialist
context-subset:
  - ui-requirements
  - design-system
  - component-specifications
  - styling-guidelines
when: "frontend component or UI work is needed"
timeout: 10m
```

### Composes
- validation/message-preflight (pre-execution)
- validation/domain-detection (analysis)

## Instructions

### Step 1: Analyze Frontend Requirements

Identify the specific frontend work:
1. **Component Creation**: New React component(s)
2. **Styling**: CSS, Tailwind, styled-components
3. **Layout**: Page structure, grid, flexbox
4. **Forms**: Input handling, validation
5. **State**: Local state, context

### Step 2: Prepare Context

```yaml
context-subset:
  - ui-requirements: What the UI should do/look like
  - design-system: Project's design tokens
  - component-specifications: Props, events, structure
  - styling-guidelines: CSS approach
```

### Step 3: Invoke Implementation Specialist

Delegate to `implementation-specialist` with:
- Clear component specifications
- Expected props and events
- Styling requirements
- Integration points

### Step 4: Validate Output

- [ ] Component follows React best practices
- [ ] Proper TypeScript types
- [ ] Accessibility (a11y) implemented
- [ ] Responsive design works
- [ ] Tests included (Principle II)

## Constitutional Compliance

- **Principle II**: Tests required for components
- **Principle X**: Routes to implementation-specialist
- **Principle XII**: Follows project design system

## Related Skills

- domain/backend-operations - API integration
- domain/testing-operations - Test strategy
- orchestration/full-stack-feature - Full-stack work
