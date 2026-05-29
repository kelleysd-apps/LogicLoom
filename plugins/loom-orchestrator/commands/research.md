---
name: research
description: Multi-LLM research with jury-on-demand tribunal. Query-type classifier picks 1-3 judges (Claude always present; OpenAI / Gemini added selectively). Use --judges all for the legacy 3-LLM panel.
model: opus
---

# /research Command — Jury-On-Demand Multi-LLM Research

A query-type classifier picks **1-3 judges** for tribunal voting based on the kind of question being asked. Claude is always present; OpenAI and Gemini are added only where their independent perspective improves the answer.

**AGENT REQUIREMENT**: This command requires the swarm-coordinator agent for parallel agent spawning.

**If you are NOT the swarm-coordinator**, delegate immediately:
```
Use the Task tool to invoke swarm-coordinator:
- description: "Execute /research command with jury-on-demand tribunal"
- prompt: "Execute the multi-LLM research flow for: $ARGUMENTS"
```

**API KEY REQUIREMENT**: `OPENAI_API_KEY` and `GEMINI_API_KEY` in `.env` are required only when those judges are selected. With `--judges all`, both are mandatory.

---

## Design Rationale (Stage 9 — jury-on-demand)

The previous version of `/research` ran a static 3-LLM tribunal (Claude + OpenAI + Gemini) on every query, regardless of whether the extra perspectives added value. This burned tokens on questions where Claude alone is already strongest (e.g. coding) and on factual lookups where a single judge suffices.

**Jury-on-demand** classifies the query first, then picks the judge panel:

- Cheap queries -> 1 judge (Claude)
- Most queries -> 2 judges (Claude + one peer)
- Taste/strategy queries -> 3 judges (full panel)

**Aggregation is simple majority** — no weighted aggregation, no predicted-agreement weights, no learned models. If the panel is 2 judges, a 1-1 split is escalated to "Conflicting"; if 3 judges, 2-1 wins.

**`--judges all`** forces the full 3-judge panel for backward compatibility with any caller that depends on the legacy behavior.

---

## Phase 0: Query Classification + Judge Selection

### Step 0a: Parse Flags

Extract `--judges` from `$ARGUMENTS`:

```
--judges all           -> force full 3-judge panel (Claude + OpenAI + Gemini)
--judges <none>        -> run classifier (default)
```

The topic is `$ARGUMENTS` with the `--judges <value>` flag stripped out.

### Step 0b: Classify the Query (Heuristic, Not Learned)

Inspect the topic and assign it to **one** category. Match keywords case-insensitively; use the first category that matches. If nothing matches, fall back to `other`.

| Category | Trigger keywords (representative) | Judges | Rationale |
|---|---|---|---|
| **factual** | "what is", "definition of", "history of", "when did", "who is" | Claude (1) | Single authoritative judge is sufficient |
| **architectural** | "architecture", "system design", "scalability", "microservices", "distributed", "database design" | Claude + OpenAI (2) | Different reasoning styles surface different trade-offs |
| **design** | "UX", "UI", "user experience", "aesthetics", "design system", "visual" | Claude + OpenAI + Gemini (3) | Taste varies — three judges reduce single-model bias |
| **security** | "security", "vulnerability", "auth", "authentication", "encryption", "XSS", "CSRF", "threat model" | Claude + OpenAI (2) | Both have safety RLHF; independent review is valuable |
| **performance** | "performance", "optimization", "latency", "throughput", "benchmark", "profiling" | Claude + OpenAI (2) | Two judges catch model-specific blind spots |
| **coding** | "implement", "code", "function", "refactor", "language", "framework", "library", "syntax" | Claude (1) | Opus 4.8 is strongest at code; extra judges add noise |
| **strategy** | "strategy", "business", "market", "pricing", "go-to-market", "roadmap", "competitive" | Claude + OpenAI + Gemini (3) | Divergent views are the point — keep all three |
| **other** | (fallback when no category matches) | Claude + OpenAI (2) | Safe default |

