---
name: finalize
description: |
  Pre-commit compliance validation — checks all 16 constitutional principles
  but NEVER executes git commands. Reports findings and suggests commands for
  manual execution. Use before committing to ensure constitutional compliance.

  Triggered by: /finalize, "check compliance", "pre-commit review",
  "validate before commit", "run constitutional check"
allowed-tools: Read, Bash, Grep, Glob
category: git
---

# Finalize Skill — Pre-Commit Compliance Validation

## Purpose

Validate that all changes comply with the 16 constitutional principles before committing. This skill **reports only** — it NEVER executes git commands (Principle VI).

## When to Use

- Before any git commit
- After completing a feature implementation
- When `/finalize` is invoked

---

## Procedure

### Step 1: Run Automated Checks

Run the constitutional compliance script:

```
bash .logic-loom/scripts/bash/constitutional-check.sh
```

Parse output for pass/fail results per principle.

### Step 2: Run Test Suite (Principle II)

Run the project test suite to validate coverage:

```
bash tests/run_all_tests.sh 2>&1
```

Check that all suites pass and coverage meets the 80% threshold.

### Step 3: Validate 16 Principles

Check each principle against the current changes:

| # | Principle | Check | How to Verify |
|---|-----------|-------|---------------|
| I | Library-First | Feature is standalone library | Look for isolated module with own tests |
| II | Test-First | Tests exist, coverage >80% | Run test suite, check coverage report |
| III | Contract-First | API contracts defined | Check for OpenAPI/GraphQL schemas |
| IV | Idempotent Ops | Scripts handle re-runs safely | Look for "already exists" guards |
| V | Progressive Enhancement | Rollback possible | Check for feature flags if applicable |
| VI | Git Approval | No auto git ops | Verify this skill only reports |
| VII | Observability | Critical ops logged | Check for structured logging |
| VIII | Doc Sync | CLAUDE.md, AGENTS.md current | Diff docs against code changes |
| IX | Dependency Mgmt | Deps declared, versions pinned | Check package.json/requirements.txt |
| X | Agent Delegation | Specialist work → specialists | Review if domain work used skills |
| XI | Input Validation | Inputs validated, outputs sanitized | Check for XSS/injection guards |
| XII | Design System | UI follows design tokens | Check component consistency |
| XIII | Access Control | Permissions enforced | Check RLS/auth if applicable |
| XIV | Model Selection | Correct AI model used | Verify Opus/Sonnet/Haiku choice |
| XV | File Organization | Files in correct locations | Check directory structure |
| XVI | Plugin-First | Capabilities as plugins | New features are plugins |

**Skip non-applicable principles** (e.g., XII for backend-only changes).

### Step 4: Check Documentation Sync (Principle VIII)

- Verify CLAUDE.md reflects any instruction changes
- Verify AGENTS.md matches current agent registry
- Check CHANGELOG.md has an entry for current changes (if the project maintains one)

### Step 5: Security Scan (Principle XI)

Check staged files for:
- API keys, passwords, tokens
- `.env` files that should not be committed
- Hardcoded credentials
- Ensure `.gitignore` covers sensitive files

### Step 6: Generate Compliance Report

Output a structured report:

```
/finalize Report:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Constitutional Compliance: X/16 principles passing
✅ Sanitization: No secrets detected
✅ Test Coverage: X% (threshold: 80%)
✅ Documentation: Synchronized
⚠️  Warnings: [list any non-blocking issues]

Suggested commit commands (for manual execution):
  git add [specific files]
  git commit -m "[suggested message]"
  git push origin [branch]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Critical Rules

1. **NEVER execute git commands** — report only, suggest commands
2. **NEVER skip Principle II** — test failures block the report
3. **NEVER ignore secrets** — any credential in staged files is a hard block
4. Mark principles as N/A when they don't apply to the change scope

## Related

- `/git-push` — Executes the git workflow (with user approval)
- `.logic-loom/scripts/bash/constitutional-check.sh` — Automated checker
