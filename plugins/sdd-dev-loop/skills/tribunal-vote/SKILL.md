---
name: tribunal-vote
version: 0.1.0
description: |
  Multi-model tribunal voting orchestration skill. Manages the full ballot lifecycle:
  anonymous claim submission from three independent AI models, confidence-weighted
  cross-evaluation voting, EMA-weighted tally with consensus determination, and
  post-tally de-anonymization for RL feedback.
allowed-tools: Read, Grep, WebSearch, Bash
triggers:
  - tribunal_vote
  - tribunal-vote
category: orchestration
constitutional_principles:
  - VI   # Git Approval: tribunal never performs git operations
  - X    # Agent Delegation: tribunal-judge is the designated specialist
  - XIV  # AI Model Selection: three distinct models prevent single-model bias
rl_metrics:
  success_rate: 0.5
  selection_weight: 0.5
  invocation_count: 0
  avg_tokens: 0
  last_updated: null
---

# Tribunal Vote Skill

## Overview

The tribunal-vote skill orchestrates multi-model anonymous voting for strategy-mode
decision points in the dev-loop. It coordinates three independent AI models (Claude,
GPT-4o, Gemini 2.5 Pro) through a four-phase anonymized ballot protocol, producing
confidence-weighted verdicts that are resistant to single-model bias, self-bias,
reputation bias, and authority bias.

The skill is invoked by the `tribunal-judge` agent at defined checkpoints during
strategy-mode execution:

- **Research**: Evaluate competing research directions and source synthesis
- **Approach**: Select implementation approach from candidate strategies
- **Quality Dispute**: Resolve disagreement between automated grading and semantic evaluation

## Operations

### Operation 1: Create Ballot

Create a new tribunal ballot, assigning anonymized identities and preparing
for parallel model queries.

**Inputs**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `session_id` | string | yes | Parent DevLoopSession reference |
| `round` | enum | yes | `research`, `approach`, or `quality_dispute` |
| `decision_point` | string | yes | Natural language description of the decision |
| `models` | string | yes | Comma-separated model identifiers (e.g., `claude-opus-4-6,gpt-4o,gemini-2.5-pro`) |
| `workdir` | string | yes | Working directory for ballot storage |

**Procedure**:

1. Validate inputs:
   - `decision_point` must be non-empty (error: `INVALID_DECISION_POINT`)
   - `round` must be one of the valid values (error: `INVALID_ROUND`)
   - At least 2 models must be provided (error: `INSUFFICIENT_MODELS`)

2. Generate ballot ID: `ballot-{YYYYMMDD}-{HHMMSS}-{round}`

3. Randomize anonymization mapping:
   - Shuffle the model list randomly
   - Assign `model-A`, `model-B`, `model-C` to the shuffled order
   - Store the sealed mapping separately from the ballot

4. Query all models in parallel via `tribunal-api.sh`:
   ```bash
   source plugins/sdd-dev-loop/lib/tribunal-api.sh
   load_api_keys
   call_all_models_parallel "$system_prompt" "$decision_point"
   ```

5. Collect anonymized claims from model responses:
   - Each response becomes a claim with `anonymized_model_id`, `assessment`,
     `confidence`, and `reasoning`
   - Claims are stored in shuffled order (not correlated with model identity)

6. Initialize ballot JSON with empty votes array and null verdict/consensus

7. Log ballot creation event:
   ```bash
   source plugins/sdd-dev-loop/lib/event-logger.sh
   log_event "vote" "$iteration" "Ballot created: $ballot_id" "$metadata"
   ```

**Outputs**: JSON ballot object matching the `tribunal-ballot.md` entity schema
(state: `created` with claims populated, votes empty)

### Operation 2: Cast Votes

Record anonymized assessments with confidence scores. Each model reviews all
claims without attribution and endorses one claim by index.