Record the result as:
```
QUERY_CATEGORY=<category>
JUDGES=<comma-separated list of: claude,openai,gemini>
```

If `--judges all` was passed, override to:
```
QUERY_CATEGORY=forced-all
JUDGES=claude,openai,gemini
```

### Step 0c: Verify Selected API Keys

```bash
if [ -z "$JUDGES" ]; then echo "ERROR: empty judge panel"; exit 1; fi

# Only enforce keys for judges that were actually selected
case ",$JUDGES," in
  *,openai,*)
    [ -f .env ] && grep -q OPENAI_API_KEY .env || {
      echo "ERROR: OPENAI_API_KEY required (openai is in judge panel)"; exit 1; }
    ;;
esac
case ",$JUDGES," in
  *,gemini,*)
    [ -f .env ] && grep -q GEMINI_API_KEY .env || {
      echo "ERROR: GEMINI_API_KEY required (gemini is in judge panel)"; exit 1; }
    ;;
esac
```

If a required key is missing for a selected judge, stop and tell the user. Reference `/initialize-project` for setup.

### Step 0d: Initialize Research Directory

```bash
RESEARCH_ID=$(date +%Y%m%d-%H%M%S)
TOPIC_SLUG=$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | cut -c1-40)
RESEARCH_DIR=".docs/research/${RESEARCH_ID}-${TOPIC_SLUG}"
mkdir -p "$RESEARCH_DIR"

# Persist the classification decision for reproducibility
cat > "$RESEARCH_DIR/jury.json" <<EOF
{
  "topic": "$TOPIC",
  "category": "$QUERY_CATEGORY",
  "judges": "$JUDGES",
  "forced": $([ "$QUERY_CATEGORY" = "forced-all" ] && echo true || echo false)
}
EOF
```

---

## Phase 1: Multi-LLM Triplicate Research

**The research phase always runs with all available LLMs that have keys present**, because researcher diversity (different training data, different RLHF) is the cheapest way to surface non-overlapping evidence. The classifier governs **voting**, not research.

If a researcher's API key is missing, skip that researcher and note the gap in `jury.json`. Claude (via Perplexity / WebSearch) is always available.

### Researcher A — Claude Opus via Perplexity (always runs)
```
Use the Task tool:
- description: "R-Claude: Research via Perplexity"
- subagent_type: "general-purpose"
- model: "opus"
- prompt: |
    You are Researcher A (Claude). Use perplexity_research (mcp__MCP_DOCKER__perplexity_research)
    for current, citation-backed research on the topic. Fall back to perplexity_ask /
    perplexity_reason / WebSearch if needed.

    TOPIC: $TOPIC

    Compile findings: key findings + evidence + source URLs, best practices, trade-offs,
    implementation notes, areas of uncertainty.

    Save to: $RESEARCH_DIR/researcher-a-claude.md
```

### Researcher B — OpenAI GPT-4o (runs if OPENAI_API_KEY present)
```
Use the Task tool:
- description: "R-OpenAI: Research via GPT-4o API"
- subagent_type: "general-purpose"
- model: "opus"
- prompt: |
    You are Researcher B (OpenAI proxy). Send the topic to GPT-4o via the API
    and compile the response into a structured research report.

    TOPIC: $TOPIC

    1. Source OPENAI_API_KEY from .env.
    2. POST to https://api.openai.com/v1/chat/completions with model gpt-4o,
       max_tokens 16000, temperature 0.7. System: research analyst with
       evidence-based output and citations. User: thorough research on the topic.
    3. Extract .choices[0].message.content. On error, save an error report.
    4. Save formatted report to: $RESEARCH_DIR/researcher-b-openai.md
```

