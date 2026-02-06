# Research: Plugin-First Architecture (v4.0)

**Branch**: `004-plugin-first-architecture` | **Date**: 2026-02-06
**Method**: Multi-pass research (Plan document analysis + Official plugin marketplace deep-dive)

---

## Research Question 1: Can Claude Code plugins fully replace the monolithic framework?

### Decision: YES — Full replacement is feasible

### Rationale
Deep analysis of 41 official marketplace plugins (28 internal, 13 external) confirms that every component type in the current framework maps 1:1 to the plugin format:

| Current Component | Plugin Equivalent | Auto-Discovered |
|-------------------|-------------------|-----------------|
| Skills (SKILL.md) | `skills/*/SKILL.md` | ✅ Yes |
| Agents (.md) | `agents/*.md` | ✅ Yes |
| Hooks (settings.json) | `hooks/hooks.json` | ✅ Yes |
| Slash commands | `commands/*.md` | ✅ Yes |
| MCP servers | `.mcp.json` | ✅ Yes |
| Bash scripts | `scripts/` | Manual (bundled) |

### Alternatives Considered
1. **Git submodules per domain** — Rejected: Too fragile, no hot-swap, poor UX
2. **npm packages** — Rejected: Wrong ecosystem, no Claude Code integration
3. **Monorepo with build system** — Rejected: Adds complexity without plugin benefits

### Key Finding
`skill-index.json` (1,332 lines) can be entirely eliminated. Its three functions (skill registry, command routing, RL metrics) are all handled natively by plugin auto-discovery, command files, and per-plugin plugin.json.

---

## Research Question 2: How do multi-agent swarms coordinate?

### Decision: tmux + state files + Stop hooks

### Rationale
The official `multi-agent-swarm` pattern (from plugin-dev references) provides a proven coordination model:

1. **Coordinator agent** spawns worker agents via `claude --print` in tmux panes
2. Each worker gets a `.claude/multi-agent-swarm.local.md` state file with task, dependencies, budget
3. **Stop hooks** notify coordinator when workers idle (task complete or blocked)
4. Coordinator resolves dependencies and spawns next phase
5. **Git worktrees** enable parallel branch work without conflicts

### Alternatives Considered
1. **Shared filesystem** — Partial: Used (via state files) but not sufficient alone
2. **Message queues** — Rejected: Overengineered for Claude Code context
3. **Polling** — Rejected: Stop hooks provide event-driven coordination
4. **stdin/stdout piping** — Rejected: Not supported across Claude sessions

### Concerns
- tmux dependency limits non-terminal environments
- No native plugin dependency declarations (workaround: runtime check in governance hook)

---

## Research Question 3: What is the optimal plugin decomposition?

### Decision: 13 plugins (1 governance + 1 specification + 1 orchestrator + 1 git + 1 creation + 1 debug + 7 domain)

### Rationale
| Category | Plugins | Reasoning |
|----------|---------|-----------|
| **Core (mandatory)** | sdd-governance | Constitutional enforcement must always be active |
| **Workflow** | sdd-specification | SDD lifecycle is a cohesive unit (spec→plan→tasks) |
| **Coordination** | sdd-orchestrator | Swarm + research + multi-skill workflows together |
| **Safety** | sdd-git | Git operations are a distinct safety domain |
| **Creation** | sdd-creation | Agent/skill/PRD creation is a distinct workflow |
| **Debug** | sdd-debug | Debug workflow is self-contained |
| **Domain (7)** | sdd-domain-{name} | Each domain is independently useful |

### Alternatives Considered
1. **Fewer plugins (5)** — Rejected: Domains bundled together lose selective install benefit
2. **More plugins (20+)** — Rejected: Each skill as a plugin creates management overhead
3. **Two-tier (core + domains)** — Close but missing orchestrator/git/creation separation

---

## Research Question 4: How should governance work across plugins?

### Decision: Governance plugin hooks run on ALL events, providing cross-plugin enforcement

### Rationale
The `UserPromptSubmit` hook event fires before any tool execution, making it the ideal enforcement point. The governance plugin:
1. Registers `UserPromptSubmit` hook → Pre-flight compliance check (4-step protocol)
2. Registers `PreToolUse` hook → Git operation gate (Principle VI)
3. Does NOT need to know about other plugins — it gates based on actions, not sources

### Risk: Hook ordering across plugins
Claude Code does not guarantee hook execution order across plugins. Mitigation:
- `UserPromptSubmit` fires before tool hooks regardless
- Governance `PreToolUse` hook should use narrow matchers to avoid conflicts
- Document that governance plugin must be installed before others

---

## Research Question 5: What are the swarm cost control mechanisms?

### Decision: `--max-budget-usd` per agent + team-level budget allocation

### Rationale
The `--max-budget-usd` CLI flag provides hard budget limits per agent process. Team-level budgets divide across agents:
- Team budget ÷ agent count = per-agent allocation (default)
- Priority-weighted allocation available (e.g., architect gets 40%, implementors split 60%)
- `--fallback-model sonnet` provides automatic cost reduction when Opus quota depletes

### Concerns
- No real-time budget visibility across swarm (each agent tracks independently)
- Kill on budget exceed may lose in-progress work (mitigation: frequent state checkpoints)

---

## Research Question 6: What is the RL integration model per plugin?

### Decision: RL metrics in plugin.json + PostToolUse hook capture + EMA algorithm

### Rationale
Each plugin's `plugin.json` contains an `rl_metrics` section that tracks:
- `success_rate`: EMA with learning rate 0.1
- `selection_weight`: Clamped to [0.1, 1.0]
- `invocation_count`: Total uses
- `avg_tokens`: Average token consumption

PostToolUse hooks capture success/failure after each skill execution and update the plugin's metrics. This enables:
- Per-plugin quality monitoring
- A/B testing (install v1.2 and v1.3 as separate plugins)
- Automatic update suggestions when success_rate drops

---

## Research Question 7: Backwards compatibility during transition

### Decision: Coexistence mode — plugins take precedence over monolithic equivalents

### Rationale
During the transition period (v3.2.0 → v4.1.0):
1. Both monolithic skills AND plugin skills can coexist
2. Plugin auto-discovery takes precedence (plugin commands/agents shadow monolithic ones)
3. If a plugin is disabled, the monolithic fallback activates
4. Migration tooling helps downstream projects adopt incrementally

### Migration Path
```
v3.2.0: Install sdd-governance plugin alongside monolithic (validate)
v3.3.0: Install core plugins, disable monolithic equivalents one-by-one
v3.4.0: Install domain plugins, remove monolithic domain skills
v4.0.0: Full plugin-first, monolithic structure deprecated
v4.1.0: Monolithic structure removed
```

---
