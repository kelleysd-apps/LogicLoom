---
name: domain-detection
description: |
  Analyze text to identify technical domains and recommend consolidated worker briefs
  for delegation following Constitutional Principle X (Agent Delegation Protocol).

  This skill examines a vision, PRD, plan, sprint, or any technical text to detect domain
  keywords and recommend single-worker vs multi-worker (swarm/team) delegation. Domains map
  to consolidated briefs in the governance-core domain-brief registry (resolved via
  get_domain_brief), not to per-domain plugins.

  Triggered by: "which worker?", "who should do this?", domain-identification needs, or the
  governance hook surfacing domains from domains.conf.
allowed-tools: Read, Bash, Grep
---

# Domain Detection Skill

## When to Use

Activate this skill when:
- You need to identify which domains are involved in a piece of work
- A user asks "which worker/brief should handle this?"
- You are choosing a delegation strategy (single-worker vs swarm/team)
- After drafting a vision/PRD/plan (identify domains early)
- Before dispatching swarm/team workers (route to the right briefs)

**Trigger keywords**: which worker, domain, who should, delegate, brief, swarm, orchestrator

## How domains are detected (hook-enforced)

Domain detection is keyword-based and driven by a single configuration file:

```
plugins/loom-orchestrator-hook/config/domains.conf   # keyword=domain
```

The governance UserPromptSubmit hook reads this map, matches keywords in the message, and
surfaces the matching domain(s) plus their consolidated worker brief as a recommendation.
There is no recited multi-step ceremony — detection runs in the hook. This skill documents
how to interpret and act on those recommendations.

## The domain-brief registry

Each detected domain resolves to a single consolidated worker brief in the
governance-core registry. This replaced the former seven `sdd-domain-*` plugins.

| Domain | Worker brief (via `get_domain_brief <domain>`) |
|--------|------------------------------------------------|
| frontend | `plugins/loom-governance/domain-briefs/frontend.md` |
| backend | `plugins/loom-governance/domain-briefs/backend.md` |
| database | `plugins/loom-governance/domain-briefs/database.md` |
| testing | `plugins/loom-governance/domain-briefs/testing.md` |
| security | `plugins/loom-governance/domain-briefs/security.md` |
| performance | `plugins/loom-governance/domain-briefs/performance.md` |
| devops | `plugins/loom-governance/domain-briefs/devops.md` |

Resolve a brief in shell:

```bash
# .logic-loom/scripts/bash/common.sh
get_domain_brief backend     # emits the consolidated "## Task Brief" section
```

`get_domain_brief` degrades gracefully (returns empty, exit 0) when a domain has no brief.

## Procedure

### Step 1: Identify the keyword map

The authoritative keyword → domain mapping is `domains.conf`. Representative keywords:

- **frontend**: UI, component, React, CSS, form, layout, responsive
- **backend**: API, endpoint, server, auth, service, middleware, route
- **database**: schema, migration, query, SQL, RLS, database, table
- **testing**: test, TDD, E2E, coverage, QA, assertion
- **security**: encryption, XSS, secrets, vulnerability, CSRF, injection, authentication
- **performance**: optimize, cache, benchmark, latency, profiling
- **devops**: deploy, CI/CD, Docker, pipeline, infrastructure

### Step 2: Count significant domains

- **0 domains** → generic work; no worker brief needed.
- **1 domain** → single-worker delegation; pull that one brief.
- **2+ domains** → swarm/team coordination; pull each relevant brief.

### Step 3: Resolve briefs and recommend a strategy

For each significant domain, call `get_domain_brief <domain>` and inject the returned Task
Brief into the worker prompt. Recommend:

- **Single-worker** when one domain dominates and work is self-contained.
- **Swarm/team** (`/swarm`, or legacy team orchestration) when 2+ domains span the work.

### Step 4: Report

```
Domain Detection Results

Detected domains: backend, database, security
Strategy: swarm/team (3 domains)
Worker briefs:
- get_domain_brief backend
- get_domain_brief database
- get_domain_brief security

Rationale: cross-domain work; dispatch one worker per brief under a swarm.
```

## Examples

### Example 1: Single-domain detection

**Request**: "Implement a loading spinner component for React"

- Keywords: component, React (frontend)
- Domains: frontend
- Strategy: single-worker
- Brief: `get_domain_brief frontend`

### Example 2: Multi-domain detection

**Request**: "Build user auth with email, password, JWT, and PostgreSQL storage"

- Keywords: auth/JWT (backend), authentication/secrets (security), schema/PostgreSQL (database)
- Domains: backend, database, security
- Strategy: swarm/team
- Briefs: `get_domain_brief backend`, `get_domain_brief database`, `get_domain_brief security`

### Example 3: No specialist needed

**Request**: "Update README with installation instructions"

- Keywords: none significant
- Strategy: handle directly; no worker brief needed.

## Constitutional Compliance

This skill implements **Principle X (Agent Delegation Protocol)**: it analyzes the task
domain and recommends the consolidated worker brief(s) so specialized work is routed to a
specialist worker rather than handled by a generalist. Enforcement is hook-driven — the
governance hook surfaces domains automatically; this skill supplies the interpretation and
brief resolution. Constitution: v3.1.0.

## Troubleshooting

### No domains detected for obviously technical work
Keyword not in the map. Add it to `plugins/loom-orchestrator-hook/config/domains.conf`
(`keyword=domain`) and re-check.

### Wrong domain detected
Ambiguous keyword overlap. Weigh by keyword frequency/context; override manually if clearly
incorrect.

### Single vs multi unclear (2 domains)
Simple integration → single worker can carry both; complex coordination → dispatch a worker
per brief under a swarm. Default to multi when unsure.

## Notes

- Detection is keyword-based — fast, not perfect.
- One registry, one consolidated brief per domain (no per-domain plugins).
- Prefer single-worker delegation when one domain clearly dominates.

## References

- Domain keyword map: `plugins/loom-orchestrator-hook/config/domains.conf`
- Domain-brief registry: `plugins/loom-governance/domain-briefs/`
- `get_domain_brief()`: `.logic-loom/scripts/bash/common.sh`
- Constitution v3.1.0: `.logic-loom/memory/constitution.md`