### Researcher C — Google Gemini 2.5 Pro (runs if GEMINI_API_KEY present)
```
Use the Task tool:
- description: "R-Gemini: Research via Gemini API"
- subagent_type: "general-purpose"
- model: "opus"
- prompt: |
    You are Researcher C (Gemini proxy). Send the topic to Gemini 2.5 Pro via the
    API and compile the response into a structured research report.

    TOPIC: $TOPIC

    1. Source GEMINI_API_KEY from .env.
    2. POST to https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-preview-05-06:generateContent
       with maxOutputTokens 16000, temperature 0.7.
    3. Extract .candidates[0].content.parts[0].text. On error, save an error report.
    4. Save formatted report to: $RESEARCH_DIR/researcher-c-gemini.md
```

Wait for all spawned researchers to complete. Note any failures in the final report.

---

## Phase 2: Claim Extraction

### Step 5: Extract Claims from Research Reports

```
Use the Task tool:
- description: "Extract claims from research reports"
- subagent_type: "general-purpose"
- model: "haiku"
- prompt: |
    Read every researcher-*.md file in $RESEARCH_DIR and extract 20-40 discrete,
    testable claims.

    Rules:
    - Deduplicate: if multiple LLMs found the same claim, list all models that did.
    - Categorize each: factual | recommendation | trade-off | opinion
    - Track convergence: how many researchers independently found each claim
    - Include short evidence summary

    Save as $RESEARCH_DIR/claims.json:
    {
      "research_topic": "<topic>",
      "extraction_date": "<YYYY-MM-DD>",
      "models_used": [<list of researchers that ran>],
      "total_claims": <N>,
      "claims": [
        {
          "id": "C01",
          "claim": "Specific testable statement",
          "category": "factual",
          "found_by_models": ["Claude", "OpenAI"],
          "convergence": "2/3",
          "evidence_summary": "Brief summary",
          "related_claims": ["C04"]
        }
      ]
    }
```

---

## Phase 3: Jury-On-Demand Tribunal Voting

Spawn **only the judges listed in `$JUDGES`** (set by Phase 0). Each judge votes on every claim with vote (approve|challenge) + confidence (0.50-0.99) + reasoning.

### Judge: Claude (always runs)
```
Use the Task tool:
- description: "Tribunal-Claude: vote on claims"
- subagent_type: "general-purpose"
- model: "sonnet"
- prompt: |
    You are Tribunal Judge — Claude. Focus: accuracy.

    Read $RESEARCH_DIR/claims.json and the researcher-*.md files for evidence.
    For each claim, vote approve or challenge with confidence 0.50-0.99 and
    1-2 sentence reasoning. Be honest about uncertainty.

    Save as JSON to: $RESEARCH_DIR/tribunal-votes-1-claude.json
    {
      "reviewer_id": "tribunal-1-claude",
      "model": "Claude Sonnet 4.6",
      "review_focus": "accuracy",
      "review_date": "<YYYY-MM-DD>",
      "votes": [{"claim_id": "C01", "vote": "approve", "confidence": 0.85, "reasoning": "...", "suggested_improvement": null}]
    }
```

### Judge: OpenAI (runs only if `openai` in `$JUDGES`)
```
Use the Task tool:
- description: "Tribunal-OpenAI: vote on claims"
- subagent_type: "general-purpose"
- model: "sonnet"
- prompt: |
    You are the proxy for Tribunal Judge — OpenAI. Focus: sourcing.

    1. Read $RESEARCH_DIR/claims.json and the researcher-*.md files.
    2. Source OPENAI_API_KEY from .env.
    3. POST to https://api.openai.com/v1/chat/completions with model gpt-4o,
       max_tokens 8000, temperature 0.3, response_format json_object.
       System: tribunal reviewer evaluating source quality.
       User: vote approve/challenge with confidence 0.50-0.99 on each claim.

    4. Save parsed JSON to: $RESEARCH_DIR/tribunal-votes-2-openai.json
       (same schema as tribunal-1; reviewer_id "tribunal-2-openai",
        model "OpenAI GPT-4o", review_focus "sourcing")

    On API failure, save an error report.
```

