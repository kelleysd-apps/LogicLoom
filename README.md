# SDD Agentic Framework v4.1.0

**Plugin-First Architecture with Multi-Agent Orchestration, Reinforcement Learning, and Constitutional Governance**

A constitutional AI framework for specification-driven development with 15 installable plugins, an MCP marketplace, intelligent skill-based routing, and continuous learning.

## Features

- **Plugin-First Architecture**: 15 discrete plugins with governance compliance (Principle XVI)
- **SDD Marketplace**: MCP server for plugin discovery, installation, and management
- **Dynamic Command Bridge**: Auto-syncs plugin commands to Claude Code
- **Multi-Agent Swarms**: Coordinated parallel agent execution with budget controls
- **Reinforcement Learning**: EMA-based skill selection with performance metrics
- **Constitutional Governance**: 16 enforceable principles (v3.0.0)
- **21 Specialized Agents**: Across governance, orchestration, specification, creation, debug, maintenance, and 7 domains
- **220 Automated Tests**: Contract, integration, E2E, and marketplace tests
- **Test-First Development**: >80% coverage requirement (Principle II)

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

# Run setup (installs all dependencies including MCP servers)
./.specify/scripts/setup.sh
```

### First Steps

1. **Read the Constitution**: [.specify/memory/constitution.md](.specify/memory/constitution.md)
2. **Review CLAUDE.md**: Framework guidance for Claude Code
3. **Check AGENTS.md**: Complete agent registry (21 agents across 15 plugins)
4. **Start Claude Code**: `claude` — all commands and marketplace tools available automatically

## Architecture

### Plugin-First Workflow

```
User Message → Governance Preflight Check → Domain Detection →
Plugin Discovery (marketplace-list) → RL-Weighted Agent Selection →
Skill Activation → Agent Invocation → Output + RL Feedback
```

### Plugin Registry

| Plugin | Category | Purpose |
|--------|----------|---------|
| `sdd-governance` | governance | Constitutional enforcement, compliance hooks |
| `sdd-specification` | core | /specification, /plan, /tasks workflows |
| `sdd-orchestrator` | orchestration | /swarm, /research, team commands |
| `sdd-creation` | core | /create-agent, /create-plugin, /create-prd |
| `sdd-git` | core | /git-push, /finalize |
| `sdd-debug` | core | /debug workflow |
| `sdd-maintenance` | core | /update-framework, /initialize-project |
| `sdd-domain-*` | domain | 7 domain specialists (frontend, backend, database, testing, security, devops, performance) |

### Core Principles

1. **Test-First Development** (Principle II): TDD mandatory, >80% coverage
2. **Git Operation Approval** (Principle VI): NO autonomous git operations
3. **Agent Delegation** (Principle X): Specialized work → specialized agents
4. **Plugin-First** (Principle XVI): All capabilities as discrete installable plugins

## Workflow Commands

### Feature Development

| Command | Purpose |
|---------|---------|
| `/specification` | Unified SDD workflow (spec + plan + tasks) |
| `/create-prd` | Create Product Requirements Document |
| `/debug` | 10-step debugging workflow |
| `/finalize` | Pre-commit compliance validation |
| `/git-push` | Complete git workflow with conflict resolution |

### Multi-Agent Teams

| Command | Purpose |
|---------|---------|
| `/swarm` | Spawn coordinated multi-agent swarm |
| `/build-team` | Sequential architect → implementor → reviewer |
| `/fullstack-team` | Parallel full-stack development team |
| `/research-team` | Parallel research with synthesis |
| `/review-team` | Parallel security + quality + performance review |
| `/research` | Multi-pass deep research |

### Plugin & Agent Management

| Command | Purpose |
|---------|---------|
| `/create-plugin` | Create new SDD plugin |
| `/create-agent` | Create specialized subagent |
| `/update-framework` | Check for upstream enhancements |
| `/initialize-project` | Post-PRD project customization |

## Configuration

- **Constitution**: v3.0.0 (16 principles, ratified 2026-02-06)
- **Architecture**: Plugin-First (v4.1)
- **RL Algorithm**: EMA (Exponential Moving Average)
- **Default Agent**: constitutional-governance-agent

## Documentation

- **Constitution**: [.specify/memory/constitution.md](.specify/memory/constitution.md)
- **Framework Guide**: [CLAUDE.md](CLAUDE.md)
- **Agent Registry**: [AGENTS.md](AGENTS.md)
- **Marketplace**: [mcp-servers/sdd-marketplace/README.md](mcp-servers/sdd-marketplace/README.md)
- **Setup Guide**: [START_HERE.md](START_HERE.md)
- **Policies**: `.docs/policies/` directory

## Testing

```bash
# Run all tests (220 tests across 8 suites)
bash tests/run_all_tests.sh

# Run specific test suites
npm run test:contracts
npm run test:integration
```

## Project Structure

```
plugins/                              # Plugin-First Architecture
├── sdd-governance/                   # Protected — constitutional enforcement
├── sdd-specification/                # SDD workflow plugins
├── sdd-orchestrator/                 # Multi-agent orchestration
├── sdd-creation/                     # Entity creation
├── sdd-git/                          # Git operations
├── sdd-debug/                        # Debug workflows
├── sdd-maintenance/                  # Framework maintenance
└── sdd-domain-*/                     # 7 domain specialists

.claude/
├── commands/                         # Slash commands (bridge-generated + static)
├── context/                          # Modular context loading
└── settings.json                     # Agent and hook configuration

mcp-servers/sdd-marketplace/          # Plugin marketplace MCP server

.specify/
├── memory/constitution.md            # v3.0.0 (16 principles)
├── scripts/bash/                     # Workflow automation + plugin bridge
└── config/                           # Quality thresholds

tests/                                # 220 tests across 8 suites
specs/                                # Feature specifications
```

## License

MIT

## Version

**Framework**: v4.1.0
**Constitution**: v3.0.0 (16 Principles)
**Architecture**: Plugin-First (v4.1) with Command Bridge
