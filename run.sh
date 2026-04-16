#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
MAX_ITERATIONS=${1:-100}
EFFORT=${EFFORT:-max}
MODEL=${MODEL:-}
FALLBACK_MODEL=${FALLBACK_MODEL:-}
BASE_BRANCH=${BASE_BRANCH:-main}
RETRY_DELAY=60
PHASE_TIMEOUT=${PHASE_TIMEOUT:-3600}  # Wall-clock timeout per phase (seconds)

cd "$PROJECT_DIR"
mkdir -p autodolist-results/logs

# Log bash script output
RUN_LOG="autodolist-results/logs/run.log"
exec > >(tee -a "$RUN_LOG") 2>&1

cleanup_children() {
  local pid="$1"
  # Kill any orphaned child processes (background bash/sleep from agent sessions)
  local children
  children=$(pgrep -P "$pid" 2>/dev/null || true)
  if [[ -n "$children" ]]; then
    echo "[$(date)] Cleaning up orphaned child processes of PID $pid"
    kill $children 2>/dev/null || true
    sleep 1
    kill -9 $children 2>/dev/null || true
  fi
}

run_step() {
  local prompt_file="$1" step_name="$2" iteration="$3" log_name="$4"
  local log_file="autodolist-results/logs/${log_name}.log"
  local session_id=""

  local base_flags=(--dangerously-skip-permissions --effort "$EFFORT" --output-format stream-json --verbose)
  [[ -n "$MODEL" ]] && base_flags+=(--model "$MODEL")
  [[ -n "$FALLBACK_MODEL" ]] && base_flags+=(--fallback-model "$FALLBACK_MODEL")

  while true; do
    echo "[$(date)] $step_name → $log_file"

    local claude_pid=""
    if [[ -n "$session_id" ]]; then
      # Resume the rate-limited session
      timeout "$PHASE_TIMEOUT" claude --resume "$session_id" -p "Continue. You were interrupted by a rate limit." \
        "${base_flags[@]}" >> "$log_file" 2>&1 &
    else
      timeout "$PHASE_TIMEOUT" claude -p "$(printf 'BASE_BRANCH=%s\n\n%s' "$BASE_BRANCH" "$(cat "$prompt_file")")" --name "autodolist #$iteration: $step_name" \
        "${base_flags[@]}" > "$log_file" 2>&1 &
    fi
    claude_pid=$!
    wait "$claude_pid" || true

    # Clean up any orphaned child processes (background bash/sleep loops)
    cleanup_children "$claude_pid"

    # Check for rate limit rejection
    local last_result
    last_result=$(grep '"type":"result"' "$log_file" | tail -1)
    if grep -q '"status":"rejected"' "$log_file" && echo "$last_result" | grep -q '"is_error":true'; then
      session_id=$(echo "$last_result" | sed 's/.*"session_id":"\([^"]*\)".*/\1/')
      local resets_at
      resets_at=$(grep '"status":"rejected"' "$log_file" | tail -1 | sed 's/.*"resetsAt":\([0-9]*\).*/\1/')
      local now wait_secs
      now=$(date +%s)
      wait_secs=$(( resets_at - now + 60 ))
      if (( wait_secs > 0 )); then
        echo "[$(date)] $step_name rate-limited. Waiting ${wait_secs}s (until $(date -d "@$resets_at" 2>/dev/null || date -r "$resets_at" 2>/dev/null || echo "epoch $resets_at") + 60s)..."
        sleep "$wait_secs"
      fi
      continue
    fi

    # Check for success (result line exists and is not an error)
    if echo "$last_result" | grep -q '"type":"result"' && ! echo "$last_result" | grep -q '"is_error":true'; then
      break
    fi

    # Other failure — retry fresh
    session_id=""
    echo "[$(date)] $step_name failed, retrying in ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
  done
}

for i in $(seq 1 "$MAX_ITERATIONS"); do
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  echo "========================================"
  echo "[$(date)] Iteration $i / $MAX_ITERATIONS"
  echo "========================================"
  run_step "$SCRIPT_DIR/prompts/generate_plan.md" "Generate & Plan" "$i" "${TIMESTAMP}-${i}-1-plan"

  if [[ -f autodolist-results/current_task.md ]]; then
    echo "----------------------------------------"
    cat autodolist-results/current_task.md
    echo "----------------------------------------"
  fi

  # Stop cleanly once the Generate phase reports the task list is exhausted.
  if [[ -f autodolist-results/current_task.md ]] && grep -q '^All tasks complete\.$' autodolist-results/current_task.md; then
    echo "[$(date)] All tasks complete. Exiting."
    break
  fi

  run_step "$SCRIPT_DIR/prompts/do_plan.md"        "Do Plan"        "$i" "${TIMESTAMP}-${i}-2-do"
  run_step "$SCRIPT_DIR/prompts/merge_main.md"     "Merge Main"     "$i" "${TIMESTAMP}-${i}-3-merge"
done
