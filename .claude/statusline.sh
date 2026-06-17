#!/bin/bash

# Modernized Status Line Script for Claude Code
# Supports stdin JSON (primary) + session file fallback
# Handles all git states, expanded model/tool detection
#
# Optional upgrade for Pro/Max subscribers:
#   npm install -g ccstatusline
#   Then update .claude/settings.json statusLine to use ccstatusline for
#   subscription usage tracking (session %, weekly %, block reset timer).
#   See: https://github.com/sirmalloc/ccstatusline

set -euo pipefail

# Color and styling constants
readonly RESET='\033[0m'
readonly DIM='\033[2m'
readonly BOLD='\033[1m'

# Foreground colors
readonly WHITE='\033[37m'

# Background colors for widgets
readonly BG_DARK_BLUE='\033[48;5;25m'
readonly BG_PURPLE='\033[48;5;54m'
readonly BG_DARK_CYAN='\033[48;5;31m'
readonly BG_DARK_MAGENTA='\033[48;5;89m'
readonly BG_DARK_RED='\033[48;5;52m'
readonly BG_GREEN='\033[48;5;22m'

# Check for jq dependency
if ! command -v jq >/dev/null 2>&1; then
    echo -e "${BG_DARK_RED}${BOLD}${WHITE} Warning: jq not installed - statusline features limited ${RESET}"
fi

# Initialize variables
context_used="0"
context_total="200000"
last_action="Ready"
model_name="Claude"
output_style=""
app_version=""
session_id=""
stdin_data=""

# Try to read JSON from stdin (with timeout to prevent blocking)
if read -t 0.1 -r stdin_line 2>/dev/null; then
    stdin_data="$stdin_line"
    # Read any additional lines
    while read -t 0.1 -r line 2>/dev/null; do
        stdin_data="$line"
    done
fi

# Function to extract data from JSON
extract_from_json() {
    local json="$1"

    if [ -z "$json" ] || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    # Extract display_name or model
    local display_name
    display_name=$(echo "$json" | jq -r '.display_name // empty' 2>/dev/null)
    if [ -n "$display_name" ]; then
        model_name="$display_name"
    else
        local model_raw
        model_raw=$(echo "$json" | jq -r '.model // .message.model // empty' 2>/dev/null)
        if [ -n "$model_raw" ]; then
            parse_model_name "$model_raw"
        fi
    fi

    # Extract context/usage — total input tokens (including cache)
    local input_tokens cache_read total_ctx
    input_tokens=$(echo "$json" | jq -r '.message.usage.input_tokens // .usage.input_tokens // 0' 2>/dev/null || echo "0")
    cache_read=$(echo "$json" | jq -r '.message.usage.cache_read_input_tokens // .usage.cache_read_input_tokens // 0' 2>/dev/null || echo "0")
    total_ctx=$((input_tokens + cache_read))
    if [ "$total_ctx" -gt 0 ] 2>/dev/null; then
        context_used=$(awk "BEGIN { printf \"%.1f\", $total_ctx / 1000 }" 2>/dev/null || echo "0")
    fi

    # Extract output style
    local style
    style=$(echo "$json" | jq -r '.output_style // empty' 2>/dev/null)
    if [ -n "$style" ] && [ "$style" != "default" ] && [ "$style" != "null" ]; then
        output_style="$style"
    fi

    # Extract app version
    local version
    version=$(echo "$json" | jq -r '.app_version // .version // empty' 2>/dev/null)
    if [ -n "$version" ] && [ "$version" != "null" ]; then
        app_version="$version"
    fi

    # Extract session ID (truncated)
    local sid
    sid=$(echo "$json" | jq -r '.session_id // empty' 2>/dev/null)
    if [ -n "$sid" ] && [ "$sid" != "null" ]; then
        session_id="${sid:0:8}"
    fi

    # Extract tool/action
    local msg_type tool_name
    msg_type=$(echo "$json" | jq -r '.type // empty' 2>/dev/null)
    tool_name=$(echo "$json" | jq -r '.message.content[0].name // .tool_name // empty' 2>/dev/null)

    if [ "$msg_type" = "assistant" ] || [ -n "$tool_name" ]; then
        if [ -n "$tool_name" ] && [ "$tool_name" != "null" ]; then
            parse_tool_action "$tool_name"
        else
            last_action="Responding"
        fi
    elif [ "$msg_type" = "user" ]; then
        last_action="Processing"
    fi

    return 0
}

