# SDD Agentic Framework v3.0.0

**Skills-First Architecture with Reinforcement Learning and DS-STAR Integration**

A constitutional AI framework for specification-driven development with intelligent skill-based routing, multi-agent orchestration, and continuous learning.

## Features

- **Skills-First Architecture**: Skills invoke agents (not vice versa)
- **Reinforcement Learning**: EMA-based skill selection with 26.9% improvement
- **Progressive Disclosure**: 50% token reduction through 3-layer loading
- **DS-STAR Integration**: 5 specialized agents (Router, Verifier, Auto-Debug, Finalizer, Context Analyzer)
- **Constitutional Governance**: 15 enforceable principles (v2.0.0)
- **13 Specialized Agents**: 8 domain + 5 DS-STAR
- **28 Active Skills**: Across 8 categories
- **Test-First Development**: >80% coverage requirement

## Quick Start

### Prerequisites

- Node.js >=18.0.0
- npm >=9.0.0
- Git

### Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd sdd-agentic-framework

# Install dependencies
npm install

# Run tests
npm test
```

### First Steps

1. **Read the Constitution**: [.specify/memory/constitution.md](.specify/memory/constitution.md)
2. **Review CLAUDE.md**: Framework guidance for Claude Code
3. **Check AGENTS.md**: Complete agent registry and capabilities
4. **Explore Skills**: [.claude/skill-index.json](.claude/skill-index.json)
5. **See TEMPLATE_INIT.md**: Initialization guide for new projects

## Architecture

### Skills-First Workflow

```
User Message → FR-707 Compliance Check → Router Agent →
Skill Selection (RL) → Skill Activation (progressive) →
Agent Invocation (minimal context) → Verifier (DS-STAR) →
Auto-Debug (if needed) → Output + RL Feedback
```

### Core Principles

1. **Test-First Development** (Principle II): TDD mandatory, >80% coverage
2. **Git Operation Approval** (Principle VI): NO autonomous git operations
3. **Skills-First Delegation** (Principle X): Skills orchestrate agents

## Workflow Commands

### Feature Development

- `/create-prd` - Create Product Requirements Document
- `/initialize-project` - Customize framework based on PRD
- `/specify` - Create feature specification
- `/plan` - Generate implementation plan
- `/tasks` - Generate dependency-ordered task list
- `/finalize` - Pre-commit compliance validation

### Agent/Skill Management

- `/create-agent` - Create specialized subagent
- `/create-skill` - Create new skill

## Configuration

- **Architecture Mode**: `skills-first` (Phase 4)
- **Constitution**: v2.0.0 (ratified 2026-01-13)
- **RL Algorithm**: EMA (Exponential Moving Average)
- **Test Framework**: Jest

See [.specify/config/architecture.conf](.specify/config/architecture.conf) for complete configuration.

## Documentation

- **Constitution**: [.specify/memory/constitution.md](.specify/memory/constitution.md)
- **Framework Guide**: [CLAUDE.md](CLAUDE.md)
- **Agent Registry**: [AGENTS.md](AGENTS.md)
- **Skill Registry**: [.claude/skill-index.json](.claude/skill-index.json)
- **Template Init Guide**: [TEMPLATE_INIT.md](TEMPLATE_INIT.md)
- **Policies**: `.docs/policies/` directory

## Performance Metrics

| Metric | Target | Achieved |
|--------|--------|----------|
| Token Efficiency | 40-50% ↓ | 50% ✅ |
| Agent Consolidation | 35% ↓ | 53% ✅ |
| RL Improvement | 15-25% ↑ | 26.9% ✅ |
| Test Coverage | >80% | 95.4% ✅ |

## Testing

```bash
# Run all tests
npm test

# Run specific test suites
npm run test:contracts
npm run test:integration
npm run test:validation
```

## Project Structure

```
.claude/
├── skill-index.json          # 28 skills with RL
├── agent-index.json          # 13 agents
├── skills/                   # 8 categories
└── agents/                   # consolidated/ + ds-star/

.specify/
├── memory/constitution.md    # v2.0.0 principles
├── scripts/bash/rl/          # RL infrastructure
├── config/                   # Architecture configuration
└── templates/                # Skill/agent templates

specs/                        # Feature specifications (created per project)
tests/                        # Contract, integration, validation tests
```

## License

MIT

## Version

**Framework**: v3.0.0
**Constitution**: v2.0.0 (ratified 2026-01-13)
**Architecture Mode**: skills-first (Phase 4)
