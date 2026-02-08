# Contract: Dev-Loop Lifecycle

## Start Session
```
POST /dev-loop/session/start
Input:  {
  task_description: string,
  config?: {
    quality_threshold?: number,      // 0.80-0.99, default 0.95
    budget_tokens?: number,           // max tokens, default 500000
    budget_cost?: number,             // max USD cost, default 10.00
    max_iterations?: number,          // 10-50, default 25
    execution_mode?: "tactic" | "strategy" | "auto",  // default "auto"
    quality_weights?: {
      test_pass_rate?: number,       // default 0.35
      test_coverage?: number,         // default 0.20
      lint?: number,                  // default 0.15
      type_safety?: number,           // default 0.15
      security?: number,              // default 0.10
      build?: number                  // default 0.05
    }
  }
}
Output: {
  session_id: string,
  status: "running",
  mode: "tactic" | "strategy",
  initial_scope_analysis: ScopeAnalysis,
  started_at: timestamp
}
Errors:
  - INVALID_THRESHOLD: Quality threshold outside 0.80-0.99 range
  - INVALID_BUDGET: Budget values must be positive
  - INVALID_WEIGHTS: Quality weights must sum to 1.0
  - INVALID_TASK: Task description empty or malformed
  - NO_GIT_BASELINE: No committed baseline found
  - NO_TEST_SUITE: No executable test suite found
Side Effects:
  - Creates session directory at .dev-loop/sessions/{session_id}
  - Initializes event log
  - Creates working branch if not exists
  - Saves checkpoint_0 (initial state)
```

## Execute Iteration
```
POST /dev-loop/session/iterate
Input:  {
  session_id: string
}
Output: {
  iteration_number: number,
  status: "complete" | "failed",
  quality_grade: QualityGrade,
  actions_taken: string[],
  resources_consumed: {
    tokens_by_model: { [model: string]: number },
    cost_by_model: { [model: string]: number },
    wall_clock_seconds: number
  },
  next_action: "continue" | "terminate",
  termination_reason?: string
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
  - SESSION_NOT_RUNNING: Session already terminated
  - BUDGET_EXHAUSTED: Token or cost limit reached
  - MAX_ITERATIONS: Iteration limit reached
  - EXECUTION_FAILED: Critical error during iteration
Side Effects:
  - Writes code changes to working branch
  - Runs test suite
  - Updates event log
  - Saves checkpoint_{N}
  - Updates quality history
  - Updates resource consumption counters
```

## Grade Iteration
```
POST /dev-loop/session/grade
Input:  {
  session_id: string,
  iteration: number
}
Output: {
  composite_grade: number,           // 0.0-1.0
  metrics: {
    test_pass_rate: number,          // 0.0-1.0
    test_coverage: number,            // 0.0-1.0
    lint_score: number,               // 0.0-1.0
    type_safety_score: number,        // 0.0-1.0
    security_score: number,           // 0.0-1.0
    build_success: number             // 0.0 or 1.0
  },
  semantic_evaluation?: {
    score: number,                    // 0.0-1.0
    commentary: string
  },
  threshold_met: boolean
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
  - ITERATION_NOT_FOUND: Iteration number invalid
  - GRADING_FAILED: Error computing metrics
Side Effects:
  - Updates quality grade history
  - Records grade in event log
```

## Terminate Session
```
POST /dev-loop/session/terminate
Input:  {
  session_id: string,
  reason: "success" | "converged" | "budget_exhausted" | "max_iterations" | "stuck" | "user_interrupt" | "error",
  save_checkpoint: boolean           // default true
}
Output: {
  status: "terminated",
  final_iteration: number,
  final_grade: number,
  termination_reason: string,
  session_report: {
    total_iterations: number,
    grade_trajectory: number[],
    tribunal_decisions: TribunalBallot[],
    resources_consumed: {
      total_tokens: number,
      total_cost: number,
      tokens_by_model: { [model: string]: number },
      cost_by_model: { [model: string]: number },
      wall_clock_seconds: number
    },
    code_changes_summary: string,
    rl_feedback_recorded: boolean
  },
  checkpoint_path?: string
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
  - ALREADY_TERMINATED: Session already ended
Side Effects:
  - Saves final checkpoint
  - Generates session report file
  - Records RL feedback metrics
  - Closes event log
  - Updates session status to "terminated"
```

## Resume Session
```
POST /dev-loop/session/resume
Input:  {
  session_id: string,
  checkpoint?: string                // checkpoint path, default latest
}
Output: {
  status: "running",
  resumed_from_iteration: number,
  quality_history: number[],
  resources_consumed_so_far: {
    total_tokens: number,
    total_cost: number
  },
  remaining_budget: {
    tokens: number,
    cost: number,
    iterations: number
  }
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
  - CHECKPOINT_NOT_FOUND: Checkpoint file doesn't exist
  - CHECKPOINT_CORRUPTED: Checkpoint data invalid
  - SESSION_ALREADY_RUNNING: Session not paused
Side Effects:
  - Restores session state from checkpoint
  - Updates session status to "running"
  - Appends to event log
```

## Get Session Status
```
GET /dev-loop/session/status
Input:  {
  session_id: string
}
Output: {
  session_id: string,
  status: "running" | "paused" | "terminated",
  current_iteration: number,
  current_grade: number,
  quality_history: number[],
  resources_consumed: {
    total_tokens: number,
    total_cost: number,
    wall_clock_seconds: number
  },
  remaining_budget: {
    tokens: number,
    cost: number,
    iterations: number
  },
  termination_reason?: string,
  last_checkpoint: string
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
```
