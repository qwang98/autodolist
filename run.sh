#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
MAX_ITERATIONS=${1:-100}
EFFORT=${EFFORT:-max}
MODEL=${MODEL:-}
FALLBACK_MODEL=${FALLBACK_MODEL:-}
RETRY_DELAY=60

cd "$PROJECT_DIR"
mkdir -p autoopt-results/logs

# Log bash script output
RUN_LOG="autoopt-results/logs/run.log"
exec > >(tee -a "$RUN_LOG") 2>&1

run_step() {
  local prompt_file="$1" step_name="$2" iteration="$3" log_name="$4"
  local log_file="autoopt-results/logs/${log_name}.log"
  local session_id=""

  local base_flags=(--dangerously-skip-permissions --effort "$EFFORT" --output-format stream-json --verbose)
  [[ -n "$MODEL" ]] && base_flags+=(--model "$MODEL")
  [[ -n "$FALLBACK_MODEL" ]] && base_flags+=(--fallback-model "$FALLBACK_MODEL")

  while true; do
    echo "[$(date)] $step_name → $log_file"

    if [[ -n "$session_id" ]]; then
      # Resume the rate-limited session
      claude --resume "$session_id" -p "Continue. You were interrupted by a rate limit." \
        "${base_flags[@]}" >> "$log_file" 2>&1 || true
    else
      claude -p "$(cat "$prompt_file")" --name "autoopt #$iteration: $step_name" \
        "${base_flags[@]}" > "$log_file" 2>&1 || true
    fi

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

  if [[ -f autoopt-results/task.md ]]; then
    echo "----------------------------------------"
    cat autoopt-results/task.md
    echo "----------------------------------------"
  fi

  run_step "$SCRIPT_DIR/prompts/do_task.md"        "Do Task"        "$i" "${TIMESTAMP}-${i}-2-do"
done
