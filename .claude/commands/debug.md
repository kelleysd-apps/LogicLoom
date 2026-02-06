# /debug Command

---
description: Interactive debugging workflow for Vercel deployment issues, API endpoint failures, and production runtime errors. Systematic diagnosis and verification of fixes.
---

> ⚠️ **DEPRECATED**: This command has moved to `plugins/sdd-debug/commands/debug.md`.
> The plugin version is the canonical source. This monolithic version will be removed in v5.0.
> 
> **Plugin-First Architecture (Principle XVI)**: All commands now live within their respective plugins.


## When to Use

Use the `/debug` command when you encounter:

- **Deployment Failures**: Vercel builds fail, functions don't deploy, 404 endpoints
- **Runtime Errors**: 500 errors, timeouts, silent failures in production
- **Local vs Production Issues**: Works locally but fails on Vercel
- **TypeScript Errors**: Compilation blocking deployments
- **Platform Issues**: Serverless function limits, cold starts, environment variables

## Trigger Keywords

The debug skill is automatically invoked when you mention:
- `debug`, `fix`, `broken`, `not working`, `failing`
- `deployment failed`, `build error`, `Vercel error`
- `404`, `500 error`, `timeout`
- `investigate`, `troubleshoot`, `diagnose`
- `works locally but not in production`

## What It Does

The debug skill provides a **systematic 10-step workflow**:

1. **Issue Identification** - Understand the symptom and scope
2. **Local Verification** - Isolate platform vs code issues
3. **Vercel-Specific Diagnostics** - Check function limits, config, dependencies
4. **API Endpoint Diagnosis** - Debug 404/500 errors, routing issues
5. **TypeScript Error Resolution** - Fix compilation errors
6. **Fix Implementation** - Apply targeted fixes
7. **Verification Process** - Clean build, test, deploy
8. **Regression Check** - Ensure no new issues introduced
9. **Completion Report** - Document root cause and fixes
10. **Iteration Handling** - Max 5 cycles before user escalation

## Constitutional Compliance

- **Principle II (Test-First)**: Verify/add tests for bug fixes
- **Principle VI (Git Approval)**: NO automatic git operations
- **Principle VIII (Documentation)**: Update docs if patterns discovered
- **Principle X (Delegation)**: Delegates to specialists when needed

## Delegation

The debug skill delegates to specialists when appropriate:

- **backend-architect**: API architecture issues, system design
- **database-specialist**: Query optimization, schema issues
- **security-specialist**: Auth/authorization, vulnerabilities
- **devops-engineer**: CI/CD failures, infrastructure

## Example Usage

```
User: "deployment failed. investigate and debug"
→ Invokes debug skill
→ Runs 10-step workflow
→ Identifies issue, applies fix, verifies deployment
→ Reports completion with root cause analysis
```

## Full Documentation

See [.claude/skills/technical/debug/SKILL.md](.claude/skills/technical/debug/SKILL.md) for complete workflow documentation, troubleshooting guides, and real-world examples.

---

**Command Version**: 1.0.0
**Skill Location**: `.claude/skills/technical/debug/SKILL.md`
**Framework Version**: 3.1.1
