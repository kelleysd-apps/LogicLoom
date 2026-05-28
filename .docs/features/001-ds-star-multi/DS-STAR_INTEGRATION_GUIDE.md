# DS-STAR Integration Guide

**Feature**: 001-ds-star-multi
**Status**: Phase 3 Complete - Ready for Testing
**Version**: 1.0.0

---

## Overview

The DS-STAR Multi-Agent Enhancement adds five new specialized agents and supporting infrastructure to the SDD Agentic Framework:

1. **Verification Agent** - Quality gate enforcement
2. **Router Agent** - Intelligent orchestration
3. **Auto-Debug Agent** - Self-healing capabilities
4. **Context Analyzer** - Codebase intelligence
5. **Compliance Finalizer** - Pre-commit validation

---

## Integration Points

### 1. Specification Verification (T041)

**Command**: `/specify`

**Enhancement**: After spec generation, optionally verify quality

**Usage**:
```bash
# Generate spec normally
/specify "feature description"

# Then optionally verify quality
python .logic-loom/scripts/python/ds_star_integration.py verify_spec specs/###-feature-name/spec.md
```

**Output**:
- Quality score (0.0-1.0)
- Binary decision (sufficient/insufficient)
- Actionable feedback for improvements

---

### 2. Plan Verification (T042)

**Command**: `/plan`

**Enhancement**: After plan generation, optionally verify against constitution

**Usage**:
```bash
# Generate plan normally
/plan

# Then optionally verify quality
python .logic-loom/scripts/python/ds_star_integration.py verify_plan specs/###-feature-name/plan.md
```

**Output**:
- Quality score with dimension breakdown
- Constitutional compliance check
- Recommendations for improvements

---

### 3. Multi-Domain Routing (T043)

**Agent**: task-orchestrator

**Enhancement**: Intelligent agent selection based on domain keywords

**Usage**: Automatic when using task-orchestrator
```python
Task(
    subagent_type="task-orchestrator",
    description="Implement multi-domain feature",
    prompt="Feature requires frontend, backend, and database work..."
)
```

**Behavior**:
- Analyzes task description for domain keywords
- Selects appropriate specialized agents
- Plans parallel execution when possible
- Logs routing decisions for audit trail

---

### 4. Auto-Debug (T044)

**Trigger**: Test failures with common error patterns

**Enhancement**: Automatic error detection and repair

**Usage**: Can be invoked manually
```python
from sdd.agents.engineering.autodebug import AutoDebugAgent

agent = AutoDebugAgent()
result = agent.debug({
    "agent_id": "engineering.autodebug",
    "task_id": "debug-001",
    "phase": "implementation",
    "error_message": "SyntaxError: invalid syntax",
    "stack_trace": "...",
    "code_file": "src/module.py"
})
```

**Targets**:
- >70% auto-fix rate for common errors (FR-016)
- Max 5 iterations before human escalation
- Supports: syntax, type, name, null, import, logic errors

---

### 5. Context Intelligence (T045)

**Agent**: planning-agent

**Enhancement**: Provides codebase context before planning

**Usage**: Manual invocation for now
```python
from sdd.agents.architecture.context_analyzer import ContextAnalyzerAgent

agent = ContextAnalyzerAgent()
result = agent.analyze({
    "agent_id": "architecture.context_analyzer",
    "task_id": "plan-001",
    "phase": "planning",
    "codebase_path": "/workspaces/project",
    "query": "authentication patterns"
})
```

**Features**:
- Semantic search with sentence-transformers
- <2 second retrieval time (FR-031)
- Graceful degradation to keyword search
- Constitutional compliance status

---

### 6. Compliance Finalizer (T046)

**Command**: Manual /finalize

**Enhancement**: Pre-commit compliance validation

**Usage**:
```bash
# Before committing, validate compliance
python .logic-loom/scripts/python/ds_star_integration.py finalize specs/###-feature-name
```

