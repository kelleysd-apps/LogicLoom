---
name: finalize
description: Pre-commit compliance validation — checks all 16 constitutional principles but NEVER executes git commands.
model: opus
---

# /finalize Command

**SKILL ACTIVATION**: Activate the finalize skill at `plugins/loom-git/skills/finalize/SKILL.md`.

## Execution Instructions

### Step 1: Run Constitutional Compliance Check
```bash
bash .logic-loom/scripts/bash/constitutional-check.sh
```
Parse output for pass/fail per principle.

### Step 2: Secret / Credential Scan
```bash
# Generic staged-file secret scan (no external tooling dependency).
git diff --cached --name-only -z 2>/dev/null | xargs -0 -r grep -nIE \
  '(api[_-]?key|secret|passwd|password|token|-----BEGIN [A-Z ]+PRIVATE KEY-----|AKIA[0-9A-Z]{16})' \
  2>/dev/null && echo "⚠ Review the matches above before committing." || echo "No obvious secrets in staged files."
```
Flag any apparent credentials, API keys, or private keys in staged files.

### Step 3: Validate Test Coverage (Principle II)
```bash
bash tests/run_all_tests.sh 2>&1
```
Ensure all test suites pass and coverage meets 80% threshold.

### Step 4: Check Documentation Sync (Principle VIII)
- Verify CLAUDE.md is up to date
- Verify AGENTS.md matches current agent registry
- Check CHANGELOG.md has an entry for current changes (if the project maintains one)

### Step 5: Generate Compliance Report
```
/finalize Report:
✅ Constitutional Compliance: [X/16] principles passing
✅ Sanitization: No secrets detected
✅ Test Coverage: [X]% (threshold: 80%)
✅ Documentation: Synchronized

Suggested commit commands (for manual execution):
  git add [files]
  git commit -m "[message]"
  git push origin [branch]
```

**CRITICAL (Principle VI)**: This command NEVER executes git commands.
It only validates and suggests. The user must manually execute git operations.

### Step 6: RL Feedback
Record finalize skill execution result.

## Constitutional Compliance
- **Principle VI (CRITICAL)**: NO git operations — report only
- **Principle II**: Validates test coverage
- **Principle VIII**: Validates documentation sync
- **Principle VII**: Structured logging of validation results

## Usage
```
/finalize
/finalize --verbose
```
