---
name: initialize-project
description: Post-PRD project initialization — customizes constitution, agents, and workflows based on PRD.
model: opus
---

# /initialize-project Command

**AGENT REQUIREMENT**: This command should be executed by the prd-specialist.

**If you are NOT the prd-specialist**, delegate immediately:
```
Use the Task tool to invoke prd-specialist:
- description: "Execute /initialize-project command"
- prompt: "Initialize project from PRD. Arguments: $ARGUMENTS"
```

## Execution Instructions (for prd-specialist)

### Step 1: Locate PRD
Find PRD at `specs/prd/PRD.md` or ask user for location.

### Step 2: Customize Constitution
Read PRD goals and constraints. Update `.specify/memory/constitution.md` principles as needed.

### Step 3: Create Custom Agents
Based on PRD-identified roles, use `/create-agent` for each.

### Step 4: Configure MCP Servers
Based on PRD tech stack, recommend MCP servers via Docker MCP Toolkit.

### Step 4b: Configure Multi-LLM API Keys
The `/research` command requires API keys for multi-LLM tribunal research.
Guide the user to add the following to `.env` (gitignored):

```bash
# Required for /research command — Multi-LLM Tribunal Research
OPENAI_API_KEY=sk-...        # OpenAI GPT-4o for research + tribunal voting
GEMINI_API_KEY=AIza...       # Google Gemini 2.5 Pro for research + tribunal voting
# Perplexity is pre-configured via Docker MCP Toolkit (no key needed here)
```

If the user doesn't have these keys yet, note it as a setup TODO and continue.
The `/research` command will validate keys are present before executing.

### Step 5: Validate Compliance
Run `.specify/scripts/bash/constitutional-check.sh`

### Step 6: Report
Show: customizations applied, agents created, MCP servers recommended, next steps.
