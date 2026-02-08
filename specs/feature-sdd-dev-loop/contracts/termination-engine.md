# Contract: Termination Engine

## Check All Layers
```
POST /termination/check
Input:  {
  session_id: string
}
Output: {
  should_terminate: boolean,
  termination_reason: string | null,  // null if should continue
  layer_triggered: number | null,     // 1-6, null if should continue
  layer_results: {
    layer_1_success: {
      triggered: boolean,
      current_grade: number,
      threshold: number
    },
    layer_2_convergence: {
      triggered: boolean,
      last_improvements: number[],    // last N deltas
      convergence_delta: number
    },
    layer_3_budget: {
      triggered: boolean,
      tokens_consumed: number,
      tokens_limit: number,
      cost_consumed: number,
      cost_limit: number
    },
    layer_4_max_iterations: {
      triggered: boolean,
      current_iteration: number,
      max_iterations: number
    },
    layer_5_stuck: {
      triggered: boolean,
      stuck_type: "error_loop" | "test_failure_loop" | "oscillation" | null,
      detection_details: string
    },
    layer_6_user_interrupt: {
      triggered: boolean,
      interrupt_time: timestamp | null
    }
  }
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
Side Effects:
  - None (read-only evaluation)
```

## Check Convergence
```
POST /termination/convergence
Input:  {
  grades: number[],                   // quality grade history
  convergence_delta: number,          // default 0.001
  consecutive_count: number           // default 3
}
Output: {
  converged: boolean,
  last_improvements: number[],        // last N grade deltas
  average_improvement: number,
  iterations_checked: number
}
Errors:
  - INSUFFICIENT_DATA: Fewer grades than consecutive_count required
  - INVALID_DELTA: Convergence delta must be positive
```

## Check Budget
```
POST /termination/budget
Input:  {
  session_id: string
}
Output: {
  budget_exhausted: boolean,
  budget_status: {
    tokens: {
      consumed: number,
      limit: number,
      remaining: number,
      percent_used: number
    },
    cost: {
      consumed: number,
      limit: number,
      remaining: number,
      percent_used: number
    }
  },
  consumption_by_model: Array<{
    model: string,
    tokens: number,
    cost: number
  }>
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
Side Effects:
  - None (read-only evaluation)
```

## Check Oscillation
```
POST /termination/oscillation
Input:  {
  session_id: string
}
Output: {
  oscillation_detected: boolean,
  oscillation_pattern: {
    cycle_length: number,             // iterations in cycle
    repeated_states: Array<{
      iteration_a: number,
      iteration_b: number,
      state_hash: string,
      similarity: number              // 0.0-1.0
    }>
  } | null,
  recommendation: string              // action to take
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
  - INSUFFICIENT_HISTORY: Fewer than 4 iterations
Side Effects:
  - Computes state hashes for all iterations if not cached
  - Caches state hashes for future checks
```

## Save Checkpoint
```
POST /termination/checkpoint
Input:  {
  session_id: string,
  checkpoint_name?: string            // default: checkpoint_{iteration}
}
Output: {
  checkpoint_path: string,
  checkpoint_size_bytes: number,
  state_captured: {
    iteration: number,
    quality_history: number[],
    event_log_entries: number,
    resources_consumed: {
      tokens: number,
      cost: number
    },
    working_branch: string,
    git_commit_sha: string            // current state commit
  }
}
Errors:
  - SESSION_NOT_FOUND: Session ID doesn't exist
  - CHECKPOINT_WRITE_FAILED: Cannot write checkpoint file
  - GIT_STATE_UNAVAILABLE: Cannot capture git state
Side Effects:
  - Creates checkpoint file at .dev-loop/sessions/{session_id}/checkpoints/
  - Commits current state to working branch (for restoration)
  - Records checkpoint in event log
```
