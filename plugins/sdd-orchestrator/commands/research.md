---
name: research
description: Multi-LLM triplicate research with tribunal cross-validation. Uses Claude, OpenAI, and Gemini for independent research and voting.
model: opus
---

# /research Command — Multi-LLM Tribunal Research

Three independent LLMs research the same topic, then a multi-LLM tribunal votes on extracted claims to produce a confidence-scored final report.

**AGENT REQUIREMENT**: This command requires the swarm-coordinator agent for parallel agent spawning.

**If you are NOT the swarm-coordinator**, delegate immediately:
```
Use the Task tool to invoke swarm-coordinator:
- description: "Execute /research command with multi-LLM tribunal"
- prompt: "Execute the multi-LLM tribunal research flow for: $ARGUMENTS"
```

**API KEY REQUIREMENT**: This command requires `OPENAI_API_KEY` and `GEMINI_API_KEY` in `.env`.
If keys are missing, warn the user and reference `/initialize-project` for setup guidance.

---

## Phase 1: Multi-LLM Triplicate Research

### Step 1: Initialize Research Directory
```bash
RESEARCH_ID=$(date +%Y%m%d-%H%M%S)
TOPIC_SLUG=$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | cut -c1-40)
RESEARCH_DIR=".docs/research/${RESEARCH_ID}-${TOPIC_SLUG}"
mkdir -p "$RESEARCH_DIR"
```

### Step 2: Verify API Keys
```bash
# Check .env exists and has required keys
if [ ! -f .env ]; then
  echo "ERROR: .env file not found. Run /initialize-project for setup."
  exit 1
fi
# Subagents will source .env to get OPENAI_API_KEY and GEMINI_API_KEY
```

If either key is missing, report to user and stop. Do NOT proceed with partial LLM coverage.

### Step 3: Spawn 3 Multi-LLM Researchers (parallel)

All 3 researchers get the **SAME topic**. Each uses a different LLM to ensure truly independent perspectives from different model families.

**Researcher A — Claude Opus 4.6 via Perplexity**:
```
Use the Task tool:
- description: "R-Claude: Research via Perplexity"
- subagent_type: "general-purpose"
- model: "opus"
- prompt: |
    You are Researcher A (Claude). Research the following topic using the
    Perplexity MCP research tool for current, citation-backed information.

    TOPIC: $TOPIC

    INSTRUCTIONS:
    1. Use the perplexity_research MCP tool (mcp__MCP_DOCKER__perplexity_research)
       to conduct deep research on the topic. Pass a comprehensive research prompt
       as a user message.

    2. If the perplexity_research tool is not available, fall back to using
       perplexity_ask or perplexity_reason MCP tools.

    3. Supplement with WebSearch if needed for additional sources.

    4. Compile ALL findings into a comprehensive research report covering:
       - Key findings with supporting evidence and source URLs
       - Best practices and recommendations
       - Trade-offs, risks, and limitations
       - Practical implementation considerations
       - Areas of uncertainty (flag what you're less confident about)

    Save your complete findings to: $RESEARCH_DIR/researcher-a-claude.md

    IMPORTANT: Be thorough. Include all citation URLs from Perplexity responses.
    State what you found with the evidence you have.
```

**Researcher B — OpenAI GPT-4o**:
```
Use the Task tool:
- description: "R-OpenAI: Research via GPT-4o API"
- subagent_type: "general-purpose"
- model: "opus"
- prompt: |
    You are Researcher B (OpenAI proxy). Your job is to send the research topic
    to OpenAI's GPT-4o model via API and compile the response into a report.

    TOPIC: $TOPIC

    INSTRUCTIONS:
    1. Read the OPENAI_API_KEY from .env:
       source .env 2>/dev/null || export OPENAI_API_KEY=$(grep OPENAI_API_KEY .env | cut -d= -f2-)

    2. Call the OpenAI API with a comprehensive research prompt:

       curl -s https://api.openai.com/v1/chat/completions \
         -H "Authorization: Bearer $OPENAI_API_KEY" \
         -H "Content-Type: application/json" \
         -d '{
           "model": "gpt-4o",
           "messages": [
             {"role": "system", "content": "You are a research analyst. Provide comprehensive, evidence-based research with specific citations and URLs where possible."},
             {"role": "user", "content": "Research the following topic thoroughly. Cover: key findings with evidence, best practices, trade-offs and risks, implementation considerations, and areas of uncertainty. Topic: $TOPIC"}
           ],
           "max_tokens": 16000,
           "temperature": 0.7
         }'

    3. Parse the JSON response to extract the content:
       - Use jq or python to extract .choices[0].message.content
       - If the API call fails, log the error and report it

    4. Format the extracted content into a structured research report.

    5. Add a header noting this research was produced by OpenAI GPT-4o.

    Save the compiled report to: $RESEARCH_DIR/researcher-b-openai.md

    IMPORTANT: If the API call fails (bad key, rate limit, etc.), save an error
    report explaining what happened so the synthesizer knows this researcher failed.
```

