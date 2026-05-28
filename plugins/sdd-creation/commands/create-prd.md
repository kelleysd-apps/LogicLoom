---
name: create-prd
description: Create a Product Requirements Document as Single Source of Truth for project initialization.
model: opus
---

# /create-prd Command

**SKILL ACTIVATION**: Activate the create-prd skill at `plugins/sdd-creation/skills/create-prd/SKILL.md`.

## Execution Instructions

### Step 1: Determine PRD Scope
Ask user: Project-level PRD, feature-level PRD, or product pivot?

### Step 2: Load Template
Read: `.logic-loom/templates/prd-template.md`

### Step 3: Interactive Questionnaire
Walk through PRD sections with user:
- Product Vision & Goals
- Target Users & Personas
- Feature Requirements (prioritized)
- Technical Constraints
- Success Metrics & KPIs
- Timeline & Milestones

### Step 4: Generate PRD
Write to: `specs/prd/PRD.md` (or feature-specific location)

### Step 5: Report
Show: PRD path, suggested next steps (/initialize-project).
