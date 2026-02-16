# Product Requirements Document (PRD): [PROJECT NAME]

**Project**: `[project-name]`
**Created**: [DATE]
**Owner**: [PRODUCT OWNER]
**Status**: Draft
**Version**: 1.0.0

---

## 📋 Executive Summary

### Vision Statement
[One paragraph describing the product vision - what you're building and why it matters]

### Problem Statement
[What problem does this product solve? Who has this problem?]

### Success Metrics
- **Primary Metric**: [Key metric that defines success]
- **Secondary Metrics**:
  - [Metric 1]
  - [Metric 2]
  - [Metric 3]

### Target Audience
- **Primary Users**: [Who will use this daily?]
- **Secondary Users**: [Who else benefits?]
- **Stakeholders**: [Who cares about this product?]

---

## 🎯 Product Goals & Objectives

### Short-term Goals (0-3 months)
1. [Goal 1]
2. [Goal 2]
3. [Goal 3]

### Medium-term Goals (3-6 months)
1. [Goal 1]
2. [Goal 2]

### Long-term Vision (6-12 months)
1. [Goal 1]
2. [Goal 2]

### Non-Goals
- [Explicitly state what this product will NOT do]
- [What's out of scope?]

---

## 👥 User Personas

### Primary Persona: [Name/Title]
- **Background**: [Role, experience level, context]
- **Goals**: [What they want to achieve]
- **Pain Points**: [Current challenges]
- **Behaviors**: [How they work, tools they use]
- **Success Criteria**: [What makes them successful?]

### Secondary Persona: [Name/Title]
- **Background**: [Role, experience level, context]
- **Goals**: [What they want to achieve]
- **Pain Points**: [Current challenges]
- **Behaviors**: [How they work, tools they use]

---

## 🗺️ User Journey Maps

### Journey 1: [Primary User Flow Name]
**Persona**: [Which persona uses this?]

1. **Discovery**: [How do they find/start using the product?]
2. **Onboarding**: [First-time experience]
3. **Core Usage**: [Main workflow steps]
4. **Advanced Usage**: [Power user capabilities]
5. **Exit/Completion**: [How does the journey end?]

**Pain Points**:
- [Pain point 1 at specific step]
- [Pain point 2 at specific step]

**Opportunities**:
- [Opportunity to improve step X]
- [Opportunity to enhance step Y]

---

## ⚙️ Core Features & Requirements

### Feature Category 1: [Category Name]
**Priority**: High | Medium | Low
**Timeline**: [When should this be built?]

#### Feature 1.1: [Feature Name]
**User Story**: As a [persona], I want to [action] so that [benefit].

**Acceptance Criteria**:
- [ ] Given [context], when [action], then [result]
- [ ] Given [context], when [action], then [result]
- [ ] [Specific requirement]

**Dependencies**: [Other features or systems required]
**Constraints**: [Technical, business, or regulatory limits]
**Success Metrics**: [How to measure this feature's impact]

#### Feature 1.2: [Feature Name]
[Repeat structure above]

### Feature Category 2: [Category Name]
[Repeat structure above]

---

## 🏗️ System Architecture Principles

### Constitutional Principles (from `.specify/memory/constitution.md`)

**CRITICAL: These principles guide ALL development decisions**

#### Immutable Principles
1. **Library-First Architecture** (Principle I)
   - How does this apply to your project? [Customize]
   - Exceptions for this project: [If any]

2. **Test-First Development (TDD)** (Principle II)
   - Minimum test coverage: 80%
   - Testing philosophy for this project: [Customize]

3. **Contract-First Design** (Principle III)
   - API contract standards: [OpenAPI, GraphQL, etc.]
   - Contract versioning approach: [Customize]

#### Quality & Safety Principles
4. **Idempotent Operations** (Principle IV)
   - Critical operations requiring idempotency: [List]

5. **Progressive Enhancement** (Principle V)
   - Feature flag strategy: [Describe]
   - Rollout approach: [Customize]

6. **Git Operation Approval** (Principle VI)
   - CRITICAL: NO automatic git operations without approval
   - Branch strategy: [main, develop, feature branches]

7. **Observability & Structured Logging** (Principle VII)
   - Logging standards: [Format, tools]
   - Monitoring approach: [Tools, dashboards]

8. **Documentation Synchronization** (Principle VIII)
   - Documentation strategy: [How to maintain]
   - Update triggers: [When docs must be updated]

9. **Dependency Management** (Principle IX)
   - Approved dependencies: [List or approval process]
   - Version pinning strategy: [Exact, caret, tilde]

#### Workflow & Delegation Principles
10. **Agent Delegation Protocol** (Principle X)
    - Agent usage policy: [When to use which agents]
    - Custom agents for this project: [List planned agents]

11. **Input Validation & Output Sanitization** (Principle XI)
    - Validation standards: [Required validations]
    - Sanitization requirements: [XSS, SQL injection, etc.]

12. **Design System Compliance** (Principle XII)
    - Design system: [Name/link or "To be created"]
    - UI/UX principles: [Consistency requirements]

13. **Feature Access Control** (Principle XIII)
    - Access tiers: [Free, Premium, Enterprise, etc.]
    - Feature gating approach: [How features are locked/unlocked]

14. **AI Model Selection Protocol** (Principle XIV)
    - Default model: Sonnet 4.5
    - When to use Haiku: [Criteria]
    - When to use Opus: [Criteria]

---

## 🔧 Technical Constraints

### Technology Stack (High-level Constraints Only)
**Note**: Specific implementation details belong in feature specs, not here.

- **Required Technologies**: [Technologies you MUST use - e.g., existing APIs]
- **Prohibited Technologies**: [Technologies you CANNOT use - e.g., licensing issues]
- **Platform Requirements**: [Web, Mobile, Desktop, etc.]

### Performance Requirements
- **Response Time**: [Max acceptable latency]
- **Throughput**: [Requests per second, concurrent users]
- **Availability**: [Uptime SLA - e.g., 99.9%]
- **Scalability**: [User/data growth expectations]

### Security & Compliance
- **Authentication**: [Required auth method]
- **Authorization**: [RBAC, ABAC, etc.]
- **Data Privacy**: [GDPR, CCPA, HIPAA compliance]
- **Encryption**: [At rest, in transit requirements]
- **Audit Logging**: [What must be logged?]

### Integration Requirements
- **External Systems**: [APIs, services to integrate with]
- **Data Import/Export**: [Formats, frequency]
- **Webhooks/Events**: [Real-time requirements]

---

## 📊 Data & Analytics

### Core Entities
List the main data objects your product manages:

1. **[Entity Name]** (e.g., User, Product, Order)
   - **Purpose**: [Why this entity exists]
   - **Key Attributes**: [Critical fields - high level only]
   - **Relationships**: [How it relates to other entities]
   - **Lifecycle**: [Created when? Deleted when?]
   - **Access Control**: [Who can view/modify?]

2. **[Entity Name]**
   [Repeat above]

### Analytics & Reporting
- **Key Reports**: [What reports do users need?]
- **Dashboard Requirements**: [Real-time metrics to display]
- **Export Capabilities**: [CSV, PDF, API access?]

---

## 🚀 Release Strategy

### MVP (Minimum Viable Product)
**Target Date**: [Date]
**Core Features**:
- [Feature 1 - absolute must-have]
- [Feature 2 - absolute must-have]
- [Feature 3 - absolute must-have]

**Success Criteria**: [How do we know MVP succeeded?]

### Phase 2: [Phase Name]
**Target Date**: [Date]
**Features**:
- [Feature 1]
- [Feature 2]

### Phase 3: [Phase Name]
**Target Date**: [Date]
**Features**:
- [Feature 1]
- [Feature 2]

---

## 🎨 Design Principles & UX Guidelines

### Design Philosophy
[Describe your product's design philosophy - e.g., minimalist, data-dense, playful]

### Accessibility Requirements
- **WCAG Compliance**: [Level A, AA, or AAA]
- **Keyboard Navigation**: [Required? Exceptions?]
- **Screen Reader Support**: [Required features]
- **Color Contrast**: [Minimum ratios]

### Responsive Design
- **Supported Devices**: [Desktop, Tablet, Mobile]
- **Breakpoints**: [If specific breakpoints required]
- **Progressive Enhancement**: [Core functionality on all devices]

---

## 🔄 Workflow Integration

### SDD Framework Integration
This PRD serves as the **Single Source of Truth (SSOT)** for:

1. **Specification Agent** (`/specify` command)
   - References this PRD for: [What spec agent pulls from here]
   - User stories source: [Section to reference]
   - Requirements source: [Section to reference]

2. **Planning Agent** (`/plan` command)
   - Technical constraints from: [Section]
   - Architecture principles from: [Section]
   - Integration requirements from: [Section]

3. **Custom Agents**
   - Agents planned: [List from Principle X section]
   - Agent purposes: [Brief description of each]

4. **Constitutional Customization**
   - This PRD's constitutional principles override framework defaults
   - Review `.specify/memory/constitution.md` after PRD creation
   - Update constitution with project-specific rules from this PRD

---

## ❓ Open Questions & Risks

### Open Questions
1. **[Question 1]**
   - **Impact**: [What's affected if unanswered?]
   - **Owner**: [Who should answer?]
   - **Deadline**: [When do we need answer?]

2. **[Question 2]**
   [Repeat above]

### Risks & Mitigation
1. **Risk**: [Describe risk]
   - **Likelihood**: High | Medium | Low
   - **Impact**: High | Medium | Low
   - **Mitigation**: [How to reduce/eliminate]
   - **Owner**: [Who manages this risk?]

2. **Risk**: [Describe risk]
   [Repeat above]

### Assumptions
- [Assumption 1 - what we're assuming is true]
- [Assumption 2 - what we're assuming is true]
- [Assumption 3 - needs validation?]

---

## 📚 Appendices

### Appendix A: Glossary
- **[Term]**: [Definition]
- **[Term]**: [Definition]

### Appendix B: References
- [Link to competitive analysis]
- [Link to user research]
- [Link to technical research]

### Appendix C: Revision History
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | [Date] | [Name] | Initial PRD |

---

## ✅ PRD Review Checklist

Before finalizing this PRD, ensure:

**Completeness**:
- [ ] Executive summary clearly states vision, problem, and success metrics
- [ ] All user personas documented with goals and pain points
- [ ] Core features have acceptance criteria and success metrics
- [ ] All 16 constitutional principles addressed with project-specific guidance
- [ ] Technical constraints documented (what's required vs prohibited)
- [ ] Release strategy with MVP clearly defined
- [ ] Open questions identified with owners and deadlines

**Clarity**:
- [ ] No ambiguous requirements (all testable and measurable)
- [ ] Success metrics are quantifiable
- [ ] Personas are specific and realistic
- [ ] Feature priorities clearly marked
- [ ] No implementation details (HOW) - only requirements (WHAT/WHY)

**Alignment**:
- [ ] Goals align with vision and problem statement
- [ ] Features support defined user journeys
- [ ] Success metrics measure stated goals
- [ ] Constitutional principles don't conflict with requirements
- [ ] Release phases are achievable given constraints

**Actionability**:
- [ ] Specification agent can extract clear user stories
- [ ] Planning agent has sufficient constraints and principles
- [ ] Each feature can be broken into tasks
- [ ] Dependencies are identified
- [ ] Risks have mitigation plans

**Stakeholder Review**:
- [ ] Product owner approved
- [ ] Key stakeholders reviewed
- [ ] Technical feasibility validated
- [ ] Legal/compliance reviewed (if applicable)
- [ ] Budget/resources confirmed

---

**Next Steps After PRD Approval**:
1. Update `.specify/memory/constitution.md` with project-specific principles
2. Run `/specify` for each core MVP feature
3. Create custom agents identified in Principle X
4. Set up design system (if Principle XII requires one)
5. Configure CI/CD for quality gates (Principles II, III, VIII)

---

*This PRD is a living document. Update it as the product evolves, but maintain version history.*
