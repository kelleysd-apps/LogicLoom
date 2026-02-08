# Contract: Quality Grading

## Run Grade
```
POST /grading/run
Input:  {
  session_id: string,
  iteration: number,
  workspace_path: string              // path to code under evaluation
}
Output: {
  iteration: number,
  composite_grade: number,            // 0.0-1.0
  metrics: {
    test_pass_rate: {
      raw: number,                    // tests_passed / tests_total
      normalized: number,             // 0.0-1.0
      weight: number                  // config-defined weight
    },
    test_coverage: {
      raw: number,                    // percentage 0-100
      normalized: number,             // 0.0-1.0
      weight: number
    },
    lint: {
      raw: number,                    // error count
      normalized: number,             // 1.0 if zero errors, else scaled
      weight: number
    },
    type_safety: {
      raw: number,                    // error count
      normalized: number,             // 1.0 if zero errors, else scaled
      weight: number
    },
    security: {
      raw: number,                    // critical+high vuln count
      normalized: number,             // 1.0 if zero, else scaled
      weight: number
    },
    build: {
      raw: boolean,                   // build success/failure
      normalized: number,             // 1.0 or 0.0
      weight: number
    }
  },
  threshold_met: boolean,             // composite >= session threshold
  execution_time_ms: number
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
  - ITERATION_NOT_FOUND: Iteration number invalid
  - WORKSPACE_NOT_FOUND: Workspace path doesn't exist
  - TEST_SUITE_FAILED: Cannot execute test suite
  - GRADING_TIMEOUT: Grading exceeded 30 second limit
Side Effects:
  - Executes test suite
  - Runs lint tools
  - Runs type checker
  - Runs security scanner
  - Attempts build
  - Records metrics in event log
```

## Compute Composite
```
POST /grading/composite
Input:  {
  metrics: {
    test_pass_rate: number,           // 0.0-1.0
    test_coverage: number,
    lint: number,
    type_safety: number,
    security: number,
    build: number
  },
  weights: {
    test_pass_rate: number,           // must sum to 1.0
    test_coverage: number,
    lint: number,
    type_safety: number,
    security: number,
    build: number
  }
}
Output: {
  composite_grade: number,            // weighted average 0.0-1.0
  breakdown: Array<{
    metric: string,
    value: number,
    weight: number,
    contribution: number              // value * weight
  }>
}
Errors:
  - INVALID_METRICS: Metric values outside 0.0-1.0
  - INVALID_WEIGHTS: Weights don't sum to 1.0 (tolerance 0.001)
```

## Check Threshold
```
POST /grading/threshold/check
Input:  {
  grade: number,                      // 0.0-1.0
  threshold: number                   // 0.80-0.99
}
Output: {
  threshold_met: boolean,
  delta: number,                      // grade - threshold
  percent_complete: number            // (grade / threshold) * 100
}
Errors:
  - INVALID_GRADE: Grade outside 0.0-1.0
  - INVALID_THRESHOLD: Threshold outside 0.80-0.99
```

## Run LLM Judge
```
POST /grading/llm-judge
Input:  {
  session_id: string,
  iteration: number,
  code_changes: string[],             // paths to changed files
  spec_requirements: string,          // from session context
  evaluation_aspects: string[]        // default ["readability", "architecture", "compliance"]
}
Output: {
  semantic_grade: number,             // 0.0-1.0
  commentary: string,                 // detailed assessment
  aspects: Array<{
    aspect: string,
    score: number,                    // 0.0-1.0
    feedback: string
  }>,
  model_used: string,
  execution_time_ms: number
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
  - ITERATION_NOT_FOUND: Iteration number invalid
  - NO_CODE_CHANGES: No changes to evaluate
  - LLM_FAILED: AI model error or timeout
Side Effects:
  - Queries AI model for semantic evaluation
  - Records evaluation in event log
```
