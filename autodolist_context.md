# AutoDolist Framework

AutoDolist is an automated task-execution harness. It uses AI agents to work through a user-defined task list, one task at a time, verifying each against its pass criteria before moving on.

## How It Works

Each iteration has three phases, each run as a separate agent session:

1. **Generate & Plan** — Read the task list, pick the next task that has not yet succeeded, and produce a reviewed implementation plan.
2. **Execute Plan** — Implement the approved plan, run an impl review loop with a subagent until satisfied or all findings rejected, run the task's pass criteria in a retry loop (max 3 fix attempts), and commit (or commit-and-revert on failure). Propose any follow-up tasks into `task_list.md`'s Proposed Tasks section.
3. **Merge to Main** — Merge the latest `main` into the workspace branch; when `main` advanced, re-verify pass criteria and run an impl review scoped to the task's PR-style diff, cross-referenced against Phase 2's Review Points. Push to `main` if both gates still hold. Propose any follow-up tasks into `task_list.md`'s Proposed Tasks section.

The phases communicate through files in `autodolist-results/`. Each phase reads the outputs of previous phases and writes its own outputs.

## Directory Structure

### Static files (`autodolist/`)

These files are part of the framework and do not change during a run:

- `autodolist_context.md` — This file. Generic framework documentation.
- `context_template.md`, `task_list_template.md`, `review_plan_guideline_template.md`, `review_impl_guideline_template.md` — Templates users copy and fill in.
- `context.md` — Project-wide context: setup and constraints.
- `task_list.md` — The ordered task list.
- `review_plan_guideline.md` — Guidelines for the Phase 1 plan review sub-agent.
- `review_impl_guideline.md` — Guidelines for the Phase 3 post-merge implementation review sub-agent. Scoped to the current task's diff only.
- `prompts/` — The three prompt files, one per phase.

### Dynamic files (`autodolist-results/`)

Created and updated during runs:

- `current_task.md` — The selected task for this iteration (overwritten each iteration).
- `log.md` — Append-only log of all completed task attempts and merges.
- `<task_name>/` — One directory per task attempt:
  - `plan.md` — Implementation plan (reviewed and approved in Phase 1).
  - `base.sha` — Workspace-branch HEAD captured by Phase 2 at the start of implementation. Defines the base of Phase 2's implementation diff.
  - `report.md` — Final detailed report with per-criterion outcomes and a "Review Points" section recording Phase 2's impl review decisions.
  - `results/` — Per-attempt pass-criterion output artifacts and (when Phase 3 merges) post-merge re-verification output and the impl review output.
  - `pre_merge_main.sha` — Tip of `origin/main` as of the merge, captured by Phase 3 only when `main` advanced. Defines the base of the task's PR-style diff.
  - `diff.patch` — Task-scoped diff for the current review. In Phase 2 this is `base.sha..HEAD`; in Phase 3 (when `main` advanced) it is rewritten to `pre_merge_main.sha..HEAD`.

## Conventions

### Task List Format

`autodolist/task_list.md` is the source of truth for what to do. Every task MUST follow this structure:

```
## Task N: <short name>

### Task Description

<what to do>

### Pass Criteria

<how success is verified — prefer concrete commands and expected outputs>
```

Agents and scripts in this repo assume this layout. A task without both subsections cannot be processed.

The file has four sections after the numbered tasks, in this order: `## Proposed Tasks` → `## Failed` → `## Completed`. Agents stop scanning for eligible tasks when they reach `## Proposed Tasks`.

- **Proposed Tasks**: Phase 2 and Phase 3 agents append candidate tasks here when they surface follow-up work during implementation or merging. Each proposal uses the same `### Proposed: <short name>` / `#### Task Description` / `#### Pass Criteria` structure. Agents check existing entries (numbered tasks AND other proposals) before appending, to avoid duplicates. Users promote proposals to numbered tasks manually (or delete them).
- **Failed**: Tasks moved here after max retries or merge failure. Users can promote back to numbered tasks.
- **Completed**: Tasks moved here after successful merge. Append-only.

### Task Naming

Format for `<task_name>` directories: `YYYY-MM-DD-HHMM-descriptive-name`

Example: `2026-04-15-1430-add-user-login`

Use the current date and time when creating the task. The descriptive name should be kebab-case and derived from the short name in the Task List.

### Sequential Execution and Branch Tip

Tasks are attempted in list order. Each **successful** task becomes the new tip of the workspace branch; the next task builds on that tip. A **failed** task is committed (to preserve the work) then reverted, leaving the tip unchanged. This means:

- Successful tasks accumulate on the workspace branch.
- Failed attempts live in git history (recoverable via `git log --all`) but do not block the branch.
- The Generate phase re-examines `log.md` each iteration to decide whether to re-attempt a failed task or advance to the next one.

### Log Format

`autodolist-results/log.md` is append-only. Each task attempt adds one section:

```
## <task_name>

**Task**: <exact task name from the Task List, e.g., "Task 1: add user login">

**Result**: <success/failure>

**Summary**: <2-3 sentences on what was done and what was learned>
```

The Merge phase appends a `**Merge**:` line to the same entry once it runs.

### Commit Strategy

- Implementation changes are committed to the project's git repository on the **workspace branch** (not `main` directly).
- `autodolist-results/` is NEVER committed or staged.
- Commit messages should be descriptive. Multiple commits per task are fine.
- If a task does NOT satisfy all pass criteria:
  1. Commit the implementation anyway (preserving it in git history).
  2. Immediately `git revert` the commit(s).
  3. This keeps the branch tip unchanged while making the work recoverable.
- After the final commit for each task (whether successful or a revert), create a tag: `autodolist/<task_name>`.

### Workspaces and Main

Multiple workspaces (separate clones) may run AutoDolist against the same upstream `main`. Each workspace runs on its own branch. The Merge phase is the serialization point:

1. It fetches the latest `main`.
2. If `main` advanced since the workspace branched off, it merges `main` into the workspace branch, re-runs every pass criterion, writes the task's effective diff to `diff.patch`, and asks a subagent to review the diff against `review_impl_guideline.md`.
3. Only if every pass criterion still holds AND (when a merge occurred) the impl review approves does it push to `main`.

If either check fails, the workspace resets the merge and does not push; the next Generate iteration decides how to proceed. When `main` has NOT advanced, no merge, no impl review, no re-verification — the pre-existing pass criteria from Phase 2 are sufficient.
