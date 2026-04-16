# Plan Review Guideline

<!-- Copy this file to review_plan_guideline.md and customize for your project. -->

## Goal

Review an implementation plan for correctness, specificity, and likelihood of
satisfying the task's pass criteria.

## Core Standard

A reviewable plan must satisfy all four:

1. **Correct** — Does not break existing behavior or invariants.
2. **Specific** — Can be implemented without inventing missing design.
3. **Targeted** — Addresses exactly what the task description asks for, nothing more.
4. **Verifiable** — The plan's outcome can be checked against the task's pass criteria.

## Review Method

1. **Extract claims** — Identify the task description and pass criteria the plan is trying to satisfy. Do not accept vague claims like "should work."
2. **Check the code path** — Verify that the plan matches the actual implementation, not an assumed one. Check file paths, call chains, data flow.
3. **Check pass criteria coverage** — Confirm that executing the plan as written will cause every pass criterion to hold. If a criterion is not demonstrably covered, that is a blocker.
4. **Separate blockers from polish** — A blocker makes the plan incorrect, unimplementable, or likely to miss its pass criteria. Everything else is polish.

## Output Structure

### Findings
- Ordered by severity
- Include file references
- State what is wrong and what must change

### Improvements
- Real alternatives that could better satisfy the task
- Distinguish from blockers

### Assessment
- Are there remaining design-level blockers?
- Is the plan prototype-ready?
- What is the strongest part of the plan?

## Approval Criteria

Approve only if ALL of these hold:
- No design-level correctness blockers remain
- No missing information needed to implement
- The plan plausibly satisfies every pass criterion of the task
- The plan is specific enough to implement without guessing
