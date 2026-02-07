---
name: tribunal-review
description: Multi-LLM tribunal voting protocol — claim extraction, cross-model voting (Claude, OpenAI, Gemini), and confidence aggregation for research validation.
triggers:
  - tribunal
  - voting
  - cross-validation
  - claim extraction
  - confidence scoring
  - multi-llm
agent: team-synthesizer
model: opus
---

# Tribunal Review Skill

Cross-validates multi-LLM triplicate research through structured claim extraction, independent cross-model tribunal voting, and confidence-weighted aggregation.

## Overview

The tribunal review process takes 3 independent research reports produced by **different LLMs** (Claude, OpenAI, Gemini) on the **same topic** and validates findings through:

1. **Claim Extraction** — Extract discrete claims from all 3 LLM reports
2. **Multi-LLM Tribunal Voting** — Claude, OpenAI, and Gemini each vote on claims
3. **Confidence Aggregation** — Combine convergence + votes into confidence scores
4. **Quality Gate** — Determine if re-research is needed for low-confidence claims

## LLM Model Routing

| Phase | Claude | OpenAI | Gemini |
|-------|--------|--------|--------|
| Research | Opus 4.6 + Perplexity | GPT-4o via API | Gemini 2.5 Pro via API |
| Claim Extraction | Haiku | — | — |
| Tribunal Voting | Sonnet 4.5 | GPT-4o via API | Gemini 2.5 Pro via API |
| Re-Research | Opus + Perplexity | — | — |
| Synthesis | Opus 4.6 | — | — |

## API Integration

### Required Keys (in `.env`)

```bash
OPENAI_API_KEY=sk-...        # OpenAI researcher + tribunal reviewer
GEMINI_API_KEY=AIza...       # Google Gemini researcher + tribunal reviewer
```

### OpenAI API Call Pattern

```bash
source .env 2>/dev/null || export OPENAI_API_KEY=$(grep OPENAI_API_KEY .env | cut -d= -f2-)

curl -s https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "system", "content": "<system prompt>"},
      {"role": "user", "content": "<research or voting prompt>"}
    ],
    "max_tokens": 16000,
    "temperature": 0.7
  }'

# Parse: jq -r '.choices[0].message.content'
```

### Gemini API Call Pattern

```bash
source .env 2>/dev/null || export GEMINI_API_KEY=$(grep GEMINI_API_KEY .env | cut -d= -f2-)

curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-preview-05-06:generateContent?key=$GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{"parts": [{"text": "<prompt>"}]}],
    "generationConfig": {
      "maxOutputTokens": 16000,
      "temperature": 0.7
    }
  }'

# Parse: jq -r '.candidates[0].content.parts[0].text'
```

### For JSON voting responses, add:

**OpenAI**: `"response_format": {"type": "json_object"}`
**Gemini**: `"responseMimeType": "application/json"` in generationConfig

## Phase 1: Claim Extraction

### Input
- 3 research reports from different LLMs on the same topic
- Reports labeled by source model (Claude, OpenAI, Gemini)

### Claim JSON Schema

```json
{
  "research_topic": "<the research topic>",
  "extraction_date": "<YYYY-MM-DD>",
  "models_used": ["Claude Opus 4.6", "OpenAI GPT-4o", "Gemini 2.5 Pro"],
  "total_claims": 25,
  "claims": [
    {
      "id": "C01",
      "claim": "Specific testable statement extracted from research",
      "category": "factual | recommendation | trade-off | opinion",
      "found_by_models": ["Claude", "OpenAI", "Gemini"],
      "convergence": "3/3 | 2/3 | 1/3",
      "evidence_summary": "Brief summary of supporting evidence from source reports",
      "related_claims": ["C04", "C12"]
    }
  ]
}
```

### Cross-Model Convergence Scoring

Claims found independently by multiple LLM families are extremely high confidence:
- **3/3 models**: Base confidence 0.90 (all LLM families agree independently)
- **2/3 models**: Base confidence 0.65 (partial cross-model agreement)
- **1/3 models**: Base confidence 0.35 (single-model finding, may be model-specific bias)

## Phase 2: Multi-LLM Tribunal Voting

### Reviewer Assignment

| Reviewer | LLM | Focus | Evaluation Priority |
|----------|-----|-------|-------------------|
| Tribunal 1 | **Claude Sonnet 4.5** | **Accuracy** | Is the claim factually correct? Is evidence valid? |
| Tribunal 2 | **OpenAI GPT-4o** | **Sourcing** | Are sources credible? Evidence sufficient and current? |
| Tribunal 3 | **Gemini 2.5 Pro** | **Relevance** | Is this actionable? Does it answer the research question? |

### Tribunal Vote JSON Schema

```json
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
      "reasoning": "Confirmed via multiple independent sources cited across reports",
      "suggested_improvement": null
    }
  ]
}
```

## Phase 3: Confidence Aggregation

### Vote Tallying

```
# Step 1: Count cross-model tribunal votes
votes_approve = count of "approve" votes across Claude, OpenAI, Gemini (0-3)
vote_confidence = votes_approve / 3

# Step 2: Get convergence from claim extraction
convergence_score:
  3/3 models found it = 0.90
  2/3 models found it = 0.65
  1/3 models found it = 0.35

# Step 3: Combine (convergence weighted 30%, votes weighted 70%)
combined_confidence = (0.3 * convergence_score) + (0.7 * vote_confidence)
```

### Confidence-to-Status Mapping

| Combined Score | Status | Action |
|---------------|--------|--------|
| >= 0.80 | **Confirmed** | Include in recommendations |
| 0.55 - 0.79 | **Likely** | Include with caveat |
| 0.30 - 0.54 | **Conflicting** | Flag for re-research |
| < 0.30 | **Refuted** | Exclude or note as disproven |

## Phase 4: Quality Gate

```
IF all claims Confirmed or Likely → SKIP re-research
IF any Conflicting or Refuted → targeted re-research (1 pass max)
IF re-research shows no improvement → circuit breaker, proceed to synthesis
```

## Configuration Parameters

Set in `.specify/config/refinement.conf`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `TRIBUNAL_REVIEWER_COUNT` | `3` | Number of tribunal reviewers |
| `TRIBUNAL_RERESEARCH_THRESHOLD` | `0.55` | Claims below this trigger re-research |
| `TRIBUNAL_MAX_RERESEARCH_PASSES` | `1` | Maximum re-research iterations |
| `TRIBUNAL_REVIEWER_MODEL` | `sonnet` | Claude model for tribunal reviewer |
| `TRIBUNAL_EXTRACTION_MODEL` | `haiku` | Claude model for claim extraction |

## Budget Allocation

| Phase | Budget % |
|-------|----------|
| 3 Multi-LLM Researchers | 35% |
| Claim Extraction (Haiku) | 5% |
| 3 Multi-LLM Tribunal Reviewers | 15% |
| Targeted Re-Research (conditional) | 10% |
| Final Synthesizer | 25% |
| Buffer/overhead | 10% |
