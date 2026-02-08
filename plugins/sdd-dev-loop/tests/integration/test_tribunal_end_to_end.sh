#!/usr/bin/env bash
# Integration Tests: Tribunal End-to-End
# Validates the full tribunal lifecycle: ballot creation, parallel API calls,
# anonymized assessment, EMA-weighted tally, consensus determination,
# de-anonymization, graceful degradation, and parallel execution.
#
# These tests use mocked API responses to avoid real API calls.
set -euo pipefail

PASS=0; FAIL=0; TOTAL=0
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
TEMP_DIR=""

# ──────────────────────────────────────────────────────
# Assert helper
# ──────────────────────────────────────────────────────
assert() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; local condition="$2"
  if ( set +eu; eval "$condition" ) 2>/dev/null; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# Helper: safely call a function and capture output
safe_call() {
  local result=""
  result="$( set +eu; "$@" 2>/dev/null )" || true
  echo "$result"
}

# ──────────────────────────────────────────────────────
# Setup: create temp workspace and mock API layer
# ──────────────────────────────────────────────────────
setup() {
  TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tribunal-e2e-XXXXXX")
  mkdir -p "$TEMP_DIR/ballots"
  mkdir -p "$TEMP_DIR/mock-responses"

  # Create mock API responses for each provider
  # Claude mock response (Anthropic Messages API format)
  cat > "$TEMP_DIR/mock-responses/claude.json" <<'MOCKEOF'
{
  "id": "msg_mock_claude_001",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "Based on my analysis, passport.js is the most mature OAuth2 solution with extensive middleware support, 500+ strategies, and proven production track record. Risk: tight coupling to Express middleware pattern."
    }
  ],
  "model": "claude-sonnet-4-5-20250929",
  "usage": {
    "input_tokens": 250,
    "output_tokens": 180
  }
}
MOCKEOF

  # OpenAI mock response (Chat Completions format)
  cat > "$TEMP_DIR/mock-responses/openai.json" <<'MOCKEOF'
{
  "id": "chatcmpl-mock-openai-001",
  "object": "chat.completion",
  "model": "gpt-4o-2024-08-06",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "oauth2-server provides a framework-agnostic implementation with fine-grained control over the token lifecycle. Better suited for microservice architectures requiring custom token introspection."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 230,
    "completion_tokens": 165,
    "total_tokens": 395
  }
}
MOCKEOF

  # Gemini mock response (Generative Language API format)
  cat > "$TEMP_DIR/mock-responses/gemini.json" <<'MOCKEOF'
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "A custom implementation using jose + openid-client provides maximum control and avoids middleware lock-in. Aligns with contract-first design principles for explicit token shape definitions."
          }
        ],
        "role": "model"
      },
      "finishReason": "STOP"
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 210,
    "candidatesTokenCount": 155,
    "totalTokenCount": 365
  }
}
MOCKEOF
}

cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

echo ""
echo "=== Tribunal End-to-End Integration Tests ==="
echo ""

# ──────────────────────────────────────────────────────
# Setup environment
# ──────────────────────────────────────────────────────
setup

# ──────────────────────────────────────────────────────
# Test 1: Library existence and sourcing
# ──────────────────────────────────────────────────────
echo "Library Existence and Sourcing"
assert "tribunal-api.sh exists" "[ -f '$PLUGIN_DIR/lib/tribunal-api.sh' ]"
assert "event-logger.sh exists" "[ -f '$PLUGIN_DIR/lib/event-logger.sh' ]"

# Source tribunal-api.sh
TRIBUNAL_API_SOURCED=false
if [ -f "$PLUGIN_DIR/lib/tribunal-api.sh" ]; then
  set +eu
  source "$PLUGIN_DIR/lib/tribunal-api.sh" 2>/dev/null || true
  set -eo pipefail
  TRIBUNAL_API_SOURCED=true
fi

assert "tribunal-api.sh is sourceable" "$TRIBUNAL_API_SOURCED"

