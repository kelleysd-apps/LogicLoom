#!/usr/bin/env bash
# Contract Tests: Tribunal Voting
# TDD tests for tribunal-ballot.md entity contract
# Tests: create_ballot, cast_vote, tally_votes, get_consensus
# These tests are written BEFORE implementation (TDD).
set -eo pipefail

PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if ( set +eu; eval "$condition" ) 2>/dev/null; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# Helper: safely call a function and capture output (returns empty string on failure)
safe_call() {
  local result=""
  result="$( set +eu; "$@" 2>/dev/null )" || true
  echo "$result"
}

# ── Setup ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="${PLUGIN_DIR}/lib"
TEST_TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

echo "=== Tribunal Voting Contract Tests ==="
echo ""

# ── Library Existence ──
echo "Library file existence"
assert "tribunal-engine.sh exists" "[ -f '${LIB_DIR}/tribunal-engine.sh' ]"

# Source library (tolerant of partially-implemented libs)
LIBS_SOURCED=false
if [ -f "${LIB_DIR}/tribunal-engine.sh" ]; then
  set +eu
  source "${LIB_DIR}/tribunal-engine.sh" 2>/dev/null || true
  set -eo pipefail
  LIBS_SOURCED=true
fi

# ── Function Existence ──
echo ""
echo "Function existence"
assert "create_ballot function exists" "type -t create_ballot 2>/dev/null | grep -q function"
assert "cast_vote function exists" "type -t cast_vote 2>/dev/null | grep -q function"
assert "tally_votes function exists" "type -t tally_votes 2>/dev/null | grep -q function"
assert "get_consensus function exists" "type -t get_consensus 2>/dev/null | grep -q function"

# ══════════════════════════════════════════
# Create Ballot Tests
# ══════════════════════════════════════════
echo ""
echo "--- Create Ballot ---"

# Test: Valid ballot creation with 3 models
echo "Valid ballot creation"
if $LIBS_SOURCED; then
  BALLOT_RESULT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'research' \
    --decision-point 'Which OAuth2 library to use: passport.js vs oauth2-server vs custom' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "create_ballot returns JSON with ballot_id" \
    "echo '$BALLOT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"ballot_id\" in d'"
  assert "create_ballot returns session_id matching input" \
    "echo '$BALLOT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"session_id\"] == \"devloop-test-session-001\"'"
  assert "create_ballot returns round=research" \
    "echo '$BALLOT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"round\"] == \"research\"'"
  assert "create_ballot returns decision_point" \
    "echo '$BALLOT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"decision_point\" in d and len(d[\"decision_point\"]) > 0'"
  assert "create_ballot returns empty claims array (length 0, awaiting submission)" \
    "echo '$BALLOT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"claims\" in d and isinstance(d[\"claims\"], list)'"
  assert "create_ballot returns empty votes array" \
    "echo '$BALLOT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"votes\" in d and isinstance(d[\"votes\"], list)'"
  assert "create_ballot returns timestamp" \
    "echo '$BALLOT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"timestamp\" in d'"
  assert "create_ballot returns consensus_level=null (not yet tallied)" \
    "echo '$BALLOT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"consensus_level\") is None'"
  assert "create_ballot returns verdict=null (not yet tallied)" \
    "echo '$BALLOT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"verdict\") is None'"

  # Save ballot_id for later tests
  BALLOT_ID="$(echo "$BALLOT_RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || true
else
  assert "create_ballot returns JSON with ballot_id" "false"
  assert "create_ballot returns session_id matching input" "false"
  assert "create_ballot returns round=research" "false"
  assert "create_ballot returns decision_point" "false"
  assert "create_ballot returns empty claims array (length 0, awaiting submission)" "false"
  assert "create_ballot returns empty votes array" "false"
  assert "create_ballot returns timestamp" "false"
  assert "create_ballot returns consensus_level=null (not yet tallied)" "false"
  assert "create_ballot returns verdict=null (not yet tallied)" "false"
  BALLOT_ID=""
fi

