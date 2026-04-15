# Review Guideline

<!-- Copy this file to review_guideline.md and customize for your project. -->

## Goal

Review an implementation plan for correctness, specificity, and likely effectiveness.

## Core Standard

A reviewable plan must satisfy all four:

1. **Correct** — Does not break existing behavior or invariants.
2. **Specific** — Can be implemented without inventing missing design.
3. **Targeted** — Addresses a measured bottleneck, not a guess.
4. **Justified** — Complexity is proportional to expected benefit.

## Review Method

1. **Extract claims** — Identify the claimed bottleneck, proposed mechanism, and expected savings. Do not accept vague claims like "should help."
2. **Check the code path** — Verify that the plan matches the actual implementation, not an assumed one. Check file paths, call chains, data flow.
3. **Check measurements** — Confirm that the targeted bottleneck is supported by profiling data. Reject priority arguments that contradict measurements.
4. **Separate blockers from polish** — A blocker makes the plan incorrect, unimplementable, or likely to miss its target. Everything else is polish.

## Output Structure

### Findings
- Ordered by severity
- Include file references
- State what is wrong and what must change

### Improvements
- Real alternatives that could better achieve the goal
- Distinguish from blockers

### Assessment
- Are there remaining design-level blockers?
- Is the plan prototype-ready?
- What is the strongest part of the plan?

## Approval Criteria

Approve only if ALL of these hold:
- No design-level correctness blockers remain
- No missing information needed to implement
- The optimization targets a measured bottleneck
- The plan is specific enough to implement without guessing