### Judge: Gemini (runs only if `gemini` in `$JUDGES`)
```
Use the Task tool:
- description: "Tribunal-Gemini: vote on claims"
- subagent_type: "general-purpose"
- model: "sonnet"
- prompt: |
    You are the proxy for Tribunal Judge — Gemini. Focus: relevance.

    1. Read $RESEARCH_DIR/claims.json and the researcher-*.md files.
    2. Source GEMINI_API_KEY from .env.
    3. POST to https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-preview-05-06:generateContent
       with maxOutputTokens 8000, temperature 0.3, responseMimeType application/json.
       Prompt: tribunal reviewer evaluating relevance, vote approve/challenge
       with confidence 0.50-0.99 on each claim.

    4. Save parsed JSON to: $RESEARCH_DIR/tribunal-votes-3-gemini.json
       (reviewer_id "tribunal-3-gemini", model "Gemini 2.5 Pro",
        review_focus "relevance")

    On API failure, save an error report.
```

Wait for all selected judges to finish.

---

## Phase 4: Simple-Majority Vote Aggregation

### Step 8: Aggregate Votes — Simple Majority

```
Inputs:
  - $RESEARCH_DIR/claims.json
  - $RESEARCH_DIR/tribunal-votes-*.json (one file per judge that ran)
  - $RESEARCH_DIR/jury.json (judge count N)

For each claim:
  1. Count approve votes A across the N judges that ran.
  2. vote_confidence = A / N
  3. status (simple majority):
       N=1:
         approve  -> Confirmed
         challenge -> Refuted
       N=2:
         2 approve  -> Confirmed
         1-1 split  -> Conflicting (no majority)
         2 challenge -> Refuted
       N=3:
         3 approve  -> Confirmed
         2-1 approve -> Likely
         2-1 challenge -> Conflicting
         3 challenge -> Refuted

  4. Convergence is reported for transparency but does NOT change the
     status assignment. (Aggregation is voting-only, not weighted.)

Save to: $RESEARCH_DIR/confidence-table.md
Include:
  - Judge panel composition (which judges ran, why — from jury.json)
  - Per-claim table: id, claim, judges who approved, judges who challenged, status
  - Convergence reported as context, not as a confidence multiplier
```

### Step 9: Quality Gate

```
IF all claims are Confirmed or Likely  -> proceed to Phase 5 (synthesis)
IF any claim is Conflicting or Refuted -> proceed to Step 10 (targeted re-research)
```

### Step 10: Targeted Re-Research (Conditional, max 1 pass)

```
Use the Task tool:
- description: "Re-research low-confidence claims"
- subagent_type: "general-purpose"
- model: "opus"
- prompt: |
    Read $RESEARCH_DIR/confidence-table.md and tribunal-votes-*.json.
    Focus only on claims with status Conflicting or Refuted.
    Use perplexity_research to gather additional evidence addressing the
    specific judge critiques.

    Save findings to: $RESEARCH_DIR/supplementary-research.md
```

HARD LIMIT: 1 re-research pass. Circuit breaker if no improvement.

---

## Phase 5: Synthesis

### Step 11: Final Synthesis

```
Use the Task tool:
- description: "Final synthesis"
- subagent_type: "general-purpose"
- model: "opus"
- prompt: |
    Read all inputs in $RESEARCH_DIR (researcher-*.md, claims.json,
    confidence-table.md, tribunal-votes-*.json, jury.json,
    supplementary-research.md if present).

    Produce $RESEARCH_DIR/final-report.md with:

    1. Executive Summary
       - Topic, classified category, judge panel composition, claim totals,
         confidence distribution.
    2. Cross-Model Agreement Analysis
       - Which findings ALL researchers found vs. only some.
       - Model-specific findings + observed biases.
    3. Findings Table by Status
       - Confirmed / Likely / Conflicting / Refuted.
    4. High-Confidence Recommendations
       - Only Confirmed or Likely claims.
    5. Contested Findings
       - All judges' perspectives preserved.
    6. Dissenting Opinions
       - Minority votes with reasoning.
    7. Methodology
       - Jury-on-demand classifier + selected panel + simple-majority voting.
       - Re-research summary if triggered.
    8. Source References
    9. Actionable Next Steps (prioritized by status)
```

