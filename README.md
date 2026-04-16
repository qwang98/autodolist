# AutoDolist

Automated task-execution loop powered by Claude. Symlink this into any project, write a context file that declares a list of tasks with pass criteria, and let agents work through them: plan, implement, verify, merge, repeat.

Adapted from [autoopt](https://github.com/georgwiese/autoopt) (itself inspired by [autoresearch](https://github.com/karpathy/autoresearch) and [Anthropic's C compiler experiment](https://www.anthropic.com/engineering/building-c-compiler)). AutoDolist swaps AutoOpt's metric-driven optimization loop for a user-defined task list.

## Quickstart

```bash
# 1. Clone this repo
git clone <repo-url> autodolist-repo
cd autodolist-repo

# 2. Symlink into your project
ln -s "$(pwd)" /path/to/your-project/autodolist

# 3. Create project-specific config
cd /path/to/your-project/autodolist
cp context_template.md context.md
cp task_list_template.md task_list.md
cp review_plan_guideline_template.md review_plan_guideline.md
cp review_impl_guideline_template.md review_impl_guideline.md

# 4. Edit context.md (project-wide setup and constraints) and
#    task_list.md (3 tasks, each with a Task Description and Pass Criteria)
$EDITOR context.md task_list.md

# 5. Optionally customize review_plan_guideline.md and review_impl_guideline.md for your domain

# 6. Run (from the target project; must be on a non-main branch)
cd /path/to/your-project
git checkout -b my-workspace    # if not already on a workspace branch
bash autodolist/run.sh          # default: 100 iterations
bash autodolist/run.sh 10       # or specify a count

# Optional: configure model and effort
EFFORT=high bash autodolist/run.sh
MODEL=sonnet bash autodolist/run.sh
FALLBACK_MODEL=sonnet bash autodolist/run.sh   # fallback when primary is overloaded
```

That's it. The agent will create `autodolist-results/` in your project directory and start working through the task list. Multiple workspaces (separate clones/branches) can run against the same `main` in parallel — the merge phase serializes them.

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- The `claude` command must be available in PATH

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `EFFORT` | `max` | Claude effort level (`low`, `medium`, `high`, `max`) |
| `MODEL` | *(default)* | Model to use (e.g., `sonnet`, `opus`) |
| `FALLBACK_MODEL` | *(none)* | Fallback model when primary is overloaded |

## How It Works

Each iteration runs three separate Claude sessions:

### Phase 1: Generate & Plan

The agent reads `task_list.md` and the history in `autodolist-results/log.md`, picks the next task that hasn't succeeded yet, and writes `autodolist-results/current_task.md` (the task description + pass criteria copied verbatim). It then designs a detailed implementation plan. The plan is reviewed by a sub-agent against the review guideline and iterated until approved.

### Phase 2: Execute Plan

The agent captures the pre-implementation HEAD as `base.sha`, implements the plan, then runs an **impl review loop** with a subagent against `review_impl_guideline.md`. The main agent accepts or rejects each finding; the loop exits when the reviewer is satisfied OR every new finding has been rejected. After that, pass criteria are run in a **retry loop** (max 3 fix attempts); if they still fail the task is marked failed and reverted. The report includes a "Review Points" section documenting every finding and decision. Any follow-up ideas are appended to `task_list.md`'s Proposed Tasks section (de-duplicated).

### Phase 3: Merge to Main

The agent fetches the latest `main`. If `main` advanced, it merges `main` in, re-runs every pass criterion, and obtains an impl review on the task's PR-style diff (`pre_merge_main.sha..HEAD`). Before deciding, the agent cross-references the reviewer's findings against Phase 2's Review Points in `report.md` — Phase 2 already settled certain issues with implementation context, so Phase 3 doesn't re-litigate them but also doesn't rubber-stamp. Only if every pass criterion still passes AND (when a merge occurred) no blocker stands after cross-reference does it push to `main`. Otherwise the merge is reset. At the end, follow-up ideas are appended to `task_list.md`'s Proposed Tasks section.

### Communication Between Phases

The three phases are independent Claude sessions with no shared context. They communicate entirely through files in `autodolist-results/`:

```
autodolist-results/
  current_task.md        # Selected task (description + pass criteria copied from task_list.md) — written by phase 1, read by phases 2 & 3
  log.md                 # Append-only history of task attempts — read by phase 1, appended by phases 2 & 3
  2026-04-15-1430-foo/
    plan.md              # Implementation plan for the current task — written by phase 1, read by phases 2 & 3
    base.sha             # Pre-implementation HEAD — written by phase 2, used to scope phase 2's impl review diff
    diff.patch           # Task-scoped diff for the current impl review — written by phase 2, overwritten by phase 3 if main advanced
    report.md            # Execution report (incl. Review Points section) — written by phase 2, read by phase 3
    results/             # Per-attempt pass-criterion outputs from phase 2, plus post-merge re-verification and impl-review output from phase 3 when main advanced
    pre_merge_main.sha   # Tip of origin/main at merge time — written by phase 3 only when main advanced
```

### Logging

All output is logged to `autodolist-results/logs/`. The terminal shows progress, including the task summary between phases:

```
========================================
[Fri Apr 15 19:20:08 CEST 2026] Iteration 1 / 100
========================================
[Fri Apr 15 19:20:08 CEST 2026] Generate & Plan → autodolist-results/logs/20260415-192008-1-1-plan.log
----------------------------------------
# 2026-04-15-1920-add-user-login
## Task Description
...
## Pass Criteria
...
----------------------------------------
[Fri Apr 15 19:49:58 CEST 2026] Do Plan → autodolist-results/logs/20260415-192008-1-2-do.log
[Fri Apr 15 20:05:14 CEST 2026] Merge Main → autodolist-results/logs/20260415-192008-1-3-merge.log
```

Each step's full output is saved as stream-json:

- `run.log` — the bash script's own output (all iterations)
- `<timestamp>-<iteration>-1-plan.log` — Generate & Plan session
- `<timestamp>-<iteration>-2-do.log` — Execute Plan session
- `<timestamp>-<iteration>-3-merge.log` — Merge to Main session

To watch a running session in readable form:

```bash
tail -f autodolist-results/logs/20260415-192008-1-1-plan.log | bash autodolist/view_log.sh
```

Or read a completed session:

```bash
bash autodolist/view_log.sh autodolist-results/logs/20260415-192008-1-1-plan.log
```

Each session is also named (e.g., "autodolist #3: Generate & Plan") so they appear in `claude --resume`.

### Error Handling

If a phase hits a rate limit, the script extracts the reset timestamp from the output, sleeps until credits are available, and resumes the same session (preserving all context). For other failures, it retries after 60 seconds with a fresh session.

## File Reference

### Checked into this repo (framework)

| File | Description |
|------|-------------|
| `run.sh` | Bash loop that drives the three phases |
| `view_log.sh` | Converts stream-json logs to readable text |
| `autodolist_context.md` | Generic framework documentation read by all agents |
| `context_template.md` | Template for project-wide context (setup, constraints) |
| `task_list_template.md` | Template for the ordered task list (3 tasks, each with Task Description and Pass Criteria) |
| `review_plan_guideline_template.md` | Template for plan review guidelines (Phase 1) |
| `review_impl_guideline_template.md` | Template for implementation review guidelines (Phase 3, post-merge) |
| `prompts/generate_plan.md` | Prompt for phase 1 (Generate & Plan) |
| `prompts/do_plan.md` | Prompt for phase 2 (Execute Plan) |
| `prompts/merge_main.md` | Prompt for phase 3 (Merge to Main) |

### Created per project (gitignored)

| File | Description |
|------|-------------|
| `context.md` | Your project-wide context (setup, constraints) |
| `task_list.md` | Your ordered task list |
| `review_plan_guideline.md` | Your project-specific plan review criteria |
| `review_impl_guideline.md` | Your project-specific implementation review criteria |

### Created at runtime in project dir

| Path | Description |
|------|-------------|
| `autodolist-results/current_task.md` | Current task |
| `autodolist-results/log.md` | Full task-attempt history |
| `autodolist-results/<task>/plan.md` | Approved plan |
| `autodolist-results/<task>/base.sha` | Pre-implementation HEAD captured by phase 2; defines phase 2's impl review diff scope |
| `autodolist-results/<task>/diff.patch` | Task-scoped diff for the current impl review (phase 2 writes, phase 3 overwrites if main advanced) |
| `autodolist-results/<task>/report.md` | Execution report including Review Points section |
| `autodolist-results/<task>/results/` | Per-attempt pass-criterion outputs; phase-3 post-merge and impl-review outputs when main advanced |
| `autodolist-results/<task>/pre_merge_main.sha` | Tip of origin/main at merge time (phase 3 only, when main advanced) |
| `autodolist-results/logs/` | Script and claude session logs |