**Researcher C — Google Gemini 2.5 Pro**:
```
Use the Task tool:
- description: "R-Gemini: Research via Gemini API"
- subagent_type: "general-purpose"
- model: "opus"
- prompt: |
    You are Researcher C (Gemini proxy). Your job is to send the research topic
    to Google's Gemini 2.5 Pro model via API and compile the response into a report.

    TOPIC: $TOPIC

    INSTRUCTIONS:
    1. Read the GEMINI_API_KEY from .env:
       source .env 2>/dev/null || export GEMINI_API_KEY=$(grep GEMINI_API_KEY .env | cut -d= -f2-)

    2. Call the Gemini API with a comprehensive research prompt:

       curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-preview-05-06:generateContent?key=$GEMINI_API_KEY" \
         -H "Content-Type: application/json" \
         -d '{
           "contents": [{
             "parts": [{
               "text": "You are a research analyst. Research the following topic thoroughly. Cover: key findings with evidence and citations, best practices, trade-offs and risks, implementation considerations, and areas of uncertainty. Provide specific URLs and references where possible.\n\nTopic: $TOPIC"
             }]
           }],
           "generationConfig": {
             "maxOutputTokens": 16000,
             "temperature": 0.7
           }
         }'

    3. Parse the JSON response to extract the content:
       - Use jq or python to extract .candidates[0].content.parts[0].text
       - If the API call fails, log the error and report it

    4. Format the extracted content into a structured research report.

    5. Add a header noting this research was produced by Google Gemini 2.5 Pro.

    Save the compiled report to: $RESEARCH_DIR/researcher-c-gemini.md

    IMPORTANT: If the API call fails (bad key, rate limit, etc.), save an error
    report explaining what happened so the synthesizer knows this researcher failed.
```

### Step 4: Wait for All 3 Researchers

Monitor Task tool completion for all 3 researchers. Report any API failures to user.

---

## Phase 2: Claim Extraction

### Step 5: Extract Claims from Triplicate Research

Reference the tribunal-review skill at `plugins/sdd-orchestrator/skills/tribunal-review/SKILL.md` for the full claim extraction protocol and JSON schema.

```
Use the Task tool:
- description: "Tribunal: Extract claims from multi-LLM research"
- subagent_type: "general-purpose"
- model: "haiku"
- prompt: |
    You are a Claim Extractor. Read all 3 research reports produced by different
    LLMs and extract discrete, testable claims into structured JSON.

    Read these 3 reports:
    - $RESEARCH_DIR/researcher-a-claude.md (refer to as "Report A — Claude")
    - $RESEARCH_DIR/researcher-b-openai.md (refer to as "Report B — OpenAI")
    - $RESEARCH_DIR/researcher-c-gemini.md (refer to as "Report C — Gemini")

    RULES:
    - Extract 20-40 claims total
    - Deduplicate: if multiple LLMs independently found the same claim, note which
    - Categorize each: factual | recommendation | trade-off | opinion
    - Track convergence: how many of the 3 LLMs independently found each claim
      (cross-model convergence is a STRONG confidence signal)
    - Include evidence summary from source report(s)
    - Note which LLM(s) produced each claim

    OUTPUT: Save as $RESEARCH_DIR/claims.json with this schema:
    {
      "research_topic": "<topic>",
      "extraction_date": "<YYYY-MM-DD>",
      "models_used": ["Claude Opus 4.6", "OpenAI GPT-4o", "Gemini 2.5 Pro"],
      "total_claims": <N>,
      "claims": [
        {
          "id": "C01",
          "claim": "Specific testable statement",
          "category": "factual",
          "found_by_models": ["Claude", "OpenAI", "Gemini"],
          "convergence": "3/3",
          "evidence_summary": "Brief summary of supporting evidence",
          "related_claims": ["C04"]
        }
      ]
    }
```

---

## Phase 3: Multi-LLM Tribunal Voting

### Step 6: Spawn 3 Multi-LLM Tribunal Reviewers (parallel)

