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

### Step 5: Project Graph Lint (ADVISORY — warn-only, never fails compliance)
```bash
# Rebuild the code↔docs bridge from the current corpus, then lint it. Both steps
# are deterministic (rg+jq, zero-LLM) and fail-open — the linter ALWAYS exits 0.
if [ -x .logic-loom/scripts/bash/build-graph-bridge.sh ] \
   && [ -x .logic-loom/scripts/bash/lint-graph.sh ]; then
  .logic-loom/scripts/bash/build-graph-bridge.sh \
    --out .logic-loom/graph/graph-bridge.jsonl >/dev/null 2>&1 || true
  .logic-loom/scripts/bash/lint-graph.sh .logic-loom/graph/graph-bridge.jsonl 2>&1 || true
else
  echo "graph-lint: skipped (build-graph-bridge.sh / lint-graph.sh not present)"
fi
```
Surface any `WARN:` lines (dangling `covers:` → a note points at a deleted/renamed
code path; dangling `links-to` → a broken `[[wikilink]]`/`[](…)`) and any `INFO:`
orphan-note lines in the report. **This step is purely advisory and fail-open: it
NEVER fails the compliance check, NEVER blocks, and NEVER touches git.** A missing
graph script, a missing bridge file, or absent `jq`/`rg` all degrade to a no-op —
graph hygiene is defense-in-depth, not a gate.

### Step 6: Generate Compliance Report
```
/finalize Report:
✅ Constitutional Compliance: [X/16] principles passing
✅ Sanitization: No secrets detected
✅ Test Coverage: [X]% (threshold: 80%)
✅ Documentation: Synchronized
ℹ️ Project Graph (advisory): [N warnings, M infos] — informational only, non-blocking

Suggested commit commands (for manual execution):
  git add [files]
  git commit -m "[message]"
  git push origin [branch]
```

**CRITICAL (Principle VI)**: This command NEVER executes git commands.
It only validates and suggests. The user must manually execute git operations.


## Constitutional Compliance
- **Principle VI (CRITICAL)**: NO git operations — report only
- **Principle II**: Validates test coverage
- **Principle VIII**: Validates documentation sync (incl. the advisory project-graph lint, warn-only)
- **Principle VII**: Structured logging of validation results

> The Step 5 project-graph lint is **advisory / fail-open**: it surfaces graph
> hygiene warnings but never contributes a pass/fail to the compliance verdict.

## Usage
```
/finalize
/finalize --verbose
```
