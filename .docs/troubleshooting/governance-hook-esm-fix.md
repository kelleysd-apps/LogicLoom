# Governance Hook: ES Module vs CommonJS Fix

**Added**: 2026-02-04
**Applies To**: Downstream projects using SDD Agentic Framework
**Status**: Guidance for Framework Updates

---

## Problem

When updating downstream projects from the SDD Agentic Framework, the governance pre-flight hook at `.claude/hooks/user-prompt-submit/governance-preflight.js` may fail silently.

**Symptom**: 
```
UserPromptSubmit hook error
```

Or the hook simply doesn't execute (no governance context injected).

---

## Root Cause

**ES Module vs CommonJS conflict** in Node.js.

If the downstream project's `package.json` has:
```json
{
  "type": "module"
}
```

This tells Node.js to treat all `.js` files as ES modules. However, the framework's governance hook uses **CommonJS syntax**:

```javascript
const fs = require('fs');      // ❌ CommonJS syntax
const path = require('path');  // ❌ CommonJS syntax
```

When Node.js executes `governance-preflight.js`, it expects ES module syntax (`import`/`export`) but finds `require()`, causing the hook to fail.

---

## Solution

### Option 1: Rename to `.cjs` (Recommended)

Rename the file from `.js` to `.cjs`:

```bash
# Rename the file
mv .claude/hooks/user-prompt-submit/governance-preflight.js \
   .claude/hooks/user-prompt-submit/governance-preflight.cjs

# Update settings.json to reference .cjs
# Change: "command": "node .claude/hooks/user-prompt-submit/governance-preflight.js"
# To:     "command": "node .claude/hooks/user-prompt-submit/governance-preflight.cjs"
```

The `.cjs` extension tells Node.js to treat this file as CommonJS **regardless** of project settings.

### Option 2: Use the Bash Version

The framework includes a bash version that doesn't have this issue:

```json
// In .claude/settings.json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "type": "command",
        "command": "bash .claude/hooks/user-prompt-submit/governance-preflight.sh",
        "timeout": 5000
      }
    ]
  }
}
```

---

## Why Option 1 Works

Node.js file extension behavior:

| Extension | In `"type": "module"` project | In `"type": "commonjs"` project |
|-----------|-------------------------------|----------------------------------|
| `.js`     | ES Module                     | CommonJS                         |
| `.mjs`    | ES Module (always)            | ES Module (always)               |
| `.cjs`    | CommonJS (always)             | CommonJS (always)                |

The `.cjs` extension **overrides** the project-level `"type"` setting.

---

## Detection

Check if your project uses ES modules:

```bash
# Check package.json
grep '"type"' package.json

# If output is: "type": "module"
# Then you need to apply this fix
```

---

## Prevention in Framework Updates

When updating downstream repos from the framework:

1. **Check project module type** before updating hooks
2. **Prefer bash version** of hooks for universal compatibility
3. **If using Node.js hooks**, use `.cjs` extension in ES module projects
4. **Document in downstream** project's troubleshooting folder

---

## Settings.json Configuration

### For CommonJS Projects (no `"type": "module"`)
```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "command": "node .claude/hooks/user-prompt-submit/governance-preflight.js"
    }]
  }
}
```

### For ES Module Projects (`"type": "module"`)
```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "command": "node .claude/hooks/user-prompt-submit/governance-preflight.cjs"
    }]
  }
}
```

### Universal (Bash - Works Everywhere)
```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "command": "bash .claude/hooks/user-prompt-submit/governance-preflight.sh"
    }]
  }
}
```

---

## Verification

After applying fix:

```
UserPromptSubmit hook success: Success
```

The hook should:
- ✅ Inject governance context into each prompt
- ✅ Detect domain keywords
- ✅ Write audit logs to `.docs/governance/audit/`
- ✅ Return correct hook contract format with `hookEventName`

---

## Related Issues

- **hookEventName missing**: See main framework fix (v3.1.3) - required field in hook output
- **Bash hook preferred**: After v3.1.3, bash version is default for universal compatibility

---

## References

- [Node.js Modules Documentation](https://nodejs.org/api/modules.html#enabling)
- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
- Framework Release: v3.1.3 (hook fixes)