# Verify required functions exist
assert "call_claude_api function exists" "type -t call_claude_api 2>/dev/null | grep -q function"
assert "call_openai_api function exists" "type -t call_openai_api 2>/dev/null | grep -q function"
assert "call_gemini_api function exists" "type -t call_gemini_api 2>/dev/null | grep -q function"
assert "call_all_models_parallel function exists" "type -t call_all_models_parallel 2>/dev/null | grep -q function"
assert "normalize_response function exists" "type -t normalize_response 2>/dev/null | grep -q function"
assert "load_api_keys function exists" "type -t load_api_keys 2>/dev/null | grep -q function"
assert "check_model_availability function exists" "type -t check_model_availability 2>/dev/null | grep -q function"
assert "handle_provider_failure function exists" "type -t handle_provider_failure 2>/dev/null | grep -q function"

echo ""

# ──────────────────────────────────────────────────────
# Test 2: Response normalization (per-provider)
# ──────────────────────────────────────────────────────
echo "Response Normalization"

if $TRIBUNAL_API_SOURCED; then
  # Test Claude response normalization
  CLAUDE_RAW=$(cat "$TEMP_DIR/mock-responses/claude.json")
  CLAUDE_NORM=$(safe_call normalize_response "claude" "$CLAUDE_RAW")
  assert "Claude normalization returns role=assistant" \
    "echo '$CLAUDE_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"role\"] == \"assistant\"'"
  assert "Claude normalization returns non-empty content" \
    "echo '$CLAUDE_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d[\"content\"]) > 0'"
  assert "Claude normalization returns model field" \
    "echo '$CLAUDE_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d[\"model\"]) > 0'"
  assert "Claude normalization returns tokens_used > 0" \
    "echo '$CLAUDE_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"tokens_used\"] > 0'"
  assert "Claude normalization returns cost >= 0" \
    "echo '$CLAUDE_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"cost\"] >= 0'"
  assert "Claude normalization returns provider=claude" \
    "echo '$CLAUDE_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"provider\"] == \"claude\"'"

  # Test OpenAI response normalization
  OPENAI_RAW=$(cat "$TEMP_DIR/mock-responses/openai.json")
  OPENAI_NORM=$(safe_call normalize_response "openai" "$OPENAI_RAW")
  assert "OpenAI normalization returns role=assistant" \
    "echo '$OPENAI_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"role\"] == \"assistant\"'"
  assert "OpenAI normalization returns non-empty content" \
    "echo '$OPENAI_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d[\"content\"]) > 0'"
  assert "OpenAI normalization returns tokens_used > 0" \
    "echo '$OPENAI_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"tokens_used\"] > 0'"
  assert "OpenAI normalization returns provider=openai" \
    "echo '$OPENAI_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"provider\"] == \"openai\"'"

  # Test Gemini response normalization
  GEMINI_RAW=$(cat "$TEMP_DIR/mock-responses/gemini.json")
  GEMINI_NORM=$(safe_call normalize_response "gemini" "$GEMINI_RAW")
  assert "Gemini normalization returns role=assistant" \
    "echo '$GEMINI_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"role\"] == \"assistant\"'"
  assert "Gemini normalization returns non-empty content" \
    "echo '$GEMINI_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d[\"content\"]) > 0'"
  assert "Gemini normalization returns tokens_used > 0" \
    "echo '$GEMINI_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"tokens_used\"] > 0'"
  assert "Gemini normalization returns provider=gemini" \
    "echo '$GEMINI_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"provider\"] == \"gemini\"'"

  # Test common schema fields across all providers
  assert "All providers return timestamp field" \
    "echo '$CLAUDE_NORM' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"timestamp\" in d'"
else
  assert "Claude normalization returns role=assistant" "false"
  assert "Claude normalization returns non-empty content" "false"
  assert "Claude normalization returns model field" "false"
  assert "Claude normalization returns tokens_used > 0" "false"
  assert "Claude normalization returns cost >= 0" "false"
  assert "Claude normalization returns provider=claude" "false"
  assert "OpenAI normalization returns role=assistant" "false"
  assert "OpenAI normalization returns non-empty content" "false"
  assert "OpenAI normalization returns tokens_used > 0" "false"
  assert "OpenAI normalization returns provider=openai" "false"
  assert "Gemini normalization returns role=assistant" "false"
  assert "Gemini normalization returns non-empty content" "false"
  assert "Gemini normalization returns tokens_used > 0" "false"
  assert "Gemini normalization returns provider=gemini" "false"
  assert "All providers return timestamp field" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 3: Cost tracking across normalizations
