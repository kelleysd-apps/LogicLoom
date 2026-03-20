#!/usr/bin/env bash
# tribunal-api.sh — Multi-LLM API abstraction library for sdd-dev-loop plugin
#
# Provides unified API wrappers for Claude, OpenAI, and Gemini models,
# enabling parallel multi-model queries for tribunal voting. Handles
# provider-specific request/response formats, error handling, timeout
# support, cost tracking, and graceful degradation.
#
# This file is designed to be sourced, not executed directly.
#
# Dependencies: curl (HTTP requests), jq (JSON processing), bc (arithmetic)
# Constitutional Principle XIV: AI Model Selection — multi-model tribunal support
# Constitutional Principle X: Agent Delegation — tribunal-judge uses this for LLM calls

set -euo pipefail

# ==============================================================================
# Plugin Directory Resolution
# ==============================================================================

if [[ -z "${PLUGIN_DIR:-}" ]]; then
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ==============================================================================
# Module Constants
# ==============================================================================

# Default models per provider
_TRIBUNAL_CLAUDE_MODEL="${TRIBUNAL_CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
_TRIBUNAL_OPENAI_MODEL="${TRIBUNAL_OPENAI_MODEL:-gpt-4o}"
_TRIBUNAL_GEMINI_MODEL="${TRIBUNAL_GEMINI_MODEL:-gemini-2.5-pro}"

# Shared fallback model (Mistral Large — fills any single failed primary slot)
_TRIBUNAL_MISTRAL_MODEL="${TRIBUNAL_MISTRAL_MODEL:-mistral-large-latest}"

# API endpoints
_ANTHROPIC_API_URL="https://api.anthropic.com/v1/messages"
_OPENAI_API_URL="https://api.openai.com/v1/chat/completions"
_GEMINI_API_BASE="https://generativelanguage.googleapis.com/v1beta/models"
_MISTRAL_API_URL="https://api.mistral.ai/v1/chat/completions"

# Timeouts and limits
_API_TIMEOUT_SECONDS="${TRIBUNAL_API_TIMEOUT:-60}"
_HEALTH_CHECK_TIMEOUT="${TRIBUNAL_HEALTH_TIMEOUT:-10}"
_MAX_TOKENS="${TRIBUNAL_MAX_TOKENS:-2048}"

# Cost tracking (approximate per 1K tokens — input/output blended)
_CLAUDE_COST_PER_1K=0.003
_OPENAI_COST_PER_1K=0.005
_GEMINI_COST_PER_1K=0.00125
_MISTRAL_COST_PER_1K=0.002

# ==============================================================================
# Module State
# ==============================================================================

# API keys (populated by load_api_keys)
_ANTHROPIC_API_KEY=""
_OPENAI_API_KEY=""
_GEMINI_API_KEY=""
_MISTRAL_API_KEY=""

# Cost accumulator for the session
_TRIBUNAL_TOTAL_COST="0"
_TRIBUNAL_TOTAL_TOKENS="0"

# Provider availability state
_CLAUDE_AVAILABLE=""
_OPENAI_AVAILABLE=""
_GEMINI_AVAILABLE=""

# ==============================================================================
# Internal Helpers
# ==============================================================================

# _bc_calc — Evaluate a floating-point expression via bc
_bc_calc() {
    local expr="$1"
    echo "$expr" | bc -l 2>/dev/null || echo "0"
}

# _iso8601_now — Get current UTC timestamp in ISO 8601 format
_iso8601_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# _estimate_cost — Estimate cost from token count and provider rate
# Usage: _estimate_cost <tokens> <cost_per_1k>
_estimate_cost() {
    local tokens="$1"
    local cost_per_1k="$2"
    _bc_calc "$tokens * $cost_per_1k / 1000"
}

