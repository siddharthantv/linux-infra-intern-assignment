#!/usr/bin/env bash
# infra-maintenance: periodic log cleanup and health snapshot
# Designed to run via systemd timer. Writes snapshots to health-snapshot.log.
set -euo pipefail

LOG_DIR="/var/log/infra-demo"
SNAPSHOT_FILE="${LOG_DIR}/health-snapshot.log"
MAX_LOG_AGE_DAYS=7

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Running infra-maintenance"

# Trim main log to last 1000 lines if it exceeds 5 MB.
# Write to tmp first to avoid an empty-log window on interrupt.
MAIN_LOG="${LOG_DIR}/infra-demo.log"
if [ -f "$MAIN_LOG" ] && [ "$(stat -c%s "$MAIN_LOG")" -gt 5242880 ]; then
    tail -n 1000 "$MAIN_LOG" > "${MAIN_LOG}.tmp"
    mv "${MAIN_LOG}.tmp" "$MAIN_LOG"
    echo "Trimmed ${MAIN_LOG} to last 1000 lines"
fi

# Delete rotated log files (*.log.*) beyond the retention window.
# '|| true' prevents set -e from aborting if no files match.
find "$LOG_DIR" -name "*.log.*" -mtime "+${MAX_LOG_AGE_DAYS}" -delete 2>/dev/null || true

# Append one snapshot entry. Brace block keeps fields grouped in a single write.
{
    echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if curl -sf http://localhost:8080/health >/dev/null; then
        echo "health_endpoint=ok"
    else
        echo "health_endpoint=fail"
    fi
    echo "service_active=$(systemctl is-active infra-demo)"
} >> "$SNAPSHOT_FILE"

echo "Maintenance complete"