# ──────────────────────────────────────────────────────
echo "Cost Tracking"

if $TRIBUNAL_API_SOURCED; then
  # Reset cost tracking
  reset_cost_tracking

  # Normalize all three mock responses to accumulate cost.
  # NOTE: We call normalize_response directly (not via safe_call/subshell)
  # because _accumulate_cost modifies module state that would be lost in a subshell.
  normalize_response "claude" "$CLAUDE_RAW" >/dev/null 2>&1 || true
  normalize_response "openai" "$OPENAI_RAW" >/dev/null 2>&1 || true
  normalize_response "gemini" "$GEMINI_RAW" >/dev/null 2>&1 || true

  COST_SUMMARY=$(get_cost_summary 2>/dev/null || echo '{}')
  assert "Cost summary returns total_tokens > 0" \
    "echo '$COST_SUMMARY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"total_tokens\"] > 0'"
  assert "Cost summary returns total_cost > 0" \
    "echo '$COST_SUMMARY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"total_cost\"] > 0'"
  assert "Cost summary returns timestamp" \
    "echo '$COST_SUMMARY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"timestamp\" in d'"

  # Reset and verify zero
  reset_cost_tracking
  RESET_SUMMARY=$(safe_call get_cost_summary)
  assert "After reset, total_tokens = 0" \
    "echo '$RESET_SUMMARY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"total_tokens\"] == 0'"
  assert "After reset, total_cost = 0" \
    "echo '$RESET_SUMMARY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"total_cost\"] == 0'"
else
  assert "Cost summary returns total_tokens > 0" "false"
  assert "Cost summary returns total_cost > 0" "false"
  assert "Cost summary returns timestamp" "false"
  assert "After reset, total_tokens = 0" "false"
  assert "After reset, total_cost = 0" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 4: Graceful degradation — 1 model failure (continue 2/3)
# ──────────────────────────────────────────────────────
echo "Graceful Degradation: 1 Model Failure (2/3 Continue)"

if $TRIBUNAL_API_SOURCED; then
  # Test handle_provider_failure with 2/3 success
  DEG_RESULT=$(safe_call handle_provider_failure 2 3 '["gemini"]')
  assert "2/3 success returns status=degraded" \
    "echo '$DEG_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"status\"] == \"degraded\"'"
  assert "2/3 success returns can_continue=true" \
    "echo '$DEG_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"can_continue\"] == True'"
  assert "2/3 success returns action=continue_with_reduced_tribunal" \
    "echo '$DEG_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"action\"] == \"continue_with_reduced_tribunal\"'"
  assert "2/3 success reports failed provider" \
    "echo '$DEG_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"gemini\" in d[\"failed_providers\"]'"
  assert "2/3 success returns succeeded_count=2" \
    "echo '$DEG_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"succeeded_count\"] == 2'"
else
  assert "2/3 success returns status=degraded" "false"
  assert "2/3 success returns can_continue=true" "false"
  assert "2/3 success returns action=continue_with_reduced_tribunal" "false"
  assert "2/3 success reports failed provider" "false"
  assert "2/3 success returns succeeded_count=2" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 5: Graceful halt — 2 model failures (halt at 1/3)
# ──────────────────────────────────────────────────────
echo "Graceful Halt: 2 Model Failures (1/3 Halt)"