# _accumulate_cost — Add to session cost tracker
# Usage: _accumulate_cost <tokens> <cost>
_accumulate_cost() {
    local tokens="$1"
    local cost="$2"
    _TRIBUNAL_TOTAL_TOKENS=$(_bc_calc "$_TRIBUNAL_TOTAL_TOKENS + $tokens")
    _TRIBUNAL_TOTAL_COST=$(_bc_calc "$_TRIBUNAL_TOTAL_COST + $cost")
}

# ==============================================================================
# load_api_keys — Load API keys from .env or environment
# ==============================================================================
# Usage: load_api_keys [env_file_path]
#
# Reads ANTHROPIC_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY from:
#   1. Environment variables (if already set)
#   2. Specified .env file
#   3. Repository root .env file
#
# Arguments:
#   env_file_path — Optional path to .env file (defaults to repo root .env)
#
# Outputs: JSON summary of loaded keys (provider: true/false)
# Returns: 0 on success (at least 2 keys loaded), 1 on failure
load_api_keys() {
    local env_file="${1:-}"

    # Try to find .env file if not specified
    if [[ -z "$env_file" ]]; then
        local repo_root
        repo_root="$(cd "$PLUGIN_DIR/../.." && pwd)"
        if [[ -f "$repo_root/.env" ]]; then
            env_file="$repo_root/.env"
        fi
    fi

    # Load from .env file if it exists
    if [[ -n "$env_file" && -f "$env_file" ]]; then
        # Source .env safely — only export known API key variables
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            # Strip quotes from value
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
            # Only load recognized API key variables
            case "$key" in
                ANTHROPIC_API_KEY) _ANTHROPIC_API_KEY="$value" ;;
                OPENAI_API_KEY)    _OPENAI_API_KEY="$value" ;;
                GEMINI_API_KEY)    _GEMINI_API_KEY="$value" ;;
                MISTRAL_API_KEY)   _MISTRAL_API_KEY="$value" ;;
            esac
        done < "$env_file"
    fi

    # Override with environment variables if set
    [[ -n "${ANTHROPIC_API_KEY:-}" ]] && _ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
    [[ -n "${OPENAI_API_KEY:-}" ]]    && _OPENAI_API_KEY="$OPENAI_API_KEY"
    [[ -n "${GEMINI_API_KEY:-}" ]]    && _GEMINI_API_KEY="$GEMINI_API_KEY"
    [[ -n "${MISTRAL_API_KEY:-}" ]]   && _MISTRAL_API_KEY="$MISTRAL_API_KEY"

    # Count loaded keys
    local loaded=0
    local claude_loaded=false openai_loaded=false gemini_loaded=false
    [[ -n "$_ANTHROPIC_API_KEY" ]] && { loaded=$((loaded + 1)); claude_loaded=true; }
    [[ -n "$_OPENAI_API_KEY" ]]   && { loaded=$((loaded + 1)); openai_loaded=true; }
    [[ -n "$_GEMINI_API_KEY" ]]   && { loaded=$((loaded + 1)); gemini_loaded=true; }

    # Output summary
    jq -n \
        --argjson claude "$claude_loaded" \
        --argjson openai "$openai_loaded" \
        --argjson gemini "$gemini_loaded" \
        --argjson total "$loaded" \
        '{
            claude: $claude,
            openai: $openai,
            gemini: $gemini,
            total_loaded: $total
        }'

    # Require at least 2 keys for tribunal operation
    if [[ $loaded -lt 2 ]]; then
        echo "ERROR: Tribunal requires at least 2 API keys. Only $loaded loaded." >&2
        return 1
    fi

    return 0
}

