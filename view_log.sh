#!/bin/bash
# Usage: bash autoopt/view_log.sh [-v] <file.log>
# Or:   tail -f <file.log> | bash autoopt/view_log.sh [-v]
#
# Converts stream-json output into readable text.
# Default: agent messages only. -v: include tool calls and results.

set -euo pipefail

VERBOSE=false
FILE=""
for arg in "$@"; do
  case "$arg" in
    -v) VERBOSE=true ;;
    *)  FILE="$arg" ;;
  esac
done

TS='(.timestamp // "" | if . != "" then split("T")[1] | split(".")[0] else "" end)'

# Post-processor: tracks last timestamp from @TS@ markers, injects into ─── lines
MERGE_TS='{ if (/^@TS@/) { ts = substr($0, 5); next } if (/^───$/ && ts != "") { print "─── " ts; ts = "" } else { print } }'

if $VERBOSE; then
  FILTER='
    if .type == "system" and .subtype == "init" then
      "═══ Session \(.session_id[:8]) | model: \(.model) ═══\n"

    elif .type == "assistant" then
      [.message.content[] |
        if .type == "text" then
          .text
        elif .type == "tool_use" then
          "→ \(.name)(\(.input | to_entries | map("\(.key)=\(.value | tostring | if length > 100 then .[:100] + "..." else . end)") | join(", ")))"
        else empty
        end
      ] | join("\n") | if . == "" then empty else "───\n\(.)" end

    elif .type == "user" then
      ('"$TS"') as $ts |
      [.message.content[] |
        if .type == "tool_result" then
          if (.content | length) > 500 then
            "  ← \(.content[:500])..."
          else
            "  ← \(.content)"
          end
        else empty
        end
      ] | join("\n") | if $ts != "" then "@TS@\($ts)\n\(.)" else . end

    elif .type == "result" then
      "\n═══ \(.subtype) | \(.duration_ms/1000)s | $\(.total_cost_usd | tostring[:6]) | \(.num_turns) turns ═══"

    else empty
    end
  '
else
  FILTER='
    if .type == "system" and .subtype == "init" then
      "═══ Session \(.session_id[:8]) | model: \(.model) ═══"

    elif .type == "assistant" then
      [.message.content[] |
        if .type == "text" then .text
        else empty
        end
      ] | join("\n") | if . == "" then empty else "───\n\(.)" end

    elif .type == "user" and .timestamp then
      "@TS@\(.timestamp | split("T")[1] | split(".")[0])"

    elif .type == "result" then
      "\n═══ \(.subtype) | \(.duration_ms/1000)s | $\(.total_cost_usd | tostring[:6]) | \(.num_turns) turns ═══"

    else empty
    end
  '
fi

if [ -n "$FILE" ]; then
  cat "$FILE" | jq -r --unbuffered "$FILTER" | awk "$MERGE_TS"
else
  jq -r --unbuffered "$FILTER" | awk "$MERGE_TS"
fi