# Parse model name from raw model string
parse_model_name() {
    local model_raw="$1"

    case "$model_raw" in
        *opus-4-8*|*opus-4.8*) model_name="Opus 4.8" ;;
        *opus-4-6*|*opus-4.6*) model_name="Opus 4.6" ;;
        *opus-4-5*|*opus-4.5*) model_name="Opus 4.5" ;;
        *opus-4-1*|*opus-4.1*) model_name="Opus 4.1" ;;
        *opus-4*|*opus4*) model_name="Opus 4" ;;
        *opus*) model_name="Opus" ;;
        *sonnet-4-6*|*sonnet-4.6*) model_name="Sonnet 4.6" ;;
        *sonnet-4-5*|*sonnet-4.5*) model_name="Sonnet 4.5" ;;
        *sonnet-4*|*sonnet4*) model_name="Sonnet 4" ;;
        *sonnet-3-7*|*sonnet-3.7*) model_name="Sonnet 3.7" ;;
        *sonnet-3-5*|*sonnet-3.5*) model_name="Sonnet 3.5" ;;
        *sonnet*) model_name="Sonnet" ;;
        *haiku-4-5*|*haiku-4.5*) model_name="Haiku 4.5" ;;
        *haiku-3-5*|*haiku-3.5*) model_name="Haiku 3.5" ;;
        *haiku*) model_name="Haiku" ;;
        *) model_name="Claude" ;;
    esac
}

