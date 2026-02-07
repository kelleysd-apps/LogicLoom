# Pass 3: Comparative Analysis -- Tribunal/Quorum Enhancement for /research-team

**Researcher**: Researcher 3 (Comparative Analysis)
**Date**: 2026-02-07
**Scope**: Architecture comparisons, integration options, cost analysis for adding tribunal/quorum-style voting to the /research-team command

---

## Table of Contents

1. [Current Architecture Baseline](#1-current-architecture-baseline)
2. [Tribunal Architecture Options (A-D)](#2-tribunal-architecture-options)
3. [Voting Round Architecture (Approaches 1-4)](#3-voting-round-architecture)
4. [Recursive Pass Architecture (Models 1-4)](#4-recursive-pass-architecture)
5. [Cost Analysis](#5-cost-analysis)
6. [Confidence Level Integration](#6-confidence-level-integration)
7. [Plugin Architecture Integration Map](#7-plugin-architecture-integration-map)
8. [Recommended Enhanced Workflow](#8-recommended-enhanced-workflow)
9. [Concrete File Changes](#9-concrete-file-changes)
10. [Final Recommendation](#10-final-recommendation)

---

## 1. Current Architecture Baseline

### Current Flow

```
/research-team "topic"
       |
       v
  [Step 1] Init directory: .docs/research/YYYYMMDD-HHMMSS/
       |
       v
  [Step 2] Spawn 3 parallel Task agents (20% budget each):
       |--- Researcher 1: Primary Sources --> pass-1-primary-sources.md
       |--- Researcher 2: Community        --> pass-2-community.md
       |--- Researcher 3: Comparative      --> pass-3-comparative.md
       |
       v
  [Step 3] Wait for all 3
       |
       v
  [Step 4] Spawn Synthesizer (40% budget):
       |   Reads all 3 reports, produces final-report.md
       |   Marks findings: Confirmed / Conflicting / Refuted
       |
       v
  [Step 5] Report to user
```

**Total agents**: 4 (3 researchers + 1 synthesizer)
**Budget split**: 20/20/20/40
**Default total**: $10.00
**Output**: 4 files (3 research passes + 1 final report)
**Validation**: None -- the synthesizer is the sole judge of finding quality

### Current Weakness

The synthesizer is a single point of failure for quality assessment. There is no cross-validation between researchers, no voting on individual findings, and no mechanism to flag low-confidence areas for re-research. The ternary confidence labels (Confirmed/Conflicting/Refuted) are assigned by one agent with no accountability or peer review.

### Related Commands in sdd-orchestrator

| Command | Pattern | Agents | Phase Structure |
|---------|---------|--------|-----------------|
| `/research` (single) | Sequential passes | 1 + domain expert | Explore -> Validate -> Synthesize |
| `/research-team` | Parallel + synth | 3 + 1 | Research(parallel) -> Synthesize |
| `/review-team` | Parallel + synth | 3 + 1 | Review(parallel) -> Synthesize |
| `/build-team` | Sequential pipeline | 3 | Architect -> Implement -> Review |
| `/swarm` | Dynamic graph | N (detected) | Dependency-ordered execution |

---

## 2. Tribunal Architecture Options

### Comparison Matrix

| Criterion | Option A: In-Place | Option B: New Skill | Option C: Flag Mode | Option D: Full Rewrite |
|-----------|-------------------|---------------------|---------------------|----------------------|
| **Complexity** | Medium | Medium-Low | Medium-High | High |
| **Backward Compat** | Breaking | Full | Full | Breaking |
| **New Files** | 0-1 | 2-3 | 0-1 | 1-2 |
| **Token Cost** | Always higher | Higher when used | User-controlled | Always higher |
| **Quality Gain** | High | High | High (when enabled) | Highest |
| **Implementation** | 2-4 hours | 3-5 hours | 4-6 hours | 6-10 hours |
| **Plugin Impact** | Modifies 1 file | Adds skill + agent | Modifies 1 file | Replaces 1 file |
| **User Control** | None | Explicit invocation | Explicit flag | None |
| **Principle XVI** | Stretches existing | Plugin-native | Stretches existing | Plugin-native |

### Detailed Analysis

**Option A: In-Place Enhancement**
- Modify `research-team.md` to add Steps 3.5 (tribunal) and 4.5 (quality gate) between current steps
- Pros: Minimal changes, no new files, single command
- Cons: Always pays tribunal cost, no way to skip, breaks the "simple parallel research" use case
- Risk: Existing users expecting 4-agent cost now get 7+ agents

**Option B: New Skill**
- Create `plugins/sdd-orchestrator/skills/tribunal-review/SKILL.md`
- Create `plugins/sdd-orchestrator/agents/tribunal-reviewer.md` (optional, can use existing team-synthesizer)
- The skill wraps the existing research-team flow and adds tribunal + confidence layers
- Pros: Clean separation, existing command unchanged, testable independently
- Cons: Two separate entry points may confuse users, skill needs its own command or invocation path

**Option C: Configurable Mode (RECOMMENDED)**
- Add `--tribunal` flag to existing `/research-team` command
- Default behavior unchanged (backward compatible)
- When `--tribunal` is passed: adds tribunal voting pass, confidence scoring, optional re-research
- Pros: User controls cost, backward compatible, single entry point, progressive enhancement
- Cons: Command file becomes more complex, conditional logic in markdown instructions

**Option D: Full Rewrite**
- Replace `research-team.md` entirely with a multi-pass architecture
- Always runs: Research -> Tribunal -> Synthesize -> Quality Gate -> (optional re-research)
- Pros: Cleanest design, no conditional complexity
- Cons: Breaking change, always expensive, alienates users who want quick research

### Architecture Decision

**Option C (Configurable Mode) is the strongest choice** because:
1. It respects Constitutional Principle V (Progressive Enhancement) by layering capability
2. It gives users cost control (the #1 concern with multi-agent workflows)
3. It maintains backward compatibility (no breaking changes to existing behavior)
4. It aligns with existing patterns -- other commands already support optional flags (e.g., `--budget`)
5. It keeps a single entry point, reducing cognitive load

---

## 3. Voting Round Architecture

### Comparison Matrix

| Criterion | Approach 1: Full Cross-Review | Approach 2: Summary Cross-Review | Approach 3: Claim-Level | Approach 4: Adversarial |
|-----------|-------------------------------|----------------------------------|------------------------|------------------------|
| **Quality** | Very High | Medium | Highest | High |
| **Cost (tokens)** | Very High | Low-Medium | Medium-High | Medium |
| **Complexity** | Low | Low | High | Medium |
| **Nuance Capture** | Excellent | Poor-Medium | Excellent | Good |
| **Output Structure** | Unstructured reviews | Summary + votes | Structured claim table | Challenge/defense pairs |
| **Actionability** | Medium | Low | Very High | High |
| **Implementation** | Simple | Simple | Complex | Medium |
| **Scalability** | Poor (O(n^2) reads) | Good (O(n) reads) | Good (O(claims * voters)) | Good (O(n) targeted) |

### Detailed Analysis

**Approach 1: Full Cross-Review**
Each of 3 tribunal reviewers reads ALL 3 full research reports and writes a comprehensive review.
- Token math: 3 reviewers x (3 reports read + 1 review written) = ~9 full-report reads + 3 review outputs
- If each report is ~4,000 tokens: 9 x 4,000 = 36,000 input tokens + ~12,000 output tokens
- Quality is high because reviewers see full context, but much of the reading is redundant
- Risk: Reviewers may anchor on the first report they read (order bias)

**Approach 2: Summary Cross-Review**
Synthesizer creates a condensed summary of key findings first, then 3 reviewers vote on the summary.
- Token math: 1 summary step (~8,000 in, ~2,000 out) + 3 reviewers x (~2,000 in, ~1,000 out)
- Total: ~14,000 input + ~5,000 output
- Much cheaper but loses nuance -- reviewers cannot challenge methodology or source quality
- Good for speed, bad for rigor

**Approach 3: Claim-Level Review (RECOMMENDED for --tribunal mode)**
Extract individual claims/findings from each report, present them as a structured list, and have each reviewer vote on each claim independently.
- Token math: 1 extraction step (~12,000 in, ~3,000 out for 20-30 claims) + 3 reviewers x (~3,000 in, ~2,000 out)
- Total: ~21,000 input + ~9,000 output
- Produces the most actionable output: a table of claims with vote tallies
- Aligns with academic literature on DelphiAgent (multi-agent claim-level verification)
- Output format is directly usable as a confidence table

**Approach 4: Adversarial Review**
Each researcher is re-invoked to specifically challenge the weakest findings from the other two.
- Token math: 3 adversarial agents x (~8,000 in reading 2 reports, ~3,000 out challenging)
- Total: ~24,000 input + ~9,000 output
- Most effective at catching errors and unsupported claims
- Risk: Can be overly negative, may reject valid findings that simply lack sources
- Natural tension produces higher quality but requires careful prompt engineering

### Voting Architecture Decision

**Approach 3 (Claim-Level Review) is the strongest choice** for the `--tribunal` mode because:
1. It produces the most structured, actionable output (claim table with vote tallies)
2. It is moderately expensive (not as costly as full cross-review)
3. It aligns with published research on multi-agent fact verification (FACT-AUDIT, DelphiAgent)
4. The output format naturally integrates with the existing Confirmed/Conflicting/Refuted labels
5. Individual claim granularity enables targeted re-research (only re-research low-confidence claims)

### Proposed Claim-Level Voting Flow

```
Step 1: Claim Extraction
   Input: 3 research reports
   Output: claims.json -- structured list of 20-40 claims
   Format per claim:
     {
       "id": "C01",
       "claim": "GraphQL reduces over-fetching by 40-60%",
       "source_researcher": "Researcher 1",
       "category": "performance",
       "evidence": "Official GraphQL documentation benchmarks"
     }

Step 2: Tribunal Voting (3 parallel reviewers)
   Input: claims.json + original 3 reports (for context)
   Each reviewer produces votes.json:
     {
       "reviewer": "Tribunal 1",
       "votes": [
         {"claim_id": "C01", "vote": "confirm", "confidence": 0.9, "note": "Matches my research"},
         {"claim_id": "C02", "vote": "challenge", "confidence": 0.4, "note": "Source is outdated"}
       ]
     }

Step 3: Vote Aggregation
   Tally votes per claim:
     - 3/3 confirm = Confirmed (high confidence)
     - 2/3 confirm = Confirmed (moderate confidence)
     - 1/3 confirm = Conflicting (low confidence, flag for re-research)
     - 0/3 confirm = Refuted (remove or re-research)
```

---

## 4. Recursive Pass Architecture

### Comparison Matrix

| Criterion | Model 1: Fixed Passes | Model 2: Quality-Gated | Model 3: Targeted Re-Research | Model 4: Full Delphi |
|-----------|----------------------|------------------------|-------------------------------|---------------------|
| **Quality** | Good | Very Good | Excellent | Highest |
| **Cost Predictability** | Exact | Variable (1-3x) | Variable (1-1.5x) | Highly variable |
| **Max Cost** | Fixed (known) | 3x base | 1.5x base | 5x+ base |
| **Implementation** | Trivial | Medium | Medium | Very High |
| **User Experience** | Simple | Uncertain wait | Efficient | Long waits |
| **Convergence** | Guaranteed (1 pass) | Probabilistic | Targeted | Proven in literature |
| **Useful When** | Quick research | Critical decisions | Most research tasks | Academic rigor |

### Detailed Analysis

**Model 1: Fixed Passes**
Always 2 passes: initial research + tribunal review. No recursion.
- Predictable: users always know cost and time upfront
- Simple: no quality check logic, no looping
- Weakness: if tribunal finds major issues, user must manually re-run
- Best for: most use cases where users want cost control

**Model 2: Quality-Gated**
After tribunal, compute overall confidence score. If below threshold (e.g., 0.85), automatically re-research.
- Uses existing `refinement.conf` thresholds (consistency with DS-STAR)
- Risk: could loop multiple times, unpredictable cost
- Needs hard cap (max 3 passes per `MAX_REFINEMENT_ROUNDS` pattern)
- Best for: high-stakes decisions where quality matters more than cost

**Model 3: Targeted Re-Research (RECOMMENDED)**
After tribunal, identify ONLY the claims with low confidence (0/3 or 1/3 votes), then spawn a focused re-research agent for just those areas.
- Efficient: does not re-research confirmed findings
- Cost-effective: re-research agent only handles the problematic subset
- Token math: if 20% of claims need re-research, re-research cost is ~20% of original
- Aligns with Option C's progressive philosophy: only pay for what you need
- Implementation: filter claims by vote count, spawn 1 targeted researcher
- Best for: balancing quality and cost

**Model 4: Full Delphi**
Multiple rounds of anonymous voting with feedback until convergence (all agents agree or max rounds hit).
- Academic gold standard (mirrors the Delphi technique in management science)
- DelphiAgent paper shows effectiveness for fact verification
- Extremely expensive: 3-5+ rounds x 3 agents = 9-15+ agent invocations
- Long execution time: could take 30-60+ minutes
- Impractical for most development research use cases
- Best for: only the most critical, high-stakes research where errors are very costly

### Recursive Architecture Decision

**Model 3 (Targeted Re-Research) is the strongest choice** because:
1. It is the most token-efficient recursive approach (only re-researches problem areas)
2. It integrates naturally with Claim-Level Voting (Approach 3) -- low-vote claims are the input
3. Cost overhead is proportional to the problem, not fixed
4. It can be combined with a hard cap (1 re-research pass max) for predictability
5. Users see value: "6 of 25 claims needed re-verification, 4 upgraded to Confirmed after re-research"

### Proposed Recursive Flow

```
After Tribunal:
   |
   v
  [Quality Gate] Count claims with <2/3 votes
   |
   |--> If all claims >= 2/3 votes: SKIP re-research, proceed to final synthesis
   |
   |--> If some claims <2/3 votes AND --tribunal flag used:
         |
         v
        [Targeted Re-Research] Spawn 1 agent focused on low-confidence claims
         |   Input: list of disputed claims + original topic
         |   Output: supplementary-research.md
         |
         v
        [Re-Vote] Quick vote on supplemented claims (optional, or just include in final)
         |
         v
        [Final Synthesis] Include re-research in final report with updated confidence
```

---

## 5. Cost Analysis

### Token Cost Model

Based on Claude Opus 4.6 pricing (as of February 2026):
- **Input tokens**: $5/million tokens
- **Output tokens**: $25/million tokens
- **Premium input** (>200k context): $10/million tokens

### Per-Agent Token Estimates

| Agent Role | Est. Input Tokens | Est. Output Tokens | Input Cost | Output Cost | Total |
|------------|------------------:|-------------------:|-----------:|------------:|------:|
| Researcher (each) | ~15,000 | ~4,000 | $0.075 | $0.100 | $0.175 |
| Synthesizer (reads 3 reports) | ~25,000 | ~5,000 | $0.125 | $0.125 | $0.250 |
| Claim Extractor | ~15,000 | ~3,000 | $0.075 | $0.075 | $0.150 |
| Tribunal Reviewer (each) | ~10,000 | ~2,000 | $0.050 | $0.050 | $0.100 |
| Targeted Re-Researcher | ~12,000 | ~3,000 | $0.060 | $0.075 | $0.135 |
| Final Confidence Synthesizer | ~30,000 | ~6,000 | $0.150 | $0.150 | $0.300 |

*Note: These estimates include system prompts, command files, and tool overhead. Actual costs vary by topic complexity and web search volume.*

### Scenario Cost Comparison

| Scenario | Agents | Est. Input | Est. Output | Est. Total Cost | Time |
|----------|-------:|----------:|-----------:|----------------:|-----:|
| **Current baseline** | 4 | ~70k | ~17k | **~$0.78** | 5-10 min |
| **+ Tribunal only (fixed)** | 8 | ~120k | ~26k | **~$1.25** | 10-15 min |
| **+ Tribunal + re-research** | 9-10 | ~140k | ~32k | **~$1.50** | 12-20 min |
| **Full Delphi (3 rounds)** | 13-16 | ~220k | ~50k | **~$2.35** | 25-40 min |

### Cost Multipliers by Configuration

| Configuration | Cost vs. Baseline | Quality vs. Baseline | Cost/Quality Ratio |
|--------------|------------------:|---------------------:|-------------------:|
| Baseline (current) | 1.0x | 1.0x | 1.00 |
| `--tribunal` (Claim-Level + Targeted) | ~1.9x | ~1.6x | 1.19 |
| `--tribunal --no-reresearch` | ~1.6x | ~1.4x | 1.14 |
| Full Delphi (theoretical) | ~3.0x | ~1.8x | 1.67 |

### Budget Allocation (Recommended for --tribunal mode)

| Phase | Budget % | Agents |
|-------|----------|--------|
| Research (parallel) | 35% | 3 researchers |
| Claim Extraction | 5% | 1 extractor (can be done by synthesizer) |
| Tribunal Voting (parallel) | 20% | 3 tribunal reviewers |
| Targeted Re-Research | 10% | 0-1 re-researcher (conditional) |
| Final Synthesis | 20% | 1 synthesizer |
| Buffer | 10% | overhead/retries |

### Cost Optimization Strategies

1. **Use Sonnet 4.5 for Tribunal Reviewers**: Voting on extracted claims is a simpler task than original research. Sonnet at $3/$15 per million tokens saves ~40% on the tribunal phase with minimal quality loss.

2. **Use Haiku for Claim Extraction**: Extracting structured claims from text is a straightforward task. Haiku at $0.80/$4 per million tokens saves ~90% on the extraction step.

3. **Skip Re-Research When Confidence is High**: If >80% of claims have 2/3+ votes, skip the re-research entirely. This makes the common case (good research) cheaper.

4. **Batch API for Non-Interactive Research**: For research that does not need real-time results, Batch API offers 50% discount on all token costs.

5. **Claim Deduplication**: Before tribunal voting, deduplicate overlapping claims across the 3 researchers to reduce the voting surface area.

6. **Model Routing Per Phase**: Apply Principle XIV (AI Model Selection) per phase:

| Phase | Recommended Model | Rationale |
|-------|-------------------|-----------|
| Research (3 agents) | Opus 4.6 | Deep reasoning needed for quality research |
| Claim Extraction | Haiku | Structured extraction is simple |
| Tribunal Voting | Sonnet 4.5 | Moderate reasoning, structured output |
| Re-Research | Opus 4.6 | Needs deep analysis of disputed areas |
| Final Synthesis | Opus 4.6 | Critical output quality matters most |

**Cost with model routing**: ~$1.10 (vs. $1.50 all-Opus) -- a ~27% reduction.

---

## 6. Confidence Level Integration

### Comparison of Confidence Representations

| Approach | Granularity | User Clarity | Machine Parseable | Cost to Compute |
|----------|-------------|-------------|-------------------|-----------------|
| Binary (Confirmed/Refuted) | Low | Very Clear | Yes | Zero (trivial) |
| Ternary (current: Confirmed/Conflicting/Refuted) | Low-Medium | Clear | Yes | Zero (current) |
| Numeric (0.0-1.0) | High | Unclear to users | Yes | Medium (LLM scoring) |
| Vote-based (N/3 votes) | Medium | Very Clear | Yes | Inherent in tribunal |
| Hybrid: Vote-based + Numeric | High | Clear | Yes | Built-in |

### Recommended: Hybrid Vote-Based Confidence

Combine the vote tally (intuitive) with a derived confidence score (machine-usable):

```markdown
| # | Claim | Votes | Confidence | Status |
|---|-------|-------|------------|--------|
| C01 | GraphQL reduces over-fetching by 40-60% | 3/3 | 0.95 | Confirmed |
| C02 | REST has better caching support | 2/3 | 0.70 | Confirmed (moderate) |
| C03 | GraphQL N+1 is a non-issue with DataLoader | 1/3 | 0.35 | Conflicting |
| C04 | GraphQL has higher learning curve | 3/3 | 0.90 | Confirmed |
| C05 | REST is always faster for simple CRUD | 0/3 | 0.10 | Refuted |
```

### Confidence Derivation Formula

```
base_confidence = votes / total_voters   # 0/3=0.0, 1/3=0.33, 2/3=0.67, 3/3=1.0

# Adjust for reviewer notes (optional weighting)
if any reviewer flagged "strong evidence": base_confidence += 0.05
if any reviewer flagged "outdated source": base_confidence -= 0.10

final_confidence = clamp(base_confidence, 0.0, 1.0)
```

### Confidence-to-Status Mapping

| Vote Count | Confidence Range | Status Label | Color | Action |
|-----------|-----------------|--------------|-------|--------|
| 3/3 | 0.85-1.0 | Confirmed | Green | Include in recommendations |
| 2/3 | 0.55-0.84 | Likely | Yellow-Green | Include with caveat |
| 1/3 | 0.25-0.54 | Conflicting | Orange | Flag for re-research or user judgment |
| 0/3 | 0.0-0.24 | Refuted | Red | Exclude or note as disproven |

### Why Hybrid is Best

1. **Vote tallies** are immediately understandable to any user ("2 out of 3 reviewers agree")
2. **Numeric scores** enable programmatic quality gating (e.g., "overall report confidence: 0.82")
3. **Status labels** provide at-a-glance assessment in the final report
4. **Derivation from votes** means no additional LLM calls are needed -- confidence is computed, not estimated
5. Existing ternary system (Confirmed/Conflicting/Refuted) is preserved and extended, not replaced

---

## 7. Plugin Architecture Integration Map

### Files That Need to Change

```
plugins/sdd-orchestrator/
  commands/
    research-team.md           # MODIFY: Add --tribunal flag logic
  skills/
    tribunal-review/           # NEW: Tribunal review skill
      SKILL.md                 #   Claim extraction + voting protocol
    team-orchestration/
      SKILL.md                 # MINOR: Add tribunal phase support
  agents/
    team-synthesizer.md        # MODIFY: Add confidence table output support
  .claude-plugin/
    plugin.json                # MODIFY: Bump version, add keyword "tribunal"
  hooks/
    hooks.json                 # NO CHANGE (existing Stop hooks sufficient)
  README.md                    # MODIFY: Document --tribunal option

.specify/config/
  refinement.conf              # MODIFY: Add TRIBUNAL_* config parameters

.claude/commands/
  research-team.md             # AUTO-SYNCED via command bridge (no manual change)
```

### New Files Required

| File | Purpose | Size Estimate |
|------|---------|---------------|
| `plugins/sdd-orchestrator/skills/tribunal-review/SKILL.md` | Tribunal voting protocol, claim extraction instructions, vote aggregation | ~100 lines |

### Impact on Other Orchestrator Commands

| Command | Impact | Reason |
|---------|--------|--------|
| `/research` (single) | None | Different flow (sequential, not parallel team) |
| `/review-team` | Future candidate | Could benefit from same tribunal pattern later |
| `/build-team` | None | Sequential pipeline, different pattern |
| `/fullstack-team` | None | Implementation-focused, not research |
| `/swarm` | None | Dynamic graph, independent architecture |

### Configuration Additions to refinement.conf

```bash
# ===================================================================
# Tribunal Research Configuration
# ===================================================================

# Enable tribunal mode for /research-team (can be overridden with --tribunal flag)
TRIBUNAL_ENABLED_BY_DEFAULT=false

# Number of tribunal reviewers (must be odd for majority voting)
TRIBUNAL_REVIEWER_COUNT=3

# Confidence threshold below which claims are flagged for re-research
TRIBUNAL_RERESEARCH_THRESHOLD=0.55

# Maximum re-research passes (prevents runaway costs)
TRIBUNAL_MAX_RERESEARCH_PASSES=1

# Model for tribunal reviewers (cost optimization)
TRIBUNAL_REVIEWER_MODEL="sonnet"

# Model for claim extraction
TRIBUNAL_EXTRACTION_MODEL="haiku"
```

### Agent Definitions

No new agent definitions are strictly required. The existing `team-synthesizer` agent can be extended for claim extraction and confidence synthesis. Tribunal reviewers can be instantiated as generic Task tool subagents with role-specific prompts (same pattern as the current 3 researchers).

However, if a dedicated agent is desired for clarity:

```yaml
# Optional: plugins/sdd-orchestrator/agents/tribunal-reviewer.md
name: tribunal-reviewer
description: Reviews research claims and votes on accuracy, sourcing, and relevance.
tools: Read, Write, Grep
model: sonnet  # Cost-optimized per Principle XIV
```

---

## 8. Recommended Enhanced Workflow

### Complete Enhanced Flow (with --tribunal)

```
/research-team "topic" --tribunal
       |
       v
  [Phase 1: RESEARCH] ===========================
  |
  |  [Step 1] Init directory
  |  [Step 2] Spawn 3 parallel researchers (same as current)
  |     |--- R1: Primary Sources --> pass-1-primary-sources.md
  |     |--- R2: Community        --> pass-2-community.md
  |     |--- R3: Comparative      --> pass-3-comparative.md
  |  [Step 3] Wait for all 3
  |
  v
  [Phase 2: TRIBUNAL] ===========================
  |
  |  [Step 4] Claim Extraction (model: haiku)
  |     Input: 3 research reports
  |     Output: claims.json (20-40 structured claims)
  |
  |  [Step 5] Spawn 3 parallel tribunal reviewers (model: sonnet)
  |     Input: claims.json + original 3 reports
  |     |--- T1: Accuracy Reviewer   --> tribunal-votes-1.json
  |     |--- T2: Sourcing Reviewer   --> tribunal-votes-2.json
  |     |--- T3: Relevance Reviewer  --> tribunal-votes-3.json
  |  [Step 6] Wait for all 3
  |
  |  [Step 7] Vote Aggregation
  |     Input: 3 vote files
  |     Output: confidence-table.md (claims with tallied votes + confidence scores)
  |
  v
  [Phase 3: RE-RESEARCH (conditional)] ===========
  |
  |  [Step 8] Quality Gate
  |     Count claims with confidence < 0.55
  |     If 0 low-confidence claims: SKIP to Phase 4
  |     If >0 low-confidence claims: continue
  |
  |  [Step 9] Spawn 1 Targeted Re-Researcher (model: opus)
  |     Input: low-confidence claims + original topic
  |     Output: supplementary-research.md
  |
  |  [Step 10] Update confidence table with supplementary findings
  |
  v
  [Phase 4: SYNTHESIS] ===========================
  |
  |  [Step 11] Spawn Final Synthesizer (model: opus)
  |     Input: All research reports + confidence-table.md + supplementary-research.md
  |     Output: final-report.md
  |
  |     Final report includes:
  |       - Executive summary
  |       - Confidence-scored findings table
  |       - Vote-backed recommendations (only claims with >= 2/3 votes)
  |       - Dissenting opinions preserved with context
  |       - Re-researched findings noted
  |       - 10+ source references
  |       - Actionable next steps (prioritized by confidence)
  |
  v
  [Phase 5: REPORT] ==============================
  |
  |  [Step 12] Report to user:
  |     - Research directory path
  |     - Total claims extracted
  |     - Confidence distribution (X confirmed, Y conflicting, Z refuted)
  |     - Re-research summary (if applicable)
  |     - Key recommendations (confidence-weighted)
  |     - Cost breakdown by phase
```

### Output Directory Structure (with --tribunal)

```
.docs/research/YYYYMMDD-HHMMSS/
  pass-1-primary-sources.md      # Phase 1: Researcher 1 output
  pass-2-community.md            # Phase 1: Researcher 2 output
  pass-3-comparative.md          # Phase 1: Researcher 3 output
  claims.json                    # Phase 2: Extracted claims
  tribunal-votes-1.json          # Phase 2: Tribunal reviewer 1 votes
  tribunal-votes-2.json          # Phase 2: Tribunal reviewer 2 votes
  tribunal-votes-3.json          # Phase 2: Tribunal reviewer 3 votes
  confidence-table.md            # Phase 2: Aggregated confidence scores
  supplementary-research.md      # Phase 3: Re-research (if triggered)
  final-report.md                # Phase 4: Final synthesis with confidence
```

### Budget Allocation (--tribunal mode, $10 default)

| Phase | Budget | Agents | Model |
|-------|-------:|-------:|-------|
| Research | $3.50 (35%) | 3 | Opus |
| Claim Extraction | $0.50 (5%) | 1 | Haiku |
| Tribunal Voting | $1.50 (15%) | 3 | Sonnet |
| Re-Research | $1.00 (10%) | 0-1 | Opus |
| Final Synthesis | $2.50 (25%) | 1 | Opus |
| Buffer | $1.00 (10%) | - | - |

---

## 9. Concrete File Changes

### 9.1 research-team.md (Modified)

Key changes to `plugins/sdd-orchestrator/commands/research-team.md`:

```markdown
## Usage
/research-team "Evaluate GraphQL vs REST for our API layer"
/research-team "Compare React, Vue, and Svelte for our frontend" --budget 15.00
/research-team "Critical architecture decision" --tribunal
/research-team "High-stakes evaluation" --tribunal --budget 20.00
```

Add after current Step 4 (Synthesizer) but restructure so the synthesizer only runs in the non-tribunal path, and the tribunal flow replaces the synthesizer with the enhanced pipeline:

```markdown
### Tribunal Mode (when --tribunal flag is present)

If $ARGUMENTS contains --tribunal, execute Steps 4T-8T instead of Step 4.

#### Step 4T: Extract Claims (5% budget, model: haiku)
[Claim extraction instructions]

#### Step 5T: Spawn 3 Parallel Tribunal Reviewers (15% budget, model: sonnet)
[Tribunal voting instructions]

#### Step 6T: Aggregate Votes
[Vote tallying instructions]

#### Step 7T: Quality Gate + Targeted Re-Research (10% budget, conditional)
[Re-research instructions]

#### Step 8T: Enhanced Synthesis (25% budget, model: opus)
[Confidence-aware synthesis instructions]
```

### 9.2 tribunal-review/SKILL.md (New)

```markdown
---
name: tribunal-review
description: |
  Claim-level tribunal review skill for research validation.
  Extracts claims from research reports, coordinates parallel voting
  by tribunal reviewers, aggregates confidence scores, and triggers
  targeted re-research for low-confidence findings.
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Tribunal Review Skill

## Procedure
1. Read all research reports from the research directory
2. Extract structured claims (20-40 per research session)
3. Spawn N tribunal reviewers (default 3) to vote on each claim
4. Aggregate votes into confidence table
5. Identify low-confidence claims (< threshold)
6. Trigger targeted re-research if needed
7. Produce updated confidence table

## Claim Extraction Format
[JSON schema for claims]

## Vote Format
[JSON schema for votes]

## Aggregation Algorithm
[Vote counting + confidence derivation]
```

### 9.3 plugin.json (Modified)

```json
{
  "name": "sdd-orchestrator",
  "version": "2.1.0",
  "description": "Multi-agent orchestration plugin -- task orchestration with MCP marketplace integration, tribunal research validation, dynamic plugin discovery, RL-weighted routing, and on-demand plugin creation.",
  "keywords": [
    "sdd", "orchestrator", "swarm", "multi-agent", "team",
    "parallel", "marketplace", "discovery", "tribunal", "voting"
  ]
}
```

### 9.4 refinement.conf (Modified)

Add the `Tribunal Research Configuration` section documented in Section 7.

---

## 10. Final Recommendation

### Summary of Recommended Choices

| Decision Point | Recommendation | Key Reason |
|---------------|---------------|------------|
| Architecture option | **C: Configurable Mode** (`--tribunal` flag) | Backward compatible, user-controlled cost |
| Voting approach | **3: Claim-Level Review** | Most structured, actionable, moderate cost |
| Recursive approach | **3: Targeted Re-Research** | Efficient, proportional cost, quality-focused |
| Confidence format | **Hybrid: Vote-based + Numeric** | Human-readable + machine-parseable |
| Cost optimization | **Model routing per phase** | ~27% savings, minimal quality loss |

### Implementation Priority Order

1. **Phase 1 (MVP)**: Add `--tribunal` flag to `research-team.md` with claim extraction + 3-reviewer voting + confidence table. No re-research yet.
   - Effort: 3-4 hours
   - Files: `research-team.md` (modify), `tribunal-review/SKILL.md` (new)
   - Cost increase: ~1.6x baseline

2. **Phase 2**: Add targeted re-research for low-confidence claims + quality gate.
   - Effort: 2-3 hours
   - Files: `research-team.md` (modify), `refinement.conf` (modify)
   - Cost increase: ~1.9x baseline (when re-research triggers)

3. **Phase 3 (future)**: Add model routing per phase (Haiku for extraction, Sonnet for voting) + cost dashboard.
   - Effort: 2-3 hours
   - Files: `research-team.md` (modify), `plugin.json` (modify)
   - Cost reduction: ~27% from Phase 2

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Token cost exceeds budget | Medium | Medium | Hard budget cap per phase, model routing |
| Tribunal reviewers agree on wrong answer | Low | High | Diverse reviewer prompts (accuracy, sourcing, relevance) |
| Claim extraction misses key findings | Medium | Medium | Extraction prompt quality, include "other" category |
| Users confused by --tribunal flag | Low | Low | Clear documentation, example usage in help text |
| Re-research loop runs away | Very Low | Medium | Hard cap at 1 re-research pass in config |

---

## References

1. [Voting or Consensus? Decision-Making in Multi-Agent Systems](https://aclanthology.org/2025.findings-acl.606.pdf) -- ACL 2025
2. [DelphiAgent: Multi-Agent Verification Framework](https://www.sciencedirect.com/science/article/abs/pii/S0306457325001827) -- ScienceDirect 2025
3. [FACT-AUDIT: Adaptive Multi-Agent Framework for Claim Verification](https://aclanthology.org/2025.acl-long.17.pdf) -- ACL 2025
4. [Multi-Agent Debate for LLM Judges with Adaptive Stability Detection](https://arxiv.org/html/2510.12697v1) -- arXiv 2025
5. [Claude Opus 4.6 Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams) -- Anthropic 2026
6. [Claude Opus 4.6 Pricing](https://platform.claude.com/docs/en/about-claude/pricing) -- Anthropic 2026
7. [Multi-LLM Agents Architecture for Claim Verification](https://ceur-ws.org/Vol-3962/paper20.pdf) -- CEUR 2025
8. [Improving Factuality and Reasoning via Multiagent Debate](https://composable-models.github.io/llm_debate/) -- 2025
9. [Enhancing LLM-as-a-Judge via Multi-Agent Collaboration](https://www.amazon.science/publications/enhancing-llm-as-a-judge-via-multi-agent-collaboration) -- Amazon Science 2025
10. [Claude Code Swarms Guide](https://addyosmani.com/blog/claude-code-agent-teams/) -- Addy Osmani 2026

---

*Generated by Researcher 3 (Comparative Analysis) as part of /research-team tribunal enhancement investigation*
*Framework: sdd-agentic-framework v4.1.0 | Plugin: sdd-orchestrator v2.0.0*
