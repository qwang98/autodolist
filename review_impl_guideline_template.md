# Implementation Review Guideline

<!-- Copy this file to review_impl_guideline.md and customize for your project. -->

## Goal

Review the diff attributable to the **current task** for correctness, scope discipline, and faithful execution of the approved plan. This review is strictly scoped to the current task's changes — files and hunks outside that diff are not in scope.

## Inputs the Reviewer Gets

- `autodolist-results/current_task.md` — task description and pass criteria
- `autodolist-results/<task_name>/plan.md` — the approved plan
- `autodolist-results/<task_name>/diff.patch` — the diff attributable to this task. The base of this diff depends on which phase invoked the review:
  - **Phase 2 (pre-pass-criteria review):** `git diff $(cat autodolist-results/<task_name>/base.sha)..HEAD` — the implementation diff against the task's starting tip.
  - **Phase 3 (post-merge review, only when `main` advanced):** `git diff $(cat autodolist-results/<task_name>/pre_merge_main.sha)..HEAD` — the PR-style diff: what the task contributes on top of the just-fetched `main`, including conflict resolution, excluding unrelated `main` changes.

Only `diff.patch` is in scope for the review. Do NOT walk the wider repository.

## Core Standard

A mergeable implementation must satisfy all four:

1. **Correct** — The diff does what the task description requires.
2. **Scoped** — Every hunk traces to a plan step or to necessary merge conflict resolution. No drive-by refactors, no unrelated edits.
3. **Safe** — No broken code paths, no committed secrets, no destructive changes outside the task's stated intent.
4. **Verified** — The task's pass criteria actually exercise the diff; they are not vacuous.

## Review Method

1. **Walk the diff** — Read every changed file and hunk in `diff.patch`.
2. **Map each hunk to a plan step** — A hunk with no plan justification (and that is not plausibly conflict resolution) is a blocker.
3. **Check conflict resolution** — If merge conflicts were resolved, verify the resolution preserves both the task's intent and what `main` brought in.
4. **Check pass-criteria coverage** — Confirm the pass criteria actually touch the changed code. A task whose pass criteria pass without exercising the diff is a blocker.
5. **Separate blockers from polish** — A blocker makes the diff incorrect, out-of-scope, unsafe, or incompatible with the pass criteria. Everything else is polish.

## Output Structure

### Findings
- Ordered by severity
- Include file path and hunk reference
- State what is wrong and what must change

### Improvements
- Refinements that would make the diff cleaner or more correct
- Distinguish from blockers

### Assessment
- Are there remaining blockers?
- Is the diff safe to push to `main`?

## Approval Criteria

Approve only if ALL of these hold:
- No blockers remain
- Every hunk traces to the approved plan or to necessary merge conflict resolution
- The pass criteria actually exercise the changed code
- Nothing outside the task's intended scope was touched