# Parse tool name to action
parse_tool_action() {
    local tool_name="$1"

    case "$tool_name" in
        "Bash") last_action="Running bash" ;;
        "Read") last_action="Reading file" ;;
        "Edit") last_action="Editing file" ;;
        "Write") last_action="Writing file" ;;
        "MultiEdit") last_action="Multi-editing" ;;
        "Grep") last_action="Searching code" ;;
        "Glob") last_action="Finding files" ;;
        "Task") last_action="Running agent" ;;
        "WebFetch") last_action="Fetching URL" ;;
        "WebSearch") last_action="Web search" ;;
        "AskUserQuestion") last_action="Asking user" ;;
        "NotebookEdit") last_action="Editing notebook" ;;
        "Skill") last_action="Running skill" ;;
        "ToolSearch") last_action="Finding tools" ;;
        "EnterPlanMode") last_action="Planning" ;;
        "ExitPlanMode") last_action="Plan ready" ;;
        "TaskCreate") last_action="Creating task" ;;
        "TaskUpdate") last_action="Updating task" ;;
        "TaskGet") last_action="Reading task" ;;
        "TaskList") last_action="Listing tasks" ;;
        "TaskOutput") last_action="Reading output" ;;
        "TaskStop") last_action="Stopping task" ;;
        mcp__*)
            # MCP tool - extract server name
            local mcp_name="${tool_name#mcp__}"
            mcp_name="${mcp_name%%__*}"
            if [ ${#mcp_name} -gt 10 ]; then
                mcp_name="${mcp_name:0:10}"
            fi
            last_action="MCP: $mcp_name"
            ;;
        *)
            if [ ${#tool_name} -gt 12 ]; then
                last_action="${tool_name:0:12}..."
            else
                last_action="$tool_name"
            fi
            ;;
    esac
}

# Find session file using multiple paths and find command
find_session_file() {
    local session_file=""
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

    # Claude Code uses absolute path with / replaced by - for project directory name
    local project_dir_name
    project_dir_name=$(echo "$repo_root" | sed 's|/|-|g')
    local project_basename
    project_basename=$(basename "$repo_root")

    # Session path patterns to search (in order of preference)
    local -a search_paths=(
        "$HOME/.claude/projects/${project_dir_name}"
        "$HOME/.claude/projects/-workspaces-${project_basename}"
        "$HOME/.claude/projects/${project_basename}"
        "$HOME/.claude/projects"
        "/home/codespace/.claude/projects/${project_dir_name}"
        "/home/codespace/.claude/projects"
    )

    for search_path in "${search_paths[@]}"; do
        if [ -d "$search_path" ]; then
            # Use stat for macOS compatibility (GNU find -printf not available on Darwin)
            if [[ "$(uname)" == "Darwin" ]]; then
                session_file=$(find "$search_path" -maxdepth 2 -name "*.jsonl" -type f 2>/dev/null | xargs stat -f '%m %N' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
            else
                session_file=$(find "$search_path" -maxdepth 2 -name "*.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
            fi
            if [ -n "$session_file" ] && [ -f "$session_file" ]; then
                echo "$session_file"
                return 0
            fi
        fi
    done

    return 1
}

# Try stdin first, then fall back to session file
if [ -n "$stdin_data" ]; then
    extract_from_json "$stdin_data"
else
    # Fall back to session file
    session_file=$(find_session_file || echo "")

    if [ -n "$session_file" ] && [ -f "$session_file" ] && command -v jq >/dev/null 2>&1; then
        # More efficient: tail | reverse | grep -m1 for first match from end
        # Use tail -r on macOS (no tac available)
        if command -v tac >/dev/null 2>&1; then
            last_entry=$(tail -20 "$session_file" 2>/dev/null | tac | grep -m1 '"usage":' || echo "")
        else
            last_entry=$(tail -20 "$session_file" 2>/dev/null | tail -r | grep -m1 '"usage":' || echo "")
        fi

        if [ -n "$last_entry" ]; then
            extract_from_json "$last_entry"
        fi
    fi
fi

# Get system info
user=$(whoami 2>/dev/null || echo "user")
hostname=$(hostname -s 2>/dev/null || echo "host")
current_dir=$(pwd)

# Calculate relative path
rel_path="/"
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
if [[ "$current_dir" == "$repo_root"* ]]; then
    rel_path="${current_dir#$repo_root}"
    if [ -z "$rel_path" ]; then
        rel_path="/"
    fi
fi

# Truncate long paths
if [ ${#rel_path} -gt 25 ]; then
    rel_path="...${rel_path: -22}"
fi

# Get git information (handles all states including detached HEAD)
git_branch=""
git_dirty=""
if git rev-parse --git-dir >/dev/null 2>&1; then
    # Try multiple methods for branch/ref detection
    git_branch=$(git symbolic-ref --short HEAD 2>/dev/null) ||
    git_branch=$(git describe --tags --exact-match 2>/dev/null) ||
    git_branch=$(git rev-parse --short HEAD 2>/dev/null) ||
    git_branch="detached"

    # Check for uncommitted changes
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        git_dirty="*"
    fi
fi

# Get environment versions
node_version=""
python_version=""
if command -v node >/dev/null 2>&1; then
    node_version=$(node --version 2>/dev/null | sed 's/v//')
fi
if command -v python3 >/dev/null 2>&1; then
    python_version=$(python3 --version 2>/dev/null | cut -d' ' -f2 | cut -d'.' -f1-2)
fi

# Calculate context percentage
context_percentage="0"
if [ -n "$context_used" ] && [ "$context_used" != "0" ]; then
    context_total_k=200
    context_percentage=$(awk "BEGIN { printf \"%.1f\", ($context_used * 100) / $context_total_k }" 2>/dev/null || echo "0")
fi

# Build the status line

# Line 1: User, path, git, model
line1=""
line1="${line1}${BG_DARK_BLUE}${BOLD}${WHITE} ${user}@${hostname} ${RESET}"
line1="${line1} ${DIM}|${RESET} ${BG_DARK_CYAN}${BOLD}${WHITE} ${rel_path} ${RESET}"

if [ -n "$git_branch" ]; then
    git_display="$git_branch"
    if [ ${#git_display} -gt 12 ]; then
        git_display="${git_display:0:12}"
    fi
    line1="${line1} ${DIM}|${RESET} ${BG_PURPLE}${BOLD}${WHITE} ${git_display}${git_dirty} ${RESET}"
fi

line1="${line1} ${DIM}|${RESET} ${BG_DARK_MAGENTA}${BOLD}${WHITE} ${model_name} ${RESET}"

# Add output style if not default
if [ -n "$output_style" ]; then
    line1="${line1} ${DIM}|${RESET} ${BG_GREEN}${BOLD}${WHITE} ${output_style} ${RESET}"
fi

printf "%b\n" "$line1"

# Line 2: Environment, context, status, version
line2=""
first_item=true

if [ -n "$node_version" ]; then
    line2="${line2}${BG_DARK_MAGENTA}${BOLD}${WHITE} node ${node_version} ${RESET}"
    first_item=false
fi

if [ -n "$python_version" ]; then
    if [ "$first_item" = false ]; then
        line2="${line2} ${DIM}|${RESET} "
    fi
    line2="${line2}${BG_DARK_BLUE}${BOLD}${WHITE} py ${python_version} ${RESET}"
    first_item=false
fi

# Context widget
if [ "$first_item" = false ]; then
    line2="${line2} ${DIM}|${RESET} "
fi
line2="${line2}${BG_PURPLE}${BOLD}${WHITE} ctx ${context_used}k/200k (${context_percentage}%) ${RESET}"

# Status widget
line2="${line2} ${DIM}|${RESET} ${BG_DARK_RED}${BOLD}${WHITE} ${last_action} ${RESET}"

# App version (if available)
if [ -n "$app_version" ]; then
    line2="${line2} ${DIM}|${RESET} ${BG_DARK_CYAN}${BOLD}${WHITE} v${app_version} ${RESET}"
fi

printf "%b" "$line2"
