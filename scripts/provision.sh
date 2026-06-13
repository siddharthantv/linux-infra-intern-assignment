#!/usr/bin/env bash
# provision.sh - Provisions the infra-demo server baseline.
# Idempotent: safe to run multiple times.

set -euo pipefail

# ---------- Configuration ----------
APP_USER="infra-demo"
APP_DIR="/opt/infra-demo"
CONF_DIR="/etc/infra-demo"
LOG_DIR="/var/log/infra-demo"
OPS_USER="opsadmin"
DEMO_PORT="8080"

# Resolve repo root (this script lives in <repo>/scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# ---------- Helper functions ----------
log() { echo -e "\n>>> $*"; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root (use sudo)." >&2
        exit 1
    fi
}

# ---------- Steps ----------

step_detect_os() {
    log "Detecting OS"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "Detected: $NAME $VERSION_ID"
    else
        echo "Could not detect OS (/etc/os-release missing)" >&2
        exit 1
    fi
}

step_update_packages() {
    log "Updating package index and installing required packages"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends \
        python3 \
        curl \
        ufw \
        ca-certificates
}

step_create_ops_user() {
    log "Ensuring operational sudo user '$OPS_USER' exists"
    if id "$OPS_USER" &>/dev/null; then
        echo "User $OPS_USER already exists, skipping creation"
    else
        adduser --disabled-password --gecos "" "$OPS_USER"
        usermod -aG sudo "$OPS_USER"
        echo "Created $OPS_USER and added to sudo group"
        echo "NOTE: set a password for $OPS_USER manually with: passwd $OPS_USER"
    fi
}

step_create_service_user() {
    log "Ensuring service user '$APP_USER' exists"
    if id "$APP_USER" &>/dev/null; then
        echo "User $APP_USER already exists, skipping creation"
    else
        useradd --system --no-create-home --shell /usr/sbin/nologin "$APP_USER"
        echo "Created system user $APP_USER"
    fi
}

step_create_directories() {
    log "Creating application directories"
    install -d -o "$APP_USER" -g "$APP_USER" -m 750 "$APP_DIR"
    install -d -o root -g "$APP_USER" -m 750 "$CONF_DIR"
    install -d -o "$APP_USER" -g "$APP_USER" -m 750 "$LOG_DIR"
}

step_deploy_app() {
    log "Deploying application files"

    install -o "$APP_USER" -g "$APP_USER" -m 750 \
        "$REPO_ROOT/scripts/infra-demo.py" "$APP_DIR/infra-demo.py"

    install -o "$APP_USER" -g "$APP_USER" -m 750 \
        "$REPO_ROOT/scripts/maintenance.sh" "$APP_DIR/maintenance.sh"

    install -o root -g "$APP_USER" -m 640 \
        "$REPO_ROOT/config/infra-demo.env" "$CONF_DIR/infra-demo.env"

    echo "Application files deployed to $APP_DIR and $CONF_DIR"
}

step_install_systemd_units() {
    log "Installing systemd units"

    install -o root -g root -m 644 \
        "$REPO_ROOT/systemd/infra-demo.service" \
        /etc/systemd/system/infra-demo.service

    install -o root -g root -m 644 \
        "$REPO_ROOT/systemd/infra-maintenance.service" \
        /etc/systemd/system/infra-maintenance.service

    install -o root -g root -m 644 \
        "$REPO_ROOT/systemd/infra-maintenance.timer" \
        /etc/systemd/system/infra-maintenance.timer

    systemctl daemon-reload

    systemctl enable --now infra-demo.service
    systemctl enable --now infra-maintenance.timer

    echo "infra-demo service and infra-maintenance timer enabled"
}

step_configure_firewall() {
    log "Configuring firewall (ufw)"

    # Allow SSH so we don't lock ourselves out
    ufw allow OpenSSH

    # Allow the demo service port
    ufw allow "${DEMO_PORT}/tcp"

    # Enable ufw non-interactively if not already active
    if ufw status | grep -q "Status: inactive"; then
        ufw --force enable
    else
        echo "ufw already active, rules updated"
    fi

    ufw status verbose
}

step_harden_ssh() {
    log "Applying SSH safe defaults"

    SSHD_CONFIG="/etc/ssh/sshd_config"
    BACKUP="${SSHD_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"

    if [ ! -f "${SSHD_CONFIG}.orig" ]; then
        cp "$SSHD_CONFIG" "${SSHD_CONFIG}.orig"
    fi
    cp "$SSHD_CONFIG" "$BACKUP"

    # Disable root login over SSH (idempotent: replace or append)
    if grep -qE '^\s*PermitRootLogin' "$SSHD_CONFIG"; then
        sed -i 's/^\s*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    else
        echo "PermitRootLogin no" >> "$SSHD_CONFIG"
    fi

    # Disable empty passwords
    if grep -qE '^\s*PermitEmptyPasswords' "$SSHD_CONFIG"; then
        sed -i 's/^\s*PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSHD_CONFIG"
    else
        echo "PermitEmptyPasswords no" >> "$SSHD_CONFIG"
    fi

    # Validate config before reloading
    if sshd -t; then
        systemctl reload ssh || systemctl reload sshd || true
        echo "SSH configuration hardened and reloaded"
    else
        echo "sshd config test failed, restoring backup" >&2
        cp "$BACKUP" "$SSHD_CONFIG"
        exit 1
    fi
}

step_summary() {
    log "Provisioning complete. Summary:"
    echo "  - Ops user:        $OPS_USER (sudo) - set password manually if newly created"
    echo "  - Service user:    $APP_USER (system, no login)"
    echo "  - App directory:   $APP_DIR"
    echo "  - Config:          $CONF_DIR/infra-demo.env"
    echo "  - Logs:            $LOG_DIR"
    echo "  - Service status:  $(systemctl is-active infra-demo) / enabled: $(systemctl is-enabled infra-demo)"
    echo "  - Timer status:    $(systemctl is-active infra-maintenance.timer) / enabled: $(systemctl is-enabled infra-maintenance.timer)"
    echo "  - Demo endpoint:   curl http://localhost:${DEMO_PORT}/health"
}

# ---------- Main ----------
main() {
    require_root
    step_detect_os
    step_update_packages
    step_create_ops_user
    step_create_service_user
    step_create_directories
    step_deploy_app
    step_install_systemd_units
    step_configure_firewall
    step_harden_ssh
    step_summary
}

main "$@"