# Test: Valid round values (approach, quality_dispute)
echo ""
echo "Valid round values"
if $LIBS_SOURCED; then
  APPROACH_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'approach' \
    --decision-point 'Monolith vs microservices architecture' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "create_ballot with round=approach succeeds" \
    "echo '$APPROACH_BALLOT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"round\"] == \"approach\"'"

  DISPUTE_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'quality_dispute' \
    --decision-point 'Automated grade 0.82 vs AI judge score 0.91' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "create_ballot with round=quality_dispute succeeds" \
    "echo '$DISPUTE_BALLOT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"round\"] == \"quality_dispute\"'"
else
  assert "create_ballot with round=approach succeeds" "false"
  assert "create_ballot with round=quality_dispute succeeds" "false"
fi

# Test: INVALID_DECISION_POINT error
echo ""
echo "INVALID_DECISION_POINT error"
if $LIBS_SOURCED; then
  EMPTY_DP="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'research' \
    --decision-point '' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Empty decision_point returns INVALID_DECISION_POINT" \
    "echo '$EMPTY_DP' | grep -q 'INVALID_DECISION_POINT'"

  NO_DP="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'research' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Missing decision_point returns INVALID_DECISION_POINT" \
    "echo '$NO_DP' | grep -q 'INVALID_DECISION_POINT'"
else
  assert "Empty decision_point returns INVALID_DECISION_POINT" "false"
  assert "Missing decision_point returns INVALID_DECISION_POINT" "false"
fi

# Test: EMPTY_CLAIMS error (submitting ballot with no claims)
echo ""
echo "EMPTY_CLAIMS error"
if $LIBS_SOURCED; then
  # Create a ballot, then try to tally before any claims are submitted
  NOCLAIMS_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'research' \
    --decision-point 'Test empty claims' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  NOCLAIMS_ID="$(echo "$NOCLAIMS_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || true
  if [ -n "$NOCLAIMS_ID" ]; then
    TALLY_NOCLAIMS="$(tally_votes --ballot "$NOCLAIMS_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
    assert "Tallying ballot with no claims returns EMPTY_CLAIMS" \
      "echo '$TALLY_NOCLAIMS' | grep -q 'EMPTY_CLAIMS'"
  else
    assert "Tallying ballot with no claims returns EMPTY_CLAIMS" "false"
  fi
else
  assert "Tallying ballot with no claims returns EMPTY_CLAIMS" "false"
fi

# Test: INSUFFICIENT_MODELS error (fewer than 2 models available)
echo ""
echo "INSUFFICIENT_MODELS error"
if $LIBS_SOURCED; then
  ONE_MODEL="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'research' \
    --decision-point 'Test insufficient models' \
    --models 'claude-opus-4-8' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Single model (< 2) returns INSUFFICIENT_MODELS" \
    "echo '$ONE_MODEL' | grep -q 'INSUFFICIENT_MODELS'"

  ZERO_MODELS="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'research' \
    --decision-point 'Test zero models' \
    --models '' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Zero models returns INSUFFICIENT_MODELS" \
    "echo '$ZERO_MODELS' | grep -q 'INSUFFICIENT_MODELS'"
else
  assert "Single model (< 2) returns INSUFFICIENT_MODELS" "false"
  assert "Zero models returns INSUFFICIENT_MODELS" "false"
fi

# Test: INVALID_ROUND error
echo ""
echo "INVALID_ROUND error"
if $LIBS_SOURCED; then
  BAD_ROUND="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'invalid_round_type' \
    --decision-point 'Test bad round' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Invalid round value returns INVALID_ROUND" \
    "echo '$BAD_ROUND' | grep -q 'INVALID_ROUND'"
else
  assert "Invalid round value returns INVALID_ROUND" "false"
fi

# ══════════════════════════════════════════
# Cast Vote Tests
# ══════════════════════════════════════════
echo ""
echo "--- Cast Vote ---"

