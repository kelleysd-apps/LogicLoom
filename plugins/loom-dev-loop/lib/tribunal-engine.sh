#!/usr/bin/env bash
# tribunal-engine.sh — Multi-model tribunal voting engine for loom-dev-loop plugin
#
# Provides functions for creating ballots, submitting claims, casting votes,
# tallying results, and determining consensus in a multi-model tribunal.
# Implements anonymous voting with EMA-weighted scoring and supports
# graceful degradation for 2-model tribunals.
#
# This file is designed to be sourced, not executed directly.
#
# Dependencies: python3 (JSON manipulation), bc (floating-point arithmetic)
# Constitutional Principle X: Agent Delegation — tribunal voting for multi-model decisions
# Constitutional Principle XIV: AI Model Selection — per-model success rate weighting

set -euo pipefail

# ==============================================================================
# Plugin Directory Resolution
# ==============================================================================

if [[ -z "${PLUGIN_DIR:-}" ]]; then
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ==============================================================================
# Internal Helpers
# ==============================================================================

# _trib_iso8601_now — Get current UTC timestamp in ISO 8601 format
_trib_iso8601_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# _trib_generate_ballot_id — Generate a unique ballot identifier
_trib_generate_ballot_id() {
    echo "ballot-$(date +%s)-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' ')"
}

