#!/bin/bash
# =============================================================================
# X88 Pro RK3566 - Build Monitor
# =============================================================================
# Watches build_log.txt and writes a result to build_status.txt when done.
# Exits 0 on success, 1 on failure.
#
# Usage:
#   ./monitor_build.sh [LOG_FILE]
#   Default log: ~/workspace/x88pro-android16/build_log.txt
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${1:-$REPO_DIR/build_log.txt}"
STATUS_FILE="$REPO_DIR/build_status.txt"

# Wait for log file to appear (build may not have started yet)
echo "[monitor] Waiting for $LOG_FILE ..."
while [[ ! -f "$LOG_FILE" ]]; do
    sleep 5
done

echo "[monitor] Log found, monitoring build..."

# Tail the log and scan for terminal conditions
tail -n 0 -f "$LOG_FILE" | while IFS= read -r line; do
    # Success
    if echo "$line" | grep -q "build completed successfully"; then
        echo "SUCCESS" > "$STATUS_FILE"
        echo "$line" >> "$STATUS_FILE"
        echo "[monitor] BUILD SUCCESS"
        # Kill the tail process
        kill "$(ps -o ppid= -p $$)" 2>/dev/null
        exit 0
    fi

    # Failure patterns
    if echo "$line" | grep -qE "^FAILED:|ninja: build stopped|make\[1\].*Error [0-9]|Error: .* failed"; then
        echo "FAILURE" > "$STATUS_FILE"
        echo "$line" >> "$STATUS_FILE"
        # Capture last 30 lines of context
        echo "--- last 30 lines ---" >> "$STATUS_FILE"
        tail -n 30 "$LOG_FILE" >> "$STATUS_FILE"
        echo "[monitor] BUILD FAILED — details in $STATUS_FILE"
        kill "$(ps -o ppid= -p $$)" 2>/dev/null
        exit 1
    fi
done

# Read final status and exit accordingly
if [[ -f "$STATUS_FILE" ]]; then
    result=$(head -1 "$STATUS_FILE")
    if [[ "$result" == "SUCCESS" ]]; then
        exit 0
    else
        exit 1
    fi
fi

exit 1
