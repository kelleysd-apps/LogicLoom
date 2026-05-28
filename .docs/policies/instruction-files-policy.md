# Instruction Files Policy (CLAUDE.md & AGENTS.md)

**Version**: 1.0.0
**Effective Date**: 2025-11-29
**Authority**: Constitution v3.0.0 - Principle VIII (Documentation Sync)
**Review Cycle**: On any agent or workflow change

---

## Purpose

This policy defines the relationship, responsibilities, and tandem update rules for the two primary AI instruction files in the SDD Framework:
- `CLAUDE.md` - Workflow rules and compliance protocols
- `AGENTS.md` - Agent registry and selection guidance

---

## File Responsibilities

### CLAUDE.md - Workflow & Compliance

**Primary Purpose**: Define HOW to work in the framework

**Contains**:
- Message pre-flight compliance check (4-step protocol)
- Domain → agent delegation triggers (quick reference)
- Constitutional compliance requirements
- Git operation rules
- File creation rules
- Task management (SSOT) rules
- Feature workflow instructions
- Testing approach
- DS-STAR enhancements
- Available agents summary (brief)

**Audience**: Claude Code (primary), developers (reference)

**Update Triggers**:
- Constitutional changes
- Workflow process changes
- Compliance requirement changes
- Delegation trigger changes
- New principles added

### AGENTS.md - Agent Registry

**Primary Purpose**: Define WHO does what in the framework

**Contains**:
- Complete agent registry by department
- Agent capabilities and tools
- Domain → agent mapping (detailed)
- Slash command → agent mapping
- Agent collaboration workflows
- Agent file locations
- Quick decision tree
- MCP server access by department
- Tandem update rules

**Audience**: Claude Code (primary), developers (reference)

**Update Triggers**:
- New agent created
- Agent modified or deleted
- Department changes
- Tool access changes
- Model selection changes

---

## Tandem Update Rules

### CRITICAL: These files MUST be updated together

```
┌─────────────────────────────────────────────────────────────────┐
│                    TANDEM UPDATE MATRIX                         │
├─────────────────────────────────────────────────────────────────┤
│ Change Type                  │ CLAUDE.md │ AGENTS.md │ Both    │
├─────────────────────────────────────────────────────────────────┤
│ New agent created            │           │     ✓     │   ✓*    │
│ Agent deleted                │           │     ✓     │   ✓*    │
│ Agent capabilities changed   │           │     ✓     │   ✓*    │
│ Agent model changed          │           │     ✓     │         │
│ Skill replaces agent         │     ✓     │     ✓     │   ✓     │
│ Domain keywords changed      │     ✓     │     ✓     │   ✓     │
│ Delegation triggers changed  │     ✓     │     ✓     │   ✓     │
│ Workflow process changed     │     ✓     │           │         │
│ Constitutional version bump  │     ✓     │     ✓     │   ✓     │
│ Principle count changed      │     ✓     │     ✓     │   ✓     │
│ New department added         │     ✓*    │     ✓     │   ✓     │
│ Slash command mapping change │     ✓*    │     ✓     │   ✓     │
│ Agent count changes          │     ✓*    │     ✓     │   ✓     │
└─────────────────────────────────────────────────────────────────┘

✓* = Update if the change affects content in that file
```

### Verification Checklist

After tandem updates, verify:

```
[ ] Agent count matches in both files (11 remaining agents)
[ ] Domain → skill/agent mappings are consistent
[ ] Constitutional version matches in both files
[ ] Delegation triggers align between files
[ ] Slash command mappings match
[ ] Department counts are accurate
[ ] Model selections are current
[ ] Skill references match plugin architecture
```

---

## Update Protocol

### When Adding a New Agent

```
1. Create agent file in plugins/[plugin]/agents/[agent].md
2. Create agent memory in .docs/agents/[dept]/[agent]/
3. Update AGENTS.md:
   - Add to department table
   - Update agent count
   - Add to domain mapping (if new domain)
   - Add to decision tree
   - Update file locations
4. Update CLAUDE.md:
   - Update domain → skill/agent mapping table (if changed)
   - Update agent count reference (if mentioned)
5. Update plugin manifest (plugins/[plugin]/plugin.json)
6. Run verification checklist
```

### When Modifying an Agent or Skill

```
1. Update agent/skill file in plugins/[plugin]/agents/ or plugins/[plugin]/skills/
2. Update AGENTS.md:
   - Update department table entry (for agents)
   - Update capabilities/tools if changed
   - Update domain mapping if keywords changed
3. Update CLAUDE.md:
   - Update delegation triggers if changed
   - Update skill/agent references
4. Update plugin manifest if capabilities changed
5. Run verification checklist
```

### When Constitutional Version Changes

```
1. Update constitution.md
2. Update CLAUDE.md:
   - Version reference
   - Principle count
   - Affected sections
3. Update AGENTS.md:
   - Version reference
   - Principle count
   - Constitutional compliance section
4. Update message-preflight skill
5. Run verification checklist
```

---

## Content Synchronization

### Domain → Agent Mapping

Both files contain domain → agent mappings. They must stay synchronized:

**CLAUDE.md** (Quick Reference - abbreviated):
```markdown
| Domain | Trigger Keywords | Delegate To |
|--------|------------------|-------------|
| Frontend | UI, component, React | frontend-operations skill |
```

**AGENTS.md** (Full Reference - detailed):
```markdown
| Domain | Keywords | Primary Skill/Agent | Backup |
|--------|----------|---------------------|--------|
| Frontend | UI, React, CSS, component | frontend-operations skill | team-synthesizer |
```

**Sync Rule**: AGENTS.md has authoritative detail; CLAUDE.md has quick reference subset.

### Agent Counts

Both files reference agent counts:

- `CLAUDE.md`: "11 agents (after v5.0 skill migration)"
- `AGENTS.md`: "Total Agents: 11, across 5 departments"

**Sync Rule**: Must match exactly. Note: 14 agents were converted to enhanced skills in v5.0.

### Constitutional Version

Both files reference constitution version:

- `CLAUDE.md`: "Constitution v3.0.0 contains 16 enforceable principles"
- `AGENTS.md`: "Constitution: v3.0.0 (16 Principles)"

**Sync Rule**: Must match exactly.

---

## Automated Verification

### Search Commands

```bash
# Verify agent counts match
grep -E "11 agents|Total Agents: 11" CLAUDE.md AGENTS.md

# Verify constitutional version
grep -E "v3\.0\.0|16 principles|16 Principles" CLAUDE.md AGENTS.md

# Find all domain mappings
grep -A 20 "Domain.*Agent.*Mapping" CLAUDE.md AGENTS.md
```

### Validation Script (Future)

A validation script should check:
1. Agent count consistency
2. Constitutional version consistency
3. Domain mapping alignment
4. Department structure accuracy

---

## File Locations

```
Repository Root/
├── CLAUDE.md          # Workflow & compliance (primary AI instructions)
├── AGENTS.md          # Agent registry (agent reference)
├── README.md          # Project overview (human-focused)
└── .logic-loom/memory/
    └── constitution.md  # Constitutional authority
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-29 | Initial policy creation |

---

## References

- Constitution: `.logic-loom/memory/constitution.md`
- Update Checklist: `.logic-loom/memory/constitution_update_checklist.md`
- Agent Collaboration: `.logic-loom/memory/agent-collaboration-triggers.md`

---

**Policy Owner**: Framework Architecture
**Enforcement**: Constitution Update Checklist, constitutional-check.sh
**Compliance**: Required for all agent and workflow changes
