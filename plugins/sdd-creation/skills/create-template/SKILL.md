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
## Related Skills

- **creation/create-skill**: Uses skill templates
- **creation/create-agent**: Uses agent templates

---

*Creation skill version: 3.0.0*