**Inputs**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ballot_id` | string | yes | Ballot to cast vote on |
| `model_id` | string | yes | Anonymized model identifier (`model-A`, `model-B`, `model-C`) |
| `vote` | integer | yes | Index into claims array (0-based) |
| `workdir` | string | yes | Working directory for ballot storage |

**Procedure**:

1. Load ballot from `workdir/ballots/{ballot_id}.json`
   - Error `BALLOT_NOT_FOUND` if ballot does not exist

2. Validate vote:
   - `model_id` must not have already voted (error: `ALREADY_VOTED`)
   - `vote` must be in range `[0, claims.length - 1]` (error: `INVALID_CLAIM_INDEX`)

3. Look up the model's `historical_success_rate` from RL metrics:
   ```bash
   # Default success rate for new models
   historical_rate=${rl_metrics[$model].success_rate:-0.75}
   ```

4. Compute voting weight from historical success rate:
   - Normalize weights so `sum(weight[i]) = 1.0` across all voters
   - Clamp individual weights to `[0.1, 1.0]`

5. Append vote to ballot's `votes` array:
   ```json
   {
     "anonymized_model_id": "model-A",
     "vote": 0,
     "weight": 0.40,
     "historical_success_rate": 0.88
   }
   ```

6. Log vote event:
   ```bash
   log_event "vote" "$iteration" "Vote cast: $model_id -> claim-$vote" "$metadata"
   ```

**Outputs**: JSON vote record with `anonymized_model_id`, `vote`, `weight`, `historical_success_rate`

### Operation 3: Tally Votes

Apply EMA-weighted scoring to determine the verdict. Computes weighted scores
per claim and determines consensus level based on vote distribution.

**Inputs**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ballot_id` | string | yes | Ballot to tally |
| `workdir` | string | yes | Working directory for ballot storage |

**Procedure**:

1. Load ballot and validate:
   - All claims must be submitted (error: `EMPTY_CLAIMS` if claims array is empty)
   - All expected votes must be cast (error: `INCOMPLETE_VOTING` if `votes.length < model_count`)

2. Count votes per claim:
   ```
   vote_counts[claim_index] = number of votes for that claim
   ```

3. Compute weighted score per claim using the EMA-weighted formula:
   ```
   For each claim C:
     weighted_score[C] = sum(confidence[i] * weight[i] for i where vote[i] == C)
                         / sum(weight[i] for ALL voters)
   ```

   Where:
   - `confidence[i]` = the confidence from `claims[vote[i]].confidence` for
     the claim endorsed by voter `i`
   - `weight[i]` = voting weight from `votes[i].weight`, derived from
     `historical_success_rate` via RL feedback
   - Denominator includes ALL voters' weights (not just supporters),
     penalizing claims with fewer supporters

4. Determine consensus level:
   | Vote Pattern | Level | Verdict Rule |
   |-------------|-------|--------------|
   | 3-of-3 same claim | `unanimous` | `approved:claim-{N}` |
   | 2-of-3 same claim | `majority` | `approved:claim-{N}` (majority choice) |
   | 1-1-1 all different | `split` | `approved:claim-{N}` (highest `weighted_score`) |
   | Degraded 2-model, 1-1 split | `no_consensus` | `no_consensus` |

5. Record the winning claim's weighted score as the ballot's `weighted_score`

6. Update ballot with `verdict`, `consensus_level`, `weighted_score`

7. Log tally event:
   ```bash
   log_event "decision" "$iteration" "Tally complete: $verdict ($consensus_level)" "$metadata"
   ```

**Outputs**: JSON tally result with `verdict`, `consensus_level`, `weighted_score`

### Operation 4: Get Consensus

De-anonymize model identities after the verdict and produce the final decision
with confidence score. This operation is ONLY valid after tally is complete.

**Inputs**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ballot_id` | string | yes | Tallied ballot ID |
| `workdir` | string | yes | Working directory for ballot storage |

**Procedure**:

1. Load ballot and validate:
   - Ballot must exist (error: `BALLOT_NOT_FOUND`)
   - Ballot must be tallied (error: `BALLOT_NOT_TALLIED` if verdict is null)

2. Extract consensus information:
   ```json
   {
     "consensus_level": "majority",
     "verdict": "approved:claim-0",
     "weighted_score": 0.592,
     "is_consensus": true
   }
   ```

3. Determine `is_consensus`:
   - `true` for `unanimous`, `majority`, `split` (a winner was determined)
   - `false` for `no_consensus` (requires orchestrator escalation)

4. For de-anonymization (separate operation via `deanonymize_ballot`):
   - Open the sealed mapping
   - Record `model-A -> claude-opus-4-6`, etc.
   - Write de-anonymized results to session event log for RL feedback

5. Log consensus event:
   ```bash
   log_event "decision" "$iteration" "Consensus: $consensus_level, verdict: $verdict" "$metadata"
   ```

**Outputs**: JSON consensus result with `consensus_level`, `verdict`,
`weighted_score`, `is_consensus`

## EMA Vote Weighting Formula

The tribunal uses Exponential Moving Average (EMA) based weights derived from
each model's historical performance in the RL feedback system:

```
historical_success_rate = EMA of past tribunal outcomes (alpha = 0.1)
  new_rate = 0.9 * old_rate + 0.1 * (1 if endorsed claim succeeded else 0)

