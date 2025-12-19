# 3-Layer Hybrid Governance Architecture

**Version**: 1.0.0
**Constitution**: v1.6.0
**Feature**: 003-governance-browser-enhancement

---

## Overview

The SDD Framework employs a **3-layer hybrid governance architecture** that combines automatic enforcement, manual review, and active agent governance to ensure constitutional compliance across all 15 principles.

```
┌─────────────────────────────────────────────────────────────┐
│                        USER MESSAGE                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: UserPromptSubmit Hook (Automatic)                 │
│  • Intercepts every message                                 │
│  • Injects governance context                               │
│  • Creates audit logs                                       │
│  • Cannot block (context only)                              │
│  • <100ms latency                                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  LAYER 2: Governance Preflight Skill (Manual)               │
│  • Invoked via /governance-preflight                        │
│  • Complex decision-making                                  │
│  • Manual validation                                        │
│  • Can recommend blocking                                   │
│  • Human-paced                                             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  LAYER 3: Constitutional Governance Agent (Active)          │
│  • Default agent (if configured)                            │
│  • Enforces principles in real-time                         │
│  • Delegates to specialists                                 │
│  • Gates git operations                                     │
│  • Full enforcement power                                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
                   EXECUTION
```

---

## Layer Comparison

| Aspect | Layer 1: Hook | Layer 2: Skill | Layer 3: Agent |
|--------|---------------|----------------|----------------|
| **Activation** | Automatic (every message) | Manual (`/governance-preflight`) | Active (default agent) |
| **Enforcement** | Context injection | Recommendation | Real-time blocking |
| **Blocking** | No | Can recommend | Yes |
| **Complexity** | Simple | Medium-High | High |
| **Latency** | <100ms | Human-paced | Per-operation |
| **Audit** | Always | When invoked | Continuous |
| **Bypass** | Impossible | Optional | Optional (switch agent) |

---

## Layer 1: UserPromptSubmit Hook

### Purpose
Provide **zero-touch constitutional awareness** by injecting governance context automatically on every user message.

### How It Works
1. User sends message to Claude Code
2. Hook intercepts before Claude processes
3. Reads agent role from `.claude/settings.json`
4. Generates governance reminder text
5. Creates audit log in `.docs/governance/audit/{date}/`
6. Injects context via `hookSpecificOutput.additionalContext`
7. Claude receives message + governance context

### Strengths
- ✅ **Always Active** - Cannot be forgotten or bypassed
- ✅ **Zero Latency** - <100ms overhead
- ✅ **Audit Trail** - Every message logged
- ✅ **No User Action** - Completely automatic

### Limitations
- ❌ **Cannot Block** - Only injects context, cannot prevent actions
- ❌ **Simple Logic** - No complex decision trees
- ❌ **No Interaction** - Cannot ask user questions

### Best For
- Reminding Claude of critical principles (VI, X, II)
- Creating audit trails
- Maintaining awareness across long sessions
- Preventing accidental principle violations

### Configuration

**File**: `.claude/settings.json`

```json
{
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

**Implementation**: `.claude/hooks/user-prompt-submit/governance-preflight.sh`

---

## Layer 2: Governance Preflight Skill

### Purpose
Provide **manual constitutional review** for complex scenarios requiring human judgment.

### How It Works
1. User invokes `/governance-preflight` (or Claude suggests it)
2. Skill presents comprehensive constitutional checklist
3. User/Claude reviews all 15 principles
4. Skill provides delegation guidance
5. Decision documented in audit log
6. User proceeds with validated approach

### Strengths
- ✅ **Comprehensive Review** - All 15 principles checked
- ✅ **Decision Guidance** - Delegation tables, examples
- ✅ **Flexible** - Can handle novel scenarios
- ✅ **Educational** - Teaches constitutional compliance

### Limitations
- ❌ **Manual Activation** - Must be invoked explicitly
- ❌ **Slow** - Human decision-making pace
- ❌ **Skippable** - User can choose not to invoke

### Best For
- Pre-commit validation
- Complex agent delegation decisions
- Constitutional exception requests
- Governance audits
- Training and onboarding

### Invocation

```bash
/governance-preflight
```

**Implementation**: `.claude/skills/governance/governance-preflight/SKILL.md`

---

## Layer 3: Constitutional Governance Agent

### Purpose
Provide **active real-time enforcement** of constitutional principles by serving as the primary orchestration agent.

### How It Works
1. User configures `constitutional-governance-agent` as default agent
2. Agent receives all user messages (with Layer 1 context)
3. Executes 4-step pre-flight protocol on every message
4. Enforces critical principles (II, VI, X)
5. Delegates specialized work to domain agents
6. Gates all git operations (Principle VI)
7. Creates detailed decision logs

### Strengths
- ✅ **Real-Time Enforcement** - Can block violations immediately
- ✅ **Intelligent Routing** - Automatically delegates per Principle X
- ✅ **Git Gating** - Prevents autonomous git operations (Principle VI)
- ✅ **Continuous** - Always active (when set as default)

### Limitations
- ❌ **Bypassable** - User can switch to different agent
- ❌ **Latency** - Adds decision overhead to each operation
- ❌ **Complexity** - Requires Opus model for best performance

### Best For
- Primary orchestration
- Principle X enforcement (agent delegation)
- Principle VI enforcement (git gating)
- Constitutional governance across entire session
- Teams requiring strict compliance

### Configuration

**File**: `.claude/settings.json`

```json
{
  "agent": "constitutional-governance-agent",
  "model": "claude-opus-4-5-20251101"
}
```

**Implementation**: `.claude/agents/governance/constitutional-governance-agent.md`

---

## Decision Flow

### Scenario: User requests "Add user authentication"

#### Layer 1 (Hook)
```
✅ Inject governance context
   "You are operating under Constitution v1.6.0 with 15 principles.
    Remember: Principle VI (Git Approval), Principle X (Agent Delegation)."