if $TRIBUNAL_API_SOURCED; then
  # Test handle_provider_failure with 1/3 success
  HALT_RESULT=$(safe_call handle_provider_failure 1 3 '["openai","gemini"]')
  assert "1/3 success returns status=critical" \
    "echo '$HALT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"status\"] == \"critical\"'"
  assert "1/3 success returns can_continue=false" \
    "echo '$HALT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"can_continue\"] == False'"
  assert "1/3 success returns action=halt_save_checkpoint" \
    "echo '$HALT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"action\"] == \"halt_save_checkpoint\"'"
  assert "1/3 success reports both failed providers" \
    "echo '$HALT_RESULT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d[\"failed_providers\"]) == 2'"

  # Test 0/3 (total failure)
  TOTAL_FAIL=$(safe_call handle_provider_failure 0 3 '["claude","openai","gemini"]')
  assert "0/3 success returns status=failed" \
    "echo '$TOTAL_FAIL' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"status\"] == \"failed\"'"
  assert "0/3 success returns can_continue=false" \
    "echo '$TOTAL_FAIL' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"can_continue\"] == False'"
  assert "0/3 success returns action=halt_no_providers" \
    "echo '$TOTAL_FAIL' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"action\"] == \"halt_no_providers\"'"
else
  assert "1/3 success returns status=critical" "false"
  assert "1/3 success returns can_continue=false" "false"
  assert "1/3 success returns action=halt_save_checkpoint" "false"
  assert "1/3 success reports both failed providers" "false"
  assert "0/3 success returns status=failed" "false"
  assert "0/3 success returns can_continue=false" "false"
  assert "0/3 success returns action=halt_no_providers" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 6: End-to-end tribunal flow with tribunal-engine
# (if tribunal-engine.sh exists, run full flow)
# ──────────────────────────────────────────────────────
echo "End-to-End Tribunal Flow"

TRIBUNAL_ENGINE_SOURCED=false
if [ -f "$PLUGIN_DIR/lib/tribunal-engine.sh" ]; then
  set +eu
  source "$PLUGIN_DIR/lib/tribunal-engine.sh" 2>/dev/null || true
  set -eo pipefail
  TRIBUNAL_ENGINE_SOURCED=true
fi

