# UserPromptSubmit Hook: Governance Preflight

## Overview

This hook automatically injects constitutional governance context on every user message to ensure compliance with all 16 principles of the Specification-Driven Development Constitution v3.2.0.

**Hook Type**: UserPromptSubmit
**Version**: 1.0.0
**Layer**: Hook (Layer 1 of 3-layer governance architecture)

---

## Purpose

The governance preflight hook serves as the first line of defense in constitutional compliance by:

1. **Automatic Context Injection** - Reminds Claude Code of constitutional requirements on every message
2. **Audit Logging** - Records all governance decisions for compliance tracking
3. **Principle Enforcement** - Ensures critical principles (VI, X, II) are not forgotten
4. **Zero-Touch Governance** - No user intervention required

---

## How It Works

### Execution Flow

```
User sends message
    ↓
Hook intercepts (via settings.json configuration)
    ↓
Reads agent role from settings.json
    ↓
Creates audit log in .docs/governance/audit/{date}/
    ↓
Generates governance context message
    ↓
Injects context via hookSpecificOutput.additionalContext
    ↓
Claude Code receives message + governance context
```

### Governance Context Injection

The hook injects a governance reminder that includes:

- **Pre-Flight Recitation** - optional; injected only under `LOOM_GOVERNANCE_MODE=strict` (lean mode relies on hook-side enforcement)
- **Domain Analysis** - Trigger keywords for agent delegation
- **Critical Principles** - VI (Git Approval), X (Agent Delegation), II (Test-First)
- **Compliance Summary Format** - Expected output format

---

## Input/Output Contract

### Input (via stdin)

JSON object from Claude Code with user message:

```json
{
  "message": "user message text",
  "context": {...}
}
```

**Note**: Hook reads entire stdin but only uses first 100 chars for audit logging.

### Output (to stdout)

JSON object conforming to Claude Code hook contract:

```json
{
  "blocked": false,
  "hookSpecificOutput": {
    "additionalContext": "governance context message as string"
  }
}
```

**Fields**:
- `blocked`: Always `false` (hook never blocks messages)
- `hookSpecificOutput.additionalContext`: Governance reminder text injected into Claude's context

### Exit Codes

- `0`: Success (always, hook never fails)

---

## Configuration

### Hook Registration

Configure in `.claude/settings.json`:

```json
{
  "agent": "constitutional-governance-agent",
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "./.claude/hooks/user-prompt-submit/governance-preflight.sh",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

**Parameters**:
- `matcher`: Empty string matches all messages
- `timeout`: 5000ms (5 seconds) - hook completes in <100ms typically
- `type`: "command" - executes bash script

### Environment Variables

The hook respects these environment variables:

- `CLAUDE_SESSION_ID`: Session identifier (falls back to timestamp-PID if not set)

---

## Audit Logging

### Log Location

```
.docs/governance/audit/
└── {YYYY-MM-DD}/
    └── session-{session_id}.json
```

**Example**: `.docs/governance/audit/2025-12-19/session-1734629400-12345.json`

### Log Schema

```json
{
  "timestamp": "2025-12-19T14:30:00-08:00",
  "session_id": "1734629400-12345",
  "event_type": "context_injection",
  "decision_type": "context_injection",
  "layer": "hook",
  "agent_role": "constitutional-governance-agent",
  "input_summary": "first 100 chars of user message",
  "output": {
    "action": "inject_governance_context",
    "blocked": false
  },
  "constitutional_principles": ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI"],
  "duration_ms": 0
}
```

### Log Retention

- Logs persist indefinitely (no automatic cleanup)
- Use `.logic-loom/scripts/bash/cleanup-governance-logs.sh` to manage old logs
- Recommended: Clean logs older than 30 days

---

## Dependencies

### Required

- **bash** (or compatible shell)
- **date** (for timestamps)
- **mkdir** (for audit directory creation)
- **cat**, **grep**, **sed** (standard utilities)

### Optional

- **jq** - For JSON parsing (has pure bash fallback if unavailable)

**Graceful Degradation**: Hook works with or without `jq`. If `jq` is not installed, falls back to pure bash JSON generation (slightly less robust but functional).

---

## Performance

**Typical Execution Time**: <100ms
- Agent role extraction: <10ms
- Audit log creation: <20ms (backgrounded, non-blocking)
- Context generation: <10ms
- JSON output: <10ms

**Timeout**: 5000ms (configured in settings.json)
**Risk**: Very low - hook completes in <2% of timeout

---

## Troubleshooting

### Hook Not Executing

**Symptom**: No governance context appears in Claude responses

**Checks**:
1. Verify hook configuration in `.claude/settings.json`
2. Check script exists: `ls .claude/hooks/user-prompt-submit/governance-preflight.sh`
3. Check executable bit: `ls -la .claude/hooks/user-prompt-submit/governance-preflight.sh` (should show `-rwxr-xr-x`)
4. Test manually: `echo '{}' | ./.claude/hooks/user-prompt-submit/governance-preflight.sh`

**Fix**:
```bash
chmod +x .claude/hooks/user-prompt-submit/governance-preflight.sh
```

---

### Invalid JSON Output

**Symptom**: Claude Code shows hook error messages

**Checks**:
1. Test hook output: `echo '{}' | ./.claude/hooks/user-prompt-submit/governance-preflight.sh | jq .`
2. Check for syntax errors in script

**Fix**: Reinstall hook from template or restore from backup

---

### Audit Logs Not Created

**Symptom**: No logs in `.docs/governance/audit/`

**Checks**:
1. Check write permissions on `.docs/` directory
2. Verify audit directory creation: `ls -la .docs/governance/audit/`
3. Check script errors: `bash -x .claude/hooks/user-prompt-submit/governance-preflight.sh < /dev/null`

**Fix**:
```bash
mkdir -p .docs/governance/audit
chmod 755 .docs/governance/audit
```

---

### Performance Issues

**Symptom**: Hook times out or slows down Claude Code

**Checks**:
1. Check timeout in settings.json (should be ≥5000ms)
2. Monitor execution time: `time echo '{}' | ./.claude/hooks/user-prompt-submit/governance-preflight.sh`
3. Check disk space (audit logs can accumulate)

**Fix**:
- Clean old audit logs: `./.logic-loom/scripts/bash/cleanup-governance-logs.sh --force`
- Increase timeout in settings.json to 10000ms

---

## Testing

### Manual Test

```bash
# Test hook execution
echo '{"message": "test"}' | ./.claude/hooks/user-prompt-submit/governance-preflight.sh