Each reviewer uses a **different LLM** and has a different evaluation focus. No Perplexity — only Claude, OpenAI, and Gemini for voting.

**Tribunal Reviewer 1 — Claude Sonnet 4.5 (Accuracy Focus)**:
```
Use the Task tool:
- description: "Tribunal-Claude: Accuracy voting"
- subagent_type: "general-purpose"
- model: "sonnet"
- prompt: |
    You are Tribunal Reviewer 1 (Claude) with focus on ACCURACY.

    Read the claims file: $RESEARCH_DIR/claims.json
    Read the research reports for evidence checking:
    - $RESEARCH_DIR/researcher-a-claude.md
    - $RESEARCH_DIR/researcher-b-openai.md
    - $RESEARCH_DIR/researcher-c-gemini.md

    For EACH claim, evaluate ACCURACY:
    - Is the claim factually correct based on the evidence provided?
    - Are there any factual errors or unsupported assertions?
    - Does the evidence actually support the claim as stated?

    Vote "approve" if accurate, "challenge" if not.
    Express genuine confidence: 0.50 = guessing, 0.90 = strong evidence.

    Save your votes as JSON to: $RESEARCH_DIR/tribunal-votes-1-claude.json
    Schema:
    {
      "reviewer_id": "tribunal-1-claude",
      "model": "Claude Sonnet 4.5",
      "review_focus": "accuracy",
      "review_date": "<YYYY-MM-DD>",
      "votes": [
        {
          "claim_id": "C01",
          "vote": "approve",
          "confidence": 0.85,
          "reasoning": "1-2 sentences",
          "suggested_improvement": null
        }
      ]
    }
```

**Tribunal Reviewer 2 — OpenAI GPT-4o (Sourcing Focus)**:
```
Use the Task tool:
- description: "Tribunal-OpenAI: Sourcing voting"
- subagent_type: "general-purpose"
- model: "sonnet"
- prompt: |
    You are the proxy for Tribunal Reviewer 2 (OpenAI) with focus on SOURCING.

    INSTRUCTIONS:
    1. Read: $RESEARCH_DIR/claims.json
    2. Read all 3 research reports for context
    3. Format the claims into a voting prompt for OpenAI

    4. Read the API key: source .env 2>/dev/null || export OPENAI_API_KEY=$(grep OPENAI_API_KEY .env | cut -d= -f2-)

    5. Call OpenAI API to vote on claims:

       Build a prompt that includes ALL claims from claims.json and asks GPT-4o to:
       - Evaluate SOURCING for each claim:
         - Are the cited sources credible and authoritative?
         - Is the evidence sufficient to support the claim?
         - Are sources current and not outdated?
       - For each claim, provide: vote (approve/challenge), confidence (0.50-0.99),
         reasoning (1-2 sentences), suggested_improvement (optional)
       - Output as JSON matching the tribunal vote schema

       curl -s https://api.openai.com/v1/chat/completions \
         -H "Authorization: Bearer $OPENAI_API_KEY" \
         -H "Content-Type: application/json" \
         -d '{
           "model": "gpt-4o",
           "messages": [
             {"role": "system", "content": "You are a tribunal reviewer evaluating research claims for source quality. Vote approve or challenge on each claim with a confidence score."},
             {"role": "user", "content": "<formatted claims and context>"}
           ],
           "max_tokens": 8000,
           "temperature": 0.3,
           "response_format": {"type": "json_object"}
         }'

    6. Parse the response and save as: $RESEARCH_DIR/tribunal-votes-2-openai.json
       Ensure it matches the schema:
       {
         "reviewer_id": "tribunal-2-openai",
         "model": "OpenAI GPT-4o",
         "review_focus": "sourcing",
         "review_date": "<YYYY-MM-DD>",
         "votes": [...]
       }

    IMPORTANT: If API call fails, save error report so aggregation knows this reviewer failed.
```

