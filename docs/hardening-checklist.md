# Security Hardening Checklist

## Overview
This document describes the security hardening measures applied to the infra-demo
server baseline, the reasoning behind each decision, and what was intentionally
skipped and why.

---

## Applied Hardening Measures

### 1. SSH Hardening

| Setting | Value | Reason |
|---|---|---|
| PermitRootLogin | no | Prevents direct root access over SSH |
| PermitEmptyPasswords | no | Ensures all accounts require a password |

- Original sshd_config backed up to `/etc/ssh/sshd_config.orig` before modification
- Config validated with `sshd -t` before reload to prevent lockout
- SSH service reloaded (not restarted) to avoid dropping active sessions

### 2. Firewall (ufw)

| Rule | Reason |
|---|---|
| Allow OpenSSH (port 22) | Maintain remote management access |
| Allow 8080/tcp | Required for infra-demo health service |
| Default deny incoming | Block all other inbound traffic |
| Default allow outgoing | Allow package updates and outbound connections |

- ufw enabled non-interactively via `--force` flag
- Rules applied before enabling to avoid lockout
- Verified with `ufw status verbose` and `ss -tulpn`

### 3. Dedicated Service User

- `infra-demo` system user created with:
  - No login shell (`/usr/sbin/nologin`)
  - No home directory
  - No password
- Service runs as `infra-demo`, not root
- Limits blast radius if the service is compromised

### 4. File Permissions and Ownership

| Path | Owner | Mode | Reason |
|---|---|---|---|
| /opt/infra-demo/ | infra-demo | 750 | App files readable only by service user |
| /opt/infra-demo/infra-demo.py | infra-demo | 750 | Executable only by service user |
| /etc/infra-demo/infra-demo.env | root:infra-demo | 640 | Config readable by service, not world |
| /var/log/infra-demo/ | infra-demo | 750 | Logs writable only by service user |

### 5. Systemd Service Hardening

The systemd unit applies the following restrictions:

| Directive | Value | Reason |
|---|---|---|
| NoNewPrivileges | true | Prevents privilege escalation via setuid |
| ProtectSystem | strict | Mounts /usr, /boot, /etc as read-only |
| ProtectHome | true | Blocks access to /home, /root, /run/user |
| ReadWritePaths | /var/log/infra-demo | Only this path is writable by the service |
| User/Group | infra-demo | Service runs as unprivileged user |

### 6. Non-root Operational User

- `opsadmin` user created for day-to-day operational work
- Added to `sudo` group for controlled privilege escalation
- Separate from root and the service account

### 7. Package Minimization

- Only required packages installed:
  `python3`, `curl`, `ufw`, `ca-certificates`
- `--no-install-recommends` flag used to avoid pulling in unnecessary dependencies
- `DEBIAN_FRONTEND=noninteractive` set during install to avoid interactive prompts

---

## Intentionally Skipped / Not Applied

### 1. SSH Key-Only Authentication (PasswordAuthentication no)
**Skipped because:** This is a local VM assignment. Disabling password auth without
first setting up SSH keys risks complete lockout since there is no key pair
configured. In a production environment, SSH keys would be set up first, then
password auth disabled.

### 2. Fail2ban / Brute-force Protection
**Skipped because:** The VM is only accessible via localhost port forwarding
(127.0.0.1:2222), not exposed to the public internet. Brute-force protection is
not meaningful in this context. Would be applied in a real deployment.

### 3. AppArmor / SELinux Profiles
**Skipped because:** Writing a custom AppArmor profile for the demo service is
outside the scope of this assignment. Ubuntu 26.04 ships with AppArmor enabled
by default for system services — no custom profile was added for infra-demo.

### 4. Automatic Security Updates (unattended-upgrades)
**Skipped because:** Auto-updates can cause unexpected reboots/service restarts
in a demo environment, breaking reproducibility. In production this would be
enabled with careful reboot scheduling.

### 5. Disabling IPv6
**Skipped because:** IPv6 is not a security risk in this context and disabling it
requires kernel parameter changes that add unnecessary complexity to the
provisioning script for a local VM assignment.

### 6. CIS Benchmark Full Compliance
**Skipped because:** Full CIS Ubuntu benchmark compliance involves 200+ controls
and is beyond the scope of a 2-month internship take-home. The measures applied
here cover the most impactful practical controls for a lightweight service
deployment.

---

## Verification Commands

```bash
# SSH hardening
grep -E 'PermitRootLogin|PermitEmptyPasswords' /etc/ssh/sshd_config

# Firewall
sudo ufw status verbose

# Service user
id infra-demo
getent passwd infra-demo

# File permissions
stat -c "%U %G %a %n" /opt/infra-demo/infra-demo.py
stat -c "%U %G %a %n" /etc/infra-demo/infra-demo.env

# Systemd restrictions
systemctl cat infra-demo | grep -E 'NoNew|Protect|ReadWrite'
```
