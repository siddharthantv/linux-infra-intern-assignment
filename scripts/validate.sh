#!/usr/bin/env bash
# validate.sh - Validates the infra-demo provisioning.
# Exits 0 if all checks pass, non-zero if any fail.

set -uo pipefail

APP_USER="infra-demo"
OPS_USER="opsadmin"
APP_DIR="/opt/infra-demo"
CONF_DIR="/etc/infra-demo"
LOG_DIR="/var/log/infra-demo"
DEMO_PORT="8080"

PASS=0
FAIL=0

ok()   { echo "[PASS] $1"; PASS=$((PASS+1)); }
bad()  { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }
info() { echo "[INFO] $1"; }

echo "===================================================="
echo " infra-demo Validation - $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "===================================================="

# ---------- 1. Service status ----------
echo ""
echo "--- Service Status ---"
if systemctl is-active --quiet infra-demo; then
    ok "infra-demo service is active"
else
    bad "infra-demo service is NOT active"
fi

if systemctl is-enabled --quiet infra-demo; then
    ok "infra-demo service is enabled (will start on boot)"
else
    bad "infra-demo service is NOT enabled"
fi

if systemctl is-active --quiet infra-maintenance.timer; then
    ok "infra-maintenance.timer is active"
else
    bad "infra-maintenance.timer is NOT active"
fi

if systemctl is-enabled --quiet infra-maintenance.timer; then
    ok "infra-maintenance.timer is enabled"
else
    bad "infra-maintenance.timer is NOT enabled"
fi

# ---------- 2. HTTP health check ----------
echo ""
echo "--- HTTP Health Check ---"
# Write body to a temp file so we can inspect it separately from the status code.
HEALTH_RESPONSE=$(curl -s -o /tmp/health_body.$$ -w "%{http_code}" "http://localhost:${DEMO_PORT}/health" || echo "000")

if [ "$HEALTH_RESPONSE" = "200" ]; then
    ok "GET /health returned HTTP 200"
    if grep -q '"status": "ok"' /tmp/health_body.$$; then
        ok "Health response contains status:ok"
    else
        bad "Health response missing status:ok"
    fi
else
    bad "GET /health returned HTTP $HEALTH_RESPONSE (expected 200)"
fi
rm -f /tmp/health_body.$$

# ---------- 3. Open ports ----------
echo ""
echo "--- Open Ports ---"
if ss -tulpn | grep -q ":${DEMO_PORT}"; then
    ok "Port ${DEMO_PORT} is listening"
else
    bad "Port ${DEMO_PORT} is NOT listening"
fi

if ss -tulpn | grep -q ":22"; then
    ok "Port 22 (SSH) is listening"
else
    bad "Port 22 (SSH) is NOT listening"
fi

info "Full listening ports:"
ss -tulpn | grep LISTEN

# ---------- 4. Firewall ----------
echo ""
echo "--- Firewall (ufw) ---"
UFW_STATUS=$(ufw status | head -1)
if echo "$UFW_STATUS" | grep -q "active"; then
    ok "ufw is active"
else
    bad "ufw is NOT active"
fi

if ufw status | grep -qE "8080.*ALLOW"; then
    ok "ufw allows port 8080"
else
    bad "ufw does not allow port 8080"
fi

if ufw status | grep -qE "(22|OpenSSH).*ALLOW"; then
    ok "ufw allows SSH"
else
    bad "ufw does not allow SSH"
fi

# ---------- 5. Users ----------
echo ""
echo "--- Users ---"
if id "$APP_USER" &>/dev/null; then
    ok "Service user '$APP_USER' exists"
    SHELL_PATH=$(getent passwd "$APP_USER" | cut -d: -f7)
    if [ "$SHELL_PATH" = "/usr/sbin/nologin" ] || [ "$SHELL_PATH" = "/bin/false" ]; then
        ok "Service user '$APP_USER' has no login shell"
    else
        bad "Service user '$APP_USER' has unexpected shell: $SHELL_PATH"
    fi
else
    bad "Service user '$APP_USER' does NOT exist"
fi

if id "$OPS_USER" &>/dev/null; then
    ok "Ops user '$OPS_USER' exists"
    if id -nG "$OPS_USER" | grep -qw sudo; then
        ok "Ops user '$OPS_USER' is in sudo group"
    else
        bad "Ops user '$OPS_USER' is NOT in sudo group"
    fi
else
    bad "Ops user '$OPS_USER' does NOT exist"
fi

# ---------- 6. File permissions ----------
echo ""
echo "--- File Permissions ---"

# Checks both owner and octal permissions in one stat call.
check_owner_perm() {
    local path="$1" expected_owner="$2" expected_perm="$3"
    if [ ! -e "$path" ]; then
        bad "$path does not exist"
        return
    fi
    local actual
    actual=$(stat -c "%U %a" "$path")
    if [ "$actual" = "$expected_owner $expected_perm" ]; then
        ok "$path has correct owner/permissions ($actual)"
    else
        bad "$path has owner/permissions '$actual', expected '$expected_owner $expected_perm'"
    fi
}

check_owner_perm "$APP_DIR" "$APP_USER" "750"
check_owner_perm "$APP_DIR/infra-demo.py" "$APP_USER" "750"
check_owner_perm "$CONF_DIR/infra-demo.env" "root" "640"
check_owner_perm "$LOG_DIR" "$APP_USER" "750"

# ---------- 7. Logs ----------
echo ""
echo "--- Logs ---"
RECENT_LOGS=$(journalctl -u infra-demo --no-pager -n 30 2>/dev/null)
if [ -n "$RECENT_LOGS" ]; then
    ok "journalctl has recent logs for infra-demo"
    info "Last 5 log lines:"
    echo "$RECENT_LOGS" | tail -5
else
    bad "No recent logs found for infra-demo in journalctl"
fi

if [ -f "$LOG_DIR/infra-demo.log" ]; then
    ok "Application log file exists at $LOG_DIR/infra-demo.log"
else
    bad "Application log file missing at $LOG_DIR/infra-demo.log"
fi

# ---------- 8. Reboot info ----------
echo ""
echo "--- System Uptime ---"
uptime

# ---------- Summary ----------
echo ""
echo "===================================================="
echo " RESULT: $PASS passed, $FAIL failed"
echo "===================================================="

if [ "$FAIL" -eq 0 ]; then
    exit 0
else
    exit 1
fi
