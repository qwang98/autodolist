# Agent Guide for AutoDolist

This file provides context for AI agents working in this codebase.
Read the [README.md](README.md).

## What This Repo Is

AutoDolist is a harness, not an application. It contains prompts and a bash script that orchestrate other Claude sessions to work through a user-defined task list on external projects. The code you're looking at is the framework itself — the actual task work happens in whatever project AutoDolist is symlinked into.

## Repository Structure

- `run.sh` — The entry point. A bash loop that invokes `claude -p` three times per iteration (generate_plan, do_plan, merge_main). Keep this minimal.
- `autodolist_context.md` — Read by every agent session. Describes the framework conventions (file formats, naming, commit strategy, merge rules). Must stay project-agnostic.
- `prompts/` — The three phase prompts. These are the most critical files. They control agent behavior.
- `context_template.md`, `task_list_template.md`, `review_plan_guideline_template.md`, `review_impl_guideline_template.md` — Templates users copy and customize. Keep generic.
- `context.md`, `task_list.md`, `review_plan_guideline.md`, `review_impl_guideline.md` — Project-specific, gitignored. Not part of this repo's source. `context.md` is the project environment; `task_list.md` is the per-task work.

## Editing Prompts

The prompts in `prompts/` are the most sensitive files in this repo. When editing them:

- **Critical instructions go at the top AND bottom.** Agents are more likely to follow instructions at the beginning and end of a prompt (primacy/recency effect).
- **Use MUST, not "should" or "please".** Soft language gets ignored in autonomous runs.
- **Be explicit about file paths.** Don't say "save the results" — say "write to `autodolist-results/<task_name>/results/pass_<N>_*`".
- **Include a checklist at the end.** The closing checklist is the last thing the agent sees before deciding whether to stop.
- **Keep the three phases independent.** Each phase runs as a separate Claude session with no shared memory. All communication happens through files in `autodolist-results/`. Never assume one phase knows what another did — only what it can read from disk.

## Key Design Decisions

1. **Three separate sessions, not one long session.** Planning, execution, and merge run as separate sessions. This prevents context window degradation during implementation (which generates the most output). The cost is that context must be re-read from files, but this is deliberate — it forces clear documentation.

2. **File-based communication.** `autodolist-results/current_task.md` and `autodolist-results/<task_name>/plan.md` are the contracts between the planning phase and the execution phase. If you change the expected format of these files, update all prompts that read them.

3. **Task list as source of truth.** `task_list.md` — with its fixed `## Task N` / `### Task Description` / `### Pass Criteria` structure — is what Phase 1 consults to decide what to do next. Do NOT invent new task structure; the prompts and future tooling depend on the canonical layout. `context.md` holds stable project environment (setup, constraints) and does not contain tasks.

4. **Commit then revert on failure.** Failed task attempts are committed before being reverted. This preserves the work in git history so it can be recovered or learned from, while keeping the branch tip clean for the next iteration.

5. **Two review guidelines, three review moments.** `review_plan_guideline.md` governs the pre-implementation plan review inside Phase 1 (iterative, by the main agent). `review_impl_guideline.md` governs impl reviews in both Phase 2 (iterative, scoped to `base.sha..HEAD`) and Phase 3 (binary gate, scoped to the PR-style diff `pre_merge_main.sha..HEAD`, and only when `main` advanced). Phase 2 is iterative because the main agent has implementation context and can accept or reject findings with reasoning — those decisions are recorded in `report.md`'s Review Points section. Phase 3 cross-references that section to avoid rubber-stamping and to avoid re-litigating already-settled issues.

6. **Merge phase re-verifies on divergence AND cross-references Phase 2.** If `main` moved while the workspace was working a task, merging may invalidate pass criteria or surface new impl concerns. Phase 3 therefore re-runs every pass criterion AND obtains a fresh impl review; before deciding push/reset it cross-references the reviewer's findings against Phase 2's Review Points (accepted / rejected / why). Push to `main` only happens when both gates hold after cross-reference.

7. **Proposed Tasks is the agent's suggestion channel.** Phases 2 and 3 end with an explicit step to append follow-up task ideas to `task_list.md`'s Proposed Tasks section, checking existing numbered tasks AND existing proposals to avoid duplicates. Users promote proposals manually (or delete them); agents never promote on their own.

## Testing Changes

There are no automated tests. To verify changes to the framework:

1. Symlink into a project with a working `context.md` (including a 3-task Task List)
2. Run `bash autodolist/run.sh 1` for a single iteration
3. Check that `autodolist-results/` contains: `current_task.md`, `log.md`, and a task directory with `plan.md`, `report.md`, and `results/`
4. Check that git commits were created (and reverted if the task failed)
5. Check that nothing under `autodolist-results/` was committed
6. If `main` is configured as a remote, check the merge phase's behavior with and without divergence

## Common Pitfalls

- **Don't add project-specific content to `autodolist_context.md` or the prompts.** These are shared across all projects. Project-specific environment goes in `context.md`; the task list goes in `task_list.md`.
- **Don't assume the agent will read files it wasn't told to read.** If a prompt needs information from a file, it must explicitly say "Read file X".
- **Don't merge the planning and execution phases.** The three-phase split is load-bearing. The execution phase generates too much output (builds, test runs, verification) to share a session with analysis and planning.
- **`autodolist-results/` lives in the target project, not here.** This repo is the framework. Results are created in whatever project the user symlinks this into.
