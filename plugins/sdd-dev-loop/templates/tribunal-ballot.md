# TribunalBallot Entity Model

> Entity template for multi-model tribunal voting ballots in the dev-loop plugin.
> Used during strategy-mode decision points (research synthesis, approach selection, quality disputes).

## Schema Version

`1.0`

## Overview

A TribunalBallot captures a single tribunal vote across three independent AI models. Models
assess a decision point anonymously (identities hidden during review), then votes are tallied
using confidence-weighted scoring. The ballot records the full lifecycle: claims submission,
vote casting, tally, and verdict.

## JSON Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "description": "TribunalBallot entity — Multi-model anonymous voting record for tribunal decision points",
  "schema_version": "1.0",

  "ballot_id": "ballot-20260207-153000-research",
  "_comment_ballot_id": "Unique ballot identifier (ballot-{timestamp}-{round}). Auto-generated on ballot creation.",

  "session_id": "devloop-20260207-143022-abc123",
  "_comment_session_id": "Parent DevLoopSession reference. Links this ballot to session state.",

  "round": "research",
  "_comment_round": "Which tribunal checkpoint produced this ballot. Determines what is being evaluated.",
  "_valid_round_values": ["research", "approach", "quality_dispute"],
  "_round_descriptions": {
    "research": "Evaluate competing research directions and source synthesis",
    "approach": "Select implementation approach from candidate strategies",
    "quality_dispute": "Resolve disagreement between automated grading and semantic evaluation"
  },

  "decision_point": "Which OAuth2 library to use: passport.js vs oauth2-server vs custom implementation",
  "_comment_decision_point": "Natural language description of the decision being voted on. MUST be non-empty. Framed as a clear question or choice.",

  "claims": [
    {
      "claim_index": 0,
      "anonymized_model_id": "model-A",
      "_comment_anonymized_model_id": "Opaque identifier hiding the real model identity. Mapping revealed only after tally. Values: model-A, model-B, model-C.",
      "assessment": "passport.js is the most mature option with 45k+ GitHub stars, extensive middleware ecosystem, and proven production track record at scale. It handles session management, supports 500+ authentication strategies, and has active maintenance.",
      "_comment_assessment": "The model's analysis and recommendation. Free-form text. Presented to all voters without attribution.",
      "confidence": 0.85,
      "_comment_confidence": "Self-reported confidence in this assessment. Range: [0.0, 1.0]. Used in weighted score calculation.",
      "reasoning": "Based on npm download trends, GitHub activity, and compatibility with the existing Express.js stack. Risk: tight coupling to Express middleware pattern.",
      "_comment_reasoning": "Supporting evidence and methodology behind the assessment. Helps voters evaluate claim quality."
    },
    {
      "claim_index": 1,
      "anonymized_model_id": "model-B",
      "assessment": "oauth2-server provides a lower-level, framework-agnostic implementation that gives more control over the token lifecycle. Better for microservice architectures where you need fine-grained control.",
      "confidence": 0.72,
      "reasoning": "Analyzed RFC 6749 compliance, token introspection support, and integration patterns with existing session-state.json schema."
    },
    {
      "claim_index": 2,
      "anonymized_model_id": "model-C",
      "assessment": "A custom implementation using jose + openid-client gives maximum control and avoids middleware lock-in. More work upfront but aligns with the contract-first design principle.",
      "confidence": 0.68,
      "reasoning": "Constitutional Principle III (Contract-First) favors explicit interfaces. Custom approach lets us define exact token shapes matching our session entity model."
    }
  ],
  "_comment_claims": "Array of exactly 3 anonymous assessments, one per tribunal model. claims.length MUST equal 3. Each claim is presented to all models for cross-evaluation without attribution.",

  "votes": [
    {
      "anonymized_model_id": "model-A",
      "vote": 0,
      "_comment_vote": "Index into claims array indicating which claim this model endorses. Range: [0, claims.length - 1].",
      "weight": 0.40,
      "_comment_weight": "Voting weight derived from historical_success_rate. Higher-performing models carry more influence. Range: [0.1, 1.0]. Normalized so sum(weight[i]) = 1.0 across all voters.",
      "historical_success_rate": 0.88,
      "_comment_historical_success_rate": "EMA-based success rate from RL feedback system. Range: [0.0, 1.0]. Used to compute voting weight."
    },
    {
      "anonymized_model_id": "model-B",
      "vote": 0,
      "weight": 0.35,
      "historical_success_rate": 0.82
    },
    {
      "anonymized_model_id": "model-C",
      "vote": 2,
      "weight": 0.25,
      "historical_success_rate": 0.75
    }
  ],
  "_comment_votes": "Array of exactly 3 votes, one per tribunal model. votes entries MUST equal 3. Each model votes for one claim by index. A model MAY vote for its own claim.",

  "verdict": "approved:claim-0",
  "_comment_verdict": "Outcome of the tally. Format: 'approved:claim-{N}' where N is the winning claim index, or 'no_consensus' if consensus_level = no_consensus.",
  "_valid_verdict_patterns": ["approved:claim-0", "approved:claim-1", "approved:claim-2", "no_consensus"],

  "consensus_level": "majority",
  "_comment_consensus_level": "Degree of agreement among the three voters.",
  "_valid_consensus_values": ["unanimous", "majority", "split", "no_consensus"],
  "_consensus_definitions": {
    "unanimous": "All 3 models vote for the same claim (3-of-3).",
    "majority": "Exactly 2 models vote for the same claim (2-of-3). Verdict goes to the majority choice.",
    "split": "All 3 models vote for different claims (1-1-1). Verdict determined by weighted_score (highest wins).",
    "no_consensus": "Degraded state: fewer than 3 models available (e.g., 2-model tribunal with 1-1 split). Requires orchestrator escalation."
  },

  "weighted_score": 0.81,
  "_comment_weighted_score": "Confidence-weighted agreement score for the winning claim. Range: [0.0, 1.0].",
  "_formula_weighted_score": "weighted_score = sum(confidence[i] * weight[i] for i where vote[i] == winning_claim) / sum(weight[i] for all i)",
  "_calculation_example": "Winning claim = 0. Voters for claim 0: model-A (conf=0.85, w=0.40), model-B (conf=0.72, w=0.35). All weights: 0.40+0.35+0.25=1.0. weighted_score = (0.85*0.40 + 0.72*0.35) / (0.40+0.35+0.25) = (0.340 + 0.252) / 1.0 = 0.592. Note: denominator includes ALL model weights, not just supporters.",

  "timestamp": "2026-02-07T15:30:00Z",
  "_comment_timestamp": "Ballot creation/completion timestamp (ISO8601).",

  "_anonymization_protocol": {
    "_comment": "Documents the anonymization lifecycle for tribunal voting",

    "phase_1_claim_submission": [
      "Each of the 3 tribunal models independently assesses the decision_point.",
      "The orchestrator assigns opaque identifiers: model-A, model-B, model-C.",
      "The mapping between real model identities and anonymized IDs is stored in a sealed envelope (not included in the ballot).",
      "Claims are shuffled randomly before presentation to voters."
    ],

    "phase_2_cross_evaluation": [
      "All 3 claims are presented to all 3 models WITHOUT attribution.",
      "Each model reads all claims and selects which claim_index to endorse.",
      "Models do NOT know which claim is theirs or which model authored which claim.",
      "This prevents: (a) self-bias, (b) reputation bias, (c) authority bias."
    ],

    "phase_3_tally": [
      "Votes are collected and tallied using the weighted_score formula.",
      "consensus_level is determined by vote distribution.",
      "verdict is set based on consensus_level and weighted_score."
    ],

    "phase_4_deanonymization": [
      "ONLY after the tally is complete, the sealed envelope is opened.",
      "The mapping (model-A -> claude-opus-4-6, model-B -> gpt-4o, model-C -> gemini-2.5-pro) is revealed.",
      "De-anonymized results are recorded in the session event log for RL feedback.",
      "This ensures voting decisions were made purely on claim quality, not model reputation."
    ],

    "model_identity_mapping_example": {
      "model-A": "claude-opus-4-6",
      "model-B": "gpt-4o",
      "model-C": "gemini-2.5-pro",
      "_comment": "This mapping is SEALED during phases 1-3 and REVEALED only in phase 4."
    }
  },

  "_weighted_score_formula": {
    "formula": "weighted_score = sum(confidence[i] * weight[i] for voters of winning claim) / sum(weight[i] for ALL voters)",
    "variables": {
      "confidence[i]": "Self-reported confidence from claims[vote[i]].confidence for the voter's endorsed claim",
      "weight[i]": "Voting weight from votes[i].weight, derived from historical_success_rate"
    },
    "denominator_note": "The denominator includes ALL voters' weights (not just supporters of the winning claim). This penalizes claims that win with fewer supporters.",
    "examples": {
      "unanimous_high_confidence": {
        "scenario": "All 3 vote for claim-0, all confidence=0.90, equal weights",
        "calculation": "(0.90*0.333 + 0.90*0.333 + 0.90*0.333) / (0.333+0.333+0.333) = 0.90"
      },
      "majority_mixed_confidence": {
        "scenario": "2 vote for claim-0 (conf=0.85, 0.72), 1 votes claim-2 (conf=0.68). Weights: 0.40, 0.35, 0.25",
        "calculation": "(0.85*0.40 + 0.72*0.35) / (0.40+0.35+0.25) = 0.592 / 1.0 = 0.592"
      },
      "split_weighted_tiebreak": {
        "scenario": "1-1-1 split. Claim-0: conf=0.90, w=0.40. Claim-1: conf=0.80, w=0.35. Claim-2: conf=0.70, w=0.25",
        "claim_0_score": "(0.90*0.40) / 1.0 = 0.360",
        "claim_1_score": "(0.80*0.35) / 1.0 = 0.280",
        "claim_2_score": "(0.70*0.25) / 1.0 = 0.175",
        "winner": "claim-0 (highest weighted_score)"
      }
    }
  },

  "_validation_rules": [
    "ballot_id MUST be non-empty string",
    "session_id MUST reference a valid DevLoopSession",
    "round MUST be one of: research, approach, quality_dispute",
    "decision_point MUST be non-empty string",
    "claims.length MUST equal 3",
    "claims[*].claim_index MUST be unique and sequential (0, 1, 2)",
    "claims[*].anonymized_model_id MUST be one of: model-A, model-B, model-C",
    "claims[*].anonymized_model_id MUST be unique across all claims",
    "claims[*].confidence MUST be in range [0.0, 1.0]",
    "claims[*].assessment MUST be non-empty string",
    "claims[*].reasoning MUST be non-empty string",
    "votes.length MUST equal 3",
    "votes[*].anonymized_model_id MUST match a claims[*].anonymized_model_id",
    "votes[*].anonymized_model_id MUST be unique across all votes",
    "votes[*].vote MUST be in range [0, claims.length - 1]",
    "votes[*].weight MUST be in range [0.1, 1.0]",
    "votes[*].historical_success_rate MUST be in range [0.0, 1.0]",
    "sum(votes[*].weight) MUST equal 1.0 (within 0.001 tolerance)",
    "consensus_level MUST be one of: unanimous, majority, split, no_consensus",
    "verdict MUST match consensus outcome (approved:claim-N or no_consensus)",
    "weighted_score MUST be in range [0.0, 1.0]",
    "weighted_score MUST equal the formula result for the winning claim",
    "timestamp MUST be valid ISO8601"
  ],

  "_state_machine": {
    "_comment": "Ballot lifecycle states",
    "created": "Ballot initialized with session_id, round, decision_point. Claims and votes empty.",
    "claims_submitted": "All 3 claims received and anonymized. claims.length = 3. Votes not yet cast.",
    "voting": "Claims presented anonymously. Models casting votes. Partial votes[].length < 3.",
    "tallied": "All 3 votes received. weighted_score, consensus_level, verdict computed.",
    "deanonymized": "Model identities revealed. Ballot finalized and appended to session event log."
  },

  "_integration": {
    "session_reference": "Ballot references are stored in DevLoopSession.tribunal_ballots[] array",
    "event_log": "Full ballot data (including de-anonymized mapping) written to session event log on completion",
    "rl_feedback": "Tribunal outcomes feed into RL metrics: model historical_success_rate updated based on whether endorsed claim led to successful implementation",
    "orchestrator_trigger": "dev-loop-orchestrator invokes tribunal-judge agent at strategy-mode checkpoints"
  }
}
```

## Entity Relationships

```
DevLoopSession (1) ----< (N) TribunalBallot
     |                           |
     |                           |--- claims[3] (anonymous assessments)
     |                           |--- votes[3]  (weighted endorsements)
     |                           |--- verdict   (outcome)
     |
     |--- tribunal_ballots[] references ballot_id
```

## Usage

### Creating a Ballot

```bash
# Invoked by tribunal-judge agent during strategy mode
create_ballot \
  --session "$SESSION_ID" \
  --round "research" \
  --decision-point "Which OAuth2 library to use: passport.js vs oauth2-server vs custom"
```

### Casting Votes

```bash
# Each model votes independently after reviewing anonymized claims
cast_vote \
  --ballot "$BALLOT_ID" \
  --model-id "model-A" \
  --vote 0 \
  --confidence 0.85
```

### Tallying

```bash
# After all 3 votes are cast, compute the result
tally_votes --ballot "$BALLOT_ID"
# Returns: { verdict, consensus_level, weighted_score }
```

### De-anonymization

```bash
# Reveal model identities after tally (for RL feedback)
deanonymize_ballot \
  --ballot "$BALLOT_ID" \
  --mapping '{"model-A":"claude-opus-4-6","model-B":"gpt-4o","model-C":"gemini-2.5-pro"}'
```
