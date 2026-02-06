# Contract: Swarm Lifecycle

## Create Swarm
```
POST /swarm/create
Input: { 
  task_description: string,
  team_template?: string,  
  total_budget_usd?: number,
  model?: string,
  fallback_model?: string
}
Output: { 
  swarm_id: string,
  agents: SwarmAgent[],
  execution_plan: ExecutionPhase[],
  estimated_cost_usd: number
}
Errors:
  - NO_DOMAINS_DETECTED: Task description too vague
  - MISSING_PLUGINS: Required domain plugins not installed
  - BUDGET_INSUFFICIENT: Budget too low for planned agents
```

## Spawn Agent
```
POST /swarm/{swarm_id}/agent/spawn
Input: {
  agent_name: string,
  agent_definition: string,
  task: string,
  budget_usd: number,
  model: string,
  dependencies: string[]
}
Output: {
  agent_id: string,
  state_file: string,
  process_id: number,
  status: "pending" | "running"
}
Errors:
  - DEPENDENCY_NOT_MET: Dependent tasks not complete
  - BUDGET_EXCEEDED: Team budget depleted
```

## Agent Status
```
GET /swarm/{swarm_id}/agent/{agent_id}/status
Output: {
  agent_id: string,
  status: "pending" | "running" | "complete" | "failed" | "killed",
  budget_spent_usd: number,
  output_summary?: string
}
```

## Terminate Swarm
```
POST /swarm/{swarm_id}/terminate
Input: { reason: string }
Output: { 
  terminated_agents: string[],
  preserved_work: string[],
  total_cost_usd: number
}
```
