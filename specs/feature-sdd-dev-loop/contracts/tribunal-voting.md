# Contract: Tribunal Voting

## Create Ballot
```
POST /tribunal/ballot/create
Input:  {
  session_id: string,
  decision_point: string,            // "research_synthesis" | "implementation_approach" | "quality_dispute"
  claims: string[],                   // statements to be assessed
  context: {
    task_description: string,
    current_state: string,
    previous_attempts?: string[]
  }
}
Output: {
  ballot_id: string,
  decision_point: string,
  claims_count: number,
  models_invoked: number,             // 2 or 3
  created_at: timestamp
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
  - INVALID_DECISION_POINT: Decision point not recognized
  - EMPTY_CLAIMS: No claims provided
  - INSUFFICIENT_MODELS: Fewer than 2 models available
Side Effects:
  - Queries all available tribunal models in parallel
  - Records ballot creation in event log
  - Stores anonymized assessments
```

## Cast Vote
```
POST /tribunal/vote/cast
Input:  {
  ballot_id: string,
  model: string,                      // model identifier
  votes: Array<{
    claim_index: number,
    assessment: "approve" | "reject" | "uncertain",
    confidence: number,                // 0.0-1.0
    reasoning: string
  }>
}
Output: {
  success: boolean,
  votes_recorded: number
}
Errors:
  - BALLOT_NOT_FOUND: Ballot ID doesn't exist
  - ALREADY_VOTED: Model already cast vote for this ballot
  - INVALID_CLAIM_INDEX: Claim index out of range
  - INVALID_CONFIDENCE: Confidence outside 0.0-1.0
Side Effects:
  - Stores anonymized vote
  - Records vote event in session log
```

## Tally Votes
```
POST /tribunal/ballot/tally
Input:  {
  ballot_id: string
}
Output: {
  ballot_id: string,
  total_models: number,                // 2 or 3
  votes_received: number,
  results: Array<{
    claim_index: number,
    claim: string,
    approval_count: number,
    rejection_count: number,
    uncertain_count: number,
    weighted_approval: number,        // EMA-adjusted score
    weighted_rejection: number,        // EMA-adjusted score
    outcome: "approved" | "rejected" | "split"
  }>,
  consensus_reached: boolean,         // true if >= 2 models agree
  tally_complete: boolean
}
Errors:
  - BALLOT_NOT_FOUND: Ballot ID doesn't exist
  - INCOMPLETE_VOTING: Not all models have voted
Side Effects:
  - Applies EMA-weighted scoring
  - Records tally in event log
```

## Get Consensus
```
GET /tribunal/ballot/consensus
Input:  {
  ballot_id: string
}
Output: {
  ballot_id: string,
  decision_point: string,
  consensus_reached: boolean,
  approved_claims: string[],
  rejected_claims: string[],
  split_claims: string[],
  final_decision: {
    outcome: "proceed" | "revise" | "escalate",
    reasoning: string,
    confidence: number                // aggregate confidence 0.0-1.0
  },
  model_contributions: Array<{
    model_id: string,                 // revealed after consensus
    reliability_weight: number,
    vote_summary: string
  }>
}
Errors:
  - BALLOT_NOT_FOUND: Ballot ID doesn't exist
  - TALLY_NOT_COMPLETE: Votes not yet tallied
  - NO_CONSENSUS: No majority reached (degraded state with 2 models)
Side Effects:
  - De-anonymizes model identities after consensus
  - Records final decision in event log
  - Updates model reliability scores (if session completes)
```