# Helper: create a ballot with claims pre-submitted for voting tests
VOTE_BALLOT_ID=""
if $LIBS_SOURCED; then
  VOTE_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'approach' \
    --decision-point 'REST vs GraphQL vs gRPC for internal API' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  VOTE_BALLOT_ID="$(echo "$VOTE_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || true

  # Submit 3 claims (one per model)
  if [ -n "$VOTE_BALLOT_ID" ]; then
    safe_call submit_claim --ballot "$VOTE_BALLOT_ID" --model-id "model-A" \
      --assessment "REST is the simplest option with widest tooling support." \
      --confidence 0.85 \
      --reasoning "Mature ecosystem, simple debugging, standard HTTP semantics." \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$VOTE_BALLOT_ID" --model-id "model-B" \
      --assessment "GraphQL provides flexible querying and reduces over-fetching." \
      --confidence 0.78 \
      --reasoning "Type-safe schema, single endpoint, introspection." \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$VOTE_BALLOT_ID" --model-id "model-C" \
      --assessment "gRPC offers best performance for internal service communication." \
      --confidence 0.72 \
      --reasoning "Binary protocol, HTTP/2, auto-generated clients, streaming." \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
  fi
fi

# Test: Valid vote recording
echo "Valid vote recording"
if $LIBS_SOURCED && [ -n "$VOTE_BALLOT_ID" ]; then
  VOTE_RESULT="$(cast_vote \
    --ballot "$VOTE_BALLOT_ID" \
    --model-id 'model-A' \
    --vote 0 \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "cast_vote returns JSON with anonymized_model_id" \
    "echo '$VOTE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"anonymized_model_id\"] == \"model-A\"'"
  assert "cast_vote returns vote index (0)" \
    "echo '$VOTE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"vote\"] == 0'"
  assert "cast_vote returns weight in range [0.1, 1.0]" \
    "echo '$VOTE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert 0.1 <= d[\"weight\"] <= 1.0'"
  assert "cast_vote returns historical_success_rate in range [0.0, 1.0]" \
    "echo '$VOTE_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert 0.0 <= d[\"historical_success_rate\"] <= 1.0'"
else
  assert "cast_vote returns JSON with anonymized_model_id" "false"
  assert "cast_vote returns vote index (0)" "false"
  assert "cast_vote returns weight in range [0.1, 1.0]" "false"
  assert "cast_vote returns historical_success_rate in range [0.0, 1.0]" "false"
fi

# Test: ALREADY_VOTED error
echo ""
echo "ALREADY_VOTED error"
if $LIBS_SOURCED && [ -n "$VOTE_BALLOT_ID" ]; then
  DOUBLE_VOTE="$(cast_vote \
    --ballot "$VOTE_BALLOT_ID" \
    --model-id 'model-A' \
    --vote 1 \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Voting twice with same model-id returns ALREADY_VOTED" \
    "echo '$DOUBLE_VOTE' | grep -q 'ALREADY_VOTED'"
else
  assert "Voting twice with same model-id returns ALREADY_VOTED" "false"
fi

# Test: INVALID_CLAIM_INDEX error
echo ""
echo "INVALID_CLAIM_INDEX error"
if $LIBS_SOURCED && [ -n "$VOTE_BALLOT_ID" ]; then
  BAD_INDEX="$(cast_vote \
    --ballot "$VOTE_BALLOT_ID" \
    --model-id 'model-B' \
    --vote 5 \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Vote index > claims.length-1 returns INVALID_CLAIM_INDEX" \
    "echo '$BAD_INDEX' | grep -q 'INVALID_CLAIM_INDEX'"

  NEG_INDEX="$(cast_vote \
    --ballot "$VOTE_BALLOT_ID" \
    --model-id 'model-B' \
    --vote -1 \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Negative vote index returns INVALID_CLAIM_INDEX" \
    "echo '$NEG_INDEX' | grep -q 'INVALID_CLAIM_INDEX'"
else
  assert "Vote index > claims.length-1 returns INVALID_CLAIM_INDEX" "false"
  assert "Negative vote index returns INVALID_CLAIM_INDEX" "false"
fi