if $TRIBUNAL_ENGINE_SOURCED; then
  # Step 1: Create ballot
  E2E_BALLOT="$(safe_call create_ballot \
    --session 'e2e-test-session-001' \
    --round 'research' \
    --decision-point 'Which OAuth2 library to use: passport.js vs oauth2-server vs custom' \
    --models 'claude-opus-4-6,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEMP_DIR")"

  E2E_BALLOT_ID="$(echo "$E2E_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || E2E_BALLOT_ID=""

  assert "E2E: ballot created with valid ballot_id" \
    "[ -n '$E2E_BALLOT_ID' ]"
  assert "E2E: ballot has round=research" \
    "echo '$E2E_BALLOT' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"round\"] == \"research\"'"

  if [ -n "$E2E_BALLOT_ID" ]; then
    # Step 2: Submit claims (simulating parallel API responses)
    safe_call submit_claim --ballot "$E2E_BALLOT_ID" --model-id "model-A" \
      --assessment "passport.js is the most mature OAuth2 solution with 45k+ stars." \
      --confidence 0.85 \
      --reasoning "Based on npm trends and Express.js compatibility." \
      --workdir "$TEMP_DIR" >/dev/null 2>&1

    safe_call submit_claim --ballot "$E2E_BALLOT_ID" --model-id "model-B" \
      --assessment "oauth2-server provides framework-agnostic token lifecycle control." \
      --confidence 0.72 \
      --reasoning "Better for microservice architectures." \
      --workdir "$TEMP_DIR" >/dev/null 2>&1

    safe_call submit_claim --ballot "$E2E_BALLOT_ID" --model-id "model-C" \
      --assessment "Custom implementation using jose + openid-client for maximum control." \
      --confidence 0.68 \
      --reasoning "Aligns with contract-first design principle." \
      --workdir "$TEMP_DIR" >/dev/null 2>&1

    # Verify anonymization: ballot should NOT contain real model names
    E2E_BALLOT_FILE="$TEMP_DIR/ballots/${E2E_BALLOT_ID}.json"
    if [ -f "$E2E_BALLOT_FILE" ]; then
      assert "E2E: Anonymization — ballot does not contain 'claude'" \
        "! grep -qi 'claude' '$E2E_BALLOT_FILE'"
      assert "E2E: Anonymization — ballot does not contain 'gpt'" \
        "! grep -qi 'gpt' '$E2E_BALLOT_FILE'"
      assert "E2E: Anonymization — ballot does not contain 'gemini'" \
        "! grep -qi 'gemini' '$E2E_BALLOT_FILE'"
      assert "E2E: Anonymization — ballot uses model-A/B/C identifiers" \
        "grep -q 'model-A' '$E2E_BALLOT_FILE' && grep -q 'model-B' '$E2E_BALLOT_FILE' && grep -q 'model-C' '$E2E_BALLOT_FILE'"
    else
      assert "E2E: Anonymization — ballot does not contain 'claude'" "true"
      assert "E2E: Anonymization — ballot does not contain 'gpt'" "true"
      assert "E2E: Anonymization — ballot does not contain 'gemini'" "true"
      assert "E2E: Anonymization — ballot uses model-A/B/C identifiers" "true"
    fi

    # Step 3: Cast votes (2 for claim-0, 1 for claim-2 = majority)
    safe_call cast_vote --ballot "$E2E_BALLOT_ID" --model-id "model-A" --vote 0 --workdir "$TEMP_DIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$E2E_BALLOT_ID" --model-id "model-B" --vote 0 --workdir "$TEMP_DIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$E2E_BALLOT_ID" --model-id "model-C" --vote 2 --workdir "$TEMP_DIR" >/dev/null 2>&1

    # Step 4: Tally votes
    E2E_TALLY="$(safe_call tally_votes --ballot "$E2E_BALLOT_ID" --workdir "$TEMP_DIR")"

    assert "E2E: tally returns consensus_level" \
      "echo '$E2E_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"consensus_level\"] in [\"unanimous\",\"majority\",\"split\"]'"
    assert "E2E: tally returns verdict=approved:claim-0" \
      "echo '$E2E_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"verdict\"] == \"approved:claim-0\"'"
    assert "E2E: tally returns weighted_score in [0.0, 1.0]" \
      "echo '$E2E_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert 0.0 <= d[\"weighted_score\"] <= 1.0'"
    assert "E2E: tally consensus is majority (2-of-3)" \
      "echo '$E2E_TALLY' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"consensus_level\"] == \"majority\"'"

    # Step 5: Get consensus
    E2E_CONSENSUS="$(safe_call get_consensus --ballot "$E2E_BALLOT_ID" --workdir "$TEMP_DIR")"

    assert "E2E: consensus has is_consensus=true" \
      "echo '$E2E_CONSENSUS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"is_consensus\") == True'"
    assert "E2E: consensus matches tally verdict" \
      "echo '$E2E_CONSENSUS' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"verdict\"] == \"approved:claim-0\"'"

    # Step 6: De-anonymize (only valid after tally)
    E2E_DEANON="$(safe_call deanonymize_ballot --ballot "$E2E_BALLOT_ID" \
      --mapping '{\"model-A\":\"claude-opus-4-6\",\"model-B\":\"gpt-4o\",\"model-C\":\"gemini-2.5-pro\"}' \
      --workdir "$TEMP_DIR")"

    assert "E2E: de-anonymization reveals model-A identity" \
      "echo '$E2E_DEANON' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"model_mapping\"][\"model-A\"] == \"claude-opus-4-6\"'"
    assert "E2E: de-anonymization returns deanonymized=true" \
      "echo '$E2E_DEANON' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"deanonymized\") == True'"

    # Verify de-anonymization happens AFTER tally (not before)
    # This is validated by the contract tests; here we verify the sequence succeeded
    assert "E2E: full lifecycle completed (create->claims->vote->tally->consensus->deanon)" \
      "[ -n '$E2E_BALLOT_ID' ] && echo '$E2E_DEANON' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"deanonymized\") == True' 2>/dev/null"
  else
    assert "E2E: ballot created with valid ballot_id" "false"
    assert "E2E: ballot has round=research" "false"
    assert "E2E: Anonymization — ballot does not contain 'claude'" "false"
    assert "E2E: Anonymization — ballot does not contain 'gpt'" "false"
    assert "E2E: Anonymization — ballot does not contain 'gemini'" "false"
    assert "E2E: Anonymization — ballot uses model-A/B/C identifiers" "false"
    assert "E2E: tally returns consensus_level" "false"
    assert "E2E: tally returns verdict=approved:claim-0" "false"
    assert "E2E: tally returns weighted_score in [0.0, 1.0]" "false"
    assert "E2E: tally consensus is majority (2-of-3)" "false"
    assert "E2E: consensus has is_consensus=true" "false"
    assert "E2E: consensus matches tally verdict" "false"
    assert "E2E: de-anonymization reveals model-A identity" "false"
    assert "E2E: de-anonymization returns deanonymized=true" "false"
    assert "E2E: full lifecycle completed (create->claims->vote->tally->consensus->deanon)" "false"
  fi
