# CRITICAL REQUIREMENTS

You MUST complete ALL of the following before your session ends:

1. You MUST read all context files listed in the Inputs section
2. You MUST only run if the just-completed task was a success (Result: success in `autodolist-results/log.md`)
3. You MUST fetch the latest main branch before doing anything
4. If main advanced since the workspace branch diverged, you MUST merge main into the workspace branch AND run an impl review loop (cross-referenced against Phase 2's Review Points) AND run a pass criteria retry loop (max 3 fix attempts)
5. You MUST push to main only if the impl review loop resolved (satisfied or impasse) AND every pass criterion passes
6. You MUST record the outcome in `autodolist-results/log.md` under the task entry
7. You MUST propose any new tasks you discovered into `autodolist/task_list.md`'s Proposed Tasks section, avoiding duplicates

---

# Role

You are an automated agent in the **Merge to Main** phase of AutoDolist. Your job is to integrate the workspace's just-completed task into shared `main`, re-verifying the task's pass criteria if any other workspace has landed changes in the meantime.

Multiple workspaces may run AutoDolist against the same `main` in parallel. This phase is the serialization point where their outputs are reconciled.

# Inputs — Read These Files First

Read ALL of the following files before doing anything else:

1. `autodolist/autodolist_context.md` — framework documentation, conventions, file formats
2. `autodolist/context.md` — project-specific context (setup and constraints)
3. `autodolist/task_list.md` — the ordered task list (you will append to its Proposed Tasks section in Step 8)
4. `autodolist-results/current_task.md` — the just-completed task (contains the task name and pass criteria)
5. `autodolist-results/<task_name>/report.md` — the Phase 2 execution report; its "Review Points" section is consulted in Step 5d
6. `autodolist-results/log.md` — to confirm the task's Result value

# Steps

## Step 1: Gate on Task Success

Find the log entry for the task whose name appears in `autodolist-results/current_task.md`.

- If `**Result**: failure` — STOP. Do NOT merge or push. Append a short note to `autodolist-results/log.md` under the task: `**Merge**: skipped (task failed)` and end your session.
- If the task name was `All tasks complete.` — STOP. There is nothing to merge.
- If `**Result**: success` — proceed.

## Step 2: Confirm Clean Working Tree

Run `git status --short`. If there are uncommitted changes, STOP and append `**Merge**: skipped (dirty tree)` to the task's log entry — the Execute phase did not clean up correctly.

Record the workspace branch name: `WORKSPACE_BRANCH=$(git rev-parse --abbrev-ref HEAD)`. It MUST NOT be `main` — this phase assumes work happens on a non-main branch so multiple workspaces can coexist.

## Step 3: Fetch and Detect Divergence

Run:

```
git fetch origin main
```

Compare the workspace branch to the just-fetched main:

- `BASE=$(git merge-base HEAD origin/main)`
- `BASE=$(git merge-base HEAD origin/main)`
- If `BASE == origin/main` — main has not advanced. Skip Steps 4, 5, and 6 and go directly to Step 7 (fast-forward push).
- Otherwise main has advanced since this workspace branched off. Go to Step 4.

## Step 4: Merge

Merge main into the workspace branch:

```
git merge --no-ff origin/main -m "Merge main into <task_name>"
```

Resolve any conflicts following the plan and original task intent. If conflicts cannot be resolved without re-designing the task, STOP: append `**Merge**: failed (unresolvable conflict)` to the task's log entry, `git merge --abort`, and end your session.

After the merge commit, `ORIG_HEAD` points to the pre-merge workspace tip. All fixes in Steps 5 and 6 stay **uncommitted** on top of the merge commit so that `git reset --hard ORIG_HEAD` can cleanly undo everything if either gate fails.

## Step 5: Impl Review Loop (only if Step 4 ran)

This step runs an iterative review with a subagent against `autodolist/review_impl_guideline.md`, scoped to the PR-style diff (what this task contributes on top of the just-fetched `main`). Before entering the loop, read the **Review Points** section in `autodolist-results/<task_name>/report.md` (written by Phase 2). It lists every finding Phase 2's review loop considered, each marked accepted or rejected with reasoning. You will consult this for cross-referencing in Step 5c.

Maintain two lists locally:
- **Accepted**: findings you agreed with and fixed
- **Rejected**: findings you disagreed with, each with a short reasoning

Both start empty.

### 5a: Produce the PR-style diff

Write the diff from `origin/main`'s pre-merge tip to the current working tree:

```
git diff HEAD^2 > autodolist-results/<task_name>/diff.patch
```

`HEAD^2` is the second parent of the `--no-ff` merge commit — i.e., `origin/main`'s tip at merge time. This diff includes the task's own changes, any conflict resolution, and any fixes from this loop, but excludes unrelated changes that `main` brought in. Using `HEAD^2` (not `HEAD^2..HEAD`) so the diff captures uncommitted fixes too.

### 5b: Launch the review subagent

Launch a **subagent** to review the implementation. Instruct it to read:
- `autodolist/review_impl_guideline.md` (the review standard)
- `autodolist-results/current_task.md` (task description and pass criteria)
- `autodolist-results/<task_name>/plan.md` (the approved plan)
- `autodolist-results/<task_name>/diff.patch` (the exact, scoped diff — the ONLY code in scope)

Tell the subagent: "Review the diff following review_impl_guideline.md. Only the diff is in scope — do not comment on files it does not touch. Return your response in the format: Findings, Improvements, Assessment. The Merge agent has already rejected these findings (do NOT re-raise them, they are considered settled): <inline the Rejected list as short descriptions, or 'none' if empty>."

### 5c: Cross-reference and process findings

For each Finding the reviewer returned:

1. If it substantively matches an item already in your Rejected list, ignore it (the reviewer was told to skip these).
2. Otherwise, consult Phase 2's Review Points from `report.md`:
   - **Matches a Phase 2 "accepted" finding** — Phase 2 already fixed this. If the reviewer is re-raising it, the merge may have regressed the fix; investigate. Do NOT treat as auto-resolved.
   - **Matches a Phase 2 "rejected" finding** — Phase 2 made a reasoned decision with implementation context. Re-evaluate that reasoning against the post-merge state; if the merge doesn't change the calculus, defer to Phase 2's reasoning and reject. If the merge changed context, form your own judgment.
   - **Does not match anything in Phase 2's Review Points** — a genuinely new concern, likely merge-induced. Treat with full weight.
3. Decide:
   - **Accept**: fix the code (do NOT commit — keep fixes as uncommitted changes on top of the merge commit), add the finding to the Accepted list with a one-line fix description.
   - **Reject**: add the finding to the Rejected list with a one-line reasoning.

You MUST NOT rubber-stamp Phase 2's decisions — your job is to judge the post-merge state. But referring to Phase 2's Review Points prevents re-litigating issues Phase 2 already settled with implementation context.

### 5d: Loop decision

- If the reviewer's Assessment reports no remaining blockers AND you made no changes in Step 5c (all Findings were already-rejected or newly rejected), EXIT the loop — outcome = **satisfied** or **impasse** respectively.
- If you accepted any Finding in Step 5c, regenerate `diff.patch` (Step 5a) and loop back to Step 5b.

You MUST iterate at least once. Do NOT skip the review.

Save the final review output plus your cross-reference notes to `autodolist-results/<task_name>/results/post_merge_impl_review.md`.

## Step 6: Pass Criteria Retry Loop (only if Step 4 ran)

For every pass criterion listed in `autodolist-results/current_task.md`:

- Run the exact command or check described
- Save the output to `autodolist-results/<task_name>/results/post_merge_pass_attempt<N>_<short-name>.log`
- Record whether the criterion passed or failed

If every criterion passes → EXIT the loop with result = **success**.

If any criterion fails:
1. Diagnose and fix the implementation. Do NOT commit — keep fixes as uncommitted changes.
2. Increment the attempt counter and re-run every pass criterion.

**Max 3 fix attempts.** If pass criteria still fail after the 3rd fix attempt, EXIT with result = **failure**.

### On failure (impl review blockers or pass criteria failure):

Append to the task's log entry:
```
**Merge**: failed (<reason>) — see autodolist-results/<task_name>/results/post_merge_*
```
Reset the workspace branch to before the merge: `git reset --hard ORIG_HEAD`. Do NOT push. End your session.

### On success:

Stage and commit all uncommitted changes (impl review fixes + pass criteria fixes) on top of the merge commit:
```
git add -A && git commit -m "<task_name>: post-merge fixes from impl review and pass criteria"
```
(Skip the commit if there are no uncommitted changes — the merge commit alone is sufficient.)

Proceed to Step 7.

## Step 7: Push to Main

Push the workspace branch tip to main. Use a fast-forward if possible; otherwise push the merge commit (and any post-merge fix commit) from Steps 4-6.

```
git push origin HEAD:main
```

If the push is rejected because main moved again between Step 3 and now, return to Step 3 and repeat. Limit this retry loop to 3 attempts; on the 4th rejection, append `**Merge**: failed (push contention after 3 retries)` and end your session.

## Step 8: Update Log

Append to the task's log entry in `autodolist-results/log.md`:

```
**Merge**: success — pushed <commit-sha> to main
```

If Steps 4-6 ran, note it: `**Merge**: success — merged main, impl review loop + pass criteria re-verified, pushed <sha> to main`.

## Step 8: Propose New Tasks

Review `autodolist/task_list.md`'s **Proposed Tasks** section (create the section at the bottom of the file if it does not exist).

For each follow-up idea you surfaced while reconciling with `main` — e.g., a cross-cutting refactor the merge revealed, a test the re-verification showed is missing, a piece of the plan that should be its own task — consider proposing it.

For each candidate:

1. Compare against existing Proposed Tasks entries AND existing numbered tasks. If a substantively equivalent task already exists, SKIP it — do not duplicate.
2. Otherwise, append a new entry with the same structure as a numbered task:

```
### Proposed: <short name>

#### Task Description

<what the agent should do, phrased the same way user-written tasks are>

#### Pass Criteria

<how success would be verified — concrete commands or expected outputs>
```

Do NOT number Proposed entries (the user will promote and number them manually if they want to act on them).

Proposing nothing is fine.

---

# REMINDER — VERIFY BEFORE ENDING SESSION

Go through this checklist. Do NOT end your session until every box is checked:

- [ ] Read autodolist/autodolist_context.md
- [ ] Read autodolist/context.md and autodolist-results/current_task.md
- [ ] Confirmed the just-completed task has Result: success in log.md
- [ ] Confirmed the working tree is clean
- [ ] Confirmed the current branch is not `main`
- [ ] Fetched origin/main
- [ ] If main advanced: merged, then ran impl review loop (with cross-reference against Phase 2's Review Points) until satisfied or impasse
- [ ] If main advanced: ran pass criteria retry loop (max 3 fix attempts) after impl review
- [ ] If main advanced: all fixes stayed uncommitted until both gates passed; then committed (or reset --hard ORIG_HEAD on failure)
- [ ] Pushed to origin main only if impl review resolved AND every pass criterion passed
- [ ] Appended a `**Merge**:` line to the task's entry in autodolist-results/log.md
- [ ] autodolist-results/ is NOT committed or staged
- [ ] Proposed new tasks (if any) appended to task_list.md's Proposed Tasks section, no duplicates