# ==============================================================================
# check_model_availability — Health check each provider
# ==============================================================================
# Usage: check_model_availability
#
# Performs lightweight pings to each provider to verify API key validity
# and service availability. Updates internal availability state.
#
# Outputs: JSON object with provider availability status
# Returns: 0 if at least 2 providers available, 1 otherwise
check_model_availability() {
    local claude_ok=false openai_ok=false gemini_ok=false
    local available_count=0

    # Check Claude (Anthropic) — minimal messages request
    if [[ -n "$_ANTHROPIC_API_KEY" ]]; then
        local claude_status
        claude_status=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time "$_HEALTH_CHECK_TIMEOUT" \
            -H "x-api-key: $_ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d '{"model":"'"$_TRIBUNAL_CLAUDE_MODEL"'","max_tokens":1,"messages":[{"role":"user","content":"ping"}]}' \
            "$_ANTHROPIC_API_URL" 2>/dev/null) || claude_status="000"
        # 200 = success, 400 = auth ok but bad request is fine for health check
        if [[ "$claude_status" =~ ^(200|400)$ ]]; then
            claude_ok=true
            available_count=$((available_count + 1))
        fi
    fi
    _CLAUDE_AVAILABLE="$claude_ok"

    # Check OpenAI — minimal chat completion request
    if [[ -n "$_OPENAI_API_KEY" ]]; then
        local openai_status
        openai_status=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time "$_HEALTH_CHECK_TIMEOUT" \
            -H "Authorization: Bearer $_OPENAI_API_KEY" \
            -H "Content-Type: application/json" \
            -d '{"model":"'"$_TRIBUNAL_OPENAI_MODEL"'","max_tokens":1,"messages":[{"role":"user","content":"ping"}]}' \
            "$_OPENAI_API_URL" 2>/dev/null) || openai_status="000"
        if [[ "$openai_status" =~ ^(200|400)$ ]]; then
            openai_ok=true
            available_count=$((available_count + 1))
        fi
    fi
    _OPENAI_AVAILABLE="$openai_ok"

    # Check Gemini — minimal generate request
    if [[ -n "$_GEMINI_API_KEY" ]]; then
        local gemini_status
        gemini_status=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time "$_HEALTH_CHECK_TIMEOUT" \
            "${_GEMINI_API_BASE}/${_TRIBUNAL_GEMINI_MODEL}:generateContent?key=${_GEMINI_API_KEY}" \
            -H "Content-Type: application/json" \
            -d '{"contents":[{"parts":[{"text":"ping"}]}],"generationConfig":{"maxOutputTokens":1}}' \
            2>/dev/null) || gemini_status="000"
        if [[ "$gemini_status" =~ ^(200|400)$ ]]; then
            gemini_ok=true
            available_count=$((available_count + 1))
        fi
    fi
    _GEMINI_AVAILABLE="$gemini_ok"

    jq -n \
        --argjson claude "$claude_ok" \
        --argjson openai "$openai_ok" \
        --argjson gemini "$gemini_ok" \
        --argjson available_count "$available_count" \
        '{
            claude: $claude,
            openai: $openai,
            gemini: $gemini,
            available_count: $available_count
        }'

    if [[ $available_count -lt 2 ]]; then
        return 1
    fi
    return 0
}

# ==============================================================================
# call_claude_api — Claude-specific API wrapper (Anthropic Messages API)
# ==============================================================================
# Usage: call_claude_api <system_prompt> <user_message> [max_tokens]
#
# Sends a request to the Anthropic Messages API using the configured model
# and API key. Returns the raw API response.
#
# Arguments:
#   system_prompt — System-level instruction text
#   user_message  — User message content
#   max_tokens    — Optional max tokens (default: $_MAX_TOKENS)
#
# Outputs: Raw JSON response from the Anthropic API
# Returns: 0 on success, 1 on failure
call_claude_api() {
    local system_prompt="$1"
    local user_message="$2"
    local max_tokens="${3:-$_MAX_TOKENS}"

    if [[ -z "$_ANTHROPIC_API_KEY" ]]; then
        echo '{"error":"ANTHROPIC_API_KEY not set","provider":"claude"}' >&2
        return 1
    fi

    local request_body
    request_body=$(jq -n \
        --arg model "$_TRIBUNAL_CLAUDE_MODEL" \
        --argjson max_tokens "$max_tokens" \
        --arg system "$system_prompt" \
        --arg user "$user_message" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            system: $system,
            messages: [
                { role: "user", content: $user }
            ]
        }')

    local response
    response=$(curl -s --max-time "$_API_TIMEOUT_SECONDS" \
        -H "x-api-key: $_ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$request_body" \
        "$_ANTHROPIC_API_URL" 2>/dev/null)

    if [[ -z "$response" ]]; then
        echo '{"error":"Empty response from Claude API","provider":"claude"}' >&2
        return 1
    fi

    # Check for API error
    local error_type
    error_type=$(echo "$response" | jq -r '.error.type // empty' 2>/dev/null)
    if [[ -n "$error_type" ]]; then
        echo "$response" >&2
        return 1
    fi

    echo "$response"
    return 0
}

