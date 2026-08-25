# Feature Specification: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`  
**Created**: [DATE]  
**Status**: Draft  
**Input**: User description: "$ARGUMENTS"

## Execution Flow (main)
```
1. Parse user description from Input
   → If empty: ERROR "No feature description provided"
2. Extract key concepts from description
   → Identify: actors, actions, data, constraints
3. For each unclear aspect:
   → Mark with [NEEDS CLARIFICATION: specific question]
4. Fill Overview and Scope
   → Overview: one paragraph on WHAT and WHY
   → Scope: what is in, and explicitly what is out
5. Fill User Scenarios & Testing section
   → If no clear user flow: ERROR "Cannot determine user scenarios"
6. Generate Functional Requirements
   → Each requirement must be testable
   → Mark ambiguous requirements
7. Identify Key Entities (if data involved)
8. Fill Acceptance Criteria, Non-Functional Requirements,
   Dependencies, Risks, and Success Metrics
9. Run Review Checklist
   → If any [NEEDS CLARIFICATION]: WARN "Spec has uncertainties"
   → If implementation details found: ERROR "Remove tech details"
10. Return: SUCCESS (spec ready for planning)
```

---

## ⚡ Quick Guidelines
- ✅ Focus on WHAT users need and WHY
- ❌ Avoid HOW to implement (no tech stack, APIs, code structure)
- 👥 Written for business stakeholders, not developers

### Section Requirements
- **Mandatory sections**: Must be completed for every feature
- **Optional sections**: Include only when relevant to the feature
- When a section doesn't apply, remove it entirely (don't leave as "N/A")

### For AI Generation
When creating this spec from a user prompt:
1. **Mark all ambiguities**: Use [NEEDS CLARIFICATION: specific question] for any assumption you'd need to make
2. **Don't guess**: If the prompt doesn't specify something (e.g., "login system" without auth method), mark it
3. **Think like a tester**: Every vague requirement should fail the "testable and unambiguous" checklist item
4. **Common underspecified areas**:
   - User types and permissions
   - Data retention/deletion policies  
   - Performance targets and scale
   - Error handling behaviors
   - Integration requirements
   - Security/compliance needs

---

## Overview *(mandatory)*
[One paragraph: what this feature is and why it exists, in the language a
business stakeholder would use. No tech stack, no APIs, no code structure.]

## Scope *(mandatory)*

**In scope**
- [Capability this feature delivers]
- [Capability this feature delivers]

**Out of scope**
- [Adjacent thing a reader would reasonably assume is included, and is not]
- [Deferred capability, with the reason it is deferred]

## User Scenarios & Testing *(mandatory)*

### Primary User Story
[Describe the main user journey in plain language]

### Acceptance Scenarios
1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

### Edge Cases
- What happens when [boundary condition]?
- How does system handle [error scenario]?

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: System MUST [specific capability, e.g., "allow users to create accounts"]
- **FR-002**: System MUST [specific capability, e.g., "validate email addresses"]  
- **FR-003**: Users MUST be able to [key interaction, e.g., "reset their password"]
- **FR-004**: System MUST [data requirement, e.g., "persist user preferences"]
- **FR-005**: System MUST [behavior, e.g., "log all security events"]

*Example of marking unclear requirements:*
- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **FR-007**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]

### Key Entities *(include if feature involves data)*
- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

## Acceptance Criteria *(mandatory)*
Observable, testable conditions that decide whether this feature is done.
One per line; each must be checkable by someone who did not build it.

- [ ] [Condition, e.g. "A signed-in user with an expired session is returned to
      the sign-in page rather than a blank screen"]
- [ ] [Condition]

## Non-Functional Requirements
Performance, availability, accessibility, security, and compliance targets.
Give numbers where a number is what makes it testable.

- **Performance**: [e.g. "p95 under 200ms for the primary flow"]
- **Security/Privacy**: [e.g. "no personal data in URLs or logs"]
- **Accessibility**: [e.g. "keyboard-navigable, WCAG 2.1 AA"]

## Dependencies & Assumptions

**Depends on**
- [System, team, contract, or prior feature this cannot ship without]

**Assumes**
- [Assumption that, if wrong, changes the shape of this feature]

## Risks
- **[Risk]** — [impact if it happens] — [what reduces it]

## Success Metrics
How we will know, after shipping, that this worked.

- [Metric with a baseline and a target, e.g. "session-expiry support tickets
  drop from ~30/wk to under 5/wk within one month"]

---

## Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Content Quality
- [ ] No implementation details (languages, frameworks, APIs)
- [ ] Focused on user value and business needs
- [ ] Written for non-technical stakeholders
- [ ] All mandatory sections completed

### Requirement Completeness
- [ ] No [NEEDS CLARIFICATION] markers remain
- [ ] Requirements are testable and unambiguous  
- [ ] Success criteria are measurable
- [ ] Scope is clearly bounded
- [ ] Dependencies and assumptions identified

---

## Execution Status
*Updated by main() during processing*

- [ ] User description parsed
- [ ] Key concepts extracted
- [ ] Ambiguities marked
- [ ] User scenarios defined
- [ ] Requirements generated
- [ ] Entities identified
- [ ] Review checklist passed

---
