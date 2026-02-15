---
name: create-prd
description: Create a Product Requirements Document as Single Source of Truth for project initialization
allowed-tools: Read, Write, Bash, Grep, Glob
---

# create-prd Skill

Create a structured Product Requirements Document (PRD) that serves as the Single Source of Truth for project initialization and the `/initialize-project` workflow.

## Procedure

### Step 1: Determine PRD Scope

Ask the user which type of PRD to create:
- **Project-level PRD**: Full product requirements for a new project
- **Feature-level PRD**: Requirements for a specific feature within an existing project
- **Product pivot**: Requirements update for an existing product changing direction

### Step 2: Load Template

Read the PRD template from: `.specify/templates/prd-template.md`

If template doesn't exist, use the standard PRD structure below.

### Step 3: Interactive Questionnaire

Walk through PRD sections with the user, asking targeted questions:

1. **Product Vision & Goals**: What problem does this solve? What's the desired outcome?
2. **Target Users & Personas**: Who will use this? What are their key characteristics?
3. **Feature Requirements**: What features are needed? Use MoSCoW prioritization (Must/Should/Could/Won't)
4. **Technical Constraints**: Stack, platform, performance requirements, integration needs
5. **Success Metrics & KPIs**: How will success be measured? What are the targets?
6. **Timeline & Milestones**: Key delivery dates or phases

### Step 4: Generate PRD

1. Populate the template with gathered information
2. Add constitutional compliance section (Principle II: test requirements, Principle XVI: plugin architecture)
3. Write to: `specs/prd/PRD.md` (project-level) or `specs/{feature}/prd.md` (feature-level)

### Step 5: Report

- Show PRD file path
- Suggest next steps: `/initialize-project` to customize framework based on PRD
- Remind about `/specification` workflow for feature development

## Constitutional Compliance

- **Principle III (Contract-First)**: PRD serves as the initial contract
- **Principle VIII (Documentation Sync)**: PRD must be kept in sync with implementation
- **Principle XV (File Organization)**: PRD stored in standard specs/ location

## Task Brief

When spawning a worker to create a PRD, include this context:

> You are creating a Product Requirements Document using the SDD framework's PRD template. The PRD serves as the Single Source of Truth for project initialization. Walk through each section interactively with the user, gathering requirements for vision, users, features (MoSCoW prioritized), constraints, metrics, and timeline. Output to specs/prd/PRD.md.