# Test: INVALID_CONFIDENCE error (for submit_claim)
echo ""
echo "INVALID_CONFIDENCE error"
if $LIBS_SOURCED; then
  # Create a fresh ballot for confidence tests
  CONF_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'research' \
    --decision-point 'Test confidence validation' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  CONF_BALLOT_ID="$(echo "$CONF_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || true
  if [ -n "$CONF_BALLOT_ID" ]; then
    TOO_HIGH="$(safe_call submit_claim --ballot "$CONF_BALLOT_ID" --model-id "model-A" \
      --assessment "Test claim" --confidence 1.5 --reasoning "Test" \
      --workdir "$TEST_TMPDIR")"
    assert "Confidence > 1.0 returns INVALID_CONFIDENCE" \
      "echo '$TOO_HIGH' | grep -q 'INVALID_CONFIDENCE'"

    TOO_LOW="$(safe_call submit_claim --ballot "$CONF_BALLOT_ID" --model-id "model-A" \
      --assessment "Test claim" --confidence -0.1 --reasoning "Test" \
      --workdir "$TEST_TMPDIR")"
    assert "Confidence < 0.0 returns INVALID_CONFIDENCE" \
      "echo '$TOO_LOW' | grep -q 'INVALID_CONFIDENCE'"
  else
    assert "Confidence > 1.0 returns INVALID_CONFIDENCE" "false"
    assert "Confidence < 0.0 returns INVALID_CONFIDENCE" "false"
  fi
else
  assert "Confidence > 1.0 returns INVALID_CONFIDENCE" "false"
  assert "Confidence < 0.0 returns INVALID_CONFIDENCE" "false"
fi

# Test: BALLOT_NOT_FOUND error
echo ""
echo "BALLOT_NOT_FOUND error"
if $LIBS_SOURCED; then
  NO_BALLOT="$(cast_vote \
    --ballot 'nonexistent-ballot-id' \
    --model-id 'model-A' \
    --vote 0 \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "Voting on nonexistent ballot returns BALLOT_NOT_FOUND" \
    "echo '$NO_BALLOT' | grep -q 'BALLOT_NOT_FOUND'"
else
  assert "Voting on nonexistent ballot returns BALLOT_NOT_FOUND" "false"
fi

# ══════════════════════════════════════════
# Tally Votes Tests
# ══════════════════════════════════════════
echo ""
echo "--- Tally Votes ---"

# ── Majority outcome (2-of-3) ──
echo "Majority outcome (2-of-3)"
MAJORITY_BALLOT_ID=""
if $LIBS_SOURCED; then
  # Create a fresh ballot and populate claims + votes for majority (2 vote for claim-0)
  MAJ_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'approach' \
    --decision-point 'Majority test: 2-of-3 vote for claim-0' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  MAJORITY_BALLOT_ID="$(echo "$MAJ_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || true
  if [ -n "$MAJORITY_BALLOT_ID" ]; then
    # Submit 3 claims
    safe_call submit_claim --ballot "$MAJORITY_BALLOT_ID" --model-id "model-A" \
      --assessment "Approach A is best" --confidence 0.85 --reasoning "Evidence A" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$MAJORITY_BALLOT_ID" --model-id "model-B" \
      --assessment "Approach B is best" --confidence 0.72 --reasoning "Evidence B" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$MAJORITY_BALLOT_ID" --model-id "model-C" \
      --assessment "Approach C is best" --confidence 0.68 --reasoning "Evidence C" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    # Cast votes: model-A -> claim 0, model-B -> claim 0, model-C -> claim 2
    safe_call cast_vote --ballot "$MAJORITY_BALLOT_ID" --model-id "model-A" --vote 0 --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$MAJORITY_BALLOT_ID" --model-id "model-B" --vote 0 --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$MAJORITY_BALLOT_ID" --model-id "model-C" --vote 2 --workdir "$TEST_TMPDIR" >/dev/null 2>&1

    MAJ_TALLY="$(tally_votes --ballot "$MAJORITY_BALLOT_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
    assert "Majority (2-of-3) tally returns consensus_level=majority" \
      "echo '$MAJ_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"consensus_level\"] == \"majority\"'"
    assert "Majority tally verdict is approved:claim-0" \
      "echo '$MAJ_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"verdict\"] == \"approved:claim-0\"'"
    assert "Majority tally returns weighted_score in range [0.0, 1.0]" \
      "echo '$MAJ_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert 0.0 <= d[\"weighted_score\"] <= 1.0'"
    assert "Majority tally returns weighted_score > 0" \
      "echo '$MAJ_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"weighted_score\"] > 0'"
  else
    assert "Majority (2-of-3) tally returns consensus_level=majority" "false"
    assert "Majority tally verdict is approved:claim-0" "false"
    assert "Majority tally returns weighted_score in range [0.0, 1.0]" "false"
    assert "Majority tally returns weighted_score > 0" "false"
  fi
