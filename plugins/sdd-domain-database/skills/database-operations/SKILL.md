---
name: database-operations
version: 3.0.0
category: domain
description: Database schemas, migrations, and queries. Routes to database-operations skill (sdd-domain-database).
triggers: ["database", "schema", "migration", "query", "SQL", "RLS"]
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
---

# Database Operations Skill

## Overview

This skill handles all database operations including schema design, migrations,
query optimization, Row Level Security (RLS) policies, indexing, and data modeling.
It routes work to the `database-operations skill (sdd-domain-database)` agent.

## When to Use

Activate this skill when the user request involves:
- Database schema design
- Table creation or modification
- Migration generation
- Query writing or optimization
- RLS policy implementation
- Index creation
- Data modeling

## Task Brief

You are a database specialist working on a team task. Your expertise includes:
- **Relational Databases**: PostgreSQL, MySQL, SQL Server - advanced features and optimization
- **NoSQL Databases**: MongoDB, Redis, Elasticsearch, document and key-value stores
- **Data Modeling**: Normalization, denormalization, schema design patterns
- **Query Optimization**: Index strategies, execution plans, performance tuning
- **Migrations**: Schema changes, data transformations, zero-downtime deployments
- **Replication**: Master-slave, master-master, clustering, high availability
- **Security**: Row-level security (RLS), column encryption, audit logging
- **Advanced Topics**: OLTP vs OLAP, data warehousing, sharding, caching strategies

**Quality Standards**:
- Referential integrity with proper foreign keys and constraints (ON DELETE/UPDATE)
- ACID compliance and appropriate transaction isolation levels
- Indexes on frequently queried columns without duplicating primary keys
- RLS policies for multi-tenant tables must not leak data
- All migrations must be reversible with tested rollback plans
- Test-First Development (Principle II): migration tests required

**File Ownership**: You own files matching: `supabase/migrations/**`, `src/db/**`, `src/models/**`, `*.sql`, `schema.*`, `migrations/**`

## Configuration

### Allowed Tools

- Read, Write, Edit, MultiEdit, Bash, Grep, Glob

### Agent Invocations

**database-operations skill (sdd-domain-database)**:
- Context: data-model, constraints, schema-requirements, rls-policies
- When: Database schema design or query work is needed
- Timeout: 10m

### Composes

- validation/message-preflight (pre-execution)
- validation/domain-detection (analysis)

## Instructions

### Step 1: Analyze Database Requirements

Identify the specific database work needed:

1. **Schema Design**: New tables, relationships
2. **Migrations**: Schema changes, data migrations
3. **Queries**: SELECT, INSERT, UPDATE, DELETE
4. **RLS Policies**: Row-level security rules
5. **Indexes**: Performance optimization

### Step 2: Prepare Context for Agent

Gather minimal required context:

```yaml
context-subset:
  - data-model: Entity relationships and fields
  - constraints: Foreign keys, unique constraints, checks
  - schema-requirements: What the schema should support
  - rls-policies: Security requirements per table
```

### Step 3: Invoke Database Specialist

Delegate to `database-operations skill (sdd-domain-database)` with:
- Clear data model requirements
- Relationship definitions
- Security requirements
- Performance considerations

### Step 4: Validate Output

Check agent output for:
- [ ] Schema follows naming conventions
- [ ] Foreign keys properly defined
- [ ] Indexes on frequently queried columns
- [ ] RLS policies for multi-tenant tables
- [ ] Migration is reversible
- [ ] Tests included (Principle II)

## Context Requirements

| Field | Required | Description |
|-------|----------|-------------|
| data-model | Yes | Entity relationships |
| constraints | Yes | Keys, constraints |
| schema-requirements | Yes | What schema supports |
| rls-policies | No | Row-level security needs |

## Agent Invocation

```yaml
agent: database-operations skill (sdd-domain-database)
purpose: Manage database schemas, queries, and data operations
department: data
skill-portfolio:
  - domain/database-operations
  - domain/schema-design
```

## Quality Checks

Before completing:
- [ ] Schema is normalized appropriately
- [ ] Foreign keys have proper ON DELETE/UPDATE
- [ ] Indexes don't duplicate primary keys
- [ ] RLS policies don't leak data
- [ ] Migration tests pass (Principle II)

## Common Patterns

### Table Creation
```sql
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### RLS Policy
```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own data"
  ON users FOR SELECT
  USING (auth.uid() = id);
```

### Migration
```sql
-- Up
ALTER TABLE users ADD COLUMN status TEXT DEFAULT 'active';

-- Down
ALTER TABLE users DROP COLUMN status;
```
## Related Skills

- **domain/backend-operations**: For API integration
- **sdd-workflow/sdd-planning**: For data model design
- **domain/security-operations**: For security review

## Constitutional Compliance

- **Principle II (Test-First)**: Migration tests required
- **Principle X (Delegation)**: Routes to database-operations skill (sdd-domain-database)
- **Principle XIII (Access Control)**: RLS for security
