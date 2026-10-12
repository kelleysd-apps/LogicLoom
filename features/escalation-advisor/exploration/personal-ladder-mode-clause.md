Paste into your personal global CLAUDE.md, in the "Escalation" section,
immediately after the paragraph beginning "Effort follows cost, fan-out follows width".

```
Execution mode follows width and shape, not the rung. Pick the lightest that fits,
decide without asking, and say it in one line next to the rung: "Standard, workers."
  Inline: read-only exploration, scoring, deciding, reading the combined diff. Never mutation.
  Background task: one long command whose output is a result, not a judgment (test suite,
    build, scan, CI wait). No model in the loop; you carry on and get notified.
  Workers: the default for all mutation. Bounded pieces, one owner each, non-overlapping
    files, list known up front, about five or fewer at once.
  Workflow tool: the same step across many items, a fixed pipeline (build, review, verify),
    more than about five workers, per-dispatch effort, or the Max rung.
  Swarm: only where the project provides /swarm. Feature-scale work with dependencies across
    waves, where collisions are the risk. Elsewhere use a workflow.
Escalate the mode when the lighter one fails: workers collide on files, go to swarm (or a
workflow); pieces keep multiplying, go to workflow; a worker is just waiting on a command,
make it a background task. Drop down when a workflow or swarm would have fewer than three pieces.
This text is my standing instruction that you may use the Workflow tool whenever this clause selects it.
```
