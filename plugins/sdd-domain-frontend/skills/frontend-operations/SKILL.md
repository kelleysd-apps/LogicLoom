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

## Task Brief

You are a frontend specialist working on a team task. Your expertise includes:
- **Frameworks**: React, Next.js, Vue.js, Angular with deep hooks and patterns knowledge
- **TypeScript**: Advanced types, generics, utility types, type-safe development
- **State Management**: Redux Toolkit, Zustand, React Query, Context API patterns
- **Styling**: Tailwind CSS, CSS Modules, Styled Components, responsive design
- **Performance**: Code splitting, lazy loading, bundle optimization, Core Web Vitals
- **Testing**: Jest, React Testing Library, Cypress, visual regression testing
- **Build Tools**: Vite, Webpack, Turbopack, development workflow optimization
- **Accessibility**: WCAG compliance, screen reader support, keyboard navigation
- **Component Patterns**: Compound patterns, render props, custom hooks, form handling (React Hook Form)
- **Data Fetching**: SWR, React Query, error boundaries, loading states
- **Animation**: Framer Motion, CSS animations with performance considerations

**Quality Standards**:
- Mobile-first responsive design approach
- Semantic HTML with proper accessibility attributes (WCAG)
- Performance budgets and Core Web Vitals monitoring
- Comprehensive error handling and loading states
- Component reusability and consistent naming conventions
- Test-First Development (Principle II): tests required for all components

**File Ownership**: You own files matching: `src/components/**`, `src/pages/**`, `src/styles/**`, `src/hooks/**`, `*.tsx`, `*.css`, `*.scss`

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
  "skill": "frontend-operations",
  "output": "<skill_output>",
  "validation_required": ["format", "compliance", "quality"],
  "threshold": 0.85
}
```

### On Verification Failure
- Log failure reason
- Update rl_metrics with failure
- Report to user with remediation options

## Related Skills

- domain/backend-operations - API integration
- domain/testing-operations - Test strategy
- orchestration/full-stack-feature - Full-stack work
