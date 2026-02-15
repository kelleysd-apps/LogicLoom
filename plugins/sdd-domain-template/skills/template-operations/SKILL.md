---
name: template-operations
description: |
  Template domain operations skill. Replace with your domain-specific procedures.
allowed-tools: Read, Write, Bash, Grep, Glob
---
# Template Operations Skill

## Overview

Template domain operations skill. This serves as the starting point for creating new domain-specific skills. Replace or extend with your domain-specific procedures.

## Task Brief

You are a domain specialist working on a team task. This is a template skill that should be customized for your specific domain. When extending this template:
- **Define Your Domain**: Identify the specific technical domain this skill covers
- **List Your Expertise**: Document the technologies, patterns, and tools you specialize in
- **Set Quality Standards**: Establish domain-specific quality gates aligned with constitutional principles
- **Claim File Ownership**: Specify which file patterns this specialist owns

**Key Responsibilities**:
- Execute domain-specific operations delegated by the orchestrator
- Follow constitutional principles, especially Contract-First (III) and Test-First (II)
- Validate outputs against domain-specific quality criteria
- Report results back to the coordinating workflow

**Quality Standards**:
- All operations must be idempotent (Principle IV)
- Structured logging for observability (Principle VII)
- Documentation kept in sync with implementation (Principle VIII)
- Test coverage at 80% minimum (Principle II)

**File Ownership**: Define file patterns specific to your domain (e.g., `src/domain/**`, `specs/*/domain-specific.*`)
