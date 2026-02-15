---
name: planning-agent
description: |
  Step-by-step procedural guidance for executing the /plan command workflow. Covers Phase 0 (Research), Phase 1 (Design), and Phase 2 (Validation) for implementation planning with constitutional compliance.

  This skill provides step-by-step procedural guidance for tasks handled by
  the planning-agent agent. Use when you need to understand the workflow or
  execute tasks that planning-agent would typically handle.

  Triggered by: [TODO: Add trigger phrases]
allowed-tools: Read, Write, Bash, Grep, Glob, TaskCreate, TaskUpdate
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_feedback: null
---

# planning-agent Skill

## When to Use

Activate this skill when:
- [TODO: Add specific trigger conditions]
- User requests work that planning-agent handles
- [TODO: Add workflow phase or command]
- [TODO: Add domain-specific scenarios]

**Trigger Keywords**: [TODO: Add comma-separated keywords]

**Prerequisites**: [TODO: Add any required preconditions]

## Procedure

### Step 1: [TODO: Initialization/Setup]

**Action**: [TODO: Describe what to do in this step]

```bash
# TODO: Add commands if applicable
# Example: script.sh --flag value
```

**Expected Outcome**: [TODO: What should result from this step]

### Step 2: [TODO: Main Processing]

**Action**: [TODO: Describe core processing steps]

**Details**:
- [TODO: Important sub-step or consideration]
- [TODO: Another important detail]
- [TODO: Edge case handling]

**Expected Outcome**: [TODO: What should be produced]

### Step 3: [TODO: Validation/Completion]

**Action**: [TODO: Describe validation or finalization steps]

**Checklist**:
- [ ] [TODO: Validation item 1]
- [ ] [TODO: Validation item 2]
- [ ] [TODO: Validation item 3]

**Expected Outcome**: [TODO: Final deliverable or state]

## Constitutional Compliance

### Principle I: Library-First Architecture
[TODO: How this skill ensures features start as standalone libraries]

### Principle II: Test-First Development
[TODO: How this skill enforces writing tests before implementation]

### Principle VI: Git Operation Approval
- **CRITICAL**: NO autonomous git operations
- Request user approval for ANY git commands
- Document git operations in procedure steps

### Principle VIII: Documentation Synchronization
[TODO: How this skill maintains documentation]

### Principle X: Agent Delegation Protocol
When to delegate to planning-agent:
- [TODO: Complex scenarios requiring agent autonomy]
- [TODO: Multi-step orchestration]
- [TODO: Specialized domain work]

## Examples

### Example 1: [TODO: Common Scenario Name]

**User Request**: "[TODO: What the user asked for]"

**Skill Execution**:
1. [TODO: First action taken]
2. [TODO: Second action taken]
3. [TODO: Final action taken]

**Generated Output**:
```
[TODO: Show what files/artifacts were created]
```

**Validation**: [TODO: How to verify success]

### Example 2: [TODO: Alternative Scenario]

**User Request**: "[TODO: Different user request]"

**Skill Execution**:
1. [TODO: Steps for this scenario]

**Expected Result**: [TODO: Outcome]

## Agent Collaboration

### planning-agent
**When to delegate**: [TODO: Situations requiring this agent's autonomy]

**What they handle**: [TODO: Specific capabilities of this agent]

**Handoff format**: [TODO: How to invoke the agent]

#

## RL Feedback Loop

After skill execution completes, the RL feedback mechanism updates metrics:

### Success Criteria
- Task completed without errors
- Output validated by verifier (if applicable)
- User satisfaction (implicit from follow-up)

### Feedback Collection
```
ON SKILL COMPLETION:
  1. Capture execution result (success/failure)
  2. Record token usage
  3. Calculate execution duration
  4. Update rl_metrics via EMA:
     - success_rate = 0.9 * old_rate + 0.1 * (1 if success else 0)
     - selection_weight = adjusted based on success_rate
  5. Log to .docs/rl-metrics/skill-performance.json
```

### Metrics Update Trigger
```python
# Pseudo-code for RL update
def update_rl_metrics(skill_name: str, success: bool, tokens: int):
    metrics = load_skill_metrics(skill_name)
    metrics['invocation_count'] += 1
    metrics['success_rate'] = 0.9 * metrics['success_rate'] + 0.1 * (1 if success else 0)
    metrics['avg_tokens'] = 0.9 * metrics['avg_tokens'] + 0.1 * tokens
    metrics['selection_weight'] = max(0.1, min(1.0, metrics['success_rate']))
    metrics['last_feedback'] = datetime.utcnow().isoformat()
    save_skill_metrics(skill_name, metrics)
```


## Verifier Integration

### Pre-Completion Validation
Before marking this skill as complete, invoke verifier validation:

```
VERIFIER_CHECK:
  1. Output format validation
  2. Constitutional compliance check
  3. Quality threshold verification
  4. Domain-specific validation rules
```

### Verifier Handoff
```json
{
  "skill": "planning-agent",
  "output": "<skill_output>",
  "validation_required": ["format", "compliance", "quality"],
  "threshold": 0.85
}
```

### On Verification Failure
- Log failure reason
- Update rl_metrics with failure
- Report to user with remediation options

## Related Agents
[TODO: List other agents this skill might reference]
- **agent-name**: [TODO: When and why to use this agent]

## Validation

Verify the skill executed correctly:

- [ ] [TODO: Primary deliverable created]
- [ ] [TODO: Quality check passed]
- [ ] [TODO: Constitutional compliance verified]
- [ ] [TODO: Documentation updated]
- [ ] [TODO: User notified of next steps]

## Troubleshooting

### Issue: [TODO: Common Problem 1]

**Cause**: [TODO: Why this problem occurs]

**Solution**: [TODO: Step-by-step resolution]

**Prevention**: [TODO: How to avoid this in the future]

### Issue: [TODO: Common Problem 2]

**Cause**: [TODO: Root cause]

**Solution**: [TODO: Fix procedure]

## Notes

**Important Considerations**:
- [TODO: Critical information about this procedure]
- [TODO: Performance implications]
- [TODO: Known limitations]

**Best Practices**:
- [TODO: Recommended approach]
- [TODO: Tips for efficiency]

**Related Skills**:
- **skill-name**: [TODO: How this skill relates]
- **skill-name**: [TODO: Workflow sequence]

## Supporting Files

This skill directory can include:

### scripts/ (optional)
Executable utilities to automate parts of the procedure

### templates/ (optional)
Reusable content templates for generated artifacts

### reference.md (optional)
Detailed technical documentation and API references

### examples.md (optional)
Extended usage examples and edge cases

---

**Skill Version**: 1.0.0
**Created**: 2025-11-08
**Last Updated**: 2025-11-08
**Department**: product
**Associated Agent**: planning-agent
