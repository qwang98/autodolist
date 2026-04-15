# AutoOpt Framework

AutoOpt is an automated optimization harness. It uses AI agents to iteratively improve a system's performance through a structured loop of analysis, planning, and implementation.

## How It Works

Each iteration has two phases, each run as a separate agent session:

1. **Generate & Plan** — Analyze current performance, review optimization history, select the most promising optimization, and produce a reviewed implementation plan.
2. **Execute Task** — Implement the optimization, measure results, document findings, and commit changes.

The phases communicate through files in `autoopt-results/`. Each phase reads the outputs of previous phases and writes its own outputs.

## Directory Structure

### Static files (`autoopt/`)

These files are part of the framework and do not change during a run:

- `autoopt_context.md` — This file. Generic framework documentation.
- `context.md` — Project-specific context: setup, goals, measurement, profiling, constraints.
- `review_guideline.md` — Guidelines for the plan review sub-agent.
- `prompts/` — The three prompt files, one per phase.

### Dynamic files (`autoopt-results/`)

Created and updated during runs:

- `baseline/` — Baseline performance measurements taken before any optimizations. Created on the first run by the Generate Task agent.
- `task.md` — The current task (overwritten each iteration).
- `log.md` — Append-only log of all completed optimizations.
- `<task_name>/` — One directory per task:
  - `plan.md` — Implementation plan (reviewed and approved).
  - `report.md` — Final detailed report with results and analysis.
  - `results/` — Measurement and profiling artifacts.

## Conventions

### Task Naming

Format: `YYYY-MM-DD-HHMM-descriptive-name`

Example: `2026-04-10-1430-parallelize-kernel-launches`

Use the current date and time when creating the task. The descriptive name should be kebab-case and indicate the optimization approach.

### Results Tracking

All results MUST be reported relative to TWO reference points:

1. **Baseline** — The original performance before any optimizations (`autoopt-results/baseline/`).
2. **Previous task** — The performance after the most recent completed optimization.

This allows tracking both cumulative progress and incremental impact.

### Log Format

`autoopt-results/log.md` is append-only. Each task adds one section:

```
## <task_name>

**Idea**: <one-line description>

**Result**: <success/failure> — <key metric change vs baseline> (vs previous: <change>)

**Summary**: <2-3 sentences on what was done and learned>
```

### Commit Strategy

- Implementation changes are committed to the project's git repository.
- `autoopt-results/` is NEVER committed or staged.
- Commit messages should be descriptive. Multiple commits per task are fine.
- If an optimization does NOT improve performance:
  1. Commit the implementation anyway (preserving it in git history).
  2. Immediately `git revert` the commit(s).
  3. This keeps the branch clean while making the work recoverable.
- After the final commit for each task (whether successful or a revert), create a tag: `autoopt/<task_name>`.

### Baseline

The baseline is created once, on the first run, by the Generate Task agent. It represents the system's performance before any AutoOpt optimizations. The baseline directory should contain the same measurement artifacts that each task collects, so comparisons are straightforward.