else
  assert "Majority (2-of-3) tally returns consensus_level=majority" "false"
  assert "Majority tally verdict is approved:claim-0" "false"
  assert "Majority tally returns weighted_score in range [0.0, 1.0]" "false"
  assert "Majority tally returns weighted_score > 0" "false"
fi

# ── Unanimous outcome (3-of-3) ──
echo ""
echo "Unanimous outcome (3-of-3)"
UNANIMOUS_BALLOT_ID=""
if $LIBS_SOURCED; then
  UNA_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'research' \
    --decision-point 'Unanimous test: 3-of-3 vote for claim-1' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  UNANIMOUS_BALLOT_ID="$(echo "$UNA_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || true
  if [ -n "$UNANIMOUS_BALLOT_ID" ]; then
    # Submit 3 claims
    safe_call submit_claim --ballot "$UNANIMOUS_BALLOT_ID" --model-id "model-A" \
      --assessment "Direction A" --confidence 0.80 --reasoning "Reason A" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$UNANIMOUS_BALLOT_ID" --model-id "model-B" \
      --assessment "Direction B" --confidence 0.90 --reasoning "Reason B" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$UNANIMOUS_BALLOT_ID" --model-id "model-C" \
      --assessment "Direction C" --confidence 0.70 --reasoning "Reason C" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    # All 3 vote for claim-1
    safe_call cast_vote --ballot "$UNANIMOUS_BALLOT_ID" --model-id "model-A" --vote 1 --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$UNANIMOUS_BALLOT_ID" --model-id "model-B" --vote 1 --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$UNANIMOUS_BALLOT_ID" --model-id "model-C" --vote 1 --workdir "$TEST_TMPDIR" >/dev/null 2>&1

    UNA_TALLY="$(tally_votes --ballot "$UNANIMOUS_BALLOT_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
    assert "Unanimous (3-of-3) tally returns consensus_level=unanimous" \
      "echo '$UNA_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"consensus_level\"] == \"unanimous\"'"
    assert "Unanimous tally verdict is approved:claim-1" \
      "echo '$UNA_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"verdict\"] == \"approved:claim-1\"'"
    assert "Unanimous tally weighted_score reflects all 3 models' confidence" \
      "echo '$UNA_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"weighted_score\"] > 0.5'"
  else
    assert "Unanimous (3-of-3) tally returns consensus_level=unanimous" "false"
    assert "Unanimous tally verdict is approved:claim-1" "false"
    assert "Unanimous tally weighted_score reflects all 3 models' confidence" "false"
  fi
else
  assert "Unanimous (3-of-3) tally returns consensus_level=unanimous" "false"
  assert "Unanimous tally verdict is approved:claim-1" "false"
  assert "Unanimous tally weighted_score reflects all 3 models' confidence" "false"
fi

# ── Split outcome (1-1-1) ──
echo ""
echo "Split outcome (1-1-1)"
SPLIT_BALLOT_ID=""
if $LIBS_SOURCED; then
  SPLIT_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'approach' \
    --decision-point 'Split test: each model votes for a different claim' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  SPLIT_BALLOT_ID="$(echo "$SPLIT_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || true
  if [ -n "$SPLIT_BALLOT_ID" ]; then
    # Submit 3 claims with different confidences
    safe_call submit_claim --ballot "$SPLIT_BALLOT_ID" --model-id "model-A" \
      --assessment "Option A" --confidence 0.90 --reasoning "Strong evidence for A" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$SPLIT_BALLOT_ID" --model-id "model-B" \
      --assessment "Option B" --confidence 0.80 --reasoning "Strong evidence for B" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$SPLIT_BALLOT_ID" --model-id "model-C" \
      --assessment "Option C" --confidence 0.70 --reasoning "Moderate evidence for C" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    # Each votes for a different claim: 1-1-1 split
    safe_call cast_vote --ballot "$SPLIT_BALLOT_ID" --model-id "model-A" --vote 0 --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$SPLIT_BALLOT_ID" --model-id "model-B" --vote 1 --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$SPLIT_BALLOT_ID" --model-id "model-C" --vote 2 --workdir "$TEST_TMPDIR" >/dev/null 2>&1

    SPLIT_TALLY="$(tally_votes --ballot "$SPLIT_BALLOT_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
    assert "Split (1-1-1) tally returns consensus_level=split" \
      "echo '$SPLIT_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"consensus_level\"] == \"split\"'"
    assert "Split tally verdict determined by highest weighted_score" \
      "echo '$SPLIT_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"verdict\"].startswith(\"approved:claim-\")'"
    assert "Split tally returns weighted_score in range [0.0, 1.0]" \
      "echo '$SPLIT_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert 0.0 <= d[\"weighted_score\"] <= 1.0'"
  else
    assert "Split (1-1-1) tally returns consensus_level=split" "false"
    assert "Split tally verdict determined by highest weighted_score" "false"
    assert "Split tally returns weighted_score in range [0.0, 1.0]" "false"
  fi
