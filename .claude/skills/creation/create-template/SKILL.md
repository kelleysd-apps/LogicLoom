---
# ⚠️ DEPRECATED — MIGRATED TO PLUGIN
# This skill has been migrated to: plugins/sdd-creation/skills/create-template/
# Use the plugin version instead. This file will be removed in v5.0.
# Migration date: 2026-01-15
---

---
name: create-template
version: 3.0.0
category: creation
description: Creates templates for skills, agents, or documents
triggers:
  - create template
  - new template
  - template for
  - generate template
rl_metrics:
  success_rate: 0.0
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
progressive-disclosure:
  layer-1-metadata:
    description: "Creates templates for skills, agents, or documents"
    triggers: [create template, new template]
    primary-agent: system-architect
  layer-2-instructions: true
  layer-3-examples: true
agent-invocations:
  - agent: system-architect
    context-subset:
      - template_type
      - template_name
      - template_purpose
      - variables
    expected-output: template_file
ds-star:
  pre-execution: validation/message-preflight
  post-verification: true
  auto-debug: conditional
---

# Create Template

## Purpose

Creates reusable templates for skills, agents, documents, or other framework
artifacts. Templates use `{{VARIABLE}}` placeholders for customization.

## Constitutional Compliance

- **Principle I (Library-First)**: Templates are reusable libraries
- **Principle VIII (Documentation)**: Templates include documentation

## Instructions

### Prerequisites

1. FR-707 compliance check must pass
2. User must provide:
   - Template type (skill, agent, document)
   - Template name
   - Key variables/placeholders

### Step 1: Determine Template Type

Supported types:
```yaml
skill:
  location: .specify/templates/skill-prototypes/
  extension: .template.md

agent:
  location: .specify/templates/agent-prototypes/
  extension: .template.md

document:
  location: .specify/templates/
  extension: -template.md

config:
  location: .specify/templates/configs/
  extension: .template.conf
```

### Step 2: Gather Variables

Identify placeholders needed:
```yaml
variables:
  - name: "{{VARIABLE_NAME}}"
    description: "What this variable represents"
    required: true
    default: null
```

### Step 3: Generate Template

Create template with:
1. Clear header documentation
2. Variable placeholders
3. Usage instructions
4. Example instantiation

### Step 4: Create File

Write to appropriate location:
```
.specify/templates/
  {type}-prototypes/
    {template_name}.template.md
```

### Step 5: Document in README

Update template directory README with new template.

## Agent Invocation

```yaml
invoke: system-architect
context:
  template_type: "<skill | agent | document | config>"
  template_name: "<name>"
  template_purpose: "<description>"
  variables: ["<var1>", "<var2>"]
expected:
  format: template_file
  validation: well_formed
```

## Template Structure

### Skill Template Example

```markdown
---
name: {{SKILL_NAME}}
version: 3.0.0
category: {{CATEGORY}}
description: {{DESCRIPTION}}
triggers:
  - {{TRIGGER_1}}
rl_metrics:
  success_rate: 0.0
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# {{SKILL_NAME}}

## Purpose

{{PURPOSE}}

## Instructions

{{INSTRUCTIONS}}
```

### Agent Template Example

```markdown
---
name: {{AGENT_NAME}}
version: 2.0.0
purpose: {{PURPOSE}}
department: {{DEPARTMENT}}
skill-portfolio:
  - {{SKILL_1}}
merged-from: []
---

# {{AGENT_NAME}}

## Purpose

{{DETAILED_PURPOSE}}

## Capabilities

{{CAPABILITIES}}
```

## Examples

### Example 1: Create Skill Template

**Request**: "Create a template for integration skills"

**Generated**:
- File: `.specify/templates/skill-prototypes/integration-skill.template.md`
- Variables: `{{SKILL_NAME}}`, `{{SERVICE_NAME}}`, `{{API_ENDPOINT}}`

### Example 2: Create Config Template

**Request**: "Create a template for environment configs"

**Generated**:
- File: `.specify/templates/configs/environment.template.conf`
- Variables: `{{ENV_NAME}}`, `{{DATABASE_URL}}`, `{{API_KEY}}`

## Error Handling

| Scenario | Detection | Resolution |
|----------|-----------|------------|
| Invalid type | Validation | Show valid types |
| Missing variables | Analysis | Suggest common variables |
| Duplicate template | File check | Prompt for overwrite |

## RL Metrics

- **Success Criteria**: Template created and usable
- **Token Efficiency**: Minimize generation overhead



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
  "skill": "create-template",
  "output": "<skill_output>",
  "validation_required": ["format", "compliance", "quality"],
  "threshold": 0.85
}
```

### On Verification Failure
- Log failure reason
- Update rl_metrics with failure
- Report to user with remediation options

## Related Skills

- **creation/create-skill**: Uses skill templates
- **creation/create-agent**: Uses agent templates

---

*Creation skill version: 3.0.0*