**Output**:
- Pre-commit checklist results
- Constitutional compliance (all 14 principles)
- Documentation sync status
- Recommended git operations (user must execute manually)

**CRITICAL**: Finalizer NEVER executes git operations autonomously (Principle VI)

---

## Configuration

All DS-STAR components are configured via `.logic-loom/config/refinement.conf`:

```bash
# Refinement
MAX_REFINEMENT_ROUNDS=20
EARLY_STOP_THRESHOLD=0.95

# Quality Thresholds
SPEC_COMPLETENESS_THRESHOLD=0.90
PLAN_QUALITY_THRESHOLD=0.85
CODE_QUALITY_THRESHOLD=0.80
TEST_COVERAGE_THRESHOLD=0.80

# Router
ENABLE_PARALLEL_EXECUTION=true
MAX_PARALLEL_AGENTS=3
ROUTING_STRATEGY="adaptive"

# Auto-Debug
MAX_DEBUG_ITERATIONS=5
AUTO_DEBUG_ENABLED=true
AUTO_FIX_TARGET_RATE=0.70

# Context Retrieval
CONTEXT_RETRIEVAL_TIMEOUT=2000  # 2 seconds
SIMILARITY_THRESHOLD=0.70

# Finalizer
ENFORCE_PRE_COMMIT_CHECKS=true
AUTO_FORMAT_CODE=true
GENERATE_DOCS=true
```

---

## Testing the Integration

### Test Verification Agent
```bash
# Create a test spec
echo "# Test Spec\n\n## Requirements\n- FR-001: Test" > /tmp/test-spec.md

# Verify it (should report insufficient quality)
python .logic-loom/scripts/python/ds_star_integration.py verify_spec /tmp/test-spec.md
```

### Test Finalizer
```bash
# Run finalizer on current feature
python .logic-loom/scripts/python/ds_star_integration.py finalize specs/001-ds-star-multi
```

---

## Performance Targets

| Metric | Target | Status |
|--------|--------|--------|
| Task completion accuracy | 3.5x improvement | To be measured |
| Auto-fix rate | >70% | To be measured |
| Context retrieval | <2 seconds | ✅ Implemented |
| Constitutional compliance | >95% first-pass | To be measured |

---

## Troubleshooting

### "DS-STAR not available" Error

**Cause**: Python dependencies not installed

**Solution**:
```bash
pip install -r requirements.txt
```

### Verification Always Returns Insufficient

**Cause**: Thresholds may be too strict

**Solution**: Adjust thresholds in `.logic-loom/config/refinement.conf`

### Context Retrieval Slow

**Cause**: Large codebase or slow embeddings

**Solution**: System will automatically degrade to keyword search

---

## Next Steps

1. **Run Integration Tests**: Execute test suites to validate all components
2. **Measure Baselines**: Collect metrics before DS-STAR for comparison
3. **Enable in Workflows**: Integrate verification gates into bash scripts
4. **Monitor Performance**: Track metrics to validate 3.5x improvement

---

## Documentation

- **Specification**: `specs/001-ds-star-multi/spec.md`
- **Plan**: `specs/001-ds-star-multi/plan.md`
- **Tasks**: `specs/001-ds-star-multi/tasks.md`
- **Data Models**: `specs/001-ds-star-multi/data-model.md`
- **Contracts**: `specs/001-ds-star-multi/contracts/*.yaml`
- **Quick Reference**: `specs/001-ds-star-multi/LIBRARIES_QUICK_REFERENCE.md`

---

## Status: Phase 3 Complete ✅

All implementation tasks (T001-T046) are complete:
- ✅ Setup & Configuration (T001-T005)
- ✅ Tests First - TDD (T006-T017)
- ✅ Data Models (T018-T028)
- ✅ Agent Libraries (T029-T033)
- ✅ Supporting Libraries (T034-T040)
- ✅ Integration Scripts (T041-T046)

**Ready for**: End-to-end testing and validation