# Expected output: JSON with blocked: false and additionalContext field
```

### Automated Test

Use the debug script:

```bash
./.logic-loom/scripts/bash/debug-hook.sh
```

This validates:
- Hook exists and is executable
- Output is valid JSON
- Required fields present
- settings.json configuration correct

---

## Integration with 3-Layer Governance

This hook is **Layer 1** of the 3-layer governance architecture:

| Layer | Component | When | Enforcement |
|-------|-----------|------|-------------|
| **1** | **UserPromptSubmit Hook** (this) | Every message | Context injection |
| 2 | Governance Preflight Skill | On `/governance-preflight` | Manual review |
| 3 | Constitutional Governance Agent | Active agent | Decision execution |

**Hook Advantages**:
- Zero-touch activation
- Runs before agent processes message
- Cannot be bypassed
- Minimal performance overhead

**Hook Limitations**:
- Cannot block messages (only inject context)
- No complex decision logic
- No user interaction

For complex governance decisions, use Layer 2 (Skill) or Layer 3 (Agent).

---

## Security & Compliance

### Git Operations (Principle VI)

✅ **Compliant** - Hook performs ZERO git operations

### Audit Trail (Principle VII)

✅ **Compliant** - All hook executions logged to `.docs/governance/audit/`

### Idempotency (Principle IV)

✅ **Compliant** - Multiple executions produce same context (audit logs append, don't overwrite)

### File Organization (Principle XV)

✅ **Compliant** - Hook follows `.claude/hooks/{event}/{script}.sh` structure

---

## Maintenance

### Version Updates

When updating the hook:

1. Update VERSION in script header
2. Document changes in this README
3. Test with `debug-hook.sh`
4. Update constitutional check if governance rules change

### Log Cleanup

Run monthly:

```bash
# Dry-run (show what would be deleted)
./.logic-loom/scripts/bash/cleanup-governance-logs.sh

# Actual cleanup (delete logs older than 30 days)
./.logic-loom/scripts/bash/cleanup-governance-logs.sh --force --days 30
```

---

## Related Documentation

- **Constitution**: `.logic-loom/memory/constitution.md` - All 16 principles
- **Governance Skill**: `.claude/skills/governance/governance-preflight/SKILL.md`
- **Hybrid Architecture**: `.docs/governance/hybrid-architecture.md`
- **Hook Debugging**: `.logic-loom/scripts/bash/debug-hook.sh`
- **Governance Metrics**: `.logic-loom/scripts/bash/governance-metrics.sh`

---



## ES Module Projects Warning

If your project has `"type": "module"` in `package.json`:

**Problem**: The `.js` hook will fail because Node.js expects ES module syntax.

**Solutions**:

1. **Use the bash version** (recommended):
   ```json
   "command": "bash .claude/hooks/user-prompt-submit/governance-preflight.sh"
   ```

2. **Rename JS to CJS**:
   ```bash
   mv governance-preflight.js governance-preflight.cjs
   ```
   Then update settings.json to reference `.cjs`

