# Constitutional Governance Agent - Knowledge Base

## Core Knowledge

### Constitutional Principles Summary

**Immutable Principles (I-III)**:
1. **Principle I**: Library-First Architecture - Every feature must begin as standalone library
2. **Principle II**: Test-First Development - TDD is mandatory, >80% coverage required
3. **Principle III**: Contract-First Design - Define contracts before implementation

**Critical Principles (VI, X)**:
4. **Principle VI**: Git Operation Approval - NO autonomous git operations ever
5. **Principle X**: Agent Delegation Protocol - Specialized work to specialists

**Quality & Safety Principles (IV-V, VII-IX)**:
6. **Principle IV**: Idempotent Operations
7. **Principle V**: Progressive Enhancement
8. **Principle VII**: Observability and Structured Logging
9. **Principle VIII**: Documentation Synchronization
10. **Principle IX**: Dependency Management

**Workflow Principles (XI-XVI)**:
11. **Principle XI**: Input Validation and Output Sanitization
12. **Principle XII**: Design System Compliance
13. **Principle XIII**: Feature Access Control
14. **Principle XIV**: AI Model Selection Protocol
15. **Principle XV**: File and Folder Organization
16. **Principle XVI**: Plugin-First Architecture

### Domain-Brief Mapping

The seven `sdd-domain-*` specialist plugins have been removed. Domain expertise now
lives as lightweight **domain briefs** in the governance plugin's registry at
`plugins/loom-governance/domain-briefs/<domain>.md`, retrieved at delegation time via
`get_domain_brief()` in `common.sh`. Workers receive the relevant brief inline rather
than routing to a dedicated specialist plugin.

| Domain | Domain brief | Retrieval |
|--------|--------------|-----------|
| Frontend | `domain-briefs/frontend.md` | `get_domain_brief frontend` |
| Backend | `domain-briefs/backend.md` | `get_domain_brief backend` |
| Database | `domain-briefs/database.md` | `get_domain_brief database` |
| Testing | `domain-briefs/testing.md` | `get_domain_brief testing` |
| Security | `domain-briefs/security.md` | `get_domain_brief security` |
| Performance | `domain-briefs/performance.md` | `get_domain_brief performance` |
| DevOps | `domain-briefs/devops.md` | `get_domain_brief devops` |
| Specification | sdd-specification skill | sdd-specification |
| Planning | sdd-planning skill | sdd-specification |
| Tasks | sdd-tasks skill | sdd-specification |
| Multi-Domain | team-orchestration skill | loom-orchestrator |
| PRD | prd-specialist agent | loom-creation |

### Slash Command Routing

| Command | Skill/Agent | Description |
|---------|-------------|-------------|
| /specification | unified-specification skill | Unified spec + plan + tasks workflow |
| /create-prd | prd-specialist agent | Create Product Requirements Document |
| /specify | sdd-specification skill | Create feature specification |
| /plan | sdd-planning skill | Generate implementation plan |
| /tasks | sdd-tasks skill | Generate task list |
| /create-agent | subagent-architect agent | Create new specialized agent |
| /debug | auto-debug-agent | Debug deployment/runtime issues |
| /research | team-synthesizer agent | Multi-LLM tribunal research |
| /swarm | team-orchestration skill | Multi-agent swarm execution |
| /dev-loop | dev-loop-orchestrator agent | Recursive dev-loop with tribunal |

## Accumulated Learnings

### Effective Patterns
- [To be populated through operation]

### Common Issues
- [To be populated through operation]

### Optimization Notes
- [To be populated through operation]