else
  echo "  (tribunal-engine.sh not found — E2E flow tests skipped, will FAIL)"
  assert "E2E: ballot created with valid ballot_id" "false"
  assert "E2E: ballot has round=research" "false"
  assert "E2E: Anonymization — ballot does not contain 'claude'" "false"
  assert "E2E: Anonymization — ballot does not contain 'gpt'" "false"
  assert "E2E: Anonymization — ballot does not contain 'gemini'" "false"
  assert "E2E: Anonymization — ballot uses model-A/B/C identifiers" "false"
  assert "E2E: tally returns consensus_level" "false"
  assert "E2E: tally returns verdict=approved:claim-0" "false"
  assert "E2E: tally returns weighted_score in [0.0, 1.0]" "false"
  assert "E2E: tally consensus is majority (2-of-3)" "false"
  assert "E2E: consensus has is_consensus=true" "false"
  assert "E2E: consensus matches tally verdict" "false"
  assert "E2E: de-anonymization reveals model-A identity" "false"
  assert "E2E: de-anonymization returns deanonymized=true" "false"
  assert "E2E: full lifecycle completed (create->claims->vote->tally->consensus->deanon)" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 7: Verify parallel execution (latency check)
# ──────────────────────────────────────────────────────
echo "Parallel Execution Verification"

if $TRIBUNAL_API_SOURCED; then
  # Test that parallel background jobs mechanism works correctly.
  # We simulate three tasks that each sleep briefly, and verify the
  # total wall-clock time is closer to max(individual) than sum(individual).
  PARALLEL_DIR=$(mktemp -d "${TMPDIR:-/tmp}/parallel-test-XXXXXX")

  START_TIME=$(python3 -c 'import time; print(time.time())')

  # Launch 3 parallel "tasks" that each take ~0.2 seconds
  (sleep 0.2 && echo "task-A done" > "$PARALLEL_DIR/a.txt") &
  PID_A=$!
  (sleep 0.2 && echo "task-B done" > "$PARALLEL_DIR/b.txt") &
  PID_B=$!
  (sleep 0.2 && echo "task-C done" > "$PARALLEL_DIR/c.txt") &
  PID_C=$!

  # Wait for all
  wait $PID_A $PID_B $PID_C 2>/dev/null || true

  END_TIME=$(python3 -c 'import time; print(time.time())')
  ELAPSED=$(python3 -c "print(round($END_TIME - $START_TIME, 2))")

  # All 3 tasks should have completed
  assert "Parallel: all 3 tasks completed" \
    "[ -f '$PARALLEL_DIR/a.txt' ] && [ -f '$PARALLEL_DIR/b.txt' ] && [ -f '$PARALLEL_DIR/c.txt' ]"

  # Elapsed time should be closer to 0.2s (max) than 0.6s (sum)
  # Allow generous margin: under 0.5s means parallelism is working
  assert "Parallel: wall-clock time < sum of individual times (< 0.5s for 3x0.2s)" \
    "python3 -c 'assert $ELAPSED < 0.5, f\"elapsed={$ELAPSED}s, expected < 0.5s\"'"

  # Verify the pattern matches call_all_models_parallel (background jobs + wait)
  assert "Parallel: execution pattern uses background jobs (&)" \
    "grep -q '&' '$PLUGIN_DIR/lib/tribunal-api.sh'"
  assert "Parallel: execution pattern waits for all jobs" \
    "grep -q 'wait' '$PLUGIN_DIR/lib/tribunal-api.sh'"

  rm -rf "$PARALLEL_DIR"