✅ Create audit log
   .docs/governance/audit/2025-12-19/session-12345.json
```

#### Layer 2 (Skill - if invoked)
```
📋 Run /governance-preflight checklist

   Domain Analysis:
   - Backend (authentication, session, JWT)
   - Security (encryption, hashing, secrets)
   - Database (user table, credentials storage)

   ⚠️ Multi-domain detected (3 domains)

   Recommendation: Delegate to task-orchestrator

   Pre-Commit Checklist:
   - [ ] Tests written first (Principle II)
   - [ ] No secrets committed (Principle XI)
   - [ ] User approves git operations (Principle VI)
```

#### Layer 3 (Agent - if active)
```
🤖 Constitutional Governance Agent receives message

   Compliance Check:
   - Domain(s): multi (backend, security, database)
   - Delegation: task-orchestrator (Principle X)
   - Git operations: will request approval (Principle VI)
   - Proceeding with: delegating to task-orchestrator

   ⚡ Delegates to task-orchestrator
```

---

## When to Use Each Layer

### Use Layer 1 (Hook) When
- ✅ You want automatic constitutional awareness
- ✅ You need audit trails for all messages
- ✅ You want zero-touch governance
- ✅ You have fast, simple governance needs

### Use Layer 2 (Skill) When
- ✅ Making complex agent delegation decisions
- ✅ Reviewing pre-commit compliance
- ✅ Requesting constitutional exceptions
- ✅ Training team members on constitution
- ✅ Auditing governance decisions

### Use Layer 3 (Agent) When
- ✅ You need real-time principle enforcement
- ✅ You want automatic agent delegation (Principle X)
- ✅ You require git operation gating (Principle VI)
- ✅ You need continuous governance across session
- ✅ Strict compliance is mandatory

---

## Recommended Configurations

### Maximum Governance (Recommended for Teams)

```json
{
  "agent": "constitutional-governance-agent",
  "model": "claude-opus-4-5-20251101",
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

**Coverage**: All 3 layers active

**Best For**:
- Production environments
- Team collaboration
- Strict compliance requirements
- High-stakes projects

---

### Balanced Governance (Recommended for Solo)

```json
{
  "agent": "task-orchestrator",
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

**Coverage**: Layers 1 and 2 (manual skill invocation)

**Best For**:
- Individual developers
- Moderate compliance needs
- Cost-conscious projects (Sonnet agent)

---

### Lightweight Governance (Minimal)

```json
{
  "agent": "task-orchestrator"
}
```

**Coverage**: Layer 2 only (manual skill invocation)

**Best For**:
- Prototyping
- Learning the framework
- Low-risk projects

---

## Performance Characteristics

| Layer | Latency | Throughput | Cost |
|-------|---------|------------|------|
| **Layer 1: Hook** | <100ms | High (non-blocking) | Zero (bash script) |
| **Layer 2: Skill** | Human-paced | Low (manual) | Zero (documentation) |
| **Layer 3: Agent** | Per-operation | Medium | Moderate (Opus model) |

### Optimization Tips

1. **Hook**: Already optimized, audit log creation is backgrounded
2. **Skill**: Use sparingly for complex decisions only
3. **Agent**: Consider Sonnet model for cost-sensitive projects

---

## Audit Trail Integration

All 3 layers contribute to unified audit trail:

```
.docs/governance/audit/
└── 2025-12-19/
    ├── session-12345.json        # Layer 1: Hook
    ├── skill-decision.json        # Layer 2: Skill
    └── agent-delegation.json      # Layer 3: Agent
```

**Schema**: Consistent across layers (see governance-preflight skill for details)

**Retention**: Indefinite (clean with `cleanup-governance-logs.sh`)

**Metrics**: Generate with `governance-metrics.sh`

---

## Related Documentation

- **Layer 1 Hook**: `.claude/hooks/user-prompt-submit/README.md`
- **Layer 2 Skill**: `.claude/skills/governance/governance-preflight/SKILL.md`
- **Layer 3 Agent**: `.claude/agents/governance/constitutional-governance-agent.md`
- **Constitution**: `.specify/memory/constitution.md` (v1.6.0)
- **Setup Guide**: `.docs/governance/browser-mcp-setup.md`

---

## Troubleshooting

### Hook Not Working
- Check `.claude/settings.json` configuration
- Verify hook script is executable: `chmod +x .claude/hooks/user-prompt-submit/governance-preflight.sh`
- Test manually: `echo '{}' | ./.claude/hooks/user-prompt-submit/governance-preflight.sh`

### Skill Not Accessible
- Verify skill file exists: `ls .claude/skills/governance/governance-preflight/SKILL.md`
- Check skill frontmatter YAML is valid
- Try invoking: `/governance-preflight`

### Agent Not Delegating
- Confirm agent setting in `.claude/settings.json`
- Check agent file exists in `.claude/agents/governance/`
- Verify 4-step protocol in agent instructions

---

*This architecture is part of Feature 003: Governance Browser Enhancement*
