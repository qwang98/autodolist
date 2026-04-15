# Agent Guide for AutoOpt

This file provides context for AI agents working in this codebase.
Read the [README.md](README.md).

## What This Repo Is

AutoOpt is a harness, not an application. It contains prompts and a bash script that orchestrate other Claude sessions to perform iterative optimization on external projects. The code you're looking at is the framework itself — the actual optimization work happens in whatever project AutoOpt is symlinked into.

## Repository Structure

- `run.sh` — The entry point. A bash loop that invokes `claude -p` three times per iteration with different prompts. Keep this minimal.
- `autoopt_context.md` — Read by every agent session. Describes the framework conventions (file formats, naming, commit strategy). Must stay project-agnostic.
- `prompts/` — The three phase prompts. These are the most critical files. They control agent behavior.
- `context_template.md`, `review_guideline_template.md` — Templates users copy and customize. Keep generic.
- `context.md`, `review_guideline.md` — Project-specific, gitignored. Not part of this repo's source.

## Editing Prompts

The prompts in `prompts/` are the most sensitive files in this repo. When editing them:

- **Critical instructions go at the top AND bottom.** Agents are more likely to follow instructions at the beginning and end of a prompt (primacy/recency effect).
- **Use MUST, not "should" or "please".** Soft language gets ignored in autonomous runs.
- **Be explicit about file paths.** Don't say "save the results" — say "write to `autoopt-results/<task_name>/results/before_*`".
- **Include a checklist at the end.** The closing checklist is the last thing the agent sees before deciding whether to stop.
- **Keep the three phases independent.** Each phase runs as a separate Claude session with no shared memory. All communication happens through files in `autoopt-results/`. Never assume one phase knows what another did — only what it can read from disk.

## Key Design Decisions

1. **Two separate sessions, not one long session.** Analysis/planning and execution run as separate sessions. This prevents context window degradation during implementation (which generates the most output). The cost is that context must be re-read from files, but this is deliberate — it forces clear documentation.

2. **File-based communication.** `autoopt-results/task.md` and `autoopt-results/<task_name>/plan.md` are the contracts between the planning phase and the execution phase. If you change the expected format of these files, update all prompts that read them.

3. **Baseline + previous comparison.** Results are always relative to two points: the original baseline and the immediately previous task. This matters because it shows both cumulative progress and whether each individual task helped.

4. **Commit then revert on failure.** Failed optimizations are committed before being reverted. This preserves the work in git history so it can be recovered or learned from, while keeping the branch clean for the next iteration.

5. **Review loop in the planning phase.** The planning phase spawns a sub-agent to review the plan. The sub-agent gets all context inlined in its prompt (it has no access to the filesystem). The review iterates until the reviewer reports no design-level blockers.

## Testing Changes

There are no automated tests. To verify changes to the framework:

1. Symlink into a project with a working `context.md`
2. Run `bash autoopt/run.sh 1` for a single iteration
3. Check that `autoopt-results/` contains: `baseline/`, `task.md`, `log.md`, and a task directory with `plan.md`, `report.md`, and `results/`
4. Check that git commits were created (and reverted if the optimization failed)
5. Check that nothing under `autoopt-results/` was committed

## Common Pitfalls

- **Don't add project-specific content to `autoopt_context.md` or the prompts.** These are shared across all projects. Project-specific details go in `context.md`.
- **Don't assume the agent will read files it wasn't told to read.** If a prompt needs information from a file, it must explicitly say "Read file X".
- **Don't merge the planning and execution phases.** The two-phase split is load-bearing. The execution phase generates too much output (builds, test runs, benchmarks) to share a session with analysis and planning.
- **`autoopt-results/` lives in the target project, not here.** This repo is the framework. Results are created in whatever project the user symlinks this into.