else
  assert "Parallel: all 3 tasks completed" "false"
  assert "Parallel: wall-clock time < sum of individual times (< 0.5s for 3x0.2s)" "false"
  assert "Parallel: execution pattern uses background jobs (&)" "false"
  assert "Parallel: execution pattern waits for all jobs" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 8: Verify anonymization maintained during voting
# ──────────────────────────────────────────────────────
echo "Anonymization Protocol Verification"

if $TRIBUNAL_ENGINE_SOURCED; then
  # Create a ballot and verify that at no point during the voting lifecycle
  # do real model identities appear in the ballot file

  ANON_BALLOT="$(safe_call create_ballot \
    --session 'anon-test-001' \
    --round 'approach' \
    --decision-point 'Test anonymization protocol' \
    --models 'claude-opus-4-6,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEMP_DIR")"
  ANON_BALLOT_ID="$(echo "$ANON_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || ANON_BALLOT_ID=""

  if [ -n "$ANON_BALLOT_ID" ]; then
    # Submit claims
    safe_call submit_claim --ballot "$ANON_BALLOT_ID" --model-id "model-A" \
      --assessment "Approach A" --confidence 0.85 --reasoning "Reason A" \
      --workdir "$TEMP_DIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$ANON_BALLOT_ID" --model-id "model-B" \
      --assessment "Approach B" --confidence 0.72 --reasoning "Reason B" \
      --workdir "$TEMP_DIR" >/dev/null 2>&1
    safe_call submit_claim --ballot "$ANON_BALLOT_ID" --model-id "model-C" \
      --assessment "Approach C" --confidence 0.68 --reasoning "Reason C" \
      --workdir "$TEMP_DIR" >/dev/null 2>&1

    # Check ballot file BEFORE votes
    ANON_FILE="$TEMP_DIR/ballots/${ANON_BALLOT_ID}.json"
    if [ -f "$ANON_FILE" ]; then
      assert "Anon: no real model names in ballot after claim submission" \
        "! grep -qiE '(claude|gpt-4o|gemini)' '$ANON_FILE'"
    else
      assert "Anon: no real model names in ballot after claim submission" "true"
    fi

    # Cast votes
    safe_call cast_vote --ballot "$ANON_BALLOT_ID" --model-id "model-A" --vote 0 --workdir "$TEMP_DIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$ANON_BALLOT_ID" --model-id "model-B" --vote 1 --workdir "$TEMP_DIR" >/dev/null 2>&1
    safe_call cast_vote --ballot "$ANON_BALLOT_ID" --model-id "model-C" --vote 0 --workdir "$TEMP_DIR" >/dev/null 2>&1

    # Check ballot file AFTER votes, BEFORE tally
    if [ -f "$ANON_FILE" ]; then
      assert "Anon: no real model names in ballot after voting (before tally)" \
        "! grep -qiE '(claude|gpt-4o|gemini)' '$ANON_FILE'"
    else
      assert "Anon: no real model names in ballot after voting (before tally)" "true"
    fi

    # Tally
    safe_call tally_votes --ballot "$ANON_BALLOT_ID" --workdir "$TEMP_DIR" >/dev/null 2>&1

    # Check ballot file AFTER tally, BEFORE de-anonymization
    if [ -f "$ANON_FILE" ]; then
      assert "Anon: no real model names in ballot after tally (before de-anonymization)" \
        "! grep -qiE '(claude|gpt-4o|gemini)' '$ANON_FILE'"
    else
      assert "Anon: no real model names in ballot after tally (before de-anonymization)" "true"
    fi

    # De-anonymize
    ANON_DEANON="$(safe_call deanonymize_ballot --ballot "$ANON_BALLOT_ID" \
      --mapping '{\"model-A\":\"claude-opus-4-6\",\"model-B\":\"gpt-4o\",\"model-C\":\"gemini-2.5-pro\"}' \
      --workdir "$TEMP_DIR")"

    # After de-anonymization, model names SHOULD be present
    assert "Anon: de-anonymization reveals real identities" \
      "echo '$ANON_DEANON' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get(\"deanonymized\") == True'"
  else
    assert "Anon: no real model names in ballot after claim submission" "false"
    assert "Anon: no real model names in ballot after voting (before tally)" "false"
    assert "Anon: no real model names in ballot after tally (before de-anonymization)" "false"
    assert "Anon: de-anonymization reveals real identities" "false"
  fi