**Tribunal Reviewer 3 — Gemini 2.5 Pro (Relevance Focus)**:
```
Use the Task tool:
- description: "Tribunal-Gemini: Relevance voting"
- subagent_type: "general-purpose"
- model: "sonnet"
- prompt: |
    You are the proxy for Tribunal Reviewer 3 (Gemini) with focus on RELEVANCE.

    INSTRUCTIONS:
    1. Read: $RESEARCH_DIR/claims.json
    2. Read all 3 research reports for context
    3. Format the claims into a voting prompt for Gemini

    4. Read the API key: source .env 2>/dev/null || export GEMINI_API_KEY=$(grep GEMINI_API_KEY .env | cut -d= -f2-)

    5. Call Gemini API to vote on claims:

       Build a prompt that includes ALL claims from claims.json and asks Gemini to:
       - Evaluate RELEVANCE for each claim:
         - Is this claim directly relevant to the research question?
         - Is the claim actionable and useful for decision-making?
         - Does it answer what was actually asked?
       - For each claim, provide: vote (approve/challenge), confidence (0.50-0.99),
         reasoning (1-2 sentences), suggested_improvement (optional)
       - Output as JSON matching the tribunal vote schema

       curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-preview-05-06:generateContent?key=$GEMINI_API_KEY" \
         -H "Content-Type: application/json" \
         -d '{
           "contents": [{
             "parts": [{
               "text": "You are a tribunal reviewer evaluating research claims for relevance. For each claim, vote approve or challenge with confidence (0.50-0.99) and reasoning. Output as JSON.\n\n<formatted claims and context>"
             }]
           }],
           "generationConfig": {
             "maxOutputTokens": 8000,
             "temperature": 0.3,
             "responseMimeType": "application/json"
           }
         }'

    6. Parse the response and save as: $RESEARCH_DIR/tribunal-votes-3-gemini.json
       Ensure it matches the schema:
       {
         "reviewer_id": "tribunal-3-gemini",
         "model": "Gemini 2.5 Pro",
         "review_focus": "relevance",
         "review_date": "<YYYY-MM-DD>",
         "votes": [...]
       }

    IMPORTANT: If API call fails, save error report so aggregation knows this reviewer failed.
```

### Step 7: Wait for All 3 Tribunal Reviewers

Monitor Task tool completion. Report any API failures.

---

## Phase 4: Vote Aggregation + Quality Gate

### Step 8: Aggregate Votes

Read all vote files and compute confidence scores.

```
Read: $RESEARCH_DIR/claims.json
Read: $RESEARCH_DIR/tribunal-votes-1-claude.json
Read: $RESEARCH_DIR/tribunal-votes-2-openai.json
Read: $RESEARCH_DIR/tribunal-votes-3-gemini.json

For each claim:
  1. Count approve votes across all 3 LLMs (0-3)
  2. Compute vote_confidence = approves / 3
  3. Get convergence_score from claims.json:
     - 3/3 models found it = 0.90
     - 2/3 models found it = 0.65
     - 1/3 models found it = 0.35
  4. combined_confidence = (0.3 * convergence_score) + (0.7 * vote_confidence)
  5. Classify:
     - >= 0.80: Confirmed
     - 0.55 - 0.79: Likely
     - 0.30 - 0.54: Conflicting
     - < 0.30: Refuted

Save confidence table to: $RESEARCH_DIR/confidence-table.md

Include a cross-model agreement summary:
- Which claims did ALL 3 LLMs (Claude+OpenAI+Gemini) independently find AND approve?
- Which claims showed model-specific bias (found/approved by only 1 LLM)?
```

### Step 9: Quality Gate

```
IF all claims are Confirmed or Likely:
    → SKIP re-research, proceed to Phase 5 (synthesis)

IF any claims are Conflicting or Refuted:
    → Proceed to Step 10 (targeted re-research)
```

### Step 10: Targeted Re-Research (Conditional)

```
Use the Task tool:
- description: "Tribunal: Re-research low-confidence claims"
- subagent_type: "general-purpose"
- model: "opus"
- prompt: |
    You are a Targeted Re-Researcher. Some claims did not pass multi-LLM
    tribunal review. Find additional evidence using Perplexity research.

    Read: $RESEARCH_DIR/confidence-table.md
    Read: $RESEARCH_DIR/claims.json
    Read all tribunal vote files for reviewer critiques.

    FOCUS ONLY on claims with status "Conflicting" or "Refuted".
    Use perplexity_research MCP tool for each low-confidence claim.
    Address specific reviewer critiques from all 3 LLMs.

    Save findings to: $RESEARCH_DIR/supplementary-research.md

HARD LIMITS: Maximum 1 re-research pass. Circuit breaker if no improvement.
```

---

## Phase 5: Synthesis

### Step 11: Final Synthesis