# _find_ballot — Locate a ballot JSON file by ballot_id across all sessions
# Usage: _find_ballot <ballot_id> <workdir>
# Outputs: absolute path to ballot file, or empty string if not found
_find_ballot() {
    local ballot_id="$1" workdir="$2"
    local found=""
    for f in "$workdir"/.dev-loop/sessions/*/ballots/ballot-"${ballot_id}".json; do
        if [[ -f "$f" ]]; then
            found="$f"
            break
        fi
    done
    echo "$found"
}

# _trib_bc_calc — Evaluate a floating-point expression via bc
_trib_bc_calc() {
    echo "$1" | bc -l 2>/dev/null || echo "0"
}

# _trib_bc_compare — Compare two floating-point numbers
# Returns: 0 (true) or 1 (false)
_trib_bc_compare() {
    local a="$1" op="$2" b="$3"
    local result
    case "$op" in
        "<")  result=$(_trib_bc_calc "$a < $b") ;;
        "<=") result=$(_trib_bc_calc "$a <= $b") ;;
        ">")  result=$(_trib_bc_calc "$a > $b") ;;
        ">=") result=$(_trib_bc_calc "$a >= $b") ;;
        "==") result=$(_trib_bc_calc "$a == $b") ;;
        *)    echo "ERROR: Unknown operator: $op" >&2; return 1 ;;
    esac
    [[ "$result" == "1" ]] && return 0 || return 1
}

# _trib_get_model_weight — Look up historical success rate for a model from RL metrics
# Returns the selection_weight clamped to [0.1, 1.0], defaulting to 0.5
_trib_get_model_weight() {
    local model_id="$1"

    # Try to read from RL metrics store
    local metrics_file="${PLUGIN_DIR}/../../.docs/rl-metrics/skill-performance.json"
    local weight="0.5"

    if [[ -f "$metrics_file" ]]; then
        local found_weight
        found_weight=$(python3 -c "
import json, sys
try:
    with open('$metrics_file') as f:
        data = json.load(f)
    # Search for model-specific metrics
    if isinstance(data, dict):
        for key, val in data.items():
            if isinstance(val, dict) and val.get('model_name') == '$model_id':
                w = val.get('selection_weight', 0.5)
                print(w)
                sys.exit(0)
    elif isinstance(data, list):
        for val in data:
            if isinstance(val, dict) and val.get('model_name') == '$model_id':
                w = val.get('selection_weight', 0.5)
                print(w)
                sys.exit(0)
    print('0.5')
except:
    print('0.5')
" 2>/dev/null) || found_weight="0.5"
        weight="$found_weight"
    fi

    # Clamp to [0.1, 1.0]
    if _trib_bc_compare "$weight" "<" "0.1"; then
        echo "0.1"
    elif _trib_bc_compare "$weight" ">" "1.0"; then
        echo "1.0"
    else
        echo "$weight"
    fi
}

# ==============================================================================
# create_ballot — Create a new tribunal ballot
# ==============================================================================
# Usage: create_ballot --session ID --round research|approach|quality_dispute
#                      --decision-point STR --models CSV --workdir PATH
#
# Creates a ballot JSON file for tribunal voting.
#
# Outputs: JSON ballot object to stdout
# Returns: 0 on success, 1 on validation error
create_ballot() {
    local session_id="" round="" decision_point="" models_csv="" workdir=""
    local decision_point_set=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session)        session_id="$2"; shift 2 ;;
            --round)          round="$2"; shift 2 ;;
            --decision-point) decision_point="$2"; decision_point_set=true; shift 2 ;;
            --models)         models_csv="$2"; shift 2 ;;
            --workdir)        workdir="$2"; shift 2 ;;
            *)                shift ;;
        esac
    done

    # Validate decision_point
    if [[ "$decision_point_set" != "true" || -z "$decision_point" ]]; then
        echo "ERROR: INVALID_DECISION_POINT — decision_point must be a non-empty string" >&2
        return 1
    fi

    # Validate round
    case "$round" in
        research|approach|quality_dispute) ;;
        *)
            echo "ERROR: INVALID_ROUND — round must be one of: research, approach, quality_dispute" >&2
            return 1
            ;;
    esac

    # Validate models (need >= 2)
    local models_array="[]"
    local model_count=0
    if [[ -n "$models_csv" ]]; then
        IFS=',' read -ra model_list <<< "$models_csv"
        model_count=${#model_list[@]}
        # Build JSON array
        models_array=$(python3 -c "
import json
models = [m.strip() for m in '$models_csv'.split(',') if m.strip()]
print(json.dumps(models))
" 2>/dev/null) || models_array="[]"
        model_count=$(python3 -c "
models = [m.strip() for m in '$models_csv'.split(',') if m.strip()]
print(len(models))
" 2>/dev/null) || model_count=0
    fi

    if [[ "$model_count" -lt 2 ]]; then
        echo "ERROR: INSUFFICIENT_MODELS — tribunal requires at least 2 models, got $model_count" >&2
        return 1
    fi

    # Generate ballot ID
    local ballot_id
    ballot_id=$(_trib_generate_ballot_id)

    # Create timestamp
    local timestamp
    timestamp=$(_trib_iso8601_now)

    # Build ballot JSON
    local ballot_json
    ballot_json=$(python3 -c "
import json
ballot = {
    'ballot_id': '$ballot_id',
    'session_id': '$session_id',
    'round': '$round',
    'decision_point': $(python3 -c "import json; print(json.dumps('$decision_point'))" 2>/dev/null),
    'models': $models_array,
    'model_count': $model_count,
    'claims': [],
    'votes': [],
    'timestamp': '$timestamp',
    'consensus_level': None,
    'verdict': None,
    'weighted_score': None,
    'model_mapping': None
}
print(json.dumps(ballot, indent=2))
" 2>/dev/null)

    # Create directory structure
    local ballot_dir="${workdir}/.dev-loop/sessions/${session_id}/ballots"
    mkdir -p "$ballot_dir"

    # Write ballot file
    echo "$ballot_json" > "${ballot_dir}/ballot-${ballot_id}.json"

    # Output ballot JSON
    echo "$ballot_json"
    return 0
}

# ==============================================================================
# submit_claim — Submit a claim/assessment to a ballot
# ==============================================================================
# Usage: submit_claim --ballot ID --model-id model-A --assessment STR
#                     --confidence FLOAT --reasoning STR --workdir PATH
#
# Appends a claim to the ballot's claims array.
#
# Outputs: JSON with claim_index and anonymized_model_id
# Returns: 0 on success, 1 on validation error
submit_claim() {
    local ballot_id="" model_id="" assessment="" confidence="" reasoning="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ballot)     ballot_id="$2"; shift 2 ;;
            --model-id)   model_id="$2"; shift 2 ;;
            --assessment) assessment="$2"; shift 2 ;;
            --confidence) confidence="$2"; shift 2 ;;
            --reasoning)  reasoning="$2"; shift 2 ;;
            --workdir)    workdir="$2"; shift 2 ;;
            *)            shift ;;
        esac
    done

    # Find ballot file
    local ballot_file
    ballot_file=$(_find_ballot "$ballot_id" "$workdir")
    if [[ -z "$ballot_file" ]]; then
        echo "ERROR: BALLOT_NOT_FOUND — no ballot with id '$ballot_id'" >&2
        return 1
    fi

    # Validate confidence range [0.0, 1.0]
    local conf_valid
    conf_valid=$(python3 -c "
c = float('$confidence')
if c < 0.0 or c > 1.0:
    print('invalid')
else:
    print('valid')
" 2>/dev/null) || conf_valid="invalid"

    if [[ "$conf_valid" != "valid" ]]; then
        echo "ERROR: INVALID_CONFIDENCE — confidence must be in range [0.0, 1.0], got $confidence"
        return 1
    fi

    # Read current ballot, append claim, write back
    local result
    result=$(python3 -c "
import json, sys

with open('$ballot_file') as f:
    ballot = json.load(f)

claim = {
    'model_id': '$model_id',
    'assessment': $(python3 -c "import json; print(json.dumps('$assessment'))" 2>/dev/null),
    'confidence': float('$confidence'),
    'reasoning': $(python3 -c "import json; print(json.dumps('$reasoning'))" 2>/dev/null)
}

claim_index = len(ballot['claims'])
ballot['claims'].append(claim)

with open('$ballot_file', 'w') as f:
    json.dump(ballot, f, indent=2)

print(json.dumps({'claim_index': claim_index, 'anonymized_model_id': '$model_id'}))
" 2>/dev/null)

    echo "$result"
    return 0
}

# ==============================================================================
# cast_vote — Cast a vote on a ballot
# ==============================================================================
# Usage: cast_vote --ballot ID --model-id model-A --vote N --workdir PATH
#
# Appends a vote to the ballot's votes array.
#
# Outputs: JSON with anonymized_model_id, vote, weight, historical_success_rate
# Returns: 0 on success, 1 on validation error
cast_vote() {
    local ballot_id="" model_id="" vote="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ballot)   ballot_id="$2"; shift 2 ;;
            --model-id) model_id="$2"; shift 2 ;;
            --vote)     vote="$2"; shift 2 ;;
            --workdir)  workdir="$2"; shift 2 ;;
            *)          shift ;;
        esac
    done

    # Find ballot file
    local ballot_file
    ballot_file=$(_find_ballot "$ballot_id" "$workdir")
    if [[ -z "$ballot_file" ]]; then
        echo "ERROR: BALLOT_NOT_FOUND — no ballot with id '$ballot_id'" >&2
        return 1
    fi

    # Get model weight from RL metrics
    local weight
    weight=$(_trib_get_model_weight "$model_id")

    # Get historical success rate (same as weight before clamping, default 0.5)
    local success_rate="$weight"

    # Validate and record vote
    local result
    result=$(python3 -c "
import json, sys

with open('$ballot_file') as f:
    ballot = json.load(f)

model_id = '$model_id'
vote_idx = int('$vote')
weight = float('$weight')
success_rate = float('$success_rate')

# Check for ALREADY_VOTED
for v in ballot['votes']:
    if v['model_id'] == model_id:
        print('ERROR: ALREADY_VOTED', file=sys.stderr)
        sys.exit(1)

# Check for INVALID_CLAIM_INDEX
claims_count = len(ballot['claims'])
if vote_idx < 0 or vote_idx >= claims_count:
    print('ERROR: INVALID_CLAIM_INDEX', file=sys.stderr)
    sys.exit(1)

# Record vote
vote_entry = {
    'model_id': model_id,
    'vote': vote_idx,
    'weight': weight,
    'historical_success_rate': success_rate
}
ballot['votes'].append(vote_entry)

with open('$ballot_file', 'w') as f:
    json.dump(ballot, f, indent=2)

print(json.dumps({
    'anonymized_model_id': model_id,
    'vote': vote_idx,
    'weight': weight,
    'historical_success_rate': success_rate
}))
" 2>/dev/null)

    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        # Re-run to get the error message on stderr
        python3 -c "
import json, sys

with open('$ballot_file') as f:
    ballot = json.load(f)

model_id = '$model_id'
vote_idx = int('$vote')

# Check for ALREADY_VOTED
for v in ballot['votes']:
    if v['model_id'] == model_id:
        print('ALREADY_VOTED')
        sys.exit(0)

# Check for INVALID_CLAIM_INDEX
claims_count = len(ballot['claims'])
if vote_idx < 0 or vote_idx >= claims_count:
    print('INVALID_CLAIM_INDEX')
    sys.exit(0)
" 2>/dev/null
        return 1
    fi

    echo "$result"
    return 0
}

# ==============================================================================
# tally_votes — Tally all votes on a ballot and determine consensus
# ==============================================================================
# Usage: tally_votes --ballot ID --workdir PATH
#
# Counts votes per claim, determines consensus level, and computes
# weighted scores.
#
# Outputs: JSON with consensus_level, verdict, weighted_score
# Returns: 0 on success, 1 on validation error
tally_votes() {
    local ballot_id="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ballot)  ballot_id="$2"; shift 2 ;;
            --workdir) workdir="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    # Find ballot file
    local ballot_file
    ballot_file=$(_find_ballot "$ballot_id" "$workdir")
    if [[ -z "$ballot_file" ]]; then
        echo "ERROR: BALLOT_NOT_FOUND — no ballot with id '$ballot_id'" >&2
        return 1
    fi

    # Tally votes using python3
    local result
    result=$(python3 -c "
import json, sys

with open('$ballot_file') as f:
    ballot = json.load(f)

claims = ballot.get('claims', [])
votes = ballot.get('votes', [])
model_count = ballot.get('model_count', len(ballot.get('models', [])))

# Validate EMPTY_CLAIMS
if len(claims) == 0:
    print('EMPTY_CLAIMS')
    sys.exit(0)

# Validate INCOMPLETE_VOTING
if len(votes) < model_count:
    print('INCOMPLETE_VOTING')
    sys.exit(0)

# Count votes per claim
vote_counts = {}
for v in votes:
    idx = v['vote']
    vote_counts[idx] = vote_counts.get(idx, 0) + 1

# Find claim with most votes
max_votes = max(vote_counts.values())
total_votes = len(votes)

# Determine winning claim(s)
# In case of tie, use weighted score to determine winner
best_claim = None
best_weighted_score = -1.0

for claim_idx in vote_counts:
    # Compute weighted score for this claim: sum(confidence * weight) / sum(weight)
    claim_voters = [v for v in votes if v['vote'] == claim_idx]
    total_weight = sum(v.get('weight', 0.5) for v in claim_voters)
    if total_weight > 0:
        weighted_sum = 0.0
        for v in claim_voters:
            # Get confidence from the claim submitted by this voter
            voter_model = v['model_id']
            voter_confidence = 0.5  # default
            for c in claims:
                if c['model_id'] == voter_model:
                    voter_confidence = c.get('confidence', 0.5)
                    break
            weighted_sum += voter_confidence * v.get('weight', 0.5)
        ws = weighted_sum / total_weight
    else:
        ws = 0.0

    if vote_counts[claim_idx] > (best_weighted_score if best_claim is not None and vote_counts.get(best_claim, 0) == vote_counts[claim_idx] else -1):
        pass  # Just use the logic below

    # Track best by vote count first, then weighted score as tiebreaker
    if best_claim is None:
        best_claim = claim_idx
        best_weighted_score = ws
    elif vote_counts[claim_idx] > vote_counts[best_claim]:
        best_claim = claim_idx
        best_weighted_score = ws
    elif vote_counts[claim_idx] == vote_counts[best_claim] and ws > best_weighted_score:
        best_claim = claim_idx
        best_weighted_score = ws

# Determine consensus level
winning_vote_count = vote_counts[best_claim]
num_distinct_votes = len(vote_counts)

if winning_vote_count == total_votes:
    consensus_level = 'unanimous'
elif winning_vote_count > total_votes / 2:
    consensus_level = 'majority'
else:
    consensus_level = 'split'

# For 2-model tribunal with 1-1 split, tally still produces split
# but get_consensus will map it to no_consensus

verdict = 'approved:claim-{}'.format(best_claim)

# Update ballot file with results
ballot['consensus_level'] = consensus_level
ballot['verdict'] = verdict
ballot['weighted_score'] = round(best_weighted_score, 6)

with open('$ballot_file', 'w') as f:
    json.dump(ballot, f, indent=2)

# Output tally result
print(json.dumps({
    'consensus_level': consensus_level,
    'verdict': verdict,
    'weighted_score': round(best_weighted_score, 6)
}))
" 2>/dev/null)

    # Check if result is an error code string
    case "$result" in
        EMPTY_CLAIMS)
            echo "ERROR: EMPTY_CLAIMS — ballot has no claims to tally" >&2
            return 1
            ;;
        INCOMPLETE_VOTING)
            echo "ERROR: INCOMPLETE_VOTING — not all models have voted" >&2
            return 1
            ;;
    esac

    echo "$result"
    return 0
}

# ==============================================================================
# get_consensus — Retrieve consensus information from a tallied ballot
# ==============================================================================
# Usage: get_consensus --ballot ID --workdir PATH
#
# Returns consensus info from a ballot that has been tallied. For 2-model
# tribunals with a 1-1 split, returns "no_consensus".
#
# Outputs: JSON with consensus_level, verdict, weighted_score, is_consensus
# Returns: 0 on success, 1 on error
get_consensus() {
    local ballot_id="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ballot)  ballot_id="$2"; shift 2 ;;
            --workdir) workdir="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    # Find ballot file
    local ballot_file
    ballot_file=$(_find_ballot "$ballot_id" "$workdir")
    if [[ -z "$ballot_file" ]]; then
        echo "ERROR: BALLOT_NOT_FOUND — no ballot with id '$ballot_id'" >&2
        return 1
    fi

    # Read ballot and extract consensus info
    local result
    result=$(python3 -c "
import json, sys

with open('$ballot_file') as f:
    ballot = json.load(f)

consensus_level = ballot.get('consensus_level')
verdict = ballot.get('verdict')
weighted_score = ballot.get('weighted_score', 0.0)
model_count = ballot.get('model_count', len(ballot.get('models', [])))
votes = ballot.get('votes', [])

# Check for 2-model tribunal with 1-1 split
if model_count == 2 and consensus_level == 'split':
    # Count distinct vote targets
    vote_counts = {}
    for v in votes:
        idx = v['vote']
        vote_counts[idx] = vote_counts.get(idx, 0) + 1
    # If each model voted for a different claim, it's no_consensus
    if len(vote_counts) == 2 and all(c == 1 for c in vote_counts.values()):
        consensus_level = 'no_consensus'
        verdict = 'no_consensus'

# Determine is_consensus
is_consensus = consensus_level in ('unanimous', 'majority')

print(json.dumps({
    'consensus_level': consensus_level if consensus_level else None,
    'verdict': verdict if verdict else None,
    'weighted_score': weighted_score if weighted_score is not None else 0.0,
    'is_consensus': is_consensus
}))
" 2>/dev/null)

    echo "$result"
    return 0
}

# ==============================================================================
# deanonymize_ballot — Map anonymous model IDs to real model identities
# ==============================================================================
# Usage: deanonymize_ballot --ballot ID --mapping JSON --workdir PATH
#
# Must be called AFTER tally_votes. Updates the ballot with model identity
# mapping.
#
# Outputs: JSON with model_mapping and deanonymized flag
# Returns: 0 on success, 1 on error
deanonymize_ballot() {
    local ballot_id="" mapping="" workdir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ballot)  ballot_id="$2"; shift 2 ;;
            --mapping) mapping="$2"; shift 2 ;;
            --workdir) workdir="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    # Find ballot file
    local ballot_file
    ballot_file=$(_find_ballot "$ballot_id" "$workdir")
    if [[ -z "$ballot_file" ]]; then
        echo "ERROR: BALLOT_NOT_FOUND — no ballot with id '$ballot_id'" >&2
        return 1
    fi

    # Check if ballot has been tallied and apply mapping
    local result
    result=$(python3 -c "
import json, sys

with open('$ballot_file') as f:
    ballot = json.load(f)

# Check if ballot has been tallied
if ballot.get('consensus_level') is None and ballot.get('verdict') is None:
    print('BALLOT_NOT_TALLIED')
    sys.exit(0)

# Parse mapping
mapping = json.loads('$mapping')

# Update ballot with mapping
ballot['model_mapping'] = mapping

with open('$ballot_file', 'w') as f:
    json.dump(ballot, f, indent=2)

print(json.dumps({
    'model_mapping': mapping,
    'deanonymized': True
}))
" 2>/dev/null)

    # Check for error code
    if [[ "$result" == "BALLOT_NOT_TALLIED" ]]; then
        echo "ERROR: BALLOT_NOT_TALLIED — ballot must be tallied before de-anonymization"
        return 1
    fi

    echo "$result"
    return 0
}
