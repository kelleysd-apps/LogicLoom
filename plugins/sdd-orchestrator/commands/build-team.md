---
name: build-team
description: Launch sequential architect → implementor → reviewer team for feature development
model: opus
---

# /build-team Command

## Team Composition (Sequential)
1. **Architect** (backend-architect): Design the solution architecture
2. **Implementor** (full-stack-developer): Build the implementation
3. **Reviewer** (testing-specialist): Review and test

## Budget Allocation
- Architect: 30%
- Implementor: 50%
- Reviewer: 20%
- Default total: $15.00

## Usage
```
/build-team "Build JWT authentication with refresh tokens"
/build-team "Add real-time notifications via WebSocket" --budget 20.00
```
