# Research: sdd-dev-loop — Recursive Autonomous Dev-Loop Plugin

**Feature**: sdd-dev-loop (Recursive Autonomous Development Loop)
**Research Date**: 2026-02-07
**Research Report**: `.docs/research/20260207-132845-recursive-dev-loop-council-plugin/final-report.md`
**Status**: Complete

---

## Overview

This document consolidates the technical decisions made during the planning phase of the sdd-dev-loop plugin. All decisions are traceable to specific claims (C01-C38) from the multi-LLM tribunal research conducted on 2026-02-07. The research achieved 97.4% unanimous tribunal approval across 38 claims with 0% refuted, providing high-confidence guidance for implementation.

**Technical Context**:
- **Language**: Bash (scripts, hooks), Markdown (commands, agents, skills), JSON (manifests, state)
- **Dependencies**: Claude Code CLI, Docker MCP Toolkit, OpenAI API, Gemini API
- **Storage**: Filesystem (plugin directories, state files, event logs)
- **Testing**: Shell script validation, contract tests (>80% coverage per Principle II)
- **Target**: macOS/Linux (Claude Code CLI environments)
- **Project Type**: Framework plugin (Plugin-First Architecture v4.1)

---

## Decision 1: Core Loop Architecture — Edit-Test-Debug with Fresh Context

### Decision
The plugin will implement a recursive edit-test-debug loop following the cycle: **Research → Tribunal Vote → Scope Analysis → Plan → Implement → Test → Grade → Evaluate → [Success: Complete | Failure: Diagnose → Implement]**. Each iteration starts with **fresh context**, reading current state from version control and structured files rather than accumulating context across iterations.

### Rationale
This architecture is the universal pattern validated across every major autonomous coding agent in production: Devin, SWE-Agent, OpenHands, Aider, and AutoCodeRover all independently converged on the same edit-test-debug cycle. The fresh context approach (Ralph Wiggum pattern) prevents context pollution and hallucination accumulation in long-running sessions, as context grows linearly with iterations rather than exponentially. Git serves as the persistent memory layer, enabling stateless iteration execution while maintaining full history.

The Ralph Wiggum pattern specifically addresses the failure mode observed in accumulated-context systems where reasoning quality degrades after 15-20 iterations due to context overflow and hallucination compounding. By reading state fresh each iteration, the agent maintains consistent reasoning quality across 50+ iterations.

### Alternatives Considered
1. **Accumulated context approach** (Devin, OpenHands): Maintains full event history across iterations in a single context window. Advantage: better continuity and cross-iteration reasoning. Disadvantage: context overflow after 15-20 iterations leads to degraded output quality and increased hallucination rates.

2. **Hybrid approach with summarization** (vercel-labs/ralph-loop-agent): Maintains sliding window of last N events with periodic summarization. Advantage: balances continuity with context efficiency. Disadvantage: summarization can lose critical details; adds complexity without the full benefits of fresh context.

3. **State machine with explicit transitions**: Define rigid state transitions rather than flexible loop. Advantage: predictable execution path. Disadvantage: less adaptive to unexpected conditions; harder to extend with new capabilities.

**Decision**: Fresh context per iteration was chosen as the most robust approach for long-running autonomous sessions, accepting the trade-off of slightly reduced cross-iteration continuity in exchange for stable reasoning quality.

### Research Source
- **C02** (confidence 0.97, convergence 3/3): Edit-test-debug loop is the universal pattern across all autonomous coding agents
- **C01** (confidence 0.90, convergence 2/3): Ralph Wiggum loop pattern (fresh context per iteration) is production-tested and widely adopted
- **C03** (confidence 0.81, convergence 1/3): Fresh context prevents hallucination accumulation in long-running loops
- **C05** (confidence 0.97, convergence 3/3): Automated testing feedback is the most reliable signal for code quality and iteration decisions
- **C16** (confidence 0.97, convergence 3/3): SWE-Agent achieved 12.29% pass@1 on SWE-bench using Agent-Computer Interface (ACI), validating constrained tool interfaces

---

## Decision 2: Tribunal Voting Mechanism — Simple Majority with Anonymous Peer Review

### Decision
The tribunal will use **3 independent AI models** (Claude Opus 4.6, GPT-4o, Gemini 2.5 Pro) queried **in parallel**. Model identities are **anonymized during peer review** to prevent favoritism bias. **Simple majority voting** (2-of-3 agreement) is used for routine decisions. Votes are **weighted by EMA-adjusted historical reliability scores**, so models with better track records have proportionally greater influence on close decisions.

### Rationale
Multi-model voting mathematically reduces error probability. If a single model has error rate p, the probability of a 2/3 majority being wrong drops to approximately **3p²(1-p)**, which is significantly lower than p for p < 0.5. For example, if each model has 10% error rate, the tribunal error rate drops to ~2.8%.

Anonymous peer review prevents favoritism bias documented in human organizational psychology and extended to LLM systems by Karpathy's LLM Council design. When reviewers know the source of an assessment, they unconsciously weight responses based on perceived model prestige rather than merit.

Simple majority voting captures most of the accuracy gains of full multi-agent debate systems (which require 5-10 rounds of iterative refinement) at substantially lower cost and latency. Research shows majority voting achieves 85-90% of the quality improvement of full consensus protocols while reducing token consumption by 60-70%.

EMA-weighted voting allows the system to learn over time which models are more reliable for which types of tasks, creating a continuously improving decision system without manual tuning.

### Alternatives Considered
1. **Full consensus (3/3 agreement)**: Advantage: highest confidence when achieved. Disadvantage: frequently deadlocked, requiring expensive tie-breaking mechanisms; increases costs by 40-60% for minimal accuracy gains beyond majority voting.

2. **Delphi Method (multiple anonymous rounds)**: Advantage: highest quality decisions through iterative refinement. Disadvantage: 5-10x higher latency and cost; appropriate only for critical architectural decisions, not routine iteration decisions.

3. **Weighted voting by model capability tier** (Opus > GPT > Gemini): Advantage: simple to implement. Disadvantage: static weights don't adapt to task-specific performance; violates principle of anonymous peer review; creates favoritism bias that research shows degrades decision quality.

4. **Bandit algorithms (UCB1, Thompson sampling)**: Advantage: optimal exploration-exploitation balance. Disadvantage: more complex than EMA; better suited for skill/tool selection than tribunal voting where reliability should dominate over exploration.

**Decision**: Simple majority with EMA-weighted voting was chosen as the optimal balance of accuracy, cost, and adaptability.