# ==============================================================================
# call_openai_api — OpenAI API wrapper (Chat Completions API)
# ==============================================================================
# Usage: call_openai_api <system_prompt> <user_message> [max_tokens]
#
# Sends a request to the OpenAI Chat Completions API using the configured
# model and Bearer token authentication.
#
# Arguments:
#   system_prompt — System-level instruction text
#   user_message  — User message content
#   max_tokens    — Optional max tokens (default: $_MAX_TOKENS)
#
# Outputs: Raw JSON response from the OpenAI API
# Returns: 0 on success, 1 on failure
call_openai_api() {
    local system_prompt="$1"
    local user_message="$2"
    local max_tokens="${3:-$_MAX_TOKENS}"

    if [[ -z "$_OPENAI_API_KEY" ]]; then
        echo '{"error":"OPENAI_API_KEY not set","provider":"openai"}' >&2
        return 1
    fi

    local request_body
    request_body=$(jq -n \
        --arg model "$_TRIBUNAL_OPENAI_MODEL" \
        --argjson max_tokens "$max_tokens" \
        --arg system "$system_prompt" \
        --arg user "$user_message" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            messages: [
                { role: "system", content: $system },
                { role: "user", content: $user }
            ]
        }')

    local response
    response=$(curl -s --max-time "$_API_TIMEOUT_SECONDS" \
        -H "Authorization: Bearer $_OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        "$_OPENAI_API_URL" 2>/dev/null)

    if [[ -z "$response" ]]; then
        echo '{"error":"Empty response from OpenAI API","provider":"openai"}' >&2
        return 1
    fi

    # Check for API error
    local error_msg
    error_msg=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    if [[ -n "$error_msg" ]]; then
        echo "$response" >&2
        return 1
    fi

    echo "$response"
    return 0
}

# ==============================================================================
# call_gemini_api — Gemini API wrapper (Generative Language API)
# ==============================================================================
# Usage: call_gemini_api <system_prompt> <user_message> [max_tokens]
#
# Sends a request to the Google Generative Language API using the configured
# Gemini model and API key as a query parameter.
#
# Arguments:
#   system_prompt — System-level instruction text (prepended to user message)
#   user_message  — User message content
#   max_tokens    — Optional max tokens (default: $_MAX_TOKENS)
#
# Outputs: Raw JSON response from the Gemini API
# Returns: 0 on success, 1 on failure
call_gemini_api() {
    local system_prompt="$1"
    local user_message="$2"
    local max_tokens="${3:-$_MAX_TOKENS}"

    if [[ -z "$_GEMINI_API_KEY" ]]; then
        echo '{"error":"GEMINI_API_KEY not set","provider":"gemini"}' >&2
        return 1
    fi

    local api_url="${_GEMINI_API_BASE}/${_TRIBUNAL_GEMINI_MODEL}:generateContent?key=${_GEMINI_API_KEY}"

    local request_body
    request_body=$(jq -n \
        --arg system "$system_prompt" \
        --arg user "$user_message" \
        --argjson max_tokens "$max_tokens" \
        '{
            system_instruction: {
                parts: [{ text: $system }]
            },
            contents: [
                {
                    role: "user",
                    parts: [{ text: $user }]
                }
            ],
            generationConfig: {
                maxOutputTokens: $max_tokens
            }
        }')

    local response
    response=$(curl -s --max-time "$_API_TIMEOUT_SECONDS" \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        "$api_url" 2>/dev/null)

    if [[ -z "$response" ]]; then
        echo '{"error":"Empty response from Gemini API","provider":"gemini"}' >&2
        return 1
    fi

    # Check for API error
    local error_msg
    error_msg=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    if [[ -n "$error_msg" ]]; then
        echo "$response" >&2
        return 1
    fi

    echo "$response"
    return 0
}

# ==============================================================================
# call_mistral_api — Mistral API wrapper (OpenAI-compatible Chat Completions)
# ==============================================================================
# Usage: call_mistral_api <system_prompt> <user_message> [max_tokens]
#
# Shared fallback for any single failed primary provider. Uses Mistral's
# OpenAI-compatible chat completions endpoint.
#
# Arguments:
#   system_prompt — System-level instruction text
#   user_message  — User message content
#   max_tokens    — Optional max tokens (default: $_MAX_TOKENS)
#
# Outputs: Raw JSON response from the Mistral API
# Returns: 0 on success, 1 on failure
call_mistral_api() {
    local system_prompt="$1"
    local user_message="$2"
    local max_tokens="${3:-$_MAX_TOKENS}"

    if [[ -z "$_MISTRAL_API_KEY" ]]; then
        echo '{"error":"MISTRAL_API_KEY not set","provider":"mistral"}' >&2
        return 1
    fi

    local request_body
    request_body=$(jq -n \
        --arg model "$_TRIBUNAL_MISTRAL_MODEL" \
        --argjson max_tokens "$max_tokens" \
        --arg system "$system_prompt" \
        --arg user "$user_message" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            messages: [
                { role: "system", content: $system },
                { role: "user", content: $user }
            ]
        }')

    local response
    response=$(curl -s --max-time "$_API_TIMEOUT_SECONDS" \
        -H "Authorization: Bearer $_MISTRAL_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        "$_MISTRAL_API_URL" 2>/dev/null)

    if [[ -z "$response" ]]; then
        echo '{"error":"Empty response from Mistral API","provider":"mistral"}' >&2
        return 1
    fi

    # Check for API error
    local error_msg
    error_msg=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    if [[ -n "$error_msg" ]]; then
        echo "$response" >&2
        return 1
    fi

    echo "$response"
    return 0
}

# ==============================================================================
# normalize_response — Convert provider-specific response to common schema
# ==============================================================================
# Usage: normalize_response <provider> <raw_response>
#
# Converts Claude, OpenAI, or Gemini API responses into a unified schema:
#   { role, content, model, tokens_used, cost }
#
# Arguments:
#   provider     — One of: claude, openai, gemini
#   raw_response — Raw JSON response from the provider API
#
# Outputs: Normalized JSON object
# Returns: 0 on success, 1 on parse error
normalize_response() {
    local provider="$1"
    local raw_response="$2"

    local content="" model="" tokens_used=0 cost="0"

    case "$provider" in
        claude)
            # Anthropic Messages API response format
            content=$(echo "$raw_response" | jq -r '.content[0].text // ""' 2>/dev/null)
            model=$(echo "$raw_response" | jq -r '.model // ""' 2>/dev/null)
            local input_tokens output_tokens
            input_tokens=$(echo "$raw_response" | jq -r '.usage.input_tokens // 0' 2>/dev/null)
            output_tokens=$(echo "$raw_response" | jq -r '.usage.output_tokens // 0' 2>/dev/null)
            tokens_used=$((input_tokens + output_tokens))
            cost=$(_estimate_cost "$tokens_used" "$_CLAUDE_COST_PER_1K")
            ;;

        openai)
            # OpenAI Chat Completions response format
            content=$(echo "$raw_response" | jq -r '.choices[0].message.content // ""' 2>/dev/null)
            model=$(echo "$raw_response" | jq -r '.model // ""' 2>/dev/null)
            local prompt_tokens completion_tokens
            prompt_tokens=$(echo "$raw_response" | jq -r '.usage.prompt_tokens // 0' 2>/dev/null)
            completion_tokens=$(echo "$raw_response" | jq -r '.usage.completion_tokens // 0' 2>/dev/null)
            tokens_used=$((prompt_tokens + completion_tokens))
            cost=$(_estimate_cost "$tokens_used" "$_OPENAI_COST_PER_1K")
            ;;

        gemini)
            # Gemini Generative Language API response format
            content=$(echo "$raw_response" | jq -r '.candidates[0].content.parts[0].text // ""' 2>/dev/null)
            model="$_TRIBUNAL_GEMINI_MODEL"
            local prompt_token_count candidates_token_count
            prompt_token_count=$(echo "$raw_response" | jq -r '.usageMetadata.promptTokenCount // 0' 2>/dev/null)
            candidates_token_count=$(echo "$raw_response" | jq -r '.usageMetadata.candidatesTokenCount // 0' 2>/dev/null)
            tokens_used=$((prompt_token_count + candidates_token_count))
            cost=$(_estimate_cost "$tokens_used" "$_GEMINI_COST_PER_1K")
            ;;

        mistral)
            # Mistral OpenAI-compatible Chat Completions response format
            content=$(echo "$raw_response" | jq -r '.choices[0].message.content // ""' 2>/dev/null)
            model=$(echo "$raw_response" | jq -r '.model // ""' 2>/dev/null)
            local m_prompt_tokens m_completion_tokens
            m_prompt_tokens=$(echo "$raw_response" | jq -r '.usage.prompt_tokens // 0' 2>/dev/null)
            m_completion_tokens=$(echo "$raw_response" | jq -r '.usage.completion_tokens // 0' 2>/dev/null)
            tokens_used=$((m_prompt_tokens + m_completion_tokens))
            cost=$(_estimate_cost "$tokens_used" "$_MISTRAL_COST_PER_1K")
            ;;

        *)
            echo "ERROR: Unknown provider: $provider" >&2
            return 1
            ;;
    esac

    # Accumulate cost tracking
    _accumulate_cost "$tokens_used" "$cost"

    # Output normalized response
    jq -n \
        --arg role "assistant" \
        --arg content "$content" \
        --arg model "$model" \
        --argjson tokens_used "$tokens_used" \
        --arg cost "$cost" \
        --arg provider "$provider" \
        --arg timestamp "$(_iso8601_now)" \
        '{
            role: $role,
            content: $content,
            model: $model,
            tokens_used: $tokens_used,
            cost: ($cost | tonumber),
            provider: $provider,
            timestamp: $timestamp
        }'

    return 0
}

