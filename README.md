# AutoOpt

Automated optimization loop powered by Claude. Symlink this into any project, write a context file describing what to optimize and how to measure it, and let agents iterate: analyze, plan, implement, measure, repeat.

Inspired by [autoresearch](https://github.com/karpathy/autoresearch) and [Anthropic's C compiler experiment](https://www.anthropic.com/engineering/building-c-compiler).

## Quickstart

```bash
# 1. Clone this repo
git clone <repo-url> autoopt-repo
cd autoopt-repo

# 2. Symlink into your project
ln -s "$(pwd)" /path/to/your-project/autoopt

# 3. Create project-specific config
cd /path/to/your-project/autoopt
cp context_template.md context.md
cp review_guideline_template.md review_guideline.md

# 4. Edit context.md — describe your optimization problem:
#    - How to build and set up
#    - What you're optimizing
#    - How to measure results (exact commands)
#    - How to profile
#    - What must not be changed
#    - What result files to collect
$EDITOR context.md

# 5. Optionally customize review_guideline.md for your domain

# 6. Run
cd /path/to/your-project
bash autoopt/run.sh        # default: 100 iterations
bash autoopt/run.sh 10     # or specify a count

# Optional: configure model and effort
EFFORT=high bash autoopt/run.sh
MODEL=sonnet bash autoopt/run.sh
FALLBACK_MODEL=sonnet bash autoopt/run.sh   # fallback when primary is overloaded
```

That's it. The agent will create `autoopt-results/` in your project directory and start optimizing.

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

Each iteration runs two separate Claude sessions:

### Phase 1: Generate & Plan

The agent reads all context and history, measures current performance, profiles the system, and generates several optimization ideas. It picks the most promising one, writes a task summary to `autoopt-results/task.md`, then designs a detailed implementation plan. The plan is reviewed by a sub-agent against the review guideline and iterated until approved.

On the first run, it also creates `autoopt-results/baseline/` with baseline measurements that all future results are compared against.

### Phase 2: Execute Task

The agent measures before, implements the plan, and measures after. It writes a detailed report with results compared to both the baseline and the previous task, appends a summary to the log, and commits the implementation. If the optimization didn't help, it commits anyway (preserving the work in git history) then reverts.

### Communication Between Phases

The two phases are independent Claude sessions with no shared context. They communicate entirely through files in `autoopt-results/`:

```
autoopt-results/
  baseline/              # Baseline measurements (created once)
  task.md                # Current task summary (written by phase 1, read by phase 2)
  log.md                 # Append-only history (read by phase 1, appended by phase 2)
  2026-04-10-1430-foo/
    plan.md              # Written by phase 1, read by phase 2
    report.md            # Written by phase 2
    results/             # Measurement artifacts from phase 2
```

### Logging

All output is logged to `autoopt-results/logs/`. The terminal shows progress, including the task summary between phases:

```
========================================
[Fri Apr 10 19:20:08 CEST 2026] Iteration 1 / 100
========================================
[Fri Apr 10 19:20:08 CEST 2026] Generate & Plan → autoopt-results/logs/20260410-192008-1-1-plan.log
----------------------------------------
# Task: Defer Round 0 D2H Synchronization
Task name: 2026-04-10-1933-defer-round0-d2h-sync
...
----------------------------------------
[Fri Apr 10 19:49:58 CEST 2026] Do Task → autoopt-results/logs/20260410-192008-1-2-do.log
```

Each step's full output is saved as stream-json:

- `run.log` — the bash script's own output (all iterations)
- `<timestamp>-<iteration>-1-plan.log` — Generate & Plan session
- `<timestamp>-<iteration>-2-do.log` — Execute Task session

To watch a running session in readable form:

```bash
tail -f autoopt-results/logs/20260410-192008-1-1-generate.log | bash autoopt/view_log.sh
```

Or read a completed session:

```bash
bash autoopt/view_log.sh autoopt-results/logs/20260410-192008-1-1-generate.log
```

Each session is also named (e.g., "autoopt #3: Generate Task") so they appear in `claude --resume`.

### Error Handling

If a phase hits a rate limit, the script extracts the reset timestamp from the output, sleeps until credits are available, and resumes the same session (preserving all context). For other failures, it retries after 60 seconds with a fresh session.

## File Reference

### Checked into this repo (framework)

| File | Description |
|------|-------------|
| `run.sh` | Bash loop that drives the two phases |
| `view_log.sh` | Converts stream-json logs to readable text |
| `autoopt_context.md` | Generic framework documentation read by all agents |
| `context_template.md` | Template for project-specific context |
| `review_guideline_template.md` | Template for plan review guidelines |
| `prompts/generate_plan.md` | Prompt for phase 1 (Generate & Plan) |
| `prompts/do_task.md` | Prompt for phase 2 (Execute Task) |

### Created per project (gitignored)

| File | Description |
|------|-------------|
| `context.md` | Your project-specific optimization context |
| `review_guideline.md` | Your project-specific review criteria |

### Created at runtime in project dir

| Path | Description |
|------|-------------|
| `autoopt-results/baseline/` | Baseline measurements |
| `autoopt-results/task.md` | Current task |
| `autoopt-results/log.md` | Full optimization history |
| `autoopt-results/<task>/plan.md` | Approved plan |
| `autoopt-results/<task>/report.md` | Results report |
| `autoopt-results/<task>/results/` | Measurement artifacts |
| `autoopt-results/logs/` | Script and claude session logs |