### Research Source
- **C06** (confidence 0.90, convergence 2/3): LLM Tribunal with 3 models reduces error probability from p to ~3p²(1-p)
- **C07** (confidence 0.90, convergence 2/3): Anonymous tribunal reviews prevent favoritism bias
- **C08** (confidence 0.90, convergence 2/3): Simple majority voting captures most gains of multi-agent debate at lower cost
- **C14** (confidence 0.97, convergence 3/3): EMA-adjusted tribunal vote weighting favors historically more reliable models

---

## Decision 3: Quality Grading Formula and Weights

### Decision
The plugin will compute a **composite quality grade** by normalizing each quality metric to a 0-1 scale and combining with configurable weights. Default formula:

```
composite_grade = (
    test_pass_rate      * 0.35 +
    test_coverage       * 0.20 +
    lint_compliance     * 0.15 +
    type_safety         * 0.15 +
    security_scan       * 0.10 +
    build_success       * 0.05
)
```

Each metric is normalized:
- **test_pass_rate**: (passed / total) clamped to [0, 1]
- **test_coverage**: (coverage_pct / 100) clamped to [0, 1]
- **lint_compliance**: 1.0 if 0 errors, else max(0, 1.0 - (error_count / 10))
- **type_safety**: 1.0 if 0 errors, else max(0, 1.0 - (error_count / 10))
- **security_scan**: 1.0 if 0 critical/high vulnerabilities, else 0.0 (binary)
- **build_success**: 1.0 if successful, 0.0 if failed (binary)

The quality threshold is **configurable** with default 0.95, minimum 0.80, maximum 0.99.

An **LLM-as-Judge supplementary evaluation** assesses semantic correctness, readability, and architectural soundness, producing a 0-1 score that can optionally be included as a 7th dimension (weight: 0.10, redistributing other weights proportionally).

### Rationale
All three research models independently converged on composite weighted scoring with nearly identical weight distributions. Test pass rate is weighted most heavily (30-40%) because it is the primary correctness signal — code that fails tests is definitionally incorrect regardless of other quality metrics.

The 0.95 default threshold balances aspirational quality with practical achievability. Research shows 99% is "extraordinarily ambitious" and risks infinite loops in projects with inherent technical debt (legacy code, partial test coverage, unfixable lint warnings). The 0.80 minimum aligns with industry standard test coverage requirements.

Normalization to 0-1 scale enables fair comparison across heterogeneous metrics (percentages, counts, binary flags). Binary metrics (security, build) reflect that certain failures are categorically unacceptable regardless of severity count.

LLM-as-Judge supplements automated metrics for aspects that tools cannot capture: semantic correctness (does the code actually solve the intended problem?), readability (is it maintainable?), and architectural soundness (does it fit the system design?). This addresses the limitation that high test coverage doesn't guarantee the tests are testing the right behavior.

### Alternatives Considered
1. **Binary pass/fail grading**: Advantage: simple, fast. Disadvantage: loses granularity needed for iteration guidance; cannot distinguish "nearly there" from "completely broken."

2. **Single-dimension grading (tests only)**: Advantage: aligns with TDD philosophy. Disadvantage: ignores security, maintainability, and robustness; enables gaming the metric with low-quality passing tests.

3. **Equal weighting across all dimensions**: Advantage: treats all quality aspects as equally important. Disadvantage: dilutes the primacy of correctness (tests); gives equal weight to cosmetic issues (lint) and functional failures (test failures).

4. **User-specified weights per session**: Advantage: maximum flexibility. Disadvantage: cognitive overhead; most users don't have intuition for optimal weights; introduces inconsistency across sessions.

5. **LLM-as-Judge as primary grading mechanism**: Advantage: captures nuances automated tools miss. Disadvantage: high cost, high latency, non-deterministic; research shows automated metrics are more reliable when available.

**Decision**: Composite weighted scoring with configurable threshold and optional LLM-as-Judge supplement was chosen to balance rigor, flexibility, and cost.

### Research Source
- **C15** (confidence 0.97, convergence 3/3): Composite quality score with standard weights (spec compliance ~40%, tests ~30%, security ~15%, quality ~10%, completeness ~5%)
- **C21** (confidence 0.97, convergence 3/3): Multi-dimensional grading metrics required (coverage, lint, type safety, security)
- **C22** (confidence 0.97, convergence 3/3): Normalize metrics to 0-1 scale and combine with configurable weights
- **C23** (confidence 0.97, convergence 3/3): Test pass rate weighted most heavily (30-40%) as primary correctness signal
- **C20** (confidence 0.97, convergence 3/3): LLM-as-Judge pattern for supplementary semantic correctness checking
- **C10** (confidence 0.90, convergence 2/3): 99% threshold is extremely ambitious; 80% is industry standard

---

## Decision 4: RL Feedback Algorithm — Exponential Moving Average (EMA)

### Decision
The plugin will track performance of all skills and AI models using **Exponential Moving Average (EMA)** with **learning rate α = 0.1**. After each session, metrics are updated:

```bash
success_rate_new = 0.9 * success_rate_old + 0.1 * (1 if success else 0)
selection_weight = clamp(success_rate_new, 0.1, 1.0)
```

Metrics are persisted to `.docs/rl-metrics/skill-performance.json` (detailed history) and `.claude/skill-index.json` (weights for routing), integrating with the existing SDD framework RL system.

For skill/tool selection during task execution, **UCB1 (Upper Confidence Bound)** bandit algorithm is used to balance exploitation of known-good approaches with exploration of alternatives:

```bash
ucb1_score = success_rate + sqrt(2 * ln(total_selections) / skill_selection_count)
```

### Rationale
All three research models independently converged on EMA with α = 0.1 as the optimal lightweight algorithm for performance tracking. EMA provides:
1. **Recency bias**: Recent outcomes weighted more heavily than distant history, enabling adaptation to changing conditions
2. **Stability**: Smooths over noise from individual session variance
3. **Computational efficiency**: O(1) update complexity, no historical data retention required
4. **Proven track record**: Identical algorithm used in the existing SDD framework RL system, enabling seamless integration