raw_weight[i] = clamp(historical_success_rate[i], 0.1, 1.0)
weight[i] = raw_weight[i] / sum(raw_weight[j] for all j)

weighted_score = sum(confidence[i] * weight[i] for voters of winning claim)
                 / sum(weight[i] for ALL voters)
```

This formula ensures:
- Models with better track records have more voting influence
- No single model can dominate (weights normalized, clamped to [0.1, 1.0])
- The denominator includes ALL voters, penalizing thin support
- New models start with default weight 0.75 and converge via EMA

## Integration Points

### tribunal-api.sh (Multi-LLM Calls)

```bash
source plugins/sdd-dev-loop/lib/tribunal-api.sh
load_api_keys
check_model_availability

# Parallel query for claim submission
call_all_models_parallel "$system_prompt" "$decision_point"

# Individual calls for cross-evaluation voting
call_claude_api "$system_prompt" "$voting_prompt"
call_openai_api "$system_prompt" "$voting_prompt"
call_gemini_api "$system_prompt" "$voting_prompt"
```

### event-logger.sh (Tribunal Event Logging)

```bash
source plugins/sdd-dev-loop/lib/event-logger.sh
init_event_log "$session_id" "$session_dir"

# Log tribunal events
log_event "vote" 0 "Ballot created: $ballot_id" '{"round":"research"}'
log_event "vote" 0 "Vote cast: model-A -> claim-0" '{"confidence":0.85}'
log_event "decision" 0 "Tally: approved:claim-0 (majority)" '{"weighted_score":0.592}'
```

### RL Feedback (Post-Tribunal)

After implementation outcomes are known, tribunal results feed back into
the RL system to update model `historical_success_rate`:

```bash
# Model that endorsed the winning claim, and the claim led to success
.specify/scripts/bash/rl/collect-feedback.sh tribunal-vote success $tokens
.specify/scripts/bash/rl/sync-metrics.sh
```

## Constitutional Compliance

| Principle | Enforcement |
|-----------|-------------|
| **VI (Git Approval)** | Tribunal skill performs NO git operations. All work is ballot orchestration and vote management. Read-only code analysis only. |
| **X (Agent Delegation)** | The `tribunal-judge` agent is the designated specialist for all tribunal operations. The dev-loop-orchestrator MUST delegate tribunal decisions here. |
| **XIV (AI Model Selection)** | Three distinct models (Claude, GPT-4o, Gemini) are used to prevent single-model bias. Model selection follows `tribunal_models` configuration. Cost-efficient models used for tribunal queries (Sonnet, not Opus, for API calls). |

## Error Codes

| Code | Trigger | Resolution |
|------|---------|------------|
| `INVALID_DECISION_POINT` | Empty or missing decision_point | Provide a clear, non-empty decision description |
| `INVALID_ROUND` | Round not in `[research, approach, quality_dispute]` | Use a valid round value |
| `INSUFFICIENT_MODELS` | Fewer than 2 models available | Check API keys and provider availability |
| `BALLOT_NOT_FOUND` | Ballot ID does not exist in workdir | Verify ballot_id and workdir path |
| `EMPTY_CLAIMS` | Tally attempted with no claims submitted | Submit claims before tallying |
| `INCOMPLETE_VOTING` | Tally attempted before all votes cast | Wait for all models to vote |
| `ALREADY_VOTED` | Same model_id voting twice on same ballot | Each model votes exactly once |
| `INVALID_CLAIM_INDEX` | Vote index outside `[0, claims.length-1]` | Use a valid claim index |
| `INVALID_CONFIDENCE` | Confidence outside `[0.0, 1.0]` | Provide confidence in valid range |
| `BALLOT_NOT_TALLIED` | De-anonymization before tally complete | Complete tally before de-anonymizing |

## RL Feedback

At ballot completion, the skill records its outcome:

- **Consensus reached** (unanimous/majority/split) -> `collect-feedback.sh tribunal-vote success $tokens`
- **No consensus** -> `collect-feedback.sh tribunal-vote failure $tokens`
- **Provider failure halt** -> `collect-feedback.sh tribunal-vote failure $tokens`

The EMA algorithm (alpha=0.1) adjusts the skill's `selection_weight` over time:
```
selection_weight = clamp(0.9 * old_weight + 0.1 * outcome, 0.1, 1.0)
```