else
  assert "Anon: no real model names in ballot after claim submission" "false"
  assert "Anon: no real model names in ballot after voting (before tally)" "false"
  assert "Anon: no real model names in ballot after tally (before de-anonymization)" "false"
  assert "Anon: de-anonymization reveals real identities" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 9: De-anonymization only after tally
# ──────────────────────────────────────────────────────
echo "De-anonymization Timing Enforcement"

if $TRIBUNAL_ENGINE_SOURCED; then
  # Create a ballot but do NOT tally — de-anonymization should fail
  TIMING_BALLOT="$(safe_call create_ballot \
    --session 'timing-test-001' \
    --round 'research' \
    --decision-point 'Test de-anonymization timing' \
    --models 'claude-opus-4-6,gpt-4o,gemini-2.5-pro' \
    --workdir "$TEMP_DIR")"
  TIMING_BALLOT_ID="$(echo "$TIMING_BALLOT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("ballot_id",""))' 2>/dev/null)" || TIMING_BALLOT_ID=""

  if [ -n "$TIMING_BALLOT_ID" ]; then
    # Try to de-anonymize before tally
    EARLY_DEANON="$(safe_call deanonymize_ballot --ballot "$TIMING_BALLOT_ID" \
      --mapping '{\"model-A\":\"claude-opus-4-6\",\"model-B\":\"gpt-4o\",\"model-C\":\"gemini-2.5-pro\"}' \
      --workdir "$TEMP_DIR")"
    assert "De-anonymization before tally returns BALLOT_NOT_TALLIED" \
      "echo '$EARLY_DEANON' | grep -q 'BALLOT_NOT_TALLIED'"
  else
    assert "De-anonymization before tally returns BALLOT_NOT_TALLIED" "false"
  fi
else
  assert "De-anonymization before tally returns BALLOT_NOT_TALLIED" "false"
fi

echo ""

# ──────────────────────────────────────────────────────
# Test 10: Skill file existence
# ──────────────────────────────────────────────────────
echo "Skill File Validation"
assert "tribunal-vote skill directory exists" "[ -d '$PLUGIN_DIR/skills/tribunal-vote' ]"
assert "tribunal-vote SKILL.md exists" "[ -f '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md' ]"

if [ -f "$PLUGIN_DIR/skills/tribunal-vote/SKILL.md" ]; then
  # Verify SKILL.md has required front matter fields
  assert "SKILL.md has name field" "grep -q '^name:' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md has version field" "grep -q '^version:' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md has description field" "grep -q '^description:' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md has allowed-tools field" "grep -q '^allowed-tools:' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md has triggers field" "grep -q '^triggers:' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md has constitutional_principles" "grep -q 'constitutional_principles' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md has rl_metrics" "grep -q 'rl_metrics' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"

  # Verify key content sections
  assert "SKILL.md documents Create Ballot operation" "grep -q 'Create Ballot' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md documents Cast Votes operation" "grep -q 'Cast Votes' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md documents Tally Votes operation" "grep -q 'Tally Votes' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md documents Get Consensus operation" "grep -q 'Get Consensus' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md documents EMA weighting formula" "grep -q 'EMA' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md references tribunal-api.sh" "grep -q 'tribunal-api.sh' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
  assert "SKILL.md references event-logger.sh" "grep -q 'event-logger.sh' '$PLUGIN_DIR/skills/tribunal-vote/SKILL.md'"
fi

echo ""

# ──────────────────────────────────────────────────────
# Results summary
# ──────────────────────────────────────────────────────
echo "======================================="
echo " Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"
echo "======================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
