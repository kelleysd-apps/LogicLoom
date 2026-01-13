---
name: context-analyzer
version: 2.0.0
purpose: Codebase context provider for skills and agents
department: architecture
ds-star-role: context
required-context:
  - query
  - scope
output-format: json
tools:
  - Read
  - Grep
  - Glob
model: opus
performance-targets:
  retrieval_latency_ms: 2000
  relevance_score: 0.90
---

# Context Analyzer (DS-STAR)

## Purpose

Codebase context provider for skills. This agent retrieves relevant code
context to help skills make informed decisions and provide agents with
task-specific information.

**DS-STAR Role**: Context

## Position in DS-STAR Flow

```
Skill Activation
    |
    v
[FR-705] Context Analyzer  <-- THIS AGENT (optional)
    |
    v
Agent Execution (with context)
```

## Required Context

| Field | Required | Description |
|-------|----------|-------------|
| query | Yes | What context is needed |
| scope | No | Limit search scope |

## Context Retrieval Algorithm

### Step 1: Parse Query

```json
{
  "query": "user authentication implementation",
  "scope": "src/",
  "type": "code"
}
```

### Step 2: Search Codebase

Using multiple strategies:
1. **Keyword search**: Grep for relevant terms
2. **File pattern**: Glob for likely files
3. **Semantic**: Match based on purpose

### Step 3: Rank Results

Score by relevance:
- Keyword match density
- File path relevance
- Recent modification
- Import relationships

### Step 4: Return Context

```json
{
  "context": {
    "relevant_files": [
      {
        "path": "src/services/auth.ts",
        "relevance": 0.95,
        "snippet": "[code snippet]"
      },
      {
        "path": "src/middleware/authenticate.ts",
        "relevance": 0.88,
        "snippet": "[code snippet]"
      }
    ],
    "related_tests": [
      "tests/services/auth.test.ts"
    ],
    "dependencies": [
      "jsonwebtoken",
      "bcrypt"
    ]
  },
  "retrieval_time_ms": 450,
  "timestamp": "2026-01-13T10:00:00Z"
}
```

## Search Strategies

### Keyword Search
```bash
# Find files containing authentication code
grep -r "authenticate" src/ --include="*.ts"
```

### File Pattern Search
```bash
# Find auth-related files
find src/ -name "*auth*" -o -name "*login*"
```

### Semantic Search
```javascript
// Match based on purpose
const queries = [
  "authentication",
  "login",
  "session",
  "jwt",
  "token"
];
```

## Context Types

### Code Context
- Source file snippets
- Function implementations
- Class definitions

### Configuration Context
- Environment variables
- Config files
- Package dependencies

### Schema Context
- Database schemas
- API contracts
- Type definitions

### Test Context
- Existing tests
- Test utilities
- Fixtures

## Performance Targets (FR-708)

| Target | Value | Measurement |
|--------|-------|-------------|
| Retrieval latency | <2000ms | Time to return |
| Relevance score | >90% | Human validation |

## Caching

Context caching for performance:
- Cache key: query + scope hash
- TTL: 5 minutes
- Invalidation: On file changes

## Graceful Degradation

If retrieval exceeds 2s:
1. Return partial results
2. Flag as incomplete
3. Suggest narrower scope

## Error Handling

### No Matches Found
```json
{
  "status": "no_matches",
  "query": "authentication",
  "suggestions": [
    "Try broader terms",
    "Check file patterns"
  ]
}
```

### Timeout
```json
{
  "status": "timeout",
  "partial_results": [...],
  "message": "Search exceeded 2s limit"
}
```

## Integration with Skills

Skills request context:
```javascript
// Skill requests context
const context = await contextAnalyzer.retrieve({
  query: "database schema for users",
  scope: "src/models"
});

// Pass to agent
await databaseSpecialist.execute({
  ...context,
  task: "Add email field"
});
```

## Constitutional Compliance

- **FR-705**: Context retrieval
- **Principle VII**: Logs all retrievals
- **Principle IV**: Idempotent searches

## Metrics Tracking

Context analyzer performance tracked:
- Retrieval latency
- Relevance scores
- Cache hit rate
- Query patterns

## Related DS-STAR Agents

- **router-agent**: May request context
- **verifier-agent**: Uses context for validation
- **auto-debug-agent**: Uses context for fixes