### Step 12: Report to User

Report:
- Research directory path
- Query category + judge panel used (from `jury.json`)
- Researchers that ran (may be fewer than the panel if a key was missing)
- Total claims voted on
- Confidence distribution (Confirmed / Likely / Conflicting / Refuted)
- Re-research summary (if triggered)
- Top 5 recommendations
- List of output files

---

## Backward Compatibility

| Caller invocation | Behavior |
|---|---|
| `/research "<topic>"` | Classifier picks 1-3 judges based on category |
| `/research "<topic>" --judges all` | Forces full 3-judge panel (Claude + OpenAI + Gemini) — original behavior |

Existing callers that rely on the 3-judge panel can add `--judges all` to preserve the legacy aggregation. The output schema (claims.json, tribunal-votes-*.json, confidence-table.md, final-report.md) is unchanged; only the **number** of `tribunal-votes-*.json` files varies with the panel size, and `confidence-table.md` reports panel composition explicitly.

---

## Budget Allocation (Variable by Panel Size)

| Phase | 1 judge | 2 judges | 3 judges |
|---|---|---|---|
| Research (all available LLMs) | 35% | 35% | 35% |
| Claim extraction (Haiku) | 5% | 5% | 5% |
| Tribunal voting | 5% | 10% | 15% |
| Re-research (conditional) | 10% | 10% | 10% |
| Final synthesis (Opus) | 35% | 30% | 25% |
| Buffer | 10% | 10% | 10% |

Single-judge runs allocate more to synthesis because there is no inter-judge disagreement to reconcile.

---

## API Requirements

| Key | Provider | Required When |
|---|---|---|
| Perplexity (Docker MCP, pre-configured) | Perplexity | Always — Claude researcher uses it |
| `OPENAI_API_KEY` | OpenAI | Panel includes `openai`, or `--judges all` |
| `GEMINI_API_KEY` | Google | Panel includes `gemini`, or `--judges all` |

Run `/initialize-project` to configure missing keys.

---

## Usage Examples

```
# Classifier picks the panel:
/research "Evaluate GraphQL vs REST for our API layer"           # architectural -> 2 judges
/research "Best UX patterns for onboarding flows"                # design -> 3 judges
/research "How do I implement a Rust trait for serde?"           # coding -> 1 judge
/research "OWASP top 10 mitigations for Node.js APIs"            # security -> 2 judges
/research "What is RAFT consensus?"                              # factual -> 1 judge

# Force legacy 3-judge panel for backward compat:
/research "Compare authentication strategies for SaaS" --judges all
```

---

## Output Files

```
.docs/research/YYYYMMDD-HHMMSS-topic/
  jury.json                           # Classifier decision (category + judge panel)
  researcher-a-claude.md              # Claude + Perplexity research (always)
  researcher-b-openai.md              # OpenAI GPT-4o research (if key present)
  researcher-c-gemini.md              # Gemini 2.5 Pro research (if key present)
  claims.json                         # Extracted claims with convergence
  tribunal-votes-1-claude.json        # Claude votes (always)
  tribunal-votes-2-openai.json        # OpenAI votes (only if openai in panel)
  tribunal-votes-3-gemini.json        # Gemini votes (only if gemini in panel)
  confidence-table.md                 # Simple-majority status per claim
  supplementary-research.md           # Re-research (if triggered)
  final-report.md                     # Final report
```

---

## Constitutional Compliance

- **Principle X (Agent Delegation)**: All research and voting work is dispatched via the Task tool to general-purpose subagents; this command coordinates only.
- **Principle VI (Git Approval)**: This command writes only to `.docs/research/...` and never invokes git.
- **Principle VII (Observability)**: `jury.json` records the classification decision and panel composition for every run, enabling post-hoc audit of the jury-on-demand heuristic.
