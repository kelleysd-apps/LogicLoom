# Final Research Report: Recursive Autonomous Dev-Loop Plugin

**Research ID**: 20260207-095051-recursive-dev-loop
**Date**: 2026-02-07
**Synthesized By**: Research Synthesizer Agent
**Inputs**: Pass 1 (Primary Sources), Pass 2 (Community), Pass 3 (Comparative Analysis)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Key Findings with Confidence Levels](#2-key-findings-with-confidence-levels)
3. [Recommended Architecture](#3-recommended-architecture)
4. [Cross-Referenced Recommendations](#4-cross-referenced-recommendations)
5. [Dissenting Opinions](#5-dissenting-opinions)
6. [Risk Assessment](#6-risk-assessment)
7. [Implementation Roadmap](#7-implementation-roadmap)
8. [Source References](#8-source-references)
9. [Actionable Next Steps](#9-actionable-next-steps)

---

## 1. Executive Summary

This report synthesizes findings from three independent research passes investigating the feasibility, architecture, and implementation strategy for a recursive autonomous dev-loop plugin (`sdd-recursive-dev-loop`) within the SDD Agentic Framework. The research covered official API documentation and Claude Code internals (Pass 1), community projects, real-world implementations, and lessons learned from production autonomous coding systems (Pass 2), and detailed comparative analysis of architecture options, cost models, safety approaches, and RL mechanisms (Pass 3).

The core concept is a plugin that autonomously executes a full development cycle -- research, specification, planning, implementation, testing, evaluation -- in a recursive loop, using a multi-LLM council (Claude, GPT, Gemini) for quality gating, and continuing iterations until a configurable quality threshold is met. The research confirms this is technically feasible using Claude Code's existing infrastructure. The Stop hook system provides a natural recursive loop mechanism, Agent Teams enable parallel council coordination, and the framework's existing RL feedback system can be extended for multi-LLM evaluation. The Ralph Wiggum pattern -- a simple bash loop with fresh context per iteration and git as the memory layer -- has been independently validated by dozens of community implementations and is now an officially supported pattern within Claude Code itself.

However, all three researchers converge on critical warnings: the originally proposed 99% quality threshold is unrealistic for current AI capabilities (community data shows instance-level success rates of 36% when all constraints must be simultaneously satisfied); cost management is non-negotiable (a 50-iteration loop can easily exceed $100); and autonomous execution without sandboxing and branch locking is dangerous (the SaaStr incident of 2025 demonstrated that agents can execute destructive database operations and fabricate logs to cover their tracks). The recommended path is a phased implementation starting with the core loop mechanism and branch-locked safety model, adding the multi-LLM council in Phase 2, RL self-improvement in Phase 3, and graduated autonomy in Phase 4.

### Top 5 Most Important Findings

1. **The Stop hook is the recursive loop mechanism.** Claude Code's Stop hook (agent-based) can check quality grades and force continuation when below threshold, with built-in `stop_hook_active` safety to prevent infinite loops. This is the cleanest implementation path. (All 3 researchers agree.)

2. **Simple majority voting captures 70-80% of the benefit of full multi-agent debate at one-third the cost.** The NeurIPS 2025 spotlight paper "Debate or Vote" proved that debate alone does not improve expected correctness (martingale proof). Targeted interventions with structured rubrics provide the remaining gains. (Passes 2 and 3 agree, supported by academic research.)

3. **The 99% quality threshold is unreachable.** With 80% code coverage (Constitutional Principle II minimum), the theoretical composite score maximum is 96-97%. Even with 90% coverage, 97% is the ceiling. The threshold must be configurable, with a realistic default of 95%. (All 3 researchers agree.)

4. **Git-as-memory and fresh-context-per-iteration are the dominant patterns.** Every successful autonomous coding loop implementation stores state in git and files, not in LLM context windows. The Ralph Wiggum pattern and Anthropic's own engineering harness both validate this. (All 3 researchers agree.)

5. **The SDD framework already provides approximately 75-80% of the required infrastructure.** The plugin architecture, RL feedback system, constitutional governance hooks, command bridge, and specification workflow all exist. The primary new components are the council voting engine, LLM adapter layer, stop-hook loop implementation, and autonomy mode controller. (Passes 1 and 3 agree.)

### Overall Feasibility Assessment

**Verdict: Buildable. Estimated total effort: 6-10 weeks across 4 phases.**

The plugin is technically feasible with current Claude Code capabilities. The main risk is not "can it be built" but "can it be made reliable and cost-effective." The phased approach mitigates this by delivering value at each stage, with each phase validating assumptions before committing to more complexity.

---

## 2. Key Findings with Confidence Levels

### 2.1 Ralph Wiggum Architecture and Its Applicability

**Confidence: Confirmed** -- All 3 researchers agree.

The Ralph Wiggum pattern (Geoffrey Huntley, 2025) is a bash `while true` loop that repeatedly feeds a prompt file to an AI coding agent, with progress persisted in files and git history rather than the LLM context window. Pass 1 documented Claude Code's official Ralph Wiggum plugin using Stop hooks. Pass 2 cataloged 8+ community implementations including the sophisticated `ralph-orchestrator` (Rust orchestrator, 7 AI backends, Hat System, backpressure gates, Telegram HITL). Pass 3 confirmed that the pattern aligns naturally with Claude Code's hook system.

**Key details from cross-referencing:**
- The official Claude Code Ralph plugin uses the Stop hook (Pass 1, Section 8.3), confirming this is the endorsed mechanism.
- Context rotation signals (token tracking, gutter detection) are critical for preventing stuck loops (Pass 2, Section 1).
- The `ralph-orchestrator` project provides the most architecturally relevant reference, with its Hat System mapping to our multi-agent roles and its backpressure gates mapping to our quality gates (Pass 2, Section 1).
- All implementations require `--dangerously-skip-permissions` or equivalent `bypassPermissions` mode (Pass 1 Section 1.3, Pass 2 Section 1).

**Applicability to our plugin**: Direct. The Ralph pattern is the core loop mechanism. The Stop hook is the implementation mechanism. The branch-lock safety model replaces the sandbox requirement.

---

### 2.2 Multi-LLM Council Methodology

**Confidence: Confirmed** -- All 3 researchers agree on the pattern; specific implementation details have minor variance.

Pass 1 documented the API capabilities of GPT (Chat Completions, Structured Outputs, Function Calling) and Gemini (Function Calling, Structured Outputs, built-in MCP support). Pass 2 cataloged Karpathy's LLM Council (three-stage: individual responses, anonymized peer review, chairman synthesis) and PolyCouncil (rubric-based scoring, weighted voting). Pass 3 evaluated five council architectures and recommended a tiered system.

**Which pattern works best?** All researchers converge on a tiered approach:
- **Tier 1 (default)**: Simple majority vote (3 LLMs independently evaluate, 2/3 agreement). Captures 70-80% of debate quality at 33% of the cost.
- **Tier 2 (standard review)**: Weighted vote with RL-adaptive weights. Same cost as Tier 1 but leverages learned model strengths.
- **Tier 3 (deep deliberation)**: Full Karpathy-style debate protocol for critical architecture decisions or when scores fall below 80%.

**Council composition (all 3 agree)**:
- Primary executor: Claude Opus 4.6 (native to Claude Code, best instruction following)
- Member 2: GPT-5 ($1.25/$10 per MTok, strong structured output)
- Member 3: Gemini 2.5 Pro ($1.25/$10, largest context window at 1M)
- Budget alternative: Sonnet 4.5 + o4-mini + Gemini 2.5 Flash

**Invocation mechanism** (minor disagreement resolved):
- Pass 1 recommended Bash tool API calls for simplicity
- Pass 3 recommended Docker MCP Toolkit first with Bash fallback
- Resolution: Hybrid approach (MCP when Docker available, direct API fallback) provides resilience without hard Docker dependency

---

### 2.3 The 99% Threshold

**Confidence: Refuted** -- The originally proposed 99% threshold is unrealistic. All 3 researchers agree.

Pass 2 provided the strongest evidence:
- Instance-level Success Rate (ISR): Even Claude 4.5 Opus achieves only 36.2% when all constraints must be simultaneously satisfied.
- SWE-Bench Pro (long-horizon tasks): Top agents achieve only ~23%.
- Instruction-following degrades progressively as conversation length increases.

Pass 3 performed a mathematical analysis proving that with the current composite score formula and 80% code coverage (Principle II minimum), the theoretical maximum is 97%. Even with 90% coverage, 97% remains the ceiling.

**Recommended replacement**: A configurable threshold system:
- Default: 95% (achievable and demanding)
- Minimum floor: 80% (safety net)
- Maximum: 99% (aspirational, user-configurable)
- Composite scoring: 70% automated metrics (tests, lint, coverage, security) + 30% LLM council evaluation (spec alignment, code quality, docs)

---

### 2.4 Autonomous Execution Safety

**Confidence: Confirmed** -- All 3 researchers converge on a defense-in-depth model.

Pass 1 documented Claude Code's hook-based safety mechanisms: PreToolUse for blocking dangerous operations, PermissionRequest for auto-approving safe operations, and the `bypassPermissions` mode for full autonomy. Pass 2 documented the SaaStr incident (autonomous agent executed `DROP DATABASE` and fabricated logs), Stack Overflow research showing AI creates 1.7x more bugs than humans, and Gartner's prediction that 40%+ of agentic AI projects will be scrapped by 2027. Pass 3 evaluated 5 safety models and recommended a 4-layer hybrid.

**What safety model works?** Constitutional Guard + Branch-Lock + Graduated Trust + Checkpoint Recovery:

- **Layer 1 (Branch Lock)**: PreToolUse hook intercepts and denies all git branch-switching, merging, rebasing, and push commands. Only `git add`, `git commit`, `git status`, `git diff`, and `git log` are permitted.
- **Layer 2 (Constitutional Guard)**: Every Bash command validated against an allowlist. Blocks `rm -rf`, `DROP TABLE`, unauthorized network requests.
- **Layer 3 (Graduated Trust)**: New sessions start with restricted permissions. Successful iterations unlock capabilities. Trust decays 10% per day of inactivity.
- **Layer 4 (Checkpoint Recovery)**: Git commit before each task execution. Automatic rollback on quality score regression >15%.

**Critical requirement (all 3 agree)**: The end-state of a dev-loop session is always a Pull Request for human review, never an auto-merge.

---

### 2.5 Cost Estimates

**Confidence: Confirmed** -- Detailed cost modeling from Pass 3, validated by community data from Pass 2.

**Per council vote** (Standard: Opus + GPT-5 + Gemini Pro): $0.38 per 3-vote session.
**Per council vote** (Budget: Sonnet + o4-mini + Flash): $0.20 per 3-vote session.

**Per dev-loop iteration** (Standard, 5 tasks, including research, execution, council evaluation, debug):
- First iteration (includes specification): ~$3.35
- Subsequent iterations (execution + evaluation): ~$2.70

**Per session by scope**:

| Scope | Tasks | Iterations | Standard Cost | Budget Cost | Time Saved |
|-------|:---:|:---:|:---:|:---:|:---:|
| Small (bug fix) | 2-3 | 1-2 | $2-5 | $0.80-2.00 | 2-4 hours |
| Medium (feature) | 4-6 | 2-3 | $6-15 | $2.50-6.00 | 4-8 hours |
| Large (multi-domain) | 7-12 | 3-5 | $15-40 | $6-16 | 8-16 hours |
| Complex (architecture) | 10-20 | 5-10 | $35-90 | $14-36 | 16-40 hours |

**Key cost insight**: Claude accounts for ~90% of total cost (primary executor + largest council member). External LLMs add only ~10% overhead for the council. Even the most expensive configuration provides 27-300x ROI compared to developer time.

**Cost optimization strategies**: Prompt caching (90% savings on cached input), batch API for council votes (50% savings), budget council for early iterations (60% overall savings).

---

### 2.6 RL Self-Improvement Mechanisms

**Confidence: Confirmed** -- All 3 researchers agree on a phased approach building on existing infrastructure.

Pass 1 documented the existing SDD RL system: EMA algorithm with learning rate 0.1, `collect-feedback.sh`, `sync-metrics.sh`, `grpo-optimizer.sh`, and `credit-assignment.sh`. Pass 2 documented self-improving systems including Godel Agent (runtime self-modification), EvoAgentX (prompt evolution via EvoPrompt), SAFLA (hybrid memory + meta-cognition), and AlphaEvolve (evolutionary coding with ensemble of Gemini models). Pass 3 evaluated 5 RL mechanisms and recommended a phased evolution.

**Recommended phased approach**:
- **Phase 1 (Launch)**: Enhanced EMA + UCB1 exploration bonus. Score = EMA_weight + C * sqrt(ln(N) / n_skill). Builds on existing infrastructure.
- **Phase 2 (Month 2-3)**: Prompt evolution. Maintain 3-5 prompt variants per skill, mutate top performers, prune low performers.
- **Phase 3 (Month 4-6)**: In-context RL. Leverage LLMs' ability to perform RL through prompting (validated by arXiv:2506.06303). No training infrastructure needed.
- **Phase 4 (Month 6+, Optional)**: Full SAGE-style RL with training pipeline. Only if earlier phases show insufficient improvement.

---

### 2.7 Claude Code Hooks for Automation

**Confidence: Confirmed** -- Pass 1 provides definitive documentation; Passes 2 and 3 validate the approach.

The hooks system is the primary automation mechanism. The full event lifecycle supports every phase of the dev-loop:

| Hook Event | Dev-Loop Role |
|-----------|--------------|
| `SessionStart` | Initialize dev-loop state, load config, detect existing session for resume |
| `UserPromptSubmit` | Detect `/dev-loop` command, inject context, modify governance for autonomy |
| `PreToolUse` | Auto-approve safe operations, block branch switching, enforce allowlist |
| `PermissionRequest` | Auto-approve expected permission dialogs during autonomous execution |
| `PostToolUse` | Track progress, update metrics after each tool execution |
| `SubagentStart` | Inject council context into subagents |
| `SubagentStop` | Collect subagent results, update progress tracking |
| `Stop` | Check quality grade, trigger recursive continuation (THE CORE LOOP) |
| `TeammateIdle` | Enforce quality gates before a teammate stops |
| `TaskCompleted` | Validate task completion criteria |
| `PreCompact` | Preserve critical dev-loop state before context compaction |
| `SessionEnd` | Generate final session report, cleanup state files |

**Critical Stop hook mechanism**: When the Stop hook returns `decision: "block"`, Claude continues working with the provided reason. The `stop_hook_active` field prevents infinite loops by detecting when Claude is already continuing due to a Stop hook. This is the recursive loop.

**Agent-based hooks** can run up to 50 turns with full tool access, enabling complex verification (e.g., running test suites, checking quality scores) before deciding whether to continue the loop.

---

### 2.8 Plugin Self-Creation Capabilities

**Confidence: Confirmed** -- The framework already supports plugin creation via `/create-plugin`.

Pass 1 documented the plugin architecture (Principle XVI) and the command bridge that automatically syncs plugin commands. Pass 3 detailed the integration architecture for `sdd-recursive-dev-loop`:

```
plugins/sdd-recursive-dev-loop/
  .claude-plugin/plugin.json    # Standard manifest with rl_metrics
  commands/dev-loop.md          # Auto-synced via command bridge
  skills/                       # Auto-discovered via skill-index.json
  agents/                       # Standard delegation protocol
  hooks/hooks.json              # Stop hook + PreToolUse hook
  scripts/                      # LLM adapters, quality scoring, session state
  config/                       # Configuration files
```

The existing `sync-plugin-commands.sh` bridge will automatically make `/dev-loop` available as a slash command. No manual registration is needed.

---

### 2.9 Interrupt/Resume Architecture

**Confidence: Confirmed** -- All 3 researchers agree on a hybrid checkpoint + git approach.

Pass 2 documented multiple patterns: Anthropic's two-agent harness (initializer + coding agent), LangGraph's `interrupt()` function with checkpointer, Ralph Orchestrator's Telegram-based HITL, and community consensus on checkpoint practices. Pass 3 evaluated 4 approaches and recommended the hybrid.

**Recommended architecture**:
- **Primary**: Session state file (`.claude/dev-loop-session.local.json`) updated at every phase boundary. Small (<100KB), fast to load.
- **Secondary**: Git-based milestones. Commit at each task completion, tag at each iteration boundary (`dev-loop-iter-N`).
- **Crash recovery**: Stop hook saves state on clean exit. On startup, check for orphaned session files. Offer resume or discard.
- **Event log** (optional): Append-only `.docs/dev-loop-sessions/<session-id>/events.jsonl` for debugging and audit.

**Key design decision from Anthropic's engineering team**: Use JSON files for state tracking, not Markdown, because "the model is less likely to inappropriately change or overwrite JSON files."

---

## 3. Recommended Architecture

Based on the synthesis of all three research passes, this section presents the recommended architecture for the `sdd-recursive-dev-loop` plugin.

### 3.1 Overall Workflow (Step by Step)

```
USER: /dev-loop "Build feature X" [--quality 95] [--budget $20] [--council standard]
  |
  v
PHASE 0: INITIALIZATION
  - Detect existing session (resume?) or create new
  - Load config (quality threshold, budget cap, iteration limit)
  - Lock to current branch (PreToolUse hook activated)
  - Validate API keys for council members (GPT, Gemini)
  - Initialize session state file (.claude/dev-loop-session.local.json)
  - Git checkpoint: tag dev-loop-start
  |
  v
PHASE 1: RESEARCH (Multi-LLM Council)
  - Dispatch research query to 3 LLMs in parallel:
    * Claude: Codebase analysis, existing patterns, framework integration
    * GPT-5: Alternative approaches, industry best practices
    * Gemini 2.5 Pro: Documentation review, API research, long-context analysis
  - Each LLM returns structured research findings (JSON schema enforced)
  |
  v
PHASE 2: COUNCIL VOTE ON SCOPE
  - All 3 LLMs review combined research
  - Each votes on: scope (small/medium/large), approach, task breakdown
  - Tier 1: Simple majority vote (2/3 agreement)
  - If no agreement: escalate to Tier 2 (weighted vote) or Tier 3 (debate)
  - Produce scoping decision with rationale
  |
  v
PHASE 3: SPECIFICATION
  - Invoke existing /specification workflow (sdd-specification plugin)
  - Feed council-approved scope and approach
  - Generate: spec.md, plan.md, tasks.md
  - Automatic quality gating via existing refinement engine
  |
  v
PHASE 4: EXECUTION (per task)
  - For each task in priority order:
    1. Git checkpoint: commit current state
    2. Execute task (Claude Opus as primary)
    3. Run automated quality checks (tests, lint, type-check)
    4. If task fails: invoke /debug workflow, retry (max 3 attempts)
    5. If task succeeds: mark complete, update session state
  - Budget check after each task
  |
  v
PHASE 5: QUALITY ASSESSMENT
  - Automated scoring (70% of total):
    * Test pass rate (35% of automated)
    * Code coverage (20% of automated)
    * Constitutional compliance (20% of automated)
    * Lint + type-check (15% of automated)
    * Security scan (10% of automated)
  - LLM council scoring (30% of total):
    * Spec alignment (40% of council)
    * Code quality/design (30% of council)
    * Documentation quality (20% of council)
    * Performance assessment (10% of council)
  - Compute composite quality score
  |
  v
PHASE 6: DECISION GATE (Stop Hook)
  - If quality >= threshold AND all tasks complete:
    -> PHASE 7: FINALIZE
  - If quality < threshold AND iterations < max AND budget remaining:
    -> Identify lowest-scoring dimensions
    -> Generate targeted improvement plan
    -> Increment iteration counter
    -> Return to PHASE 4 with improvement focus
  - If iterations >= max OR budget exhausted:
    -> PHASE 7: FINALIZE (best-effort)
  |
  v
PHASE 7: FINALIZE
  - Run /finalize compliance check
  - Generate session report (iterations, quality trajectory, cost, council votes)
  - Update RL metrics (collect-feedback.sh, sync-metrics.sh)
  - Present PR-ready summary to user
  - WAIT FOR USER: Approve PR creation (Principle VI)
```

### 3.2 Council Design

**Pattern**: Tiered council with auto-escalation.

**Tier 1 -- Majority Vote (Default)**:
- Each LLM independently evaluates the output against a structured rubric
- Rubric dimensions: correctness, completeness, code quality, test coverage, spec alignment
- Each dimension scored 0-100 with chain-of-thought reasoning
- Final score: weighted average of all dimensions
- Agreement threshold: 2 of 3 scores within 10 points of each other
- If no agreement: escalate to Tier 2

**Tier 2 -- Weighted Vote**:
- Same as Tier 1, but each LLM's vote weighted by its demonstrated domain accuracy
- Weights initialized to equal (0.33/0.33/0.33) and adjusted via RL after each session
- Weight formula: `weight(model, domain) = EMA_success(model, domain) / sum(EMA_success(all, domain))`
- Triggered: automatically when Tier 1 fails to reach agreement, or for standard code reviews

**Tier 3 -- Full Debate (Karpathy Protocol)**:
- Stage 1: Independent evaluation (same as Tier 1)
- Stage 2: Each LLM receives anonymized evaluations from the other two, writes critique
- Stage 3: Chairman model (Claude Opus) synthesizes all evaluations and critiques into final verdict
- Triggered: user request (`--council deep`), critical architecture decisions, quality score below 80%

**Anonymization**: During peer review, model identities are stripped. Evaluations are labeled "Reviewer A", "Reviewer B", "Reviewer C" to prevent brand-bias (Karpathy's LLM Council found models preferred GPT-5.1 outputs regardless of quality).

**Structured output enforcement**: All council responses must conform to a JSON schema with required fields: `score`, `reasoning`, `dimension_scores`, `issues_found`, `recommendations`. GPT uses `response_format: json_schema`, Gemini uses `responseSchema`, Claude uses `--json-schema`.

### 3.3 Safety Model

**4-Layer Defense-in-Depth**:

**Layer 1 -- Branch Lock**:
- At dev-loop start, record current branch name in session state
- PreToolUse hook on Bash tool intercepts all git commands
- ALLOW: `git add`, `git commit` (with `[dev-loop]` prefix), `git status`, `git diff`, `git log`, `git tag`
- DENY: `git checkout`, `git switch`, `git branch -d/-D`, `git merge`, `git rebase`, `git push`, `git stash`, `git reset --hard`
- Implementation: PreToolUse hook reads Bash command from stdin JSON, regex matches against deny list, returns `permissionDecision: "deny"` with reason

**Layer 2 -- Operation Allowlist**:
- ALLOW: file read/write/edit, test execution, lint, build commands, npm/pip install (with version pinning)
- BLOCK: `rm -rf` (outside project dir), `DROP TABLE/DATABASE`, `curl` to unknown hosts, `sudo` commands
- DEFER: operations requiring unset API keys, external service calls not in allowlist
- Implementation: PreToolUse hook with configurable allowlist in `config/operation-allowlist.json`

**Layer 3 -- Graduated Trust**:
- Session starts at trust level 1 (basic file operations + test execution)
- After 2 successful iterations: trust level 2 (add npm install, build commands)
- After 4 successful iterations: trust level 3 (add external API calls from allowlist)
- Trust decays 10% per day of inactivity across sessions
- Trust resets to 0 on any safety violation

**Layer 4 -- Checkpoint Recovery**:
- Git commit before each task execution
- Git tag at each iteration boundary: `dev-loop-iter-{N}`
- Automatic rollback (git reset to last tag) if quality score regresses by more than 15%
- User can manually rollback to any checkpoint via `/dev-loop rollback iter-3`

### 3.4 Performance Grading

**Composite score formula**:

```
QUALITY = (AUTOMATED * 0.70) + (COUNCIL * 0.30)

AUTOMATED (70%):
  test_pass_rate * 0.245
  + code_coverage * 0.140
  + constitutional_compliance * 0.140
  + lint_typecheck * 0.105
  + security_scan * 0.070

COUNCIL (30%):
  spec_alignment * 0.120
  + code_quality * 0.090
  + documentation * 0.060
  + performance * 0.030
```

**Threshold configuration**:
- `default_threshold = 95%` (achievable, demanding)
- `min_threshold = 80%` (safety floor, cannot go lower)
- `max_threshold = 99%` (aspirational, user-configurable via `--quality 99`)
- Configurable per session: `/dev-loop "task" --quality 95`

**Improvement tracking**: Track quality score trajectory across iterations. If score plateaus (less than 2% improvement across 3 consecutive iterations), trigger "plateau escape" -- council identifies the bottleneck dimension and generates a targeted improvement plan.

### 3.5 RL Improvement Loop

**Phase 1 (Launch): Enhanced EMA + UCB1**

Extend the existing RL system with exploration:

```
score(skill) = EMA_weight + C * sqrt(ln(N) / n_skill)

Where:
  EMA_weight = existing exponential moving average (learning rate 0.1)
  C = exploration constant (default 1.41, sqrt(2))
  N = total invocations across all skills
  n_skill = invocations of this specific skill
```

New metrics tracked per dev-loop session:
- `iterations`: number of loop iterations
- `quality_achieved`: final composite score
- `total_cost_usd`: total API cost
- `council_agreement_rate`: how often the 3 LLMs agreed
- `per_provider_accuracy`: how often each provider's vote matched final outcome
- `improvement_per_iteration`: quality delta per iteration

Council weights updated after each session based on per-provider accuracy.

**Phase 2+ (Future)**: Prompt evolution, in-context RL, and optionally full SAGE-style RL as described in Section 2.6.

### 3.6 Cost Controls

- **Per-session budget cap**: Configurable, default $50. Hard stop at cap.
- **Per-iteration tracking**: Cost per iteration logged in session state file.
- **Budget alerts**: Notifications at 50%, 75%, 90% of budget.
- **Budget council switching**: Automatically switch from Standard to Budget council when 70% of budget consumed.
- **Kill switches**: `/dev-loop stop` for graceful termination, Ctrl+C for immediate stop (with state save).
- **Iteration limits**: Configurable, default 10. Hard stop at limit.
- **Timeout**: Configurable session timeout, default 2 hours.

### 3.7 Integration with Existing SDD Framework

**Plugin architecture (Principle XVI)**: Standard plugin at `plugins/sdd-recursive-dev-loop/` with manifest, commands, skills, agents, hooks, scripts, and config directories.

**Command bridge**: The `/dev-loop` command is automatically synced to `.claude/commands/dev-loop.md` via the existing `sync-plugin-commands.sh` bridge.

**RL feedback**: Uses existing `collect-feedback.sh` and `sync-metrics.sh` with extended metrics schema at `.docs/rl-metrics/dev-loop-performance.json`.

**Governance integration**: The `governance-preflight.sh` hook detects active dev-loop sessions and injects dev-loop context (iteration number, quality score, current phase) instead of standard governance context. Constitutional principles remain authoritative outside dev-loop sessions.

**Workflow reuse**: Invokes existing `/specification`, `/debug`, and `/finalize` workflows from the sdd-specification, sdd-debug, and sdd-git plugins respectively.

**Hook ordering**: Governance hooks fire first (protected plugin), dev-loop hooks fire second (additive restrictions), other plugin hooks follow normal ordering.

---

## 4. Cross-Referenced Recommendations

### 4.1 Architecture Recommendations

| Topic | Pass 1 | Pass 2 | Pass 3 | Agreement |
|-------|--------|--------|--------|-----------|
| Core loop mechanism | Stop hook (agent-based) | Ralph pattern (bash loop) | Stop hook + checkpoint | **Converge**: Stop hook implements Ralph pattern natively |
| Orchestration | Agent Teams for council coordination | Planner/Worker/Judge hierarchy (Cursor) | Tiered council with auto-escalation | **Converge**: Agent Teams as mechanism, P/W/J as roles |
| Multi-LLM invocation | Bash tool calling APIs directly | MCP servers where available | Hybrid (MCP first, Bash fallback) | **Minor variance**: Pass 1 prefers simplicity, Pass 3 prefers resilience. **Resolution**: Hybrid approach |
| Subagent limitation | Subagents cannot spawn subagents | N/A | N/A | **Pass 1 only**: Critical constraint -- loop must be managed from main thread |
| Context management | Auto-compaction at 95% context | Fresh context per iteration (Ralph) | Checkpoint + git milestones | **Converge**: Fresh context per iteration with git as memory |

### 4.2 Council Methodology

| Topic | Pass 1 | Pass 2 | Pass 3 | Agreement |
|-------|--------|--------|--------|-----------|
| Voting pattern | Structured voting with schemas | Simple majority (NeurIPS finding) | Tiered (majority -> weighted -> debate) | **Converge**: Tiered with majority as default |
| Model selection | Claude + GPT + Gemini | Different models for different roles (Aider, AlphaEvolve) | Opus + GPT-5 + Gemini 2.5 Pro | **Agree**: Multi-model, role-specific |
| Anonymization | Not addressed | Karpathy found brand-bias | Recommended for peer review | **Converge**: Anonymize during evaluation |
| Debate value | Documented debate patterns | NeurIPS: "debate alone does not improve expected correctness" | 70-80% of benefit from majority vote alone | **Converge**: Debate is overrated; structured rubrics matter more |

### 4.3 Safety and Autonomy

| Topic | Pass 1 | Pass 2 | Pass 3 | Agreement |
|-------|--------|--------|--------|-----------|
| Permission mode | `bypassPermissions` + PreToolUse hooks | `--dangerously-skip-permissions` required | Constitutional Guard + Branch-Lock | **Converge**: Full permission bypass with hook-enforced safety |
| Branch safety | PreToolUse hook denying branch commands | Branch-only development, never auto-merge | Branch-Lock as Layer 1 of safety model | **Unanimous** |
| End state | Not specified | PR-based completion, human review | PR, never auto-merge | **Converge**: Always PR |
| Sandbox | Container isolation available via Docker | SaaStr incident proves sandboxing needed | Branch-lock sufficient if hooks enforced | **Minor variance**: Pass 2 wants stronger isolation. **Resolution**: Branch-lock + hook allowlist as minimum; container sandbox as optional enhancement |

### 4.4 Performance Grading

| Topic | Pass 1 | Pass 2 | Pass 3 | Agreement |
|-------|--------|--------|--------|-----------|
| 99% threshold | Not directly addressed | Unrealistic (ISR 36.2%) | Unreachable (math: 97% ceiling) | **Converge**: Replace with configurable default of 95% |
| Grading approach | RLAIF-adapted evaluation | Multi-dimensional (test rate + lint + build + LLM judge) | Hybrid (70% automated + 30% LLM council) | **Converge**: Hybrid multi-dimensional |
| Evaluation method | Constitutional AI principles-based | Pairwise comparison outperforms pointwise | Structured rubrics with chain-of-thought | **Converge**: Rubric-based with chain-of-thought reasoning |

### 4.5 Cost Optimization

| Topic | Pass 1 | Pass 2 | Pass 3 | Agreement |
|-------|--------|--------|--------|-----------|
| Budget controls | `maxTurns` limits in SDK | Iteration limits + token budget caps + time limits | Per-session cap ($50 default), per-iteration tracking | **Converge**: Multi-level budget controls |
| Cost tracking | Not detailed | $50-100+ per 50-iteration loop (community data) | Detailed per-phase modeling ($2-90 per session) | **Converge**: Pass 3 provides definitive numbers |
| Optimization | Not detailed | Use cheaper models for breadth (AlphaEvolve) | Prompt caching (90% savings), batch API (50%), budget council switching | **Converge**: Layer multiple optimization strategies |

### 4.6 RL and Self-Improvement

| Topic | Pass 1 | Pass 2 | Pass 3 | Agreement |
|-------|--------|--------|--------|-----------|
| Base mechanism | Existing EMA (learning rate 0.1) | Prompt evolution (EvoAgentX), self-modification (Godel Agent) | EMA + UCB1 exploration (Phase 1) | **Converge**: Extend existing EMA, add exploration |
| Advanced mechanisms | GRPO optimizer already in framework | AlphaEvolve (evolutionary + multi-model) | Phased: MAB -> Prompt Evolution -> In-Context RL -> Full RL | **Converge**: Phased approach, don't over-engineer at launch |
| In-context RL | Not addressed | Not directly addressed | arXiv:2506.06303 validates prompt-based RL | **Pass 3 adds**: In-context RL as Phase 3 (no training infra needed) |

---

## 5. Dissenting Opinions

### 5.1 Multi-LLM Invocation Method

**Pass 1 (Primary Sources)** recommended direct API calls via the Bash tool, arguing that "MCP servers add complexity and potential failure points. Direct API calls via Bash are simpler, more reliable, and give full control over request/response schemas."

**Pass 3 (Comparative)** recommended Docker MCP Toolkit first with Bash fallback, arguing for container isolation, managed credentials, and a unified interface.

**Resolution**: The hybrid approach (MCP when Docker is available, direct API when not) was adopted. This respects Pass 1's simplicity concern while gaining Pass 3's resilience benefit. The direct API path serves as both a fallback and a simpler initial implementation.

### 5.2 Sandbox Requirements

**Pass 2 (Community)** strongly emphasized sandboxed execution, citing the SaaStr incident and community consensus that "coding agents should be treated as high-risk identities." Pass 2 viewed branch-locking as insufficient.

**Pass 3 (Comparative)** viewed the Constitutional Guard + Branch-Lock as sufficient, noting that the sandbox-first approach imposes "2x overhead" and "very high implementation complexity."

**Resolution**: The recommended architecture uses Branch-Lock + Constitutional Guard as the primary safety model, with container sandboxing available as an optional enhancement for high-security environments. The rationale is that the hook-enforced allowlist prevents the specific class of incidents documented (destructive database operations, unauthorized network calls) without the overhead of full containerization. However, Pass 2's warnings should be taken seriously -- if the plugin is ever used in environments with production database access, container isolation should be mandatory.

### 5.3 Council Value vs. Cost

**Pass 2 (Community)** noted that "tests are the only reliable quality signal" and that "LLM self-assessment is unreliable." This implies the multi-LLM council adds cost without proportional quality improvement.

**Pass 3 (Comparative)** quantified the council's contribution at 70-85% of debate quality improvement at 40% of the cost, and showed that external LLMs add only ~10% overhead to total session cost.

**Resolution**: The council is included but with cost awareness. The default Tier 1 (majority vote) adds minimal cost. The council's primary value is catching blind spots that automated tests miss (architecture quality, spec alignment, documentation completeness). The 30% weight given to council scoring in the hybrid grading system reflects this -- tests remain dominant at 70%.

### 5.4 Agent Teams vs. Task Tool

**Pass 1 (Primary Sources)** recommended Agent Teams as "the ideal coordination mechanism for the multi-LLM council," noting inter-agent communication, shared task lists, and delegate mode.

However, Agent Teams are marked as **experimental** (requiring opt-in via environment variable), have no session resumption with in-process teammates, and cannot resume sessions. This conflicts with the interrupt/resume requirement.

**Resolution**: Agent Teams are the aspirational target for Phase 2+ but should not be a hard dependency for Phase 1. The MVP should use the simpler Task tool for subagent delegation and Bash-based LLM invocation for the council. Agent Teams can replace Task tool coordination once the experimental flag is removed and session resumption is supported.

---

## 6. Risk Assessment

### 6.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|:---:|:---:|---|
| **Context window exhaustion on long loops** | High | High | Fresh context per iteration (Ralph pattern), progressive compression, subagent delegation. PreCompact hook preserves critical state. |
| **Stop hook reliability (infinite loops)** | Medium | High | Multiple termination conditions: `stop_hook_active` check, iteration limit, budget cap, timeout, quality plateau detection. Watchdog timer as backstop. |
| **Rate limiting from external LLMs** | Medium | Medium | Fallback to available providers, retry with exponential backoff, cache council results, continue with reduced council (2/3 or 1/3). |
| **Hook ordering conflicts** | Medium | Medium | Strict ordering: governance first, dev-loop second. Integration tests for hook chain behavior. |
| **Subagent nesting limitation** | Low | Medium | Managed from main thread. Council votes delegated via Bash (not subagents). Agent Teams resolve this in Phase 2. |
| **API schema drift (GPT/Gemini)** | Low | Medium | Adapter layer isolates API specifics. Schema validation on responses. Graceful degradation on malformed responses. |

### 6.2 Cost Risks

| Risk | Probability | Impact | Mitigation |
|------|:---:|:---:|---|
| **Runaway spending (zombie loops)** | Medium | High | Per-session budget cap (hard stop), per-iteration cost tracking, budget alerts at 50/75/90%, automatic downgrade to budget council at 70%. |
| **Unexpected pricing changes** | Low | Medium | Adapter layer can swap providers. Budget council fallback. Cost per session logged for trend analysis. |
| **Token waste on stuck iterations** | Medium | Medium | Gutter detection (identify repeated failures, file thrashing). Plateau escape after 3 iterations with <2% improvement. |
| **Council cost without quality gain** | Medium | Low | Council adds only ~10% to total cost. Configurable council tiers allow cost reduction. RL tracks council value score. |

### 6.3 Safety Risks

| Risk | Probability | Impact | Mitigation |
|------|:---:|:---:|---|
| **Destructive git operations** | Low (mitigated) | Critical | 4-layer defense: branch lock (PreToolUse), operation allowlist, graduated trust, checkpoint recovery. |
| **Unauthorized external calls** | Low (mitigated) | High | Network call allowlist in PreToolUse hook. Unknown hosts blocked. API keys validated at session start. |
| **Constitutional bypass exploited** | Low | Critical | Governance hooks fire before dev-loop hooks (strict ordering). Audit log for all actions. Trust reset on any safety violation. |
| **Data exfiltration via LLM council** | Low | High | Only send code context to council (not secrets, credentials). PreToolUse hook strips `.env` content from Bash commands. |
| **Permission escalation** | Low | Critical | Graduated trust starts at level 1. `bypassPermissions` scoped to dev-loop agent only. Main session retains normal permissions. |

### 6.4 Quality Risks

| Risk | Probability | Impact | Mitigation |
|------|:---:|:---:|---|
| **Infinite loops without progress** | Medium | Medium | Iteration limit (default 10), plateau detection (3 iterations with <2% improvement triggers escape), quality regression rollback (>15% drop). |
| **AI creates more bugs than it fixes** | Medium | Medium | Test-first validation (Principle II), multi-dimensional grading, council cross-review. Stack Overflow data (1.7x bugs vs. humans) accepted and managed via testing. |
| **Prompt decay in long sessions** | Medium | Medium | Fresh context per iteration (Ralph pattern). Critical state in JSON files, not in prompts. Exponential decay on instruction age. |
| **Self-bias in LLM evaluation** | Medium | Low | Council evaluator is a different model than the executor. Anonymized evaluation prevents brand-bias. Rubric-based scoring reduces subjectivity. |
| **Over-optimization for metrics** | Low | Medium | Multi-dimensional grading prevents gaming single metrics. Council evaluation captures qualitative dimensions. User-configurable weights. |

---

## 7. Implementation Roadmap

### Phase 1: MVP -- Core Loop (Estimated: 2-3 weeks)

**Goal**: A working recursive loop that executes tasks, runs tests, grades quality, and iterates.

**Build**:
1. Plugin scaffold (`sdd-recursive-dev-loop` via `/create-plugin`)
2. `/dev-loop` command (bridge-discovered)
3. Session state management (JSON file, load/save/resume)
4. Branch-lock PreToolUse hook
5. Stop hook implementing the recursive loop
6. Quality scoring engine (automated metrics only -- tests, lint, coverage)
7. Iteration limit and budget cap controls
8. Session report generator

**Does NOT include**: Multi-LLM council, RL extensions, graduated trust, Agent Teams.

**Quality bar for Phase 1**: Single-model (Claude only) loop that can take a task description, execute it, test it, and iterate until quality threshold met or limits reached. Produces a PR-ready branch.

**Estimated cost to run**: $2-15 per session (Claude only, no council overhead).

### Phase 2: Multi-LLM Council (Estimated: 2-3 weeks)

**Goal**: Add GPT and Gemini as council members for quality evaluation and research diversity.

**Build**:
1. LLM adapter layer (OpenAI, Gemini, with MCP fallback)
2. Council voting engine (Tier 1: majority vote)
3. Structured output schemas for council responses
4. Council integration into quality assessment (30% council weight)
5. Council integration into research phase (parallel research)
6. Anonymization for peer review
7. Council cost tracking and budget auto-switching

**Upgrade from Phase 1**: Quality scoring becomes hybrid (70% automated + 30% council). Research phase uses 3 LLMs instead of 1.

**Estimated cost to run**: $6-40 per session (Standard council).

### Phase 3: Self-Improvement (Estimated: 2-3 weeks)

**Goal**: Add RL-based improvement that makes the system better over time.

**Build**:
1. Enhanced EMA + UCB1 exploration bonus for skill selection
2. Per-provider council performance tracking
3. Council weight adaptation based on per-domain accuracy
4. Prompt evolution (3-5 variants per skill, mutation, selection)
5. Dev-loop performance metrics (`.docs/rl-metrics/dev-loop-performance.json`)
6. Cross-session learning (guardrails accumulation, strategy preferences)

**Upgrade from Phase 2**: System learns which models are best for which tasks. Prompt quality improves over time. Council weights reflect demonstrated capability.

### Phase 4: Graduated Autonomy (Estimated: 2-3 weeks)

**Goal**: Progressive trust model that expands capabilities as the system proves itself.

**Build**:
1. Trust level system (1-3, with trust decay)
2. Dynamic operation allowlist (expands with trust)
3. Tiered council (auto-escalate to Tier 2/3 based on task complexity)
4. In-context RL (include last N outcomes in prompts)
5. Agent Teams integration (when no longer experimental)
6. Advanced plateau escape strategies
7. Plugin self-modification capabilities (prompt evolution applied to own prompts)

**Upgrade from Phase 3**: System earns expanded permissions. Council depth adapts to task importance. Full RLAIF loop operational.

### Effort Summary

| Phase | Scope | Effort | Cumulative |
|-------|-------|--------|------------|
| Phase 1: MVP | Core loop, single-model, safety | 2-3 weeks | 2-3 weeks |
| Phase 2: Council | Multi-LLM, voting, research | 2-3 weeks | 4-6 weeks |
| Phase 3: Self-Improvement | RL extensions, prompt evolution | 2-3 weeks | 6-9 weeks |
| Phase 4: Full Autonomy | Graduated trust, advanced features | 2-3 weeks | 8-12 weeks |

---

## 8. Source References

### Official Documentation

1. [Claude Code Docs - Create Custom Subagents](https://code.claude.com/docs/en/sub-agents) -- Subagent architecture, configuration, limitations
2. [Claude Code Docs - Hooks Reference](https://code.claude.com/docs/en/hooks) -- Complete hook event lifecycle, auto-approval, Stop hook
3. [Claude Code Docs - Agent Teams](https://code.claude.com/docs/en/agent-teams) -- Team coordination, TeammateIdle, TaskCompleted hooks
4. [Claude Code Docs - Run Programmatically](https://code.claude.com/docs/en/headless) -- Agent SDK, headless mode, permission modes
5. [OpenAI API Reference - Chat Completions](https://platform.openai.com/docs/api-reference/chat) -- GPT API integration
6. [OpenAI Docs - Structured Outputs](https://platform.openai.com/docs/guides/structured-outputs) -- JSON schema enforcement
7. [Gemini API Docs - Function Calling](https://ai.google.dev/gemini-api/docs/function-calling) -- Gemini function calling, structured output
8. [Docker MCP Catalog and Toolkit](https://docs.docker.com/ai/mcp-catalog-and-toolkit/) -- 310+ MCP servers, container isolation
9. [Git - githooks Documentation](https://git-scm.com/docs/githooks) -- pre-checkout, pre-commit hooks

### Academic Papers

10. [Constitutional AI: Harmlessness from AI Feedback](https://arxiv.org/abs/2212.08073) (Anthropic, 2022) -- RLAIF methodology, constitutional principles
11. [Debate or Vote: Which Yields Better Decisions in Multi-Agent LLMs?](https://arxiv.org/abs/2508.17536) (NeurIPS 2025 Spotlight) -- Martingale proof that debate alone does not improve expected correctness
12. [Voting or Consensus? Decision-Making in Multi-Agent Systems](https://aclanthology.org/2025.findings-acl.606.pdf) (ACL 2025) -- Majority voting accounts for most performance gains
13. [Fault-Tolerant Sandboxing for AI Coding Agents](https://arxiv.org/abs/2512.12806) (2025) -- Transactional sandboxing, 10-15% overhead
14. [Multi-Armed Bandits Meet Large Language Models](https://arxiv.org/abs/2501.xxxxx) (IBM Research, AAAI 2026) -- UCB1 for LLM optimization
15. [Reward Is Enough: LLMs Are In-Context Reinforcement Learners](https://arxiv.org/abs/2506.06303) (2025) -- Prompt-based RL without weight updates
16. [Reinforcement Learning for Self-Improving Agent with Skill Library (SAGE)](https://arxiv.org/abs/2512.17102) (2025) -- GRPO + skill library

### GitHub Projects

17. [karpathy/llm-council](https://github.com/karpathy/llm-council) -- Multi-LLM consensus, three-stage debate protocol
18. [mikeyobrien/ralph-orchestrator](https://github.com/mikeyobrien/ralph-orchestrator) -- Rust orchestrator, 7 AI backends, Hat System, backpressure gates
19. [fstandhartinger/ralph-wiggum](https://github.com/fstandhartinger/ralph-wiggum) -- Spec-driven autonomous dev with SpecKit
20. [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) -- Claude Code specific with dual-condition exit gate
21. [SWE-agent/SWE-agent](https://github.com/SWE-agent/SWE-agent) -- Agent-Computer Interface for code editing
22. [OpenHands/OpenHands](https://github.com/OpenHands/OpenHands) -- Event-sourced state model, modular SDK
23. [TrentPierce/PolyCouncil](https://github.com/TrentPierce/PolyCouncil) -- Multi-model deliberation engine
24. [EvoAgentX/EvoAgentX](https://github.com/EvoAgentX/EvoAgentX) -- Prompt evolution via EvoPrompt
25. [ruvnet/SAFLA](https://github.com/ruvnet/SAFLA) -- Self-Aware Feedback Loop Algorithm
26. [Arvid-pku/Godel_Agent](https://github.com/Arvid-pku/Godel_Agent) -- Runtime self-modification with RL

### Community Posts and Articles

27. [Anthropic - Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) -- Two-agent harness, JSON for state tracking
28. [Cursor - Scaling Long-Running Autonomous Coding](https://cursor.com/blog/scaling-agents) -- Planner/Worker/Judge, multi-model roles, prompting > infrastructure
29. [Addy Osmani - Self-Improving Coding Agents](https://addyosmani.com/blog/self-improving-agents/) -- Four-channel memory, failure modes
30. [Addy Osmani - The 80% Problem in Agentic Coding](https://addyo.substack.com/p/the-80-problem-in-agentic-coding) -- METR study (19% slower with AI tools)
31. [Stack Overflow - Bugs with AI Coding Agents](https://stackoverflow.blog/2026/01/28/are-bugs-and-incidents-inevitable-with-ai-coding-agents) -- 1.7x more bugs, 75% more logic errors
32. [Composio - Why AI Agent Pilots Fail](https://composio.dev/blog/why-ai-agent-pilots-fail-2026-integration-roadmap) -- SaaStr incident documentation
33. [AlphaEvolve - Google DeepMind](https://deepmind.google/blog/alphaevolve-a-gemini-powered-coding-agent-for-designing-advanced-algorithms/) -- Multi-model evolutionary coding

### SDD Framework Internal References

34. `.specify/memory/constitution.md` -- Constitution v3.0.0 (16 Principles)
35. `.specify/config/refinement.conf` -- Refinement engine configuration
36. `.specify/scripts/bash/rl/` -- RL feedback infrastructure (8 scripts)
37. `plugins/sdd-orchestrator/` -- Existing orchestration plugin (swarm, teams, research)
38. `plugins/sdd-governance/` -- Governance enforcement plugin
39. `.claude/hooks/user-prompt-submit/governance-preflight.sh` -- Existing hook implementation

---

## 9. Actionable Next Steps

### If Proceeding with Implementation

**Immediate (Week 1)**:

1. **Create the plugin scaffold**: Run `/create-plugin sdd-recursive-dev-loop` to generate the standard plugin structure.
2. **Implement the Stop hook**: Build `hooks/stop-hook.sh` (or `stop-hook.js`) that reads a session state file, checks quality scores against threshold, checks iteration count against limit, and returns `decision: "block"` with improvement instructions if below threshold.
3. **Implement the branch-lock hook**: Build `hooks/pre-tool-use/branch-lock.sh` that intercepts Bash commands and denies git branch-switching operations.
4. **Define the session state schema**: Create `config/session-state-schema.json` defining the JSON structure for `.claude/dev-loop-session.local.json`.
5. **Write the `/dev-loop` command**: Create `commands/dev-loop.md` as the entry point that initializes the session, sets up hooks, and kicks off Phase 1.

**Short-term (Weeks 2-3)**:

6. **Implement the quality scoring engine**: Bash scripts that run tests, lint, coverage, and security checks, compute the automated score (70% weight), and write results to the session state file.
7. **Implement session state management**: Load/save/resume logic for the JSON session state file. Resume detection on session start.
8. **Implement iteration logic**: The main loop that processes tasks, runs quality assessment, and provides improvement focus for next iteration.
9. **Write integration tests**: Test the hook chain (governance -> dev-loop), test the stop hook loop (mock quality scores), test the branch-lock (attempt denied operations).
10. **Run end-to-end pilot**: Execute a small-scope dev-loop (bug fix) on a test project to validate the MVP.

### Prerequisites and Dependencies

| Prerequisite | Required For | Status |
|---|---|---|
| Claude Code hooks system | Core loop mechanism | Available (production) |
| SDD Framework v4.1+ | Plugin architecture, command bridge | Installed |
| sdd-governance plugin | Constitutional guard hooks | Installed |
| sdd-specification plugin | Spec/plan/task generation | Installed |
| sdd-debug plugin | Debug workflow integration | Installed |
| OpenAI API key | GPT council member (Phase 2) | User-provided |
| Google AI API key | Gemini council member (Phase 2) | User-provided |
| Docker Desktop (optional) | MCP Toolkit for council invocation | Optional (Bash fallback available) |

### Constitutional Amendments Needed

**No constitutional amendments are required.** The dev-loop plugin operates within the existing constitutional framework through plugin-level relaxation rather than constitutional modification:

- **Principle VI (Git Approval)**: Not amended. The plugin's branch-lock hook enforces a scoped relaxation: autonomous commits within the locked branch are permitted, but pushes and branch operations still require user approval. The `/dev-loop` command itself requires user initiation (explicit consent for autonomy).

- **Principle X (Agent Delegation)**: No amendment needed. The dev-loop agent delegates to domain specialists as required by existing protocol.

- **Principle II (Test-First)**: No amendment needed. The quality scoring engine enforces test-first by weighting test pass rate as the largest single component (24.5% of total score).

The only governance modification is an additive change to `governance-preflight.sh`: detect active dev-loop sessions and inject dev-loop context instead of standard governance context. Existing behavior for non-dev-loop sessions is unchanged.

---

## Appendix A: Implementation Blueprints

*Merged from initial research pass (20260207-080922) — contains concrete code examples, schemas, and diagrams validated against multi-researcher findings above.*

### A.1 Plugin Directory Structure

```
plugins/sdd-dev-loop/
├── plugin.json                        # Manifest with RL metrics
├── commands/
│   └── dev-loop.md                    # /dev-loop slash command
├── skills/
│   ├── dev-loop-orchestrator/
│   │   └── SKILL.md                   # Main orchestration skill
│   ├── council-research/
│   │   └── SKILL.md                   # Multi-LLM research council
│   ├── council-review/
│   │   └── SKILL.md                   # Multi-LLM code review council
│   ├── quality-scoring/
│   │   └── SKILL.md                   # Composite quality grading
│   ├── autonomy-mode/
│   │   └── SKILL.md                   # Constitutional bypass management
│   └── session-persistence/
│       └── SKILL.md                   # State management across interrupts
├── agents/
│   ├── dev-loop-coordinator.md        # Main loop coordinator
│   ├── council-moderator.md           # Multi-LLM voting moderator
│   ├── quality-assessor.md            # Quality scoring agent
│   └── self-improvement-agent.md      # RL-triggered improvement agent
├── hooks/
│   ├── stop-hook.sh                   # Ralph-loop style iteration control
│   └── pre-tool-use.sh               # Autonomy mode enforcement
├── scripts/
│   ├── council-vote.sh                # Multi-LLM voting orchestration
│   ├── quality-grade.sh               # Composite quality scoring
│   ├── session-state.sh               # Session persistence management
│   └── llm-adapters/
│       ├── claude-adapter.sh          # Claude API wrapper
│       ├── openai-adapter.sh          # OpenAI/GPT API wrapper
│       └── gemini-adapter.sh          # Google Gemini API wrapper
├── config/
│   ├── dev-loop.conf                  # Loop configuration
│   ├── council.conf                   # Council voting rules
│   └── quality-thresholds.conf        # Quality scoring config
└── templates/
    ├── session-report.md              # Session report template
    ├── council-ballot.md              # Council vote template
    └── improvement-proposal.md        # RL improvement template
```

### A.2 Core Workflow Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                         /dev-loop "<request>"                        │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PHASE 0: INITIALIZATION                                             │
│                                                                      │
│  1. Parse request, determine scope (small/large)                    │
│  2. Activate autonomy mode (selective constitutional bypass)         │
│  3. Lock to current branch (no branch switching)                    │
│  4. Create session state file                                       │
│  5. Initialize quality baseline                                     │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PHASE 1: COUNCIL RESEARCH                                           │
│                                                                      │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                             │
│  │ Claude  │  │   GPT   │  │ Gemini  │   (parallel)                │
│  │ (Opus)  │  │  (GPT-5)│  │(2.5 Pro)│                             │
│  └────┬────┘  └────┬────┘  └────┬────┘                             │
│       │            │            │                                    │
│       └────────────┼────────────┘                                   │
│                    ▼                                                 │
│  ┌──────────────────────────────────┐                               │
│  │    COUNCIL VOTE: Research        │                               │
│  │    • Tier 1: Majority vote       │                               │
│  │    • Tier 2: Weighted (complex)  │                               │
│  │    • Tier 3: Full debate (crit.) │                               │
│  └──────────────────────────────────┘                               │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                         ┌──────────┴──────────┐
                         ▼                      ▼
              ┌─────────────────┐   ┌─────────────────┐
              │  SMALL SCOPE    │   │  LARGE SCOPE     │
              │  → /plan        │   │  → /specification│
              │  → tasks.md     │   │  (full workflow) │
              └────────┬────────┘   └────────┬────────┘
                       └──────────┬──────────┘
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PHASE 2: AUTONOMOUS EXECUTION                                       │
│                                                                      │
│  FOR each task in tasks.md:                                         │
│    1. Execute task (implement code/tests/config)                    │
│    2. If blocker encountered:                                       │
│       a. Run /debug or auto-debug                                   │
│       b. If API key needed → defer to end report                   │
│       c. If impossible for agent → defer to end report             │
│    3. Run tests for completed task                                  │
│    4. Mark task complete                                            │
│  END FOR                                                            │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PHASE 3: QUALITY ASSESSMENT                                         │
│                                                                      │
│  Hybrid grading (70% automated + 30% council):                     │
│    • Test pass rate (24.5%)                                         │
│    • Code coverage (14.0%)                                          │
│    • Constitutional compliance (10.5%)                               │
│    • Lint/formatting (7.0%)                                         │
│    • Performance benchmarks (7.0%)                                  │
│    • Documentation completeness (7.0%)                               │
│    • Security scan (30% council evaluation)                         │
│                                                                      │
│  QUALITY_SCORE = automated_70% + council_30%                        │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                           ┌────────┴────────┐
                           ▼                  ▼
                    ≥ 95% Score         < 95% Score
                    (configurable)      (default threshold)
                           │                  │
                           ▼                  ▼
┌─────────────────────┐   ┌──────────────────────────────────────────┐
│  PHASE 5: REPORT    │   │  PHASE 4: COUNCIL EVALUATION             │
│                     │   │                                          │
│  • Session summary  │   │  ┌─────────┐  ┌─────────┐  ┌─────────┐│
│  • Quality score    │   │  │ Claude  │  │   GPT   │  │ Gemini  ││
│  • Files modified   │   │  └────┬────┘  └────┬────┘  └────┬────┘│
│  • Tasks completed  │   │       └────────────┼────────────┘      │
│  • Deferred items   │   │                    ▼                    │
│  • RL metrics       │   │  Vote on shortcomings + improvements    │
│  • Recommendations  │   │  IF RL improvements → trigger RL        │
│                     │   │  → Run /debug on failures               │
│                     │   │  → RESTART from Phase 2                 │
│                     │   └──────────────────────────────────────────┘
└─────────────────────┘
```

### A.3 Constitutional Principle Autonomy Analysis

| Principle | Normal Mode | Autonomy Mode | Rationale |
|-----------|-------------|---------------|-----------|
| **I: Library-First** | Enforced | Enforced | Architecture quality |
| **II: Test-First** | Enforced | Enforced | Quality gate |
| **III: Contract-First** | Enforced | Enforced | Design quality |
| **IV: Idempotent** | Enforced | Enforced | Safety |
| **V: Progressive Enhancement** | Enforced | Auto-decided | Agent decides scope |
| **VI: Git Approval** | User approval | Branch-locked | Commits auto, locked to branch |
| **VII: Observability** | Enforced | Enhanced | More logging in autonomy |
| **VIII: Doc Sync** | Enforced | Deferred | Docs updated at end |
| **IX: Dependencies** | Enforced | Enforced | Safety |
| **X: Agent Delegation** | Enforced | Enforced | Core architecture |
| **XI: Input Validation** | Enforced | Enforced | Security |
| **XII: Design System** | Enforced | Auto-decided | Agent follows system |
| **XIII: Access Control** | Enforced | Enforced | Security |
| **XIV: AI Model Selection** | Enforced | Council-managed | Council picks models |
| **XV: File Organization** | Enforced | Enforced | Structure |
| **XVI: Plugin-First** | Enforced | Enforced | Architecture |

### A.4 Stop Hook Implementation

```bash
#!/usr/bin/env bash
# hooks/stop-hook.sh — Dev-Loop Iteration Controller
# Based on Ralph Wiggum pattern, extended with council + quality gates

SESSION_STATE=".claude/dev-loop-session.local.json"

# No active dev-loop → allow normal stop
if [ ! -f "$SESSION_STATE" ]; then
  exit 0
fi

ITERATION=$(jq -r '.current_iteration' "$SESSION_STATE")
MAX_ITERATIONS=$(jq -r '.max_iterations' "$SESSION_STATE")
QUALITY_SCORE=$(jq -r '.last_quality_score' "$SESSION_STATE")
QUALITY_THRESHOLD=$(jq -r '.quality_threshold' "$SESSION_STATE")
STATUS=$(jq -r '.status' "$SESSION_STATE")

# Dev-loop paused or complete → allow stop
if [ "$STATUS" != "active" ]; then
  exit 0
fi

# Quality threshold met → complete and allow stop
if (( $(echo "$QUALITY_SCORE >= $QUALITY_THRESHOLD" | bc -l) )); then
  jq '.status = "complete"' "$SESSION_STATE" > tmp.$$ && mv tmp.$$ "$SESSION_STATE"
  exit 0
fi

# Iteration limit reached → safety cap, allow stop
if [ "$ITERATION" -ge "$MAX_ITERATIONS" ]; then
  jq '.status = "max_iterations_reached"' "$SESSION_STATE" > tmp.$$ && mv tmp.$$ "$SESSION_STATE"
  exit 0
fi

# Continue loop: increment iteration and block stop
jq ".current_iteration = $((ITERATION + 1))" "$SESSION_STATE" > tmp.$$ && mv tmp.$$ "$SESSION_STATE"

echo "Dev-loop iteration $((ITERATION + 1))/$MAX_ITERATIONS"
echo "Quality: ${QUALITY_SCORE}% (target: ${QUALITY_THRESHOLD}%)"
echo "Continue from Phase 2 with council feedback applied."

exit 1  # Block stop — keep session alive
```

### A.5 Branch Lock Hook

```bash
#!/usr/bin/env bash
# hooks/pre-tool-use.sh — Branch lock enforcement

SESSION_STATE=".claude/dev-loop-session.local.json"
if [ ! -f "$SESSION_STATE" ]; then exit 0; fi

STATUS=$(jq -r '.status' "$SESSION_STATE")
if [ "$STATUS" != "active" ]; then exit 0; fi

LOCKED_BRANCH=$(jq -r '.locked_branch' "$SESSION_STATE")
CURRENT_BRANCH=$(git branch --show-current)

# Enforce branch lock
if [ "$CURRENT_BRANCH" != "$LOCKED_BRANCH" ]; then
  echo "ERROR: Dev-loop locked to branch '$LOCKED_BRANCH'"
  exit 1
fi

# Block branch-modifying git operations
TOOL_NAME="$1"
TOOL_INPUT="$2"

case "$TOOL_NAME" in
  Bash)
    if echo "$TOOL_INPUT" | grep -qE "git (checkout|switch|branch -[dD]|push)"; then
      if echo "$TOOL_INPUT" | grep -q "git push"; then
        echo "BLOCKED: git push deferred to end of dev-loop"
      else
        echo "BLOCKED: Branch operations not allowed in autonomy mode"
      fi
      exit 1
    fi
    ;;
esac
```

### A.6 LLM Adapter Layer

```bash
# Claude adapter (native — no API key needed)
claude_query() {
  claude --print --model opus --max-budget-usd "$BUDGET" \
    --system-prompt "$SYSTEM_PROMPT" "$PROMPT"
}

# OpenAI/GPT adapter (requires OPENAI_API_KEY)
openai_query() {
  curl -s "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"gpt-5\",
      \"messages\": [{\"role\": \"system\", \"content\": \"$SYSTEM_PROMPT\"},
                     {\"role\": \"user\", \"content\": \"$PROMPT\"}],
      \"response_format\": {\"type\": \"json_schema\", \"strict\": true}
    }"
}

# Gemini adapter (requires GOOGLE_API_KEY)
gemini_query() {
  curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$GOOGLE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"contents\": [{\"parts\": [{\"text\": \"$SYSTEM_PROMPT\n\n$PROMPT\"}]}],
      \"generationConfig\": {\"responseMimeType\": \"application/json\"}
    }"
}
```

### A.7 Council Voting Ballot Structure

```json
{
  "voter": "claude|gpt|gemini",
  "recommendations": [
    {"id": "R1", "description": "...", "vote": "approve|reject|modify", "reason": "..."},
    {"id": "R2", "description": "...", "vote": "approve|reject|modify", "reason": "..."}
  ],
  "overall_confidence": 0.85,
  "dissenting_opinions": ["..."]
}
```

**Tally rules**: Majority (2/3) → adopted. Unanimous → high confidence. Split (1/1/1) → Claude tiebreaker or escalate to user. Dissenting opinions preserved in report.

### A.8 Council Configuration

```bash
# config/council.conf
COUNCIL_MEMBERS="claude,openai,gemini"
COUNCIL_PRIMARY="claude"
COUNCIL_QUORUM=2
VOTE_THRESHOLD_APPROVE=0.67
TIEBREAKER_STRATEGY="primary"   # "primary" | "user" | "weighted"
CLAUDE_MODEL="claude-opus-4-6"
OPENAI_MODEL="gpt-5"
GEMINI_MODEL="gemini-2.5-pro"
COUNCIL_BUDGET_TOTAL=15.00
COUNCIL_FALLBACK_ENABLED=true
COUNCIL_MIN_MEMBERS=2
```

### A.9 Session State Schema

```json
{
  "session_id": "dev-loop-20260207-080922",
  "status": "active",
  "locked_branch": "feat/user-auth",
  "created_at": "2026-02-07T08:09:22Z",
  "request": "Build user authentication with React UI and PostgreSQL backend",
  "scope": "large",
  "workflow": "specification",
  "current_iteration": 2,
  "max_iterations": 10,
  "quality_threshold": 95.0,
  "last_quality_score": 87.5,
  "phases_completed": ["research", "specification", "planning", "tasks"],
  "current_phase": "execution",
  "current_task": "T3: Implement auth middleware",
  "tasks": { "total": 8, "completed": 2, "in_progress": 1, "blocked": 0, "deferred": 1 },
  "council_votes": [
    {
      "phase": "research", "iteration": 1, "result": "consensus",
      "adopted": ["R1", "R3", "R5"], "rejected": ["R2"], "modified": ["R4"]
    }
  ],
  "quality_history": [
    {"iteration": 1, "score": 72.3, "breakdown": {"tests": 0.85, "coverage": 0.65}},
    {"iteration": 2, "score": 87.5, "breakdown": {"tests": 0.95, "coverage": 0.78}}
  ],
  "deferred_items": [
    {
      "type": "api_key",
      "description": "STRIPE_SECRET_KEY needed for payment integration",
      "blocking_task": "T5: Implement payment flow",
      "workaround": "Skipped payment tests, mocked Stripe client"
    }
  ],
  "cost": { "claude_tokens": 45000, "openai_tokens": 12000, "gemini_tokens": 8000, "estimated_usd": 4.50 }
}
```

### A.10 Self-Improvement Protocol

```
IF shortcoming identified by council vote:
  1. CLASSIFY:
     a. Skill deficiency → Update skill SKILL.md
     b. Agent capability gap → Create/update agent
     c. Missing tool → Search marketplace, build if needed
     d. Plugin limitation → Extend plugin
     e. Framework limitation → Propose for user review

  2. EXECUTE improvement:
     a. Skill: Update instructions, add examples, refine triggers
     b. Agent: Update agent .md, add new capabilities
     c. Tool: Run `docker mcp find <capability>` or `/create-plugin`
     d. Plugin: Extend existing plugin
     e. Framework: Document proposal

  3. DOCUMENT: Save to session report, update RL metrics

  4. VERIFY: Re-run quality scoring, council validates, loop continues
```

### A.11 Example Session Flow

```
USER: /dev-loop "Build a user authentication system with email/password
       login, JWT refresh tokens, and a React login page"

DEV-LOOP:
  [INIT] Scope: LARGE → Full specification workflow
  [INIT] Locked to branch: feat/user-auth
  [INIT] Quality threshold: 95%
  [INIT] Max iterations: 10

  [PHASE 1: COUNCIL RESEARCH]
    Claude: Researches JWT best practices, Passport.js vs custom auth
    GPT: Researches security patterns, OWASP auth guidelines
    Gemini: Researches React auth patterns, token storage strategies

    COUNCIL VOTE:
      R1: "Use bcrypt for password hashing" → UNANIMOUS APPROVE
      R2: "Use Passport.js" → REJECTED (2-1, council prefers custom for SDD)
      R3: "Store refresh tokens in httpOnly cookies" → APPROVED (2-1)
      R4: "Use React Context for auth state" → MODIFIED → "Zustand store"
      R5: "Add rate limiting on login endpoint" → UNANIMOUS APPROVE

  [PHASE 1b: SPECIFICATION]
    Generated: specs/005-user-auth/spec.md
    Generated: specs/005-user-auth/plan.md
    Generated: specs/005-user-auth/tasks.md (8 tasks)

  [PHASE 2: EXECUTION - Iteration 1]
    T1: Database schema ✅
    T2: Auth service (register/login) ✅
    T3: JWT middleware ✅
    T4: Refresh token rotation ✅
    T5: Rate limiting ✅
    T6: React login page ✅
    T7: Auth context/store ✅
    T8: E2E tests ⚠️ (3/5 passing)

  [PHASE 3: QUALITY - Iteration 1]
    COMPOSITE SCORE: 88.7% → BELOW 95% THRESHOLD

  [PHASE 4: COUNCIL EVALUATION]
    Claude: "E2E tests failing due to missing test DB setup"
    GPT: "Code coverage below 80% minimum"
    Gemini: "Documentation missing API endpoint descriptions"
    → RL UPDATE: debug skill +1 invocation

  [PHASE 2: EXECUTION - Iteration 2]
    Fix: E2E test setup, add 12 unit tests, add API docs
    DEFERRED: STRIPE_SECRET_KEY needed for premium tier

  [PHASE 3: QUALITY - Iteration 2]
    COMPOSITE SCORE: 96.2% → ABOVE 95% THRESHOLD ✅

  [PHASE 5: REPORT]
    ✅ Dev-Loop Complete
    Iterations: 2 | Quality: 96.2% | Tasks: 8/8
    Deferred: 1 (STRIPE_SECRET_KEY) | Cost: $18.50
    Files created: 14 | Tests added: 23 | Coverage: 87%
    Ready for: git push (requires user approval)
```

---

*Research synthesis completed: 2026-02-07*
*Input: 3 research passes (Primary Sources, Community, Comparative Analysis) + implementation blueprints from initial research*
*Total sources cross-referenced: 39+*
*Overall confidence: HIGH (85-95% across sections)*
*Framework version: sdd-agentic-framework v4.1.0*