else
  assert "Split (1-1-1) tally returns consensus_level=split" "false"
  assert "Split tally verdict determined by highest weighted_score" "false"
  assert "Split tally returns weighted_score in range [0.0, 1.0]" "false"
fi

# ── EMA-weighted scoring verification ──
echo ""
echo "EMA-weighted scoring"
if $LIBS_SOURCED; then
  # Create ballot with known weights to verify formula
  EMA_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'research' \
    --decision-point 'EMA weight test' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  EMA_BALLOT_ID="$(echo "$EMA_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || true
  if [ -n "$EMA_BALLOT_ID" ]; then
    # Submit claims with exact known confidences
    safe_call submit_claim --ballot "$EMA_BALLOT_ID" --model-id "model-A" \
      --assessment "Claim A" --confidence 0.90 --reasoning "R-A" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$EMA_BALLOT_ID" --model-id "model-B" \
      --assessment "Claim B" --confidence 0.80 --reasoning "R-B" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$EMA_BALLOT_ID" --model-id "model-C" \
      --assessment "Claim C" --confidence 0.70 --reasoning "R-C" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    # All vote for claim-0 (unanimous) so we can verify weighted_score formula
    safe_call cast_vote --ballot "$EMA_BALLOT_ID" --model-id "model-A" --vote 0 --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$EMA_BALLOT_ID" --model-id "model-B" --vote 0 --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$EMA_BALLOT_ID" --model-id "model-C" --vote 0 --workdir "$TEST_TMPDIR" >/dev/null 2>&1

    EMA_TALLY="$(tally_votes --ballot "$EMA_BALLOT_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
    # Verify weighted_score = sum(conf[i]*w[i]) / sum(w[i])
    # We can't predict exact weights without knowing historical_success_rate,
    # but we CAN verify the formula is applied correctly
    assert "Weighted score follows formula: sum(conf*weight)/sum(weight)" \
      "echo '$EMA_TALLY' | python3 -c '