# ==============================================================================
# call_all_models_parallel — Query all available models in parallel
# ==============================================================================
# Usage: call_all_models_parallel <system_prompt> <user_message> [max_tokens]
#
# Sends the same prompt to all available tribunal models using bash background
# jobs (&) for parallel execution. Waits for all to complete, then collects
# and normalizes results.
#
# Graceful degradation:
#   - 3/3 succeed: full tribunal
#   - 2/3 succeed: degraded tribunal (continue)
#   - 1/3 or 0/3 succeed: halt with error
#
# Arguments:
#   system_prompt — System-level instruction text
#   user_message  — User message content
#   max_tokens    — Optional max tokens (default: $_MAX_TOKENS)
#
# Outputs: JSON object with results array and metadata:
#   { results: [...], available_count, succeeded_count, failed_providers, parallel: true }
# Returns: 0 if >= 2 models succeed, 1 otherwise
call_all_models_parallel() {
    local system_prompt="$1"
    local user_message="$2"
    local max_tokens="${3:-$_MAX_TOKENS}"

    local work_dir
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/tribunal-parallel-XXXXXX")

    local pids=()
    local providers=()

    # Launch Claude in background
    if [[ "$_CLAUDE_AVAILABLE" == "true" || -n "$_ANTHROPIC_API_KEY" ]]; then
        (
            local raw_resp
            raw_resp=$(call_claude_api "$system_prompt" "$user_message" "$max_tokens" 2>/dev/null) || {
                echo '{"error":"Claude API call failed","provider":"claude"}' > "$work_dir/claude.json"
                exit 1
            }
            normalize_response "claude" "$raw_resp" > "$work_dir/claude.json" 2>/dev/null
        ) &
        pids+=($!)
        providers+=("claude")
    fi

    # Launch OpenAI in background
    if [[ "$_OPENAI_AVAILABLE" == "true" || -n "$_OPENAI_API_KEY" ]]; then
        (
            local raw_resp
            raw_resp=$(call_openai_api "$system_prompt" "$user_message" "$max_tokens" 2>/dev/null) || {
                echo '{"error":"OpenAI API call failed","provider":"openai"}' > "$work_dir/openai.json"
                exit 1
            }
            normalize_response "openai" "$raw_resp" > "$work_dir/openai.json" 2>/dev/null
        ) &
        pids+=($!)
        providers+=("openai")
    fi

    # Launch Gemini in background
    if [[ "$_GEMINI_AVAILABLE" == "true" || -n "$_GEMINI_API_KEY" ]]; then
        (
            local raw_resp
            raw_resp=$(call_gemini_api "$system_prompt" "$user_message" "$max_tokens" 2>/dev/null) || {
                echo '{"error":"Gemini API call failed","provider":"gemini"}' > "$work_dir/gemini.json"
                exit 1
            }
            normalize_response "gemini" "$raw_resp" > "$work_dir/gemini.json" 2>/dev/null
        ) &
        pids+=($!)
        providers+=("gemini")
    fi

    # Wait for all background jobs
    local exit_codes=()
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null && exit_codes+=(0) || exit_codes+=($?)
    done

    # Collect results
    local results="[]"
    local succeeded=0
    local failed_providers="[]"

    for i in "${!providers[@]}"; do
        local provider="${providers[$i]}"
        local result_file="$work_dir/${provider}.json"

        if [[ -f "$result_file" ]]; then
            local result_content
            result_content=$(cat "$result_file")

            # Check if result is valid (has content field, not just error)
            local has_content
            has_content=$(echo "$result_content" | jq -r '.content // empty' 2>/dev/null)

            if [[ -n "$has_content" ]]; then
                results=$(echo "$results" | jq --argjson item "$result_content" '. + [$item]')
                succeeded=$((succeeded + 1))
            else
                failed_providers=$(echo "$failed_providers" | jq --arg p "$provider" '. + [$p]')
            fi
        else
            failed_providers=$(echo "$failed_providers" | jq --arg p "$provider" '. + [$p]')
        fi
    done

    # Clean up temp directory
    rm -rf "$work_dir"

    # Output results
    jq -n \
        --argjson results "$results" \
        --argjson available_count "${#providers[@]}" \
        --argjson succeeded_count "$succeeded" \
        --argjson failed_providers "$failed_providers" \
        --argjson parallel true \
        --arg timestamp "$(_iso8601_now)" \
        '{
            results: $results,
            available_count: $available_count,
            succeeded_count: $succeeded_count,
            failed_providers: $failed_providers,
            parallel: $parallel,
            timestamp: $timestamp
        }'

    # Mistral fallback: if exactly 1 primary failed and Mistral key is available,
    # fill the failed slot with Mistral Large
    local failed_count
    failed_count=$(echo "$failed_providers" | jq 'length')

    if [[ "$failed_count" -eq 1 && -n "$_MISTRAL_API_KEY" ]]; then
        local failed_provider
        failed_provider=$(echo "$failed_providers" | jq -r '.[0]')
        echo "FALLBACK: $failed_provider failed, attempting Mistral Large fill..." >&2

        local mistral_raw mistral_norm
        mistral_raw=$(call_mistral_api "$system_prompt" "$user_message" "$max_tokens" 2>/dev/null) || true

        if [[ -n "$mistral_raw" ]]; then
            mistral_norm=$(normalize_response "mistral" "$mistral_raw" 2>/dev/null) || true
            local mistral_content
            mistral_content=$(echo "$mistral_norm" | jq -r '.content // empty' 2>/dev/null)

            if [[ -n "$mistral_content" ]]; then
                results=$(echo "$results" | jq --argjson item "$mistral_norm" '. + [$item]')
                succeeded=$((succeeded + 1))
                failed_providers="[]"
                echo "FALLBACK: Mistral Large filled $failed_provider slot successfully" >&2
            else
                echo "HALT: Mistral fallback returned empty content — all backups exhausted" >&2
            fi
        else
            echo "HALT: Mistral fallback failed — all backups exhausted" >&2
        fi
    elif [[ "$failed_count" -ge 2 ]]; then
        echo "HALT: $failed_count primaries failed — backups exhausted, check API keys before retrying" >&2
    fi

    # Apply graceful degradation rules
    if [[ $succeeded -lt 2 ]]; then
        handle_provider_failure "$succeeded" "${#providers[@]}" "$failed_providers"
        return 1
    fi

    return 0
}

