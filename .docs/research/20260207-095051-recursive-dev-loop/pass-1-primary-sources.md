# Pass 1: Primary Sources Research -- Recursive Dev-Loop Plugin

**Research ID**: 20260207-095051-recursive-dev-loop
**Researcher**: Researcher 1 (Primary Sources)
**Date**: 2026-02-07
**Focus**: Official documentation, specifications, APIs, and authoritative sources

---

## Table of Contents

1. [Claude Code CLI Architecture](#1-claude-code-cli-architecture)
2. [OpenAI API / GPT Integration](#2-openai-api--gpt-integration)
3. [Google Gemini API Integration](#3-google-gemini-api-integration)
4. [Multi-Agent Orchestration Patterns](#4-multi-agent-orchestration-patterns)
5. [Docker MCP Toolkit](#5-docker-mcp-toolkit)
6. [Reinforcement Learning from AI Feedback (RLAIF)](#6-reinforcement-learning-from-ai-feedback-rlaif)
7. [Branch Safety in Git](#7-branch-safety-in-git)
8. [Claude Code Hooks System](#8-claude-code-hooks-system)

---

## 1. Claude Code CLI Architecture

### 1.1 Task Tool and Subagent Spawning

**Source**: [Claude Code Official Docs - Create Custom Subagents](https://code.claude.com/docs/en/sub-agents)

The Task tool is Claude Code's primary mechanism for spawning specialized subagents. Key architectural facts:

- **Each subagent runs in its own context window** with a custom system prompt, specific tool access, and independent permissions.
- **Subagents cannot spawn other subagents** -- this is a hard limitation. Nesting is not supported. For nested delegation workflows, skills or chained subagents from the main conversation must be used.
- **Built-in subagent types**: Explore (Haiku, read-only), Plan (inherited model, read-only), General-purpose (inherited model, all tools), Bash, statusline-setup, Claude Code Guide.
- **Custom subagents** are defined as Markdown files with YAML frontmatter in `.claude/agents/` (project) or `~/.claude/agents/` (user) or via plugin `agents/` directories.

**Subagent Configuration Fields**:

| Field | Description |
|-------|-------------|
| `name` | Unique identifier (lowercase + hyphens) |
| `description` | When Claude should delegate to this subagent |
| `tools` | Tool allowlist (inherits all if omitted) |
| `disallowedTools` | Tool denylist |
| `model` | `sonnet`, `opus`, `haiku`, or `inherit` |
| `permissionMode` | `default`, `acceptEdits`, `delegate`, `dontAsk`, `bypassPermissions`, `plan` |
| `maxTurns` | Maximum agentic turns before stop |
| `skills` | Skills to preload into context |
| `mcpServers` | MCP servers available to subagent |
| `hooks` | Lifecycle hooks scoped to subagent |
| `memory` | Persistent memory: `user`, `project`, or `local` |

**CLI-Defined Subagents** (session-only, not saved to disk):
```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer.",
    "prompt": "You are a senior code reviewer.",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  }
}'
```

**Key Limitation for Dev-Loop Plugin**: Subagents cannot spawn subagents. This means the recursive loop must be managed from the main thread or via agent teams, not through nested Task tool calls.

### 1.2 Agent Teams (Opus 4.6 Feature)

**Source**: [Claude Code Official Docs - Agent Teams](https://code.claude.com/docs/en/agent-teams)

Agent Teams are the newest parallel agent coordination mechanism, shipped with Opus 4.6 (Feb 2026). They are **experimental** and require opt-in.

**Architecture**:
- **Team lead**: The main Claude Code session that creates the team, spawns teammates, and coordinates work
- **Teammates**: Separate Claude Code instances, each with their own context window
- **Task list**: Shared list of work items that teammates claim and complete (with file locking to prevent races)
- **Mailbox**: Direct messaging system for inter-agent communication

**Key Properties**:
- Teammates work independently in their own context windows
- Teammates can message each other directly (not just report back to lead)
- Supports `delegate` mode where the lead only coordinates, never implements
- Task dependencies are managed automatically
- `TeammateIdle` hook fires when a teammate is about to go idle -- can force them to keep working
- `TaskCompleted` hook fires when a task is marked complete -- can reject completion

**Display Modes**: In-process (all in one terminal) or split panes (tmux/iTerm2)

**Enabling**:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Limitations**:
- No session resumption with in-process teammates
- One team per session
- No nested teams (teammates cannot spawn their own teams)
- Lead is fixed for the session lifetime
- Permissions set at spawn time

**Relevance to Dev-Loop**: Agent teams provide the ideal coordination mechanism for the multi-LLM council and parallel execution phases. The lead can orchestrate the dev-loop while teammates handle research, implementation, testing, and evaluation.

### 1.3 Headless Mode / Agent SDK

**Source**: [Claude Code Official Docs - Run Programmatically](https://code.claude.com/docs/en/headless)

The Agent SDK enables programmatic Claude Code execution via CLI (`-p` flag), Python, or TypeScript packages.

**CLI Usage**:
```bash
claude -p "Find and fix the bug in auth.py" --allowedTools "Read,Edit,Bash"
```

**Key Features**:
- `--output-format json` for structured output with session metadata
- `--output-format stream-json` for real-time streaming
- `--json-schema` for enforcing output schemas
- `--allowedTools` for auto-approving specific tools
- `--append-system-prompt` for adding instructions
- `--continue` / `--resume` for conversation continuation
- Session IDs for managing multi-turn conversations

**Autonomous Execution**: The `-p` flag combined with `--allowedTools` enables fully autonomous execution with controlled tool access. The `--dangerously-skip-permissions` flag bypasses all permission checks.

**Permission Modes for Automation**:
- `bypassPermissions`: Skip all permission checks (requires explicit opt-in)
- `dontAsk`: Auto-deny permission prompts (only explicitly allowed tools work)
- `acceptEdits`: Auto-accept file edits

**Budget Controls**: `maxTurns` limits the number of agentic turns. Cost controls can be set via the SDK.

### 1.4 Autonomous Execution Limits

Based on the official documentation, the key limits for autonomous execution are:

| Constraint | Limit | Configurable? |
|-----------|-------|---------------|
| Subagent nesting | 1 level (no sub-sub-agents) | No |
| Agent teams per session | 1 | No |
| Auto-compaction | ~95% context window (configurable via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) | Yes |
| Background tasks | Supported via `run_in_background` | Yes |
| Max turns | Configurable via `maxTurns` frontmatter or SDK | Yes |
| Context window | Model-dependent (Opus 4.6: 1M tokens) | No |
| Tool access | Fully configurable via allowlists/denylists | Yes |

---

## 2. OpenAI API / GPT Integration

### 2.1 Chat Completions API

**Source**: [OpenAI API Reference - Chat Completions](https://platform.openai.com/docs/api-reference/chat)

The Chat Completions API is the primary interface for invoking GPT models. As of 2025-2026, it coexists with the newer Responses API.

**Endpoint**: `POST https://api.openai.com/v1/chat/completions`

**Key Parameters**:
- `model`: e.g., `gpt-4o`, `gpt-4o-mini`, `o1`, `o3-mini`
- `messages`: Array of role/content objects
- `tools`: Array of function definitions
- `response_format`: For structured outputs (`json_object` or `json_schema`)
- `temperature`, `max_tokens`, `top_p`: Generation controls

### 2.2 Function Calling

**Source**: [OpenAI Docs - Function Calling](https://platform.openai.com/docs/guides/function-calling)

Function calling enables GPT to generate structured arguments for predefined functions.

**Key Features**:
- **Strict mode** (`strict: true`): Guarantees arguments match the JSON Schema exactly
- **Parallel function calling**: Model can call multiple functions in one turn
- **Tool choice**: `auto`, `required`, `none`, or specific function name
- Models: Available on all models from `gpt-4-0613` onward, including `gpt-4o` and `gpt-4o-mini`

**Strict Mode Requirements**:
- `additionalProperties` must be `false` for all objects
- All fields must be in `required` array
- JSON Schema must be complete and valid

### 2.3 Structured Outputs

**Source**: [OpenAI Docs - Structured Outputs](https://platform.openai.com/docs/guides/structured-outputs)

Structured Outputs guarantees the model produces valid JSON conforming to a provided schema.

**Two Forms**:
1. **Function calling with `strict: true`**: For tool use patterns
2. **Response format with `json_schema`**: For direct structured responses

**SDK Support**: Python (Pydantic) and Node.js (Zod) have native support.

### 2.4 Invoking GPT from Claude Code

**Practical Integration Approaches**:

1. **Via Bash tool**: Execute `curl` or a Python/Node script that calls the OpenAI API
2. **Via MCP Server**: Use an OpenAI MCP server (available via Docker MCP Toolkit or community servers)
3. **Via Docker MCP Toolkit**: `mcp-add` to add an OpenAI MCP server at runtime

**Example Bash invocation from within Claude Code**:
```bash
curl -s https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Evaluate this code..."}],
    "response_format": {"type": "json_schema", "json_schema": {...}}
  }'
```

### 2.5 OpenAI MCP Adoption

**Source**: [MCP - Wikipedia](https://en.wikipedia.org/wiki/Model_Context_Protocol)

OpenAI officially adopted MCP in March 2025, integrating it across the Agents SDK, Responses API, and ChatGPT desktop. This means OpenAI tools can be exposed as MCP servers, enabling direct integration with Claude Code's MCP infrastructure.

**Available MCP Servers**:
- [openai-mcp](https://github.com/arthurcolle/openai-mcp): OpenAI Code Assistant MCP Server
- [Composio OpenAI MCP](https://composio.dev/toolkits/openai/framework/claude-code): Composio integration

### 2.6 Responses API (March 2025)

OpenAI released the Responses API in March 2025 as the successor to the Chat Completions API for agent-oriented workflows. It includes:
- Built-in tools: Web Search, File Search, Computer Use
- Agents SDK with Tracing
- Native streaming support

**Relevance**: For the council voting pattern, the Responses API with structured outputs and function calling provides a clean interface for GPT to vote on proposals and return structured evaluations.

---

## 3. Google Gemini API Integration

### 3.1 Function Calling

**Source**: [Gemini API Docs - Function Calling](https://ai.google.dev/gemini-api/docs/function-calling)

Gemini supports function calling with automatic tool execution via SDKs.

**Key Features**:
- **Automatic function calling**: Python and JavaScript SDKs can auto-execute functions
- **Parallel function calling**: Multiple functions in one response
- **Streaming function call arguments**: Gemini 3 Pro+ supports `streamFunctionCallArguments: true`
- **Compositional function calling**: Chain function results

**Supported Models**: Gemini 2.0 Flash, Gemini 2.5 Pro/Flash, Gemini 3 Pro/Flash

### 3.2 Structured Outputs

**Source**: [Gemini API Docs - Structured Output](https://ai.google.dev/gemini-api/docs/structured-output)

Gemini supports structured output via `responseSchema` with JSON Schema support.

**Key Features**:
- Full JSON Schema support (including `anyOf`, `$ref`)
- Compatible with Pydantic (Python) and Zod (JavaScript/TypeScript)
- Combinable with function calling (Gemini 3+)
- Combinable with built-in tools (Grounding, URL Context, Code Execution)
- Implicit property ordering preserved

### 3.3 MCP Integration

**Source**: [Gemini API Docs - Interactions API](https://ai.google.dev/gemini-api/docs/interactions)

Gemini SDKs have **built-in MCP support**:
- Automatic tool calling for MCP tools
- Python and JavaScript SDK can auto-execute MCP tools and send responses back
- Continues the loop until no more tool calls are made

**Interactions API**: Designed for building agents, supports function calling, built-in tools, structured outputs, and MCP.

### 3.4 Invoking Gemini from Claude Code

**Practical Integration Approaches**:

1. **Via Bash tool**: Execute `curl` or Python/Node script calling the Gemini API
2. **Via MCP Server**: Use a Gemini MCP server
3. **Via Docker MCP Toolkit**: Docker supports Gemini as a client and has Gemini-compatible MCP servers

**Gemini API Endpoint**: `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent`

**Key Consideration**: Gemini's multi-modal capabilities (vision, audio, video) could be leveraged for evaluating UI screenshots or analyzing test output visually.

### 3.5 Model Versions (Current as of 2026)

| Model | Context Window | Best For |
|-------|---------------|----------|
| Gemini 3 Pro | 1M tokens | Complex reasoning, council evaluation |
| Gemini 3 Flash | 1M tokens | Fast evaluation, lower cost |
| Gemini 2.5 Pro | 1M tokens | Fallback option |

---

## 4. Multi-Agent Orchestration Patterns

### 4.1 Framework Comparison

**Source**: [LangGraph vs CrewAI vs AutoGen Guide 2026](https://dev.to/pockit_tools/langgraph-vs-crewai-vs-autogen-the-complete-multi-agent-ai-orchestration-guide-for-2026-2d63)

| Framework | Architecture | Key Pattern | Relevance |
|-----------|-------------|-------------|-----------|
| **LangGraph** | Graph-based workflows | Directed graphs with cycles, conditional branching | Loop/recursive patterns |
| **CrewAI** | Role-based teams | Agents as employees with responsibilities | Team composition |
| **AutoGen** (now Microsoft Agent Framework) | Conversational agents | Async message passing | Council debate |
| **Google Agent Builder** | Vertex AI agents | Managed agent deployment | Enterprise patterns |

### 4.2 Council / Voting Patterns

**Source**: [Patterns for Democratic Multi-Agent AI: Debate-Based Consensus](https://medium.com/@edoardo.schepis/patterns-for-democratic-multi-agent-ai-debate-based-consensus-part-2-implementation-2348bf28f6a6)

Debate-based consensus is a documented multi-agent pattern where:
1. Multiple agents independently evaluate a proposal
2. Agents share their evaluations
3. Agents can challenge each other's reasoning
4. Consensus is reached through structured voting or convergence detection

**Implementation Pattern (from LangGraph)**:
```
Round 1: Each agent independently evaluates
Round 2: Agents see each other's evaluations, can revise
Round N: Check for convergence (identical/compatible outputs)
Terminal: Vote or explicit concession
```

**Convergence Detection**: After each round, check if agents' outputs are effectively identical or if one explicitly concedes. Special tokens or phrases can indicate finalization intent.

### 4.3 Recursive Self-Improvement Loops

**Source**: [LangGraph Multi-Agent Orchestration Guide 2025](https://latenode.com/blog/ai-frameworks-technical-infrastructure/langgraph-multi-agent-orchestration/)

LangGraph supports recursive loops through:
- **Graph cycles**: Nodes can loop back to earlier nodes
- **Termination criteria**: Explicit conditions to exit loops
- **Quality-driven iteration**: Routing based on validation scores
- **State persistence**: Graph state maintained across iterations

**Pattern for Recursive Dev-Loop**:
```
[Research] -> [Council Vote] -> [Scope Decision]
    |                                    |
    v                                    v
[Execute] -> [Test] -> [Grade] -> [Evaluate]
    ^                                    |
    |                                    v
    +------ [Debug/Improve] <--- [Grade < 99%]
```

### 4.4 Microsoft Agent Framework (AutoGen + Semantic Kernel)

Microsoft merged AutoGen with Semantic Kernel into a unified framework with GA set for Q1 2026. Key patterns:
- Multi-language support (Python, .NET, Java)
- Deep Azure integration
- Flexible agent routing
- Asynchronous communication

### 4.5 A2A (Agent-to-Agent) Protocol

LangGraph 2026 includes first-class support for Agent-to-Agent (A2A) and MCP standards, enabling cross-framework agent communication. This is relevant for the multi-LLM council where Claude, GPT, and Gemini agents need to communicate.

---

## 5. Docker MCP Toolkit

### 5.1 Overview

**Source**: [Docker MCP Catalog and Toolkit](https://docs.docker.com/ai/mcp-catalog-and-toolkit/)

The Docker MCP Toolkit provides:
- **MCP Catalog**: 310+ containerized MCP servers searchable and installable
- **MCP Gateway**: Centralized routing, authentication, and translation between clients and tools
- **Container Isolation**: Each server runs in its own container (1 CPU, 2GB RAM default)
- **Security**: microVM-based isolation for coding agents

### 5.2 Runtime Server Addition

**Source**: [Docker MCP Toolkit Docs](https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/)

Servers can be added at runtime via:
- **Docker Desktop GUI**: MCP Toolkit > Catalog tab > search and add
- **`mcp-add` tool**: Programmatic addition from within Claude Code
- **`mcp-find` tool**: Search the 310+ server catalog
- **`mcp-config-set` tool**: Configure credentials

### 5.3 Adding OpenAI and Gemini MCP Servers

**Approach for the Dev-Loop Plugin**:

1. **At plugin initialization**: Use `mcp-find` to search for OpenAI/Gemini MCP servers
2. **Dynamic addition**: Use `mcp-add` to add them to the current session
3. **Configuration**: Use `mcp-config-set` to configure API keys from environment variables

**Available Servers** (via Docker MCP Catalog):
- OpenAI-compatible completion servers
- Google AI / Gemini servers
- Generic LLM gateway servers

### 5.4 Client Compatibility

Docker MCP Toolkit supports these clients:
- Claude Code, Claude Desktop
- Cursor, VS Code, Continue.dev
- Gemini CLI
- LM Studio, Codex, Kiro

### 5.5 Security Considerations

- Store API keys in `.env` (never commit)
- Use `env:VAR_NAME` syntax in MCP configuration
- Container isolation provides sandboxing
- MCP Gateway handles authentication routing

**Relevance to Dev-Loop**: The Docker MCP Toolkit is the cleanest path to integrating GPT and Gemini as council members. The `mcp-add` tool can dynamically provision these servers, and the MCP Gateway handles routing.

---

## 6. Reinforcement Learning from AI Feedback (RLAIF)

### 6.1 Constitutional AI (Anthropic)

**Source**: [Anthropic - Constitutional AI: Harmlessness from AI Feedback](https://www.anthropic.com/research/constitutional-ai-harmlessness-from-ai-feedback) | [ArXiv: 2212.08073](https://arxiv.org/abs/2212.08073)

Constitutional AI is Anthropic's method for training AI through self-improvement using a list of principles (a "constitution") rather than human feedback labels.

**Two-Phase Process**:

1. **Supervised Learning Phase (Self-Critique + Revision)**:
   - Sample initial responses from the model
   - Model generates self-critiques based on constitutional principles
   - Model generates revised responses addressing critiques
   - Fine-tune on the revised responses

2. **Reinforcement Learning Phase (RLAIF)**:
   - Sample pairs of responses from the fine-tuned model
   - AI evaluator compares responses for constitutional compliance
   - Train a preference model from AI preferences
   - Use preference model as reward signal for RL (PPO)

**Key Advantages over RLHF**:
- Scalable: No human labelers needed
- Consistent: Less subjective than human evaluation
- Transparent: Principles are explicit and auditable
- Performs equally well or better on helpfulness and harmlessness

### 6.2 RLAIF Implementation Pattern

**Source**: [AssemblyAI - How RLAIF Works](https://www.assemblyai.com/blog/how-reinforcement-learning-from-ai-feedback-works) | [RLHF Book - Constitutional AI](https://rlhfbook.com/c/13-cai)

The RLAIF pattern applicable to the dev-loop:

```
Code Output → Multi-LLM Evaluation → Preference Signal → Weight Update
     |                |                      |                  |
     v                v                      v                  v
  Generated    Claude + GPT + Gemini   Aggregated Score    RL Metrics
   Code          each score 0-100       (weighted vote)    Updated
```

**For the Dev-Loop Plugin, the adapted RLAIF flow**:
1. Agent produces code/output
2. Three LLMs evaluate against quality principles (the "constitution")
3. Each LLM provides structured critique and numerical score
4. Scores are aggregated (majority vote or weighted average)
5. If below threshold: critiques feed back into revision cycle
6. If above threshold: output accepted, RL metrics updated

### 6.3 Collective Constitutional AI

Anthropic ran an experiment with 1,000 Americans who contributed 1,127 statements and 38,252 votes to create a "public constitution." This demonstrates that constitutional principles can be:
- Collaboratively defined
- Voted on democratically
- Applied at scale

**Relevance**: The multi-LLM council is essentially a small-scale version of this -- multiple AI "voters" evaluating against shared principles.

### 6.4 Existing RL Infrastructure in SDD Framework

The SDD Framework already has RL feedback infrastructure:

**Scripts** (at `.specify/scripts/bash/rl/`):
- `collect-feedback.sh` - Record skill execution results
- `sync-metrics.sh` - Update skill-index.json from metrics
- `dashboard.sh` - View RL metrics
- `select-skill.sh` - RL-weighted skill selection
- `update-skill-weight.sh` - Update individual skill weights
- `credit-assignment.sh` - Multi-agent credit assignment
- `grpo-optimizer.sh` - Group relative policy optimization

**Algorithm**: Exponential Moving Average (EMA) with learning rate 0.1:
```
success_rate = 0.9 * old_rate + 0.1 * (1 if success else 0)
selection_weight = clamp(success_rate, 0.1, 1.0)
```

**Configuration** (at `.specify/config/refinement.conf`):
- `MAX_REFINEMENT_ROUNDS=20`
- `EARLY_STOP_THRESHOLD=0.95`
- `MAX_DEBUG_ITERATIONS=5`
- `CIRCUIT_BREAKER_THRESHOLD=0.50`

---

## 7. Branch Safety in Git

### 7.1 Git Hook Types for Branch Protection

**Source**: [Git - githooks Documentation](https://git-scm.com/docs/githooks)

Relevant git hooks for branch locking:

| Hook | Trigger | Can Block? | Use Case |
|------|---------|-----------|----------|
| `pre-commit` | Before commit | Yes | Block commits to protected branches |
| `pre-checkout` | Before branch switch (Git 2.44+) | Yes | Prevent branch switching |
| `post-checkout` | After branch switch | No (advisory) | Detect unauthorized switches |
| `pre-push` | Before push | Yes | Block pushes to wrong branches |
| `pre-rebase` | Before rebase | Yes | Block rebasing |

**Note**: `pre-checkout` was added in Git 2.44 (released Feb 2024) and can actually prevent branch switches.

### 7.2 Pre-Commit Framework

**Source**: [pre-commit.com](https://pre-commit.com/) | [pre-commit-hooks](https://github.com/pre-commit/pre-commit-hooks)

The `no-commit-to-branch` hook prevents commits to specific branches:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    hooks:
      - id: no-commit-to-branch
        args: ['--branch', 'main', '--branch', 'staging']
```

### 7.3 "Locked to Current Branch" Implementation

For the dev-loop plugin's requirement to lock execution to the current branch:

**Approach 1: Claude Code PreToolUse Hook** (Recommended)
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/pre-tool-use/lock-branch.sh"
          }
        ]
      }
    ]
  }
}
```

The `lock-branch.sh` script would:
1. Read the Bash command from stdin JSON
2. Check if command contains `git checkout`, `git switch`, `git branch -d`, `git worktree`
3. If detected, return `permissionDecision: "deny"` with reason

**Approach 2: Git Hook (pre-checkout)**
```bash
#!/bin/bash
# .git/hooks/pre-checkout
CURRENT_BRANCH=$(git branch --show-current)
if [ "$LOCKED_BRANCH" = "$CURRENT_BRANCH" ]; then
  echo "Branch locked by dev-loop. Cannot switch." >&2
  exit 1
fi
```

**Approach 3: Combined** -- Use both Claude Code hooks (to prevent the agent from attempting) and git hooks (as a safety net).

### 7.4 Branch Operations to Block

For the dev-loop plugin, these git commands should be blocked:
- `git checkout <branch>` / `git switch <branch>` (branch switching)
- `git checkout -b` / `git switch -c` (branch creation)
- `git branch -d` / `git branch -D` (branch deletion)
- `git merge` (merging other branches)
- `git rebase` (rebasing)
- `git push` (pushing -- require explicit user approval)
- `git stash` (stashing could lose context)

**Allowed Operations**:
- `git add` (staging files)
- `git status` / `git diff` (read-only)
- `git log` (read-only)
- `git commit` (committing to current branch -- part of autonomous flow)

---

## 8. Claude Code Hooks System

### 8.1 Complete Hook Event Reference

**Source**: [Claude Code Official Docs - Hooks Reference](https://code.claude.com/docs/en/hooks)

The hooks system is the primary mechanism for automating approval workflows and enforcing constraints.

**Full Event Lifecycle**:

```
SessionStart
    |
    v
UserPromptSubmit
    |
    v
[Agentic Loop:]
    PreToolUse -> [Tool Execution] -> PostToolUse / PostToolUseFailure
    PermissionRequest (when permission dialog would appear)
    SubagentStart (when subagent spawned)
    SubagentStop (when subagent finishes)
    Notification (when notification sent)
    TeammateIdle (when agent team member goes idle)
    TaskCompleted (when task marked complete)
    PreCompact (before context compaction)
    |
    v
Stop
    |
    v
SessionEnd
```

### 8.2 Auto-Approval Mechanisms

**For bypassing user approval in the dev-loop**, there are three hook-based approaches:

#### A. PreToolUse with `permissionDecision: "allow"`
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Auto-approved by dev-loop plugin"
  }
}
```
This bypasses the permission system entirely for the matched tool.

#### B. PermissionRequest with `behavior: "allow"`
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "updatedPermissions": [
        {"type": "toolAlwaysAllow", "tool": "Bash"}
      ]
    }
  }
}
```
This auto-approves permission dialogs and can apply persistent "always allow" rules.

#### C. Permission Mode: `bypassPermissions`
Set `permissionMode: "bypassPermissions"` on the subagent to skip all permission checks.

### 8.3 Stop Hook for Recursive Loop

The `Stop` hook is critical for implementing the recursive loop:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "Check if the dev-loop quality grade meets 99% threshold. Read the grade report at .docs/dev-loop/current-grade.json. If grade < 99%, respond with {\"ok\": false, \"reason\": \"Grade is X%. Debug and improve.\"}. If >= 99%, respond {\"ok\": true}.",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

When `decision: "block"` is returned, Claude continues working with the provided reason. This creates the recursive loop naturally.

**Critical Safety**: The `stop_hook_active` field in Stop hook input is `true` when Claude is already continuing due to a Stop hook. This must be checked to prevent infinite loops:

```json
{
  "stop_hook_active": true  // Already in a continuation cycle
}
```

### 8.4 Hook Types and Their Roles in the Dev-Loop

| Hook Event | Role in Dev-Loop |
|-----------|-----------------|
| `SessionStart` | Initialize dev-loop state, load config, set environment |
| `UserPromptSubmit` | Detect `/dev-loop` command, inject context |
| `PreToolUse` | Auto-approve safe operations, block branch switching |
| `PermissionRequest` | Auto-approve expected permission dialogs |
| `PostToolUse` | Track progress, update metrics after tool execution |
| `SubagentStart` | Inject council context into subagents |
| `SubagentStop` | Collect subagent results, update progress |
| `Stop` | Check quality grade, trigger recursive continuation |
| `TeammateIdle` | Enforce quality gates before teammate stops |
| `TaskCompleted` | Validate task completion criteria |
| `PreCompact` | Preserve critical dev-loop state before compaction |
| `SessionEnd` | Generate final report, cleanup |

### 8.5 Prompt-Based and Agent-Based Hooks

Beyond command hooks, Claude Code supports:

**Prompt hooks** (`type: "prompt"`): Single-turn LLM evaluation
- Fast (default timeout: 30s)
- Returns `{ "ok": true/false, "reason": "..." }`
- Good for simple yes/no decisions

**Agent hooks** (`type: "agent"`): Multi-turn with tool access
- Can read files, search code, run tests
- Up to 50 turns of investigation
- Default timeout: 60s
- Good for complex verification (e.g., "are all tests passing?")

### 8.6 Async Hooks

Hooks can run asynchronously with `"async": true`:
- Run in background without blocking Claude
- Results delivered on next conversation turn
- Cannot return blocking decisions
- Useful for: test suites, external API calls, metrics collection

### 8.7 Hook Configuration Locations

| Location | Scope | Shareable |
|----------|-------|-----------|
| `~/.claude/settings.json` | All projects | No |
| `.claude/settings.json` | Single project | Yes (committable) |
| `.claude/settings.local.json` | Single project | No (gitignored) |
| Plugin `hooks/hooks.json` | When plugin enabled | Yes |
| Skill/agent frontmatter | While component active | Yes |
| Managed policy settings | Organization-wide | Yes |

### 8.8 Input Modification Capabilities

PreToolUse and PermissionRequest hooks can modify tool inputs before execution via `updatedInput`:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": {
      "command": "npm test -- --coverage"
    }
  }
}
```

This enables the dev-loop to intercept and enhance commands (e.g., always add `--coverage` to test commands).

### 8.9 Context Injection

Multiple hooks can inject context via `additionalContext`:
- `SessionStart`: Set up dev-loop context at session start
- `UserPromptSubmit`: Add context based on user input
- `PreToolUse`: Add context before tool execution
- `SubagentStart`: Inject council instructions into subagents
- `PostToolUse`: Add context after tool execution
- `PostToolUseFailure`: Add recovery guidance after failures

---

## Key Architectural Decisions Informed by Research

### Decision 1: Orchestration Mechanism
**Recommendation**: Use **Agent Teams** as the primary orchestration mechanism for the multi-LLM council and parallel execution. Fall back to **Task tool subagents** for individual delegated tasks within the team.

**Rationale**: Agent teams provide inter-agent communication, shared task lists, and the delegate mode needed for a team lead that coordinates without implementing.

### Decision 2: Multi-LLM Council Implementation
**Recommendation**: Invoke GPT and Gemini via **Bash tool** calling the respective APIs with structured output schemas, rather than through MCP servers.

**Rationale**: MCP servers add complexity and potential failure points. Direct API calls via Bash are simpler, more reliable, and give full control over request/response schemas. MCP can be added as an enhancement later.

**Alternative**: Use Docker MCP Toolkit's `mcp-add` for dynamic server provisioning if a more integrated approach is needed.

### Decision 3: Recursive Loop Mechanism
**Recommendation**: Use the **Stop hook** (agent-based) to check quality grades and force continuation when below threshold.

**Rationale**: The Stop hook naturally implements "keep going until done" with built-in safety via `stop_hook_active` to prevent infinite loops.

### Decision 4: Branch Locking
**Recommendation**: Use a **PreToolUse hook** on the Bash tool to intercept and deny git branch-switching commands.

**Rationale**: This catches the operation before it executes, provides a clear denial reason, and works within Claude Code's existing permission model.

### Decision 5: Approval Bypass
**Recommendation**: Use **`permissionMode: "bypassPermissions"`** for the dev-loop agent combined with **PreToolUse hooks** for selective blocking of dangerous operations (branch switching, API key exposure).

**Rationale**: This gives maximum autonomy while maintaining safety rails through hooks.

### Decision 6: RLAIF Implementation
**Recommendation**: Adapt the existing SDD Framework RL infrastructure (EMA algorithm, `collect-feedback.sh`, `sync-metrics.sh`) and extend it with multi-LLM evaluation.

**Rationale**: The framework already has RL feedback loops. The dev-loop adds a multi-evaluator dimension but the underlying metric collection and weight update mechanics are the same.

---

## Source References

### Official Documentation
1. [Claude Code Docs - Create Custom Subagents](https://code.claude.com/docs/en/sub-agents)
2. [Claude Code Docs - Hooks Reference](https://code.claude.com/docs/en/hooks)
3. [Claude Code Docs - Agent Teams](https://code.claude.com/docs/en/agent-teams)
4. [Claude Code Docs - Run Programmatically](https://code.claude.com/docs/en/headless)
5. [Anthropic - Enabling Claude Code to Work More Autonomously](https://www.anthropic.com/news/enabling-claude-code-to-work-more-autonomously)
6. [OpenAI API Reference - Chat Completions](https://platform.openai.com/docs/api-reference/chat)
7. [OpenAI Docs - Structured Outputs](https://platform.openai.com/docs/guides/structured-outputs)
8. [OpenAI Docs - Function Calling](https://platform.openai.com/docs/guides/function-calling)
9. [Gemini API Docs - Function Calling](https://ai.google.dev/gemini-api/docs/function-calling)
10. [Gemini API Docs - Structured Output](https://ai.google.dev/gemini-api/docs/structured-output)
11. [Gemini API Docs - Interactions API](https://ai.google.dev/gemini-api/docs/interactions)
12. [Docker MCP Catalog and Toolkit](https://docs.docker.com/ai/mcp-catalog-and-toolkit/)
13. [Docker MCP Toolkit Docs](https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/)
14. [Git - githooks Documentation](https://git-scm.com/docs/githooks)
15. [pre-commit.com](https://pre-commit.com/)

### Research Papers and Articles
16. [Anthropic - Constitutional AI: Harmlessness from AI Feedback](https://www.anthropic.com/research/constitutional-ai-harmlessness-from-ai-feedback)
17. [ArXiv: 2212.08073 - Constitutional AI](https://arxiv.org/abs/2212.08073)
18. [RLHF Book - Constitutional AI & AI Feedback](https://rlhfbook.com/c/13-cai)
19. [AssemblyAI - How RLAIF Works](https://www.assemblyai.com/blog/how-reinforcement-learning-from-ai-feedback-works)
20. [Patterns for Democratic Multi-Agent AI: Debate-Based Consensus](https://medium.com/@edoardo.schepis/patterns-for-democratic-multi-agent-ai-debate-based-consensus-part-2-implementation-2348bf28f6a6)

### Framework Guides
21. [LangGraph vs CrewAI vs AutoGen Guide 2026](https://dev.to/pockit_tools/langgraph-vs-crewai-vs-autogen-the-complete-multi-agent-ai-orchestration-guide-for-2026-2d63)
22. [LangGraph Multi-Agent Orchestration Guide 2025](https://latenode.com/blog/ai-frameworks-technical-infrastructure/langgraph-multi-agent-orchestration/)
23. [DataCamp - CrewAI vs LangGraph vs AutoGen](https://www.datacamp.com/tutorial/crewai-vs-langgraph-vs-autogen)
24. [Top AI Agent Frameworks 2026](https://o-mega.ai/articles/langgraph-vs-crewai-vs-autogen-top-10-agent-frameworks-2026)

### Community and News
25. [MCP - Wikipedia](https://en.wikipedia.org/wiki/Model_Context_Protocol)
26. [OpenAI MCP Server (GitHub)](https://github.com/arthurcolle/openai-mcp)
27. [Composio OpenAI MCP for Claude Code](https://composio.dev/toolkits/openai/framework/claude-code)
28. [Building Agents with Claude Code's SDK](https://blog.promptlayer.com/building-agents-with-claude-codes-sdk/)
29. [Claude Code Swarm Orchestration Skill (GitHub Gist)](https://gist.github.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2ea)
30. [Anthropic releases Opus 4.6 with Agent Teams (TechCrunch)](https://techcrunch.com/2026/02/05/anthropic-releases-opus-4-6-with-new-agent-teams/)

### SDD Framework Internal References
31. `.specify/memory/constitution.md` -- Constitution v3.0.0 (16 Principles)
32. `.specify/config/refinement.conf` -- Refinement engine configuration
33. `.specify/scripts/bash/rl/` -- RL feedback infrastructure (8 scripts)
34. `.claude/hooks/user-prompt-submit/governance-preflight.sh` -- Existing hook implementation
35. `plugins/sdd-orchestrator/` -- Existing orchestration plugin (swarm, teams, research)
36. `plugins/sdd-governance/` -- Governance enforcement plugin

---

## Version Information Summary

| Technology | Current Version | Release Date | Key Capability |
|-----------|----------------|--------------|----------------|
| Claude Opus | 4.6 | 2026-02-05 | 1M context, Agent Teams |
| Claude Code | ~2.1.x | Ongoing | Hooks, subagents, Agent SDK |
| OpenAI GPT-4o | Latest | 2024+ | Structured outputs, function calling |
| OpenAI Responses API | v1 | 2025-03 | Agent-oriented API |
| Gemini 3 Pro | Latest | 2025+ | MCP native, structured outputs |
| Docker MCP Toolkit | GA | 2025 | 310+ servers, container isolation |
| MCP Protocol | v1.0+ | 2024-11 | Industry standard (Linux Foundation) |
| LangGraph | 2026 | 2026 | A2A support, graph cycles |
| SDD Framework | v4.1.0 | 2026-02 | 15 plugins, 16 principles |

---

*Research completed: 2026-02-07*
*Confidence: HIGH for Claude Code internals, OpenAI/Gemini APIs, hooks system*
*Confidence: MEDIUM for multi-agent voting patterns (limited official implementations)*
*Confidence: HIGH for RLAIF/Constitutional AI (well-documented by Anthropic)*
