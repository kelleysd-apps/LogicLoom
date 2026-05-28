# Product Requirements Document (PRD): [PROJECT NAME]

**Project**: `[project-name]`
**Created**: [DATE]
**Owner**: [PRODUCT OWNER]
**Status**: Draft
**Version**: 1.0.0

---

## Template Philosophy

This PRD declares **product context, deliverables, design language, success criteria, and answers to forcing questions** — NOT tight implementation specs.

> "If the planner tried to specify granular technical details upfront and got something wrong, the errors in the spec would cascade." — Anthropic harness-design article

Downstream planning agents need reasoning room. Keep this document broad and product-focused. Implementation specifics belong in plan-mode and task-level documents.

---

## Forcing Questions

**Answer these 6 questions FIRST, before any product detail below.** Each answer should cite source inputs inline (e.g., *per `vision.md` §Goals*, *per `research/competitive-landscape.md`*). If an answer is genuinely unknown from available inputs, write `UNKNOWN — needs user input` and surface it to the user during PRD review.

### 1. Who exactly is this for?
*(Concrete user / persona. Avoid "everyone" or vague segments. Name the specific role, context, and how they currently solve the problem.)*

[Answer]

### 2. What is the smallest valuable thing we could ship?
*(MVP scope. What is the minimum surface area that delivers real user value? What would you cut if forced to ship in half the time?)*

[Answer]

### 3. What does "done" look like at the user-visible level?
*(Describe the user-observable outcome. Not technical milestones — what the user sees, feels, or accomplishes when this works.)*

[Answer]

### 4. What are we explicitly NOT doing in this iteration?
*(Bullet list of scope cuts. The act of writing these prevents downstream scope creep.)*

- [Not-doing 1]
- [Not-doing 2]
- [Not-doing 3]

### 5. What is the riskiest assumption?
*(The single thing most likely to be wrong. If this assumption fails, what breaks? How would you validate it cheaply before committing to build?)*

[Answer]

### 6. What does success look like quantitatively (or qualitatively if metrics aren't tractable)?
*(Prefer numbers — adoption rate, latency target, error reduction. If the work isn't measurable yet, state the qualitative signal you'll watch and acknowledge the gap.)*

[Answer]

---

## Executive Summary

### Vision Statement
[One paragraph describing the product vision — what you're building and why it matters. Pull from `vision.md` if available.]

### Problem Statement
[What problem does this product solve? Who has this problem?]

### Target Audience
- **Primary Users**: [Who will use this daily?]
- **Secondary Users**: [Who else benefits?]
- **Stakeholders**: [Who cares about this product?]

---

## Product Goals & Objectives

### Short-term Goals (0-3 months)
1. [Goal 1]
2. [Goal 2]

### Medium-term Goals (3-6 months)
1. [Goal 1]
2. [Goal 2]

### Long-term Vision (6-12 months)
1. [Goal 1]
2. [Goal 2]

### Non-Goals
*(Already partially captured in Forcing Question 4. Restate here for downstream agents.)*
- [Out of scope]
- [Out of scope]

---

## User Personas

### Primary Persona: [Name/Title]
- **Background**: [Role, experience level, context]
- **Goals**: [What they want to achieve]
- **Pain Points**: [Current challenges]
- **Success Criteria**: [What makes them successful?]

### Secondary Persona: [Name/Title]
- **Background**: [Role, experience level, context]
- **Goals**: [What they want to achieve]
- **Pain Points**: [Current challenges]

---

## User Journeys (High-Level)

### Journey 1: [Primary User Flow Name]
**Persona**: [Which persona uses this?]

1. **Discovery**: [How do they find/start?]
2. **Core Usage**: [Main workflow — broad strokes only]
3. **Exit/Completion**: [How does the journey end?]

**Key Friction Points**: [What hurts today?]
**Desired Improvement**: [What should feel different?]

*(Keep journeys high-level. Step-by-step UX choreography belongs in design/plan documents, not PRD.)*

---

## Core Deliverables

List the **product-level deliverables** — not features as implementation units. Group by user-visible capability.

### Deliverable 1: [Capability Name]
**Priority**: Must | Should | Could
**User-visible outcome**: [What the user can now do that they couldn't before]
**Success signal**: [How we know it landed]

### Deliverable 2: [Capability Name]
*(Repeat structure)*

*(Avoid acceptance criteria here — those belong in plan/task docs where downstream agents will derive them with full context.)*

---

## Design Language & UX Principles

### Design Philosophy
[Describe the product's design philosophy in 2-3 sentences — e.g., minimalist, data-dense, playful, terminal-native.]

### Tone & Voice
[How the product talks to the user. Examples or anchor brands if helpful.]

### Accessibility Floor
- **WCAG Compliance**: [Level — typically AA]
- **Keyboard Navigation**: [Required?]
- **Screen Reader Support**: [Required?]

### Responsive / Multi-surface Behavior
- **Supported surfaces**: [Web, mobile, CLI, etc.]
- **Progressive enhancement stance**: [Core capability must work where?]

---

## Constraints (High-level only)

*(Specific tech choices belong in plan docs. List only constraints that are non-negotiable inputs to planning.)*

### Required
- [Technology / system / API that MUST be used]

### Prohibited
- [Technology / approach that CANNOT be used and why]

### Non-functional Constraints
- **Latency floor**: [Max acceptable response time, if known]
- **Availability**: [Uptime expectation]
- **Privacy / compliance**: [GDPR, HIPAA, etc.]
- **Security floor**: [Auth, encryption, audit requirements]

---

## Success Metrics

*(Forcing Question 6 captures the headline. Expand here if multiple metrics apply.)*

| Metric | Target | Measurement source | Cadence |
|--------|--------|--------------------|---------|
| [Primary metric] | [Target] | [Where it's measured] | [How often] |
| [Secondary] | [Target] | [Source] | [Cadence] |

---

## Inputs Consumed

*(Vision-driven mode only — list which input files informed this PRD so downstream agents can trace provenance.)*

- `features/<feature-name>/vision.md`
- `features/<feature-name>/research/[...]` *(if present)*
- `features/<feature-name>/exploration/[...]` *(if present)*
- `.docs/architecture/[...]` *(if relevant)*

---

## Open Questions & Risks

### Open Questions
1. **[Question]**
   - **Impact if unanswered**: [What's blocked]
   - **Owner**: [Who should answer]

### Risks
1. **Risk**: [Describe]
   - **Likelihood**: High | Medium | Low
   - **Impact**: High | Medium | Low
   - **Mitigation stance**: [Approach — not detailed plan]

### Assumptions
- [Assumption — link to Forcing Question 5 if this is the riskiest one]

---

## PRD Review Checklist

Before handing off to plan-mode:

- [ ] All 6 Forcing Questions answered (or explicitly marked `UNKNOWN — needs user input`)
- [ ] User has reviewed and approved the PRD (this is the real quality gate)
- [ ] Personas are concrete (no "all users")
- [ ] Deliverables describe user-visible outcomes, not implementation tasks
- [ ] Non-goals are explicit
- [ ] At least one quantitative or honestly-qualitative success metric
- [ ] Input provenance (vision.md, research, etc.) is cited
- [ ] No granular technical implementation specs (those come later, in plan docs)

---

## Revision History
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | [Date] | [Name] | Initial PRD |

---

*This PRD is a living document. Update it as the product evolves; maintain version history.*