# ==============================================================================
# handle_provider_failure — Graceful degradation for provider failures
# ==============================================================================
# Usage: handle_provider_failure <succeeded_count> <total_count> <failed_providers_json>
#
# Implements the degradation policy:
#   - 2/3 succeed: log warning, continue with degraded tribunal
#   - 1/3 or fewer: halt execution, save checkpoint, report error
#
# Arguments:
#   succeeded_count      — Number of providers that returned valid responses
#   total_count          — Total number of providers attempted
#   failed_providers_json — JSON array of failed provider names
#
# Outputs: JSON degradation report
# Returns: 0 if degraded but operable (2/3), 1 if halted (1/3 or less)
handle_provider_failure() {
    local succeeded="$1"
    local total="$2"
    local failed_json="$3"

    local status="unknown"
    local action="unknown"
    local can_continue=false

    if [[ $succeeded -ge 2 ]]; then
        status="degraded"
        action="continue_with_reduced_tribunal"
        can_continue=true
    elif [[ $succeeded -eq 1 ]]; then
        status="critical"
        action="halt_save_checkpoint"
        can_continue=false
    else
        status="failed"
        action="halt_no_providers"
        can_continue=false
    fi

    jq -n \
        --arg status "$status" \
        --arg action "$action" \
        --argjson can_continue "$can_continue" \
        --argjson succeeded "$succeeded" \
        --argjson total "$total" \
        --argjson failed_providers "$failed_json" \
        --arg timestamp "$(_iso8601_now)" \
        '{
            status: $status,
            action: $action,
            can_continue: $can_continue,
            succeeded_count: $succeeded,
            total_count: $total,
            failed_providers: $failed_providers,
            timestamp: $timestamp
        }'

    if [[ "$can_continue" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# ==============================================================================
# get_cost_summary — Return accumulated cost and token usage for the session
# ==============================================================================
# Usage: get_cost_summary
#
# Outputs: JSON object with total tokens and cost
# Returns: 0
get_cost_summary() {
    jq -n \
        --arg total_tokens "$_TRIBUNAL_TOTAL_TOKENS" \
        --arg total_cost "$_TRIBUNAL_TOTAL_COST" \
        --arg timestamp "$(_iso8601_now)" \
        '{
            total_tokens: ($total_tokens | tonumber),
            total_cost: ($total_cost | tonumber),
            timestamp: $timestamp
        }'
    return 0
}

# ==============================================================================
# reset_cost_tracking — Reset the session cost accumulator
# ==============================================================================
# Usage: reset_cost_tracking
#
# Outputs: nothing
# Returns: 0
reset_cost_tracking() {
    _TRIBUNAL_TOTAL_COST="0"
    _TRIBUNAL_TOTAL_TOKENS="0"
    return 0
}
