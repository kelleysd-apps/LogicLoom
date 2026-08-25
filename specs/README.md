# Feature Specifications Directory

This directory contains feature specifications created using the SDD (Specification-Driven Development) workflow.

## Purpose

Each feature gets its own subdirectory with the format `###-feature-name/` containing:
- `spec.md` - Feature specification (user stories, requirements)
- `plan.md` - Technical implementation plan
- `research.md` - Technical research and decisions
- `data-model.md` - Entity definitions
- `contracts/` - API contracts
- `quickstart.md` - Test scenarios
- `tasks.md` - Implementation tasks

## Workflow

1. **Generate the artifacts**: Use the `/specification` command — it produces
   spec, plan, and tasks in one run. Scope it to a single phase with
   `--phase spec|plan|tasks`, and continue an interrupted run with `--resume`.
2. **Implement**: Follow tasks in dependency order
3. **Validate**: Use `/finalize` command before commit

## More Information

See the main [README.md](../README.md) for complete workflow documentation.