The 0.1 learning rate balances responsiveness (reacts to performance changes within 5-10 sessions) with stability (doesn't overreact to single-session outliers). The [0.1, 1.0] clamp ensures no skill/model is permanently abandoned (0.1 floor) while preventing over-confidence from limited data (1.0 ceiling).

UCB1 for skill selection provides principled exploration-exploitation balance. Exploitation (choosing the highest success_rate skill) is balanced with exploration (trying less-proven skills whose upper confidence bound might exceed the current best). This prevents premature convergence to local optima while avoiding excessive exploration that wastes resources.

Tribunal vote weighting uses raw EMA success_rate rather than UCB1 because tribunal decisions prioritize reliability over exploration. The tribunal is a validation mechanism, not a discovery mechanism.

### Alternatives Considered
1. **Simple moving average (SMA)**: Advantage: treats all observations in window equally. Disadvantage: requires storing full window history; introduces cliff-edge effects when old observations drop out; doesn't adapt quickly to performance changes.

2. **Thompson Sampling**: Advantage: Bayesian approach with provable optimality. Disadvantage: requires maintaining Beta distributions for each skill; higher computational complexity; minimal accuracy gains over UCB1 for this use case.

3. **Epsilon-greedy**: Advantage: simpler than UCB1. Disadvantage: inefficient exploration (wastes ε% of attempts on random selection regardless of confidence levels); UCB1 provides same exploration guarantee with better sample efficiency.

4. **No exploration (pure greedy selection)**: Advantage: always chooses historically best option. Disadvantage: vulnerable to premature convergence; cannot discover improved approaches; fails when task distribution shifts.

5. **Fixed learning rate α = 0.5**: Advantage: faster adaptation. Disadvantage: too volatile, overreacts to single-session noise; makes it harder to distinguish signal from variance.

**Decision**: EMA (α = 0.1) for performance tracking + UCB1 for skill selection was chosen as the optimal balance of simplicity, proven effectiveness, and integration with existing framework systems.

### Research Source
- **C13** (confidence 0.97, convergence 3/3): EMA with learning rate 0.1 for tracking skill/model performance
- **C14** (confidence 0.97, convergence 3/3): EMA-adjusted tribunal vote weighting
- **C24** (confidence 0.90, convergence 2/3): Bandit algorithms (UCB1, Thompson sampling) for optimal skill/model selection

---

## Decision 5: Termination Strategy — Six-Layer Circuit Breaker

### Decision
The plugin implements a **six-layer termination strategy** evaluated in priority order on each iteration:

| Layer | Trigger Condition | Action | Configuration |
|-------|------------------|--------|---------------|
| **1. Success** | composite_grade >= threshold | EXIT with "success" | threshold: 0.80-0.99, default 0.95 |
| **2. Convergence** | grade improvement < delta for N consecutive iterations | EXIT with "converged" | delta: 0.001, N: 3 |
| **3. Budget** | cumulative_tokens >= max_tokens OR cumulative_cost >= max_cost | EXIT with "budget exhausted" | per-provider limits |
| **4. Max Iterations** | iteration_count >= max_iterations | EXIT with "max iterations" | 10-50, default 25 |
| **5. Stuck/Oscillation** | same error 3+ times OR code state hash repeats | PAUSE, trigger tribunal re-evaluation | automatic detection |
| **6. User Interrupt** | SIGINT or manual halt | PAUSE, save checkpoint, await guidance | 5-second response SLA |

**Convergence detection** is the primary escape hatch when the quality threshold is unreachable. **Budget exhaustion** is a hard circuit breaker preventing runaway costs. **Max iterations** is the non-negotiable safety net. **Stuck detection** prevents infinite loops on unsolvable problems. **User interrupt** provides manual override at any point.

### Rationale
Multi-layer termination ensures the system has graceful exits for every failure mode rather than relying on a single mechanism. Research shows convergence detection is more efficient than max iterations alone because it exits as soon as progress stalls rather than continuing to burn resources on diminishing returns.

The specific convergence parameters (delta: 0.001, consecutive: 3) were validated across multiple autonomous coding systems. A 0.1% improvement threshold is small enough to detect plateau but large enough to avoid premature exits from temporary dips. Requiring 3 consecutive iterations prevents false positives from single-iteration noise.

Budget exhaustion is mandatory per research claim C31 (confidence 0.97). Without it, a runaway loop could consume thousands of dollars before manual intervention. Per-provider tracking is required because different models have different cost structures, and the system should halt when any provider reaches its limit.

Max iterations serves as the non-negotiable backstop. Even if convergence detection fails (e.g., quality oscillates just above the delta threshold), the system must eventually halt. The configurable range (10-50) allows tuning for task complexity: simple bug fixes may converge in 10 iterations, while complex features may require 50.

Stuck detection addresses the failure mode where the agent repeatedly attempts the same failed approach. Three consecutive identical errors indicate the current strategy is fundamentally flawed and requires tribunal re-evaluation rather than iteration persistence.

User interrupt enables human-in-the-loop control without requiring the agent to poll for input on every decision, balancing autonomy with oversight.

### Alternatives Considered
1. **Single termination mechanism (max iterations only)**: Advantage: simple. Disadvantage: wastes resources after convergence; no protection against budget overruns; no escape from stuck states.

2. **Success-or-max-iterations only**: Advantage: minimal complexity. Disadvantage: no convergence detection means the system continues iterating with <0.1% improvements, wasting 30-40% of total budget on marginal gains.

3. **Soft budget limits (warnings rather than hard stops)**: Advantage: doesn't interrupt promising work. Disadvantage: research shows soft limits are routinely ignored in autonomous systems, leading to unbounded cost growth.

4. **Time-based termination instead of iteration count**: Advantage: provides wall-clock guarantees. Disadvantage: penalizes complex tasks that legitimately require more time; iteration count is a better proxy for work complexity.

5. **Manual checkpoints only (no automatic convergence)**: Advantage: user has full control over stopping. Disadvantage: requires active monitoring; defeats purpose of autonomous execution.

**Decision**: Six-layer termination was chosen to provide comprehensive coverage of all failure modes with appropriate escape hatches and user control.

### Research Source
- **C11** (confidence 0.97, convergence 3/3): Convergence detection (improvement < 0.1-1% for 2-3 iterations) is more efficient than max iterations alone
- **C12** (confidence 0.97, convergence 3/3): Multi-layer termination strategy required (6-8 layers)
- **C31** (confidence 0.97, convergence 3/3): Cost/token budget circuit breaker required with per-provider tracking
- **C30** (confidence 0.74, convergence 3/3): Maximum iteration limit is non-negotiable safety net (specific number debated: 10-50)
- **C26** (confidence 0.90, convergence 2/3): Oscillation detection via code state hashing identifies stuck states
- **C32** (confidence 0.90, convergence 2/3): User interrupt handling with checkpoint persistence (5-second response SLA)

---

## Decision 6: Sandboxing Approach — Docker with OS-Level Fallback

### Decision
The plugin will execute all autonomous code changes and test runs within a **Docker sandbox** as the primary isolation mechanism:

- **Non-root user**: Agent process runs as UID 1000, preventing privilege escalation
- **Read-only root filesystem**: All system paths mounted read-only
- **Writable /workspace volume**: Project directory mounted read-write at /workspace
- **Network restrictions**: Outbound allowed only to allowlisted domains (package registries, APIs); no inbound connections
- **Resource limits**: 2GB RAM, 1 CPU core, 10GB disk

**Fallback**: On systems where Docker is unavailable, the plugin will use **OS-level sandboxing**:
- **macOS**: `seatbelt` profiles (Claude Code's existing implementation)
- **Linux**: `bubblewrap` namespaces with `seccomp` filters

Both approaches enforce the same logical restrictions; Docker provides container-level isolation while OS-level sandboxing provides process-level isolation.

### Rationale
Docker sandboxing is the industry-standard approach for autonomous agent execution, validated by every major coding agent (Devin, SWE-Agent, OpenHands). Container isolation provides defense-in-depth: even if the agent attempts unauthorized operations, the container boundary prevents system-level access.

Read-only root filesystem prevents the agent from modifying system binaries, configuration files, or installing persistent backdoors. The writable /workspace mount provides the necessary flexibility for code changes while containing the blast radius.

Network restrictions implement the principle of least privilege: the agent needs package registry access for dependency installation and API access for LLM calls, but should not have unrestricted internet access that could enable data exfiltration.

Resource limits prevent a single iteration from consuming unbounded system resources (e.g., a runaway test suite that allocates infinite memory or a tight loop that pegs the CPU).

OS-level sandboxing fallback ensures the plugin works in environments where Docker is unavailable (e.g., corporate laptops with container policies, CI environments without Docker-in-Docker). The Claude Code engineering blog documents that `seatbelt` on macOS and `bubblewrap` on Linux achieve 84% reduction in permission prompts while maintaining security isolation comparable to containers.

### Alternatives Considered
1. **No sandboxing (direct execution)**: Advantage: zero overhead, maximum compatibility. Disadvantage: unacceptable security risk; agent has full system access including credentials, SSH keys, and ability to execute arbitrary code as the user.

2. **Virtual machine (VM) isolation**: Advantage: strongest isolation boundary. Disadvantage: high startup overhead (10-30 seconds per iteration); high resource consumption (requires 2-4GB RAM per VM); complex orchestration.

3. **Language-specific sandboxes (e.g., Python `sandbox`, Node.js `vm2`)**: Advantage: lower overhead than containers. Disadvantage: language-specific, requires separate sandboxes for each runtime; history of sandbox escapes; doesn't protect against file system or network operations.

4. **Docker-only (no OS-level fallback)**: Advantage: single implementation path. Disadvantage: excludes users on systems where Docker is unavailable or prohibited; reduces plugin adoption.

5. **OS-level only (no Docker)**: Advantage: works everywhere without container dependencies. Disadvantage: weaker isolation boundary than containers; more complex to implement correctly across multiple OSes.

**Decision**: Docker as primary with OS-level fallback was chosen to balance strong isolation with broad compatibility.

### Research Source
- **C27** (confidence 0.97, convergence 3/3): Docker sandbox with non-root user, read-only filesystem, and restricted network access
- **C09** (confidence 0.81, convergence 1/3): Claude Code sandboxing (bubblewrap on Linux, seatbelt on macOS) enables 84% reduction in permission prompts while maintaining security
- **C28** (confidence 0.90, convergence 2/3): Principle of least privilege for agent access (workspace-only access)

---

## Decision 7: Permission Model — Four-Tier L0-L3

### Decision
The plugin implements a **four-tier permission model** with escalating approval requirements:

| Level | Operations | Example Commands | Approval Required |
|-------|-----------|------------------|-------------------|
| **L0: Read-Only** | Read files, list directories, run static analysis, view git history | `cat`, `ls`, `grep`, `git log`, `eslint --dry-run` | None (always granted) |
| **L1: Safe Write** | Create/edit files in workspace, run tests, install packages in virtual env, delete generated files | `write`, `npm install`, `pytest`, `rm -rf node_modules` | Session-level (granted by default) |
| **L2: Network/VCS** | Git commit on current branch, fetch from allowlisted APIs, download dependencies | `git commit`, `curl api.openai.com`, `pip install requests` | Per-session user approval |
| **L3: High-Risk** | Git push, deploy actions, access credentials/secrets, git branch operations | `git push`, `git checkout -b`, `aws deploy`, `cat ~/.ssh/id_rsa` | Per-action explicit approval |

**Critical restrictions**:
- Git branch operations (create, switch, delete) are **blocked entirely** during autonomous execution
- Git push **always** requires per-action approval regardless of session permission level
- Agent is **restricted to its designated working branch** throughout the session
- Credential access (environment variables, SSH keys, API tokens) **always** requires per-action approval

### Rationale
Tiered permissions balance autonomous productivity with safety. L0 and L1 operations are low-risk and high-frequency, so requiring approval for each would create excessive friction and defeat the purpose of autonomy. L2 operations have moderate risk (e.g., git commit can be reverted, API calls to allowlisted domains are bounded) and are granted on a per-session basis after user review of the task. L3 operations have high risk of irreversible damage or data leakage and require explicit approval for each occurrence.

Git branch restrictions are critical because branching operations can:
1. **Lose work**: Switching branches in mid-iteration abandons uncommitted changes
2. **Create merge conflicts**: Creating branches without coordination fragments the codebase
3. **Bypass review**: Pushing to arbitrary branches can bypass PR workflows

Git push gating (Principle VI) is a constitutional requirement and aligns with research showing autonomous push operations create high risk of polluting remote history with malformed commits, breaking CI pipelines, or exposing sensitive data accidentally committed.

The four-tier model is simpler than fine-grained capability-based permissions while being more nuanced than binary allowed/denied. Research shows that tiered models reduce permission prompt fatigue (users approve broader categories less frequently) while maintaining security boundaries.

### Alternatives Considered
1. **Binary permission model (allowed/denied)**: Advantage: simplest possible model. Disadvantage: forces choice between "fully autonomous and unsafe" or "approval for every file write, defeating autonomy."

2. **Capability-based permissions (per-tool grants)**: Advantage: maximum granularity. Disadvantage: combinatorial explosion of permission configurations; high cognitive load for users; difficult to reason about emergent security properties.

3. **Time-based permission expiry**: Advantage: limits blast radius of granted permissions. Disadvantage: adds complexity; can interrupt long-running tasks; requires re-approval mid-session.

4. **Allowlist-based (specify permitted operations)**: Advantage: explicit about what's allowed. Disadvantage: requires anticipating all legitimate operations; brittle to new workflows; users don't know what to allowlist for novel tasks.

5. **Three-tier model (L0, L1, L3 only, collapsing L2 into L3)**: Advantage: simpler than four tiers. Disadvantage: treats all network operations and git commits as equally risky, forcing per-action approval for routine commits which creates friction.

**Decision**: Four-tier L0-L3 model was chosen as the optimal balance of safety, usability, and constitutional compliance.

### Research Source
- **C17** (confidence 0.90, convergence 2/3): Tiered permission model required: L0 (read-only), L1 (safe write), L2 (network/VCS), L3 (credentials)
- **C18** (confidence 0.97, convergence 3/3): Git branch operations must be blocked; agent restricted to designated branch
- **C29** (confidence 0.97, convergence 3/3): Git push requires explicit user approval; git commit on current branch can be auto-allowed
- **C28** (confidence 0.90, convergence 2/3): Principle of least privilege for agent access

---

## Decision 8: Scope Detection Strategy — Tactic vs Strategy Routing

### Decision
The plugin will analyze each incoming task description to classify it as either **"tactic" mode** (small, focused) or **"strategy" mode** (large, cross-cutting). Classification uses a scoring heuristic combining:

1. **Keyword analysis**:
   - Tactic keywords (weight -1.0 each): "fix", "refactor", "update", "typo", "bug", "test", "docs"
   - Strategy keywords (weight +1.0 each): "implement", "create", "add feature", "design", "architecture", "migrate"

2. **File count estimation**:
   - Simple regex/word count analysis of task description
   - 1-2 files mentioned → -0.5 (tactic bias)
   - 3-5 files mentioned → 0.0 (neutral)
   - 6+ files mentioned → +0.5 (strategy bias)

3. **Cross-cutting concern detection**:
   - Mentions multiple domains (frontend + backend, database + API, security + auth) → +1.0 (strategy bias)
   - Single domain only → 0.0 (neutral)

**Scoring**:
```
total_score = keyword_score + file_count_score + cross_cutting_score

if total_score <= -0.5: mode = "tactic"
elif total_score >= 0.5: mode = "strategy"
else: mode = "tactic" (default to simpler workflow for ambiguous cases)
```

**Workflow routing**:
- **Tactic mode**: Streamlined cycle (scope → plan → implement → test → grade), skips full specification and research phases
- **Strategy mode**: Full workflow (research → tribunal → specify → plan → tasks → implement → test → grade)

Developer can **override** automatic classification with `--mode=tactic` or `--mode=strategy` flags.

### Rationale
Not all development tasks are equal in complexity. Simple bug fixes, documentation updates, and focused refactors don't require the overhead of full specification, multi-LLM research, and tribunal voting. Routing small tasks to a streamlined workflow reduces latency (tactic mode is 2-3x faster) and cost (avoids unnecessary LLM calls) while maintaining quality for focused changes.

Conversely, complex features, architectural changes, and multi-component work require the rigor of the full strategy mode workflow to avoid missing requirements, introducing technical debt, or creating cross-cutting inconsistencies.

The heuristic approach (keyword + file count + cross-cutting) is designed to be simple, interpretable, and calibratable. Unlike ML-based classification, the heuristic can be manually tuned without retraining and provides explainable decisions (users can see which signals triggered the classification).

Default-to-tactic for ambiguous cases (score near 0) is conservative: it's better to route a medium-complexity task to tactic mode and escalate if needed than to route a simple task to strategy mode and waste resources.

Developer override is essential because the agent cannot perfectly infer intent from a natural-language description. A user who says "fix the auth bug" might be describing a one-line typo fix (tactic) or a systemic security vulnerability requiring architectural changes (strategy). Override allows the user to inject their domain knowledge when the heuristic is uncertain.

### Alternatives Considered
1. **Always use strategy mode (no scope detection)**: Advantage: consistent workflow, maximum rigor. Disadvantage: 2-3x higher latency and cost for simple tasks; poor user experience for trivial operations.

2. **Always use tactic mode (no full workflow)**: Advantage: maximum speed and cost efficiency. Disadvantage: fails on complex tasks that genuinely need research, specification, and tribunal validation; leads to poor-quality implementations of large features.

3. **ML-based classification (train classifier on labeled tasks)**: Advantage: potentially higher accuracy. Disadvantage: requires training data (which doesn't exist); black-box model reduces interpretability; harder to debug and tune; overkill for this use case.

4. **User-specified mode required (no automatic detection)**: Advantage: no risk of misclassification. Disadvantage: cognitive overhead; users often don't know whether their task is "tactic" or "strategy" sized until they try; defeats convenience of autonomous execution.

5. **Token/character count threshold**: Advantage: dead simple (if description > 500 chars, strategy mode). Disadvantage: description length is a poor proxy for complexity; verbose descriptions of simple tasks would be misrouted to strategy mode.

6. **AST-based file change estimation**: Advantage: more accurate file count. Disadvantage: requires pre-processing the codebase before the agent starts; can't run on description alone; adds latency.

**Decision**: Heuristic-based classification with developer override was chosen as the optimal balance of accuracy, speed, interpretability, and user control.

### Research Source
- **C33** (confidence 0.81, convergence 1/3): Scope detection via keyword analysis, file count estimation, and cross-cutting concern heuristics should route small tasks to "Tactic Mode" and large tasks to "Strategy Mode"

---

## Decision 9: Self-Extension Lifecycle — Detect, Scaffold, Quarantine, Register

### Decision
The plugin will support autonomous capability extension through a four-phase lifecycle:

**Phase 1: Capability Gap Detection**
- Agent tracks recurring inefficiencies during execution (e.g., "manual step repeated 5+ times," "external tool invoked but not integrated")
- Gaps are logged in session event stream with frequency counts
- At session end, high-frequency gaps (≥3 occurrences) are reported in session summary

**Phase 2: Plugin Scaffolding**
- Agent uses `/create-plugin` workflow to generate new plugin structure:
  - `plugin.json` manifest (name, version, entrypoint, permissions)
  - Skill directories with SKILL.md definitions
  - Stub implementation files with TODO markers
  - Test scaffolds (contract tests, unit tests)
- Scaffolding follows SDD plugin template conventions (Plugin-First Architecture v4.1)

**Phase 3: Quarantine Validation**
- New plugin is implemented via standard dev-loop targeting the plugin codebase
- Plugin is tested in a **restricted quarantine sandbox** (separate from main workspace)
- Validation steps:
  1. **Automated test suite** (must achieve >80% coverage per Principle II)
  2. **Security scan** (static analysis, dependency audit, must have 0 critical/high vulnerabilities)
  3. **Constitutional review** (LLM governor checks plugin against 16 framework principles, flags violations)
- Only plugins passing all three validation steps are eligible for registration

**Phase 4: Dynamic Registration**
- Validated plugin manifest is registered via **MCP (Model Context Protocol)** dynamic tool discovery
- Plugin becomes available for current and future sessions without system restart
- RL metrics are initialized for the new plugin (success_rate: 0.5, selection_weight: 0.5, invocation_count: 0)

### Rationale
Self-extension addresses the fundamental limitation of static agent systems: they cannot adapt to novel requirements beyond their initial capability set. SICA research (C37) demonstrates that self-modification of tool orchestration and problem decomposition heuristics yields 17% → 53% accuracy improvement on SWE Bench Verified, validating the viability of behavioral self-improvement.

The four-phase lifecycle balances autonomy with safety:
- **Detection** is passive and risk-free (logging only)
- **Scaffolding** generates boilerplate but doesn't execute code
- **Quarantine** ensures new plugins are tested in isolation before system integration
- **Registration** makes validated plugins available but doesn't force their use (selection is governed by RL feedback)

Constitutional review is a novel safety layer proposed by Gemini (C36). It addresses the attack surface created by self-extension: a malicious or buggy plugin could violate framework principles (e.g., bypass git approval, access credentials without permission). An LLM governor applying the 16 constitutional principles acts as a final sanity check beyond automated testing.

MCP (C19) provides the infrastructure for dynamic registration without system restarts. This is critical for long-running autonomous sessions where halting to install a new plugin would break session continuity.

### Alternatives Considered
1. **No self-extension (static capability set)**: Advantage: simplest, safest. Disadvantage: agent cannot adapt to novel requirements; requires manual framework updates to add capabilities; limits long-term autonomy.

2. **Unrestricted self-modification (agent can edit its own code)**: Advantage: maximum flexibility. Disadvantage: catastrophic safety risk; agent could introduce backdoors, disable safety checks, or brick itself; no production system uses this approach.

3. **Manual approval for all self-created plugins**: Advantage: maximum human oversight. Disadvantage: breaks autonomous execution; creates approval bottleneck; defeats purpose of self-extension.

4. **Self-extension without quarantine (test in main workspace)**: Advantage: faster iteration. Disadvantage: buggy plugins can corrupt workspace, introduce security vulnerabilities, or break existing functionality; blast radius is unbounded.

5. **Capability purchase from marketplace (no local scaffolding)**: Advantage: leverages community-created plugins. Disadvantage: requires external dependency; may not have plugins for novel/niche requirements; introduces supply chain security risk.

6. **Post-hoc constitutional review (human reviewer, not LLM)**: Advantage: highest quality governance. Disadvantage: requires human time; doesn't scale to high-frequency self-extension; delays plugin activation.

**Decision**: Four-phase lifecycle with quarantine validation and LLM constitutional review was chosen as the optimal balance of autonomy, safety, and framework integration.

### Research Source
- **C34** (confidence 0.97, convergence 3/3): Agent self-extension via detect gaps → scaffold plugins → validate in quarantine → dynamically register
- **C35** (confidence 0.81, convergence 1/3): Plugin manifest schema (name, version, entrypoint, permissions_required fields)
- **C36** (confidence 0.81, convergence 1/3): Constitutional review of self-created plugins before activation (LLM governor validation)
- **C37** (confidence 0.81, convergence 1/3): SICA demonstrated 17% → 53% accuracy improvement via self-modification of tool orchestration
- **C19** (confidence 0.97, convergence 3/3): MCP enables dynamic tool discovery and runtime plugin installation without restarts

---

## Decision 10: Multi-LLM Orchestration — Parallel Execution with Graceful Degradation

### Decision
All tribunal LLM calls will execute **in parallel via async/concurrent patterns** rather than sequentially. Total latency is determined by the **slowest model response**, not the sum of all model response times.

**Implementation**:
```bash
# Pseudo-code for bash async execution
claude_response=$(call_claude_api "$prompt" &)
openai_response=$(call_openai_api "$prompt" &)
gemini_response=$(call_gemini_api "$prompt" &)
wait  # Wait for all background jobs to complete
```

**Graceful degradation**:
- If 1 of 3 models fails (provider outage, rate limit, timeout), continue with remaining 2 models
- Adjust voting threshold from "2 of 3" to "2 of 2" (require unanimous agreement when only 2 models available)
- If 2 of 3 models fail, pause execution, save checkpoint, and notify user (tribunal cannot proceed with only 1 model)
- Log all provider failures in event stream for post-hoc analysis

**Infrastructure**:
- **Unified API abstraction layer**: Normalize request/response formats across providers (use LiteLLM or custom wrappers)
- **Per-provider rate limiting**: Track requests per minute/day, implement exponential backoff on 429 errors
- **Response normalization**: Convert all responses to common JSON schema with `{role, content, model, tokens_used, cost}` fields
- **Cost tracking**: Accumulate token usage and estimated cost per provider, enforce budget circuit breakers

### Rationale
Sequential LLM calls create unacceptable latency for tribunal decisions. If each model call takes 5-10 seconds, sequential execution means 15-30 seconds per tribunal checkpoint. With 3-5 tribunal checkpoints per session and 10-25 iterations per session, sequential calls would add 7-37 minutes of pure LLM latency overhead — most of which is idle waiting.

Parallel execution reduces tribunal latency from O(N * latency) to O(max(latency)) where N is the number of models. This is a 3x speedup for tribunal operations, making the tribunal mechanism viable for frequent use.

Graceful degradation ensures provider failures don't brick the entire system. LLM API outages are common (rate limits, service degradations, maintenance windows). A robust system must handle these failures without halting. Research (C38) shows that continuing with 2/3 models maintains decision quality at >90% of 3-model baseline while providing resilience.

The 2-of-2 unanimous agreement threshold when degraded to 2 models maintains conservative decision-making. While it increases the risk of deadlock (2 models more likely to disagree than 3), it prevents the system from accepting potentially incorrect decisions with only a single model's validation.

Unified API abstraction prevents the plugin from being tightly coupled to specific provider APIs. As new models become available (Claude Opus 5, GPT-5, Gemini 3), they can be integrated by adding provider adapters without changing core logic.

Cost tracking at the provider level is required because:
1. Different models have different pricing (Opus is 5x more expensive than Sonnet)
2. Users may have per-provider budget constraints (e.g., $50 OpenAI, $20 Google)
3. Budget exhaustion should trigger graceful degradation (disable the exhausted provider, continue with others) rather than hard failure

### Alternatives Considered
1. **Sequential execution**: Advantage: simpler implementation (no concurrency). Disadvantage: 3x higher latency; unacceptable user experience for frequent tribunal checkpoints.

2. **Primary + fallback (use GPT, call Claude only on failure)**: Advantage: reduces cost by avoiding multi-model calls when primary succeeds. Disadvantage: defeats purpose of tribunal (no redundancy, no error reduction); only provides failover, not validation.

3. **Hard failure on any provider outage**: Advantage: simplest error handling. Disadvantage: brittle; any transient provider issue halts entire session; poor user experience.

4. **Continue with 1 model when 2 fail**: Advantage: maximum resilience. Disadvantage: defeats purpose of tribunal; single-model decisions have no redundancy; research shows unacceptable error rates.

5. **Request-level retry with exponential backoff (per provider)**: Advantage: improves resilience to transient failures. Disadvantage: adds latency (5-10 second delays); can cascade into timeout issues; better to degrade to fewer models than delay all models.

6. **Static provider priority (always prefer Claude over GPT over Gemini)**: Advantage: simple cost optimization. Disadvantage: introduces favoritism bias; violates anonymous peer review principle; prevents EMA weighting from taking effect.

**Decision**: Parallel execution with graceful degradation was chosen to minimize latency while maintaining resilience and cost control.

### Research Source
- **C38** (confidence 0.90, convergence 2/3): Async/parallel API execution for multi-LLM latency reduction (slowest model determines total time, not sum)
- **FR-011** (from spec): System must continue tribunal operations with 2 of 3 models when one provider is unavailable

---

## Decision 11: Event Sourcing Architecture

### Decision
The plugin will log **every significant event** during execution into a **structured JSON event stream** stored at `.docs/dev-loop-sessions/<session-id>/events.jsonl` (newline-delimited JSON). Each event has:

```json
{
  "timestamp": "2026-02-07T14:32:15.234Z",
  "session_id": "dev-loop-20260207-143210",
  "iteration": 3,
  "event_type": "quality_grade | tribunal_vote | tool_invocation | thought | action | observation | decision",
  "payload": {
    // Event-type-specific structured data
  }
}
```

**Event types**:
- **thought**: Agent reasoning about next steps
- **action**: Tool invocation (read, write, test, etc.)
- **observation**: Tool response or system feedback
- **decision**: Tribunal vote outcome or termination decision
- **quality_grade**: Composite quality score and metric breakdown
- **tribunal_vote**: Individual model votes and consensus result
- **tool_invocation**: Detailed record of tool calls with inputs/outputs

**Use cases**:
1. **Session reports**: Aggregate events into human-readable summary (iteration count, quality trajectory, decisions made, resources consumed)
2. **Session replay**: Reconstruct exact execution path for debugging
3. **RL feedback extraction**: Connect session outcomes to skills/models that contributed
4. **Meta-learning**: Analyze patterns across sessions to improve heuristics
5. **Audit trail**: Provide verifiable record of all autonomous actions

### Rationale
Event sourcing treats the event log as the **source of truth** rather than derived state. This architectural pattern (popularized by OpenHands EventStream) provides:
1. **Complete observability**: Every decision and action is logged, enabling post-hoc debugging of "why did the agent do X?"
2. **Reproducibility**: Sessions can be replayed from events to reconstruct state at any point
3. **Auditability**: Comprehensive trail of autonomous actions for security review
4. **Meta-learning substrate**: Events provide rich training data for improving the system over time

The newline-delimited JSON format (JSONL) is append-efficient (O(1) writes), space-efficient (no need for enclosing array), and stream-processing-friendly (can process events incrementally without loading entire file).

Session-scoped storage (`.docs/dev-loop-sessions/<session-id>/`) enables efficient querying (load only relevant session) and cleanup (delete entire session directory to purge old logs).

Structured payload per event type balances flexibility (different events have different data) with schema enforcement (each event type has well-defined fields that can be validated).

### Alternatives Considered
1. **Unstructured text logs**: Advantage: human-readable, simple to generate. Disadvantage: hard to query programmatically; no schema enforcement; difficult to extract structured data for RL feedback.

2. **Single session state file (overwrite on each iteration)**: Advantage: minimal storage overhead. Disadvantage: loses history within session; cannot replay or debug intermediate states; no audit trail.

3. **Database storage (SQLite, PostgreSQL)**: Advantage: queryable via SQL, better for large-scale analysis. Disadvantage: adds external dependency; overkill for per-session logs; harder to backup/share (binary format); increases complexity.

4. **JSON array (single file per session)**: Advantage: valid JSON document. Disadvantage: requires rewriting entire file on each append (O(N) writes); can't process incrementally; file corruption risk if append fails mid-write.

5. **Event sourcing with snapshots (periodic state checkpoints)**: Advantage: faster session resume (restore from snapshot instead of replaying all events). Disadvantage: added complexity; snapshot consistency issues; not needed for sessions < 50 iterations.

6. **No event logging (only final session report)**: Advantage: minimal overhead. Disadvantage: loses ability to debug, replay, or analyze intermediate decisions; no audit trail; severely limits meta-learning opportunities.

**Decision**: JSONL event stream with session-scoped storage was chosen for optimal balance of observability, performance, and simplicity.

### Research Source
- **C25** (confidence 0.90, convergence 2/3): Event sourcing architecture for logging all thoughts, actions, observations, and decisions
- **FR-043 to FR-046** (from spec): System must log all events, generate session reports, support replay, and extract RL feedback from event log

---

## Decision 12: Plugin Structure and Naming

### Decision
The plugin will follow the SDD Plugin-First Architecture (v4.1) conventions:

**Plugin name**: `sdd-dev-loop` (category prefix: `sdd-`, function: `dev-loop`)

**Directory structure**:
```
plugins/sdd-dev-loop/
  plugin.json                     # Plugin manifest
  commands/
    dev-loop.md                   # Main /dev-loop command
  skills/
    tribunal-research/            # Multi-LLM research orchestration
    tribunal-vote/                # Voting/consensus execution
    scope-analysis/               # Tactic vs strategy detection
    autonomous-execute/           # Iteration execution loop
    quality-grade/                # Composite grading engine
    rl-feedback/                  # Performance tracking
    session-report/               # Report generation
    gap-detection/                # Capability gap identification
    plugin-scaffold/              # New plugin creation
  agents/
    dev-loop-orchestrator.md      # Main loop controller
    tribunal-judge.md             # Tribunal voting agent
    quality-assessor.md           # Quality grading agent
    debug-analyst.md              # Failure diagnosis agent
  templates/
    session-report.md             # Session report template
    tribunal-ballot.md            # Voting ballot template
    gap-analysis.md               # Capability gap template
  config/
    thresholds.json               # Quality thresholds, termination parameters
    safety-limits.json            # Budget limits, iteration limits, permissions
    weights.json                  # Quality metric weights, EMA parameters
  lib/
    grading.sh                    # Quality grading functions
    termination.sh                # Circuit breaker logic
    event-sourcing.sh             # Event logging functions
    llm-orchestration.sh          # Multi-LLM API wrapper
  tests/
    test-grading.sh               # Grading engine tests
    test-termination.sh           # Termination strategy tests
    test-tribunal.sh              # Tribunal voting tests
    test-scope-detection.sh       # Scope analysis tests
```

**Manifest** (`plugin.json`):
```json
{
  "name": "sdd-dev-loop",
  "version": "1.0.0",
  "category": "orchestration",
  "description": "Recursive autonomous dev-loop with council/tribunal methodology",
  "entrypoint": "commands/dev-loop.md",
  "permissions_required": ["L0_READ", "L1_SAFE_WRITE", "L2_NETWORK", "L2_VCS_COMMIT"],
  "permissions_elevated": ["L3_VCS_PUSH"],
  "dependencies": ["sdd-governance", "sdd-specification", "sdd-git"],
  "agents": 4,
  "skills": 9,
  "commands": 1
}
```

### Rationale
The `sdd-` prefix identifies this as a core framework plugin (vs. community plugins). The `dev-loop` name is descriptive and matches the primary command (`/dev-loop`).

The directory structure follows established SDD framework conventions:
- `commands/`: Slash commands discoverable by the command bridge
- `skills/`: Reusable capability modules with SKILL.md definitions
- `agents/`: Specialized subagents with agent.md definitions
- `templates/`: Document templates for consistent output formatting
- `config/`: JSON configuration files (separates config from code)
- `lib/`: Shared utility functions
- `tests/`: Test suite for >80% coverage (Principle II)

The manifest includes:
- **permissions_required**: Minimum permissions for base functionality (read, safe write, network for LLM APIs, git commit on current branch)
- **permissions_elevated**: Operations requiring per-action approval (git push)
- **dependencies**: Other plugins required for operation (governance for constitutional checks, specification for strategy mode, git for /finalize integration)
- **Metadata**: Agent, skill, and command counts for plugin registry

This structure enables:
1. **Automatic command discovery** via `.specify/scripts/bash/sync-plugin-commands.sh`
2. **Skill auto-indexing** for RL metrics integration
3. **Agent delegation** via existing framework agent registry
4. **Plugin marketplace** compatibility (manifest fields match marketplace schema)
5. **Testing infrastructure** (test files in standard location)

### Alternatives Considered
1. **Monolithic command (no skills/agents)**: Advantage: simpler structure. Disadvantage: not composable; cannot reuse components (e.g., tribunal voting) in other plugins; violates Plugin-First Architecture principle.

2. **Standalone tool (not a plugin)**: Advantage: no framework dependencies. Disadvantage: doesn't integrate with SDD governance, RL metrics, or command bridge; requires separate installation/configuration; can't leverage existing framework agents/skills.

3. **Multiple smaller plugins** (tribunal-voting, quality-grading, autonomous-execution as separate plugins): Advantage: maximum modularity. Disadvantage: increases dependency management complexity; requires inter-plugin communication protocol; splits cohesive feature across multiple directories.

4. **Flat directory structure (no skills/, agents/, lib/ subdirectories)**: Advantage: fewer directories. Disadvantage: harder to navigate; doesn't follow framework conventions; breaks auto-discovery mechanisms.

5. **YAML manifest instead of JSON**: Advantage: more human-readable. Disadvantage: JSON is the standard in the existing framework (all other plugins use plugin.json); requires adding YAML parser dependency.

**Decision**: Standard SDD plugin structure with `sdd-dev-loop` naming was chosen for framework consistency and tooling compatibility.

### Research Source
- **C35** (confidence 0.81, convergence 1/3): Plugin manifest schema with name, version, entrypoint, permissions_required fields
- **NFR-008** (from spec): Plugin must integrate with existing SDD framework plugin architecture, following manifest and directory conventions (Principle XVI)

---

## Summary

All 12 technical decisions are traceable to high-confidence research claims (30 claims with confidence ≥ 0.80, representing 78.9% of total research findings). The decisions form a cohesive architecture:

1. **Core loop** with fresh context per iteration (C01, C02, C03, C05)
2. **Tribunal voting** with 3 LLMs, anonymous review, and EMA weighting (C06, C07, C08, C14)
3. **Composite quality grading** with configurable weights (C15, C21, C22, C23)
4. **EMA-based RL feedback** with UCB1 skill selection (C13, C14, C24)
5. **Six-layer termination** with convergence detection (C11, C12, C26, C30, C31, C32)
6. **Docker sandboxing** with OS-level fallback (C09, C27, C28)
7. **Four-tier permissions** with git controls (C17, C18, C29)
8. **Scope detection** for tactic vs strategy routing (C33)
9. **Self-extension** with quarantine validation (C34, C35, C36, C37)
10. **Parallel LLM orchestration** with graceful degradation (C38)
11. **Event sourcing** for observability and meta-learning (C25)
12. **Plugin structure** following SDD conventions (C35, NFR-008)

This architecture provides autonomous recursive development with strong safety guarantees, multi-model validation, adaptive learning, and comprehensive observability.

---

**Research Confidence**: 97.4% tribunal consensus (37/38 claims unanimously approved)
**Total Claims**: 38 (30 confirmed ≥ 0.80, 7 likely 0.55-0.79, 1 conflicting 0.30-0.54, 0 refuted)
**Research Models**: Claude Opus 4.6, GPT-4o, Gemini 2.5 Pro
**Tribunal Models**: Claude Sonnet 4.5, GPT-4o, Gemini 2.5 Pro