```
Use the Task tool:
- description: "Tribunal: Multi-LLM confidence-scored synthesis"
- subagent_type: "general-purpose"
- model: "opus"
- prompt: |
    You are the Research Synthesizer. Produce a final report incorporating
    multi-LLM research and tribunal cross-validation results.

    Read ALL inputs:
    - $RESEARCH_DIR/researcher-a-claude.md
    - $RESEARCH_DIR/researcher-b-openai.md
    - $RESEARCH_DIR/researcher-c-gemini.md
    - $RESEARCH_DIR/claims.json
    - $RESEARCH_DIR/confidence-table.md
    - $RESEARCH_DIR/tribunal-votes-1-claude.json
    - $RESEARCH_DIR/tribunal-votes-2-openai.json
    - $RESEARCH_DIR/tribunal-votes-3-gemini.json
    - $RESEARCH_DIR/supplementary-research.md (if it exists)

    Produce: $RESEARCH_DIR/final-report.md

    Report structure:

    1. Executive Summary
       - Topic and research scope
       - Models used: Claude Opus 4.6, OpenAI GPT-4o, Gemini 2.5 Pro
       - Claims extracted, voted on, confidence distribution

    2. Cross-Model Agreement Analysis
       - Findings all 3 LLMs independently discovered (highest confidence)
       - Findings with partial agreement (2/3 LLMs)
       - Model-specific findings (only 1 LLM found this)
       - Model-specific biases or blind spots observed

    3. Confidence-Scored Findings Table
       - Full table with convergence, tribunal votes, confidence, status
       - Organized by confidence level (Confirmed first)

    4. High-Confidence Recommendations
       - Only claims with >= 2/3 model convergence AND >= 2/3 tribunal approval
       - These are findings you can act on with confidence

    5. Contested Findings
       - Claims where LLMs or tribunal reviewers disagreed
       - Preserve all perspectives with model attribution

    6. Dissenting Opinions
       - Model-specific minority viewpoints
       - Reasoning preserved for context

    7. Methodology
       - Multi-LLM triplicate research (Claude+Perplexity, OpenAI, Gemini)
       - Claim extraction and anonymization
       - Multi-LLM tribunal voting (Claude, OpenAI, Gemini)
       - Confidence aggregation formula
       - Re-research summary (if triggered)

    8. Source References
       - 10+ source URLs with descriptions
       - Cross-referenced across all 3 LLMs

    9. Actionable Next Steps
       - Prioritized by confidence level
       - Only recommend actions backed by high-confidence findings
```

### Step 12: Report to User
```
Report:
- Research directory path
- Models used: Claude Opus 4.6, OpenAI GPT-4o, Gemini 2.5 Pro
- Total claims extracted and voted on
- Confidence distribution:
  - X Confirmed (>= 0.80)
  - Y Likely (0.55-0.79)
  - Z Conflicting (0.30-0.54)
  - W Refuted (< 0.30)
- Cross-model agreement highlights
- Re-research summary (if triggered)
- Top 5 recommendations with confidence scores
- List of all output files
```

---

## Budget Allocation

| Phase | Model(s) | Budget % |
|-------|----------|----------|
| 3 Multi-LLM Researchers | Claude+Perplexity, OpenAI, Gemini | 35% |
| Claim Extraction | Claude Haiku | 5% |
| 3 Multi-LLM Tribunal Reviewers | Claude Sonnet, OpenAI, Gemini | 15% |
| Targeted Re-Research (conditional) | Claude Opus + Perplexity | 10% |
| Final Synthesizer | Claude Opus | 25% |
| Buffer/overhead | — | 10% |

## API Requirements

This command requires the following API keys in `.env`:

| Key | Provider | Used In |
|-----|----------|---------|
| `OPENAI_API_KEY` | OpenAI | Researcher B, Tribunal Reviewer 2 |
| `GEMINI_API_KEY` | Google | Researcher C, Tribunal Reviewer 3 |
| Perplexity | Docker MCP (pre-configured) | Researcher A, Re-Research |

Run `/initialize-project` to configure API keys for a new project.

## Usage

```
/research "Evaluate GraphQL vs REST for our API layer"
/research "Compare authentication strategies for SaaS applications"
/research "Best practices for real-time data synchronization"
```

## Output Files

```
.docs/research/YYYYMMDD-HHMMSS-topic/
  researcher-a-claude.md       # Claude + Perplexity research
  researcher-b-openai.md       # OpenAI GPT-4o research
  researcher-c-gemini.md       # Gemini 2.5 Pro research
  claims.json                  # Extracted claims with convergence
  tribunal-votes-1-claude.json # Claude accuracy votes
  tribunal-votes-2-openai.json # OpenAI sourcing votes
  tribunal-votes-3-gemini.json # Gemini relevance votes
  confidence-table.md          # Aggregated confidence scores
  supplementary-research.md    # Re-research (if triggered)
  final-report.md              # Confidence-scored final report
```
