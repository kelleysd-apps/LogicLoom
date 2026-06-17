# Agent File Naming Convention

**Version**: 1.0.0
**Effective Date**: TBD
**Policy Owner**: System Architecture Team

## Purpose

To prevent confusion and maintain clarity as the number of agents grows, all agent-related files must follow specific naming conventions that include the agent's identifier.

## File Naming Standards

### Memory Structure Files

Each agent's memory structure contains four main directories. Files within these directories MUST include the agent name to avoid confusion:

#### Context Directory
- **Pattern**: `{agent-name}-context.md`
- **Example**: `subagent-architect-context.md`
- **Purpose**: Current working context and state

#### Knowledge Directory
- **Pattern**: `{agent-name}-knowledge.md` (main file)
- **Additional**: `{agent-name}-{topic}.md` for specific knowledge areas
- **Example**: `subagent-architect-knowledge.md`, `subagent-architect-workflow.md`
- **Purpose**: Accumulated knowledge and learnings

#### Decisions Directory
- **Pattern**: `{agent-name}-decisions.md`
- **Example**: `subagent-architect-decisions.md`
- **Purpose**: Historical decisions and rationales

#### Performance Directory
- **Pattern**: `{agent-name}-performance.md`
- **Example**: `subagent-architect-performance.md`
- **Purpose**: Performance tracking and optimization data

### Why This Matters

Without agent-specific naming:
- Multiple `README.md` files across agents become indistinguishable
- File searches return ambiguous results
- Context switching between agents becomes error-prone
- Maintenance and debugging become difficult

With agent-specific naming:
- Each file is immediately identifiable
- Search results are precise
- Navigation is intuitive
- Scaling to many agents remains manageable

## Directory Structure Example

```
.docs/agents/architecture/subagent-architect/
├── context/
│   └── subagent-architect-context.md
├── knowledge/
│   ├── subagent-architect-knowledge.md
│   └── create-agent-workflow.md
├── decisions/
│   └── subagent-architect-decisions.md
└── performance/
    └── subagent-architect-performance.md
```

## Implementation

### For New Agents

The `create-agent.sh` script automatically creates files with the correct naming convention:
- Uses `{agent_name}-context.md` instead of `README.md`
- Applies pattern consistently across all memory directories

### For Existing Agents

Existing generic `README.md` files should be renamed to follow the convention:
```bash
# Old: README.md
# New: {agent-name}-{directory}.md
mv README.md subagent-architect-context.md
```

## Enforcement

1. **Creation Scripts**: `create-agent.sh` enforces naming automatically
2. **Code Reviews**: Check for proper file naming in agent directories
3. **Validation**: Agent compliance checks include file naming validation
4. **Documentation**: All agent documentation must reference files by their full names

## Exceptions

- Cross-agent shared resources may use generic names in `.docs/agents/shared/`
- Department-level documentation may use department-prefixed names
- System-wide policies remain as-is (e.g., this file)

## Migration Checklist

When updating existing agents:
- [ ] Rename context/README.md → context/{agent-name}-context.md
- [ ] Rename knowledge/README.md → knowledge/{agent-name}-knowledge.md
- [ ] Rename decisions/README.md → decisions/{agent-name}-decisions.md
- [ ] Rename performance/README.md → performance/{agent-name}-performance.md
- [ ] Update any internal references to these files
- [ ] Verify no broken links remain

## Benefits

1. **Scalability**: System remains organized with 10, 50, or 100+ agents
2. **Searchability**: Find agent-specific files instantly
3. **Clarity**: No ambiguity about which agent a file belongs to
4. **Maintenance**: Easier to manage and update agent-specific content
5. **Debugging**: Quickly identify and access relevant agent files

---

**Note**: This convention is automatically applied by the agent creation tooling. Manual creation of agent files should follow these standards to maintain consistency.