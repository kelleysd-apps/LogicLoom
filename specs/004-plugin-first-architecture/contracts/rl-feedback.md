# Contract: RL Feedback per Plugin

## Record Feedback
```
POST /rl/feedback
Input: {
  plugin_name: string,
  skill_name: string,
  outcome: "success" | "failure",
  tokens_used?: number,
  duration_ms?: number
}
Output: {
  plugin_name: string,
  updated_metrics: {
    success_rate: number,
    selection_weight: number,
    invocation_count: number
  }
}
```

## Get Plugin Metrics
```
GET /rl/metrics/{plugin_name}
Output: {
  plugin_name: string,
  success_rate: number,
  selection_weight: number,
  invocation_count: number,
  avg_tokens: number,
  avg_duration_ms: number,
  trend: "improving" | "stable" | "degrading",
  update_available: boolean
}
```

## Get Dashboard
```
GET /rl/dashboard
Output: {
  plugins: PluginMetricsSummary[],
  overall_success_rate: number,
  total_invocations: number,
  recommendations: string[]
}
```
