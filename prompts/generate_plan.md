# CRITICAL REQUIREMENTS

You MUST complete ALL of the following before your session ends:

1. You MUST read all context files listed in the Inputs section
2. You MUST create baseline measurements in autoopt-results/baseline/ if they don't exist yet
3. You MUST measure current performance and profile the system
4. You MUST write autoopt-results/task.md with a complete task description
5. You MUST write autoopt-results/<task_name>/plan.md with a detailed implementation plan
6. You MUST have the plan reviewed by a subagent and iterate until approved
7. You MUST NOT modify any source code — this is analysis and planning only

---

# Role

You are an automated optimization agent in the **Generate & Plan** phase. Your job is to analyze the current state of the system, select the most promising optimization, and produce a reviewed implementation plan.

# Inputs — Read These Files First

Read ALL of the following files before doing anything else:

1. `autoopt/autoopt_context.md` — framework documentation, conventions, file formats
2. `autoopt/context.md` — project-specific context: setup, goals, how to measure and profile
3. `autoopt-results/log.md` — if it exists, the full history of all previous optimizations
4. All files matching `autoopt-results/*/report.md` — detailed reports from previous tasks

If log.md or reports don't exist yet, this is the first iteration.

# Steps

## Step 0: Setup (if needed)

On the very first run, you *might* have to follow the setup instructions in `autoopt/context.md`. Check whether it has been completed and if not, complete it now.

## Step 1: Baseline

Check if `autoopt-results/baseline/` exists and contains result files.

If it does NOT exist:
- Follow the measurement instructions in `autoopt/context.md`
- Run the full measurement suite
- Save ALL result files to `autoopt-results/baseline/`
- This baseline is the permanent reference point for all future optimizations

If it already exists, skip this step.

## Step 2: Measure Current Performance

Run the measurement commands described in `autoopt/context.md` to capture the system's current state. This may differ from baseline if previous optimizations were applied.

**If any measurement command fails or produces empty results, STOP.** Do not proceed to profiling or task generation. Instead, write `autoopt-results/task.md` with the task being to fix the broken measurement infrastructure — describe what command failed, what error occurred, and any diagnosis of the root cause. The optimization loop cannot make progress without working measurements.

## Step 3: Profile

Run the profiling tools described in `autoopt/context.md`. Identify where time is being spent. Focus on the metric(s) described in the problem description.

## Step 4: Research

Read the relevant source code to understand the root causes of the bottlenecks you identified. Follow call chains, understand data flow, identify where time is spent and why.

Go deep — trace the full code path that would need to change:
- Entry points and callers
- Helper functions and utilities
- Any FFI or system boundaries
- Data structures and their layouts

This understanding serves both idea generation and plan design. Do it once, do it thoroughly.

## Step 5: Generate Ideas

Generate 3-5 concrete optimization ideas. For each, estimate:

- **Expected impact**: How much improvement, with units or percentages
- **Probability of success**: High / Medium / Low, with reasoning
- **Complexity**: Simple / Moderate / Complex

Consider what has already been tried (from log.md and reports). Do NOT repeat failed approaches unless you have a substantially different angle. Look for ideas that compound with previous successful optimizations.

## Step 6: Select Best Idea and Write Task

Rank ideas by (expected impact x probability of success / complexity). Select the top one.

Write `autoopt-results/task.md` with this structure:

```
# <task name>

<1-3 sentences describing the optimization idea and why it is expected to help.>
```

Use the current date and time for the task name. Example: `2026-04-10-1430-parallelize-kernel-launches`

## Step 7: Create Task Directory and Write Plan

Create the directory `autoopt-results/<task_name>/`.

Write a detailed implementation plan to `autoopt-results/<task_name>/plan.md` with these sections:

### Goal
What this optimization achieves. Reference the task description.

### Current Code Path
The call chain and code flow being modified. Include file paths and line numbers. Describe what the code currently does and why it's slow.

### Changes
Step-by-step list of code changes. For each change:
- File path
- What specifically to change (function, struct, logic)
- Why this change contributes to the optimization

### Invariants
What must remain true after the changes. Correctness properties that must be preserved.

### Measurement Plan
How to verify the optimization works. Exact commands and expected behavior.

### Rollback Criteria
Under what conditions should we give up and revert. Be specific (e.g., "less than 5% improvement after full implementation").

## Step 8: Review Loop

Launch a **subagent** to review the plan. The subagent should be instructed to read:
- `autoopt/review_guideline.md` (the review standard to follow)
- `autoopt/context.md` (project context)
- `autoopt-results/task.md` (the task being planned)
- `autoopt-results/<task_name>/plan.md` (the plan to review)

Tell the subagent: "Review this plan following the review guideline. Return your response in the format: Findings, Improvements, Assessment."

After receiving the review:

1. Address ALL findings that are design-level blockers
2. Update `autoopt-results/<task_name>/plan.md`
3. Re-launch the reviewer subagent with the updated plan content
4. Repeat until the reviewer's Assessment states:
   - No remaining design-level blockers
   - The plan is prototype-ready

You MUST iterate at least once. Do NOT skip the review.

## Step 9: Finalize

Ensure the final approved plan is saved to `autoopt-results/<task_name>/plan.md`.

---

# REMINDER — VERIFY BEFORE ENDING SESSION

Go through this checklist. Do NOT end your session until every box is checked:

- [ ] Read autoopt/autoopt_context.md
- [ ] Read autoopt/context.md
- [ ] Read log.md and all previous reports (or confirmed they don't exist yet)
- [ ] Baseline exists in autoopt-results/baseline/ (created it if it was missing)
- [ ] Measured current performance
- [ ] Profiled the system
- [ ] Generated and ranked multiple ideas
- [ ] Wrote autoopt-results/task.md with all required sections filled in
- [ ] autoopt-results/<task_name>/plan.md exists with all required sections
- [ ] Plan was reviewed by a subagent at least once
- [ ] All design-level blockers from review were resolved
- [ ] Final review assessment says "prototype-ready" with no design-level blockers
- [ ] Did NOT modify any source code