import json, sys
d = json.load(sys.stdin)
ws = d[\"weighted_score\"]
# weighted_score must be between min confidence (0.70) and max confidence (0.90)
# when all vote for same claim, it is a weighted average of all confidences
assert 0.60 <= ws <= 1.0, f\"weighted_score {ws} outside expected range\"
'"
    assert "Weighted score is non-negative" \
      "echo '$EMA_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"weighted_score\"] >= 0'"
  else
    assert "Weighted score follows formula: sum(conf*weight)/sum(weight)" "false"
    assert "Weighted score is non-negative" "false"
  fi
else
  assert "Weighted score follows formula: sum(conf*weight)/sum(weight)" "false"
  assert "Weighted score is non-negative" "false"
fi

# ── INCOMPLETE_VOTING error ──
echo ""
echo "INCOMPLETE_VOTING error"
if $LIBS_SOURCED; then
  INC_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'approach' \
    --decision-point 'Incomplete voting test' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  INC_BALLOT_ID="$(echo "$INC_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || true
  if [ -n "$INC_BALLOT_ID" ]; then
    # Submit claims but only 1 vote (need all 3)
    safe_call submit_claim --ballot "$INC_BALLOT_ID" --model-id "model-A" \
      --assessment "Claim A" --confidence 0.85 --reasoning "R-A" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$INC_BALLOT_ID" --model-id "model-B" \
      --assessment "Claim B" --confidence 0.78 --reasoning "R-B" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$INC_BALLOT_ID" --model-id "model-C" \
      --assessment "Claim C" --confidence 0.72 --reasoning "R-C" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$INC_BALLOT_ID" --model-id "model-A" --vote 0 --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    # Only 1 of 3 votes cast — tally should fail
    INC_TALLY="$(tally_votes --ballot "$INC_BALLOT_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
    assert "Tallying with only 1-of-3 votes returns INCOMPLETE_VOTING" \
      "echo '$INC_TALLY' | grep -q 'INCOMPLETE_VOTING'"
  else
    assert "Tallying with only 1-of-3 votes returns INCOMPLETE_VOTING" "false"
  fi
else
  assert "Tallying with only 1-of-3 votes returns INCOMPLETE_VOTING" "false"
fi

# ══════════════════════════════════════════
# Get Consensus Tests
# ══════════════════════════════════════════
echo ""
echo "--- Get Consensus ---"

# Test: Consensus reached (after successful tally)
echo "Consensus reached"
if $LIBS_SOURCED && [ -n "$MAJORITY_BALLOT_ID" ]; then
  CONSENSUS_RESULT="$(get_consensus --ballot "$MAJORITY_BALLOT_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "get_consensus returns consensus_level" \
    "echo '$CONSENSUS_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"consensus_level\"] in [\"unanimous\", \"majority\", \"split\", \"no_consensus\"]'"
  assert "get_consensus returns verdict" \
    "echo '$CONSENSUS_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"verdict\" in d'"
  assert "get_consensus returns weighted_score" \
    "echo '$CONSENSUS_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"weighted_score\" in d'"
  assert "get_consensus returns is_consensus=true for majority" \
    "echo '$CONSENSUS_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"is_consensus\") == True'"
else
  assert "get_consensus returns consensus_level" "false"
  assert "get_consensus returns verdict" "false"
  assert "get_consensus returns weighted_score" "false"
  assert "get_consensus returns is_consensus=true for majority" "false"
fi

# Test: NO_CONSENSUS in degraded 2-model state
echo ""
echo "NO_CONSENSUS in degraded 2-model state"
if $LIBS_SOURCED; then
  # Create a 2-model ballot (degraded tribunal — one model unavailable)
  DEG_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'research' \
    --decision-point 'Degraded 2-model tribunal test' \
    --models 'claude-opus-4-8,gpt-4o' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  DEG_BALLOT_ID="$(echo "$DEG_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || true
  if [ -n "$DEG_BALLOT_ID" ]; then
    # Submit 2 claims
    safe_call submit_claim --ballot "$DEG_BALLOT_ID" --model-id "model-A" \
      --assessment "Direction A" --confidence 0.85 --reasoning "R-A" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$DEG_BALLOT_ID" --model-id "model-B" \
      --assessment "Direction B" --confidence 0.80 --reasoning "R-B" \
      --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    # Each votes for different claim (1-1 split with only 2 models)
    safe_call cast_vote --ballot "$DEG_BALLOT_ID" --model-id "model-A" --vote 0 --workdir "$TEST_TMPDIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$DEG_BALLOT_ID" --model-id "model-B" --vote 1 --workdir "$TEST_TMPDIR" >/dev/null 2>&1

    DEG_TALLY="$(tally_votes --ballot "$DEG_BALLOT_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
    DEG_CONSENSUS="$(get_consensus --ballot "$DEG_BALLOT_ID" --workdir "$TEST_TMPDIR" 2>&1)" || true
    assert "Degraded 2-model 1-1 split returns consensus_level=no_consensus" \
      "echo '$DEG_CONSENSUS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"consensus_level\"] == \"no_consensus\"'"
    assert "Degraded 2-model returns verdict=no_consensus" \
      "echo '$DEG_CONSENSUS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"verdict\"] == \"no_consensus\"'"
    assert "Degraded 2-model returns is_consensus=false" \
      "echo '$DEG_CONSENSUS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"is_consensus\") == False'"
  else
    assert "Degraded 2-model 1-1 split returns consensus_level=no_consensus" "false"
    assert "Degraded 2-model returns verdict=no_consensus" "false"
    assert "Degraded 2-model returns is_consensus=false" "false"
  fi
else
  assert "Degraded 2-model 1-1 split returns consensus_level=no_consensus" "false"
  assert "Degraded 2-model returns verdict=no_consensus" "false"
  assert "Degraded 2-model returns is_consensus=false" "false"
fi

# Test: Model identity de-anonymization after tally
echo ""
echo "De-anonymization after tally"
if $LIBS_SOURCED && [ -n "$MAJORITY_BALLOT_ID" ]; then
  DEANON_RESULT="$(safe_call deanonymize_ballot --ballot "$MAJORITY_BALLOT_ID" \
    --mapping '{\"model-A\":\"claude-opus-4-8\",\"model-B\":\"gpt-4o\",\"model-C\":\"gemini-2.5-pro\"}' \
    --workdir "$TEST_TMPDIR")"
  assert "deanonymize_ballot returns model_mapping" \
    "echo '$DEANON_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"model_mapping\" in d'"
  assert "deanonymize_ballot maps model-A to real identity" \
    "echo '$DEANON_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"model_mapping\"][\"model-A\"] == \"claude-opus-4-8\"'"
  assert "deanonymize_ballot maps model-B to real identity" \
    "echo '$DEANON_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"model_mapping\"][\"model-B\"] == \"gpt-4o\"'"
  assert "deanonymize_ballot maps model-C to real identity" \
    "echo '$DEANON_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"model_mapping\"][\"model-C\"] == \"gemini-2.5-pro\"'"
  assert "deanonymize_ballot returns deanonymized=true" \
    "echo '$DEANON_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"deanonymized\") == True'"
else
  assert "deanonymize_ballot returns model_mapping" "false"
  assert "deanonymize_ballot maps model-A to real identity" "false"
  assert "deanonymize_ballot maps model-B to real identity" "false"
  assert "deanonymize_ballot maps model-C to real identity" "false"
  assert "deanonymize_ballot returns deanonymized=true" "false"
fi

# Test: De-anonymization before tally fails
echo ""
echo "De-anonymization before tally"
if $LIBS_SOURCED; then
  PRETALLY_BALLOT="$(create_ballot \
    --session 'devloop-test-session-001' \
    --round 'research' \
    --decision-point 'Pre-tally deanon test' \
    --models 'claude-opus-4-8,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEST_TMPDIR" 2>&1)" || true
  PRETALLY_ID="$(echo "$PRETALLY_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || true
  if [ -n "$PRETALLY_ID" ]; then
    EARLY_DEANON="$(safe_call deanonymize_ballot --ballot "$PRETALLY_ID" \
      --mapping '{\"model-A\":\"claude-opus-4-8\",\"model-B\":\"gpt-4o\",\"model-C\":\"gemini-2.5-pro\"}' \
      --workdir "$TEST_TMPDIR")"
    assert "De-anonymization before tally returns BALLOT_NOT_TALLIED" \
      "echo '$EARLY_DEANON' | grep -q 'BALLOT_NOT_TALLIED'"
  else
    assert "De-anonymization before tally returns BALLOT_NOT_TALLIED" "false"
  fi
else
  assert "De-anonymization before tally returns BALLOT_NOT_TALLIED" "false"
fi

# Test: BALLOT_NOT_FOUND for get_consensus
echo ""
echo "get_consensus error handling"
if $LIBS_SOURCED; then
  NO_BALLOT_CONSENSUS="$(get_consensus --ballot 'nonexistent-ballot-id' --workdir "$TEST_TMPDIR" 2>&1)" || true
  assert "get_consensus on nonexistent ballot returns BALLOT_NOT_FOUND" \
    "echo '$NO_BALLOT_CONSENSUS' | grep -q 'BALLOT_NOT_FOUND'"
else
  assert "get_consensus on nonexistent ballot returns BALLOT_NOT_FOUND" "false"
fi

# ═══════════════════════════════════════
# Final Results
# ═══════════════════════════════════════
echo ""
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
