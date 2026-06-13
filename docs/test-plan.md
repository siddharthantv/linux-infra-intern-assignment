# Test Plan

## Overview
This document describes the testing strategy for the infra-demo provisioning
project, covering what is tested, how it is tested, and the expected outcomes
for each check in validate.sh.

---

## Test Philosophy

- **Automated first:** All core checks are automated in `validate.sh` and
  can be run with a single command after provisioning or after a reboot.
- **Idempotency is a test:** Running `provision.sh` twice is itself a test
  case — the second run must not error, duplicate users, or break config.
- **Reboot is a test:** The system must recover fully after a reboot with
  zero manual intervention.
- **Exit codes matter:** `validate.sh` exits 0 on full pass, non-zero on
  any failure — suitable for use in CI or automated pipelines.

---

## Test Categories

### 1. Service Status Tests

| Check | Command | Expected Result |
|---|---|---|
| Service is active | `systemctl is-active infra-demo` | active |
| Service is enabled | `systemctl is-enabled infra-demo` | enabled |
| Timer is active | `systemctl is-active infra-maintenance.timer` | active |
| Timer is enabled | `systemctl is-enabled infra-maintenance.timer` | enabled |

**Why:** A service that is active but not enabled will not survive a reboot.
Both checks are required to confirm correct systemd wiring.

---

### 2. HTTP Health Endpoint Tests

| Check | Command | Expected Result |
|---|---|---|
| /health returns 200 | `curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health` | 200 |
| /health body contains status:ok | `grep '"status": "ok"' response body` | match found |

**Why:** Confirms the Python service is running, bound to the correct port,
and returning a meaningful health payload — not just that the process exists.

---

### 3. Open Ports Tests

| Check | Command | Expected Result |
|---|---|---|
| Port 8080 listening | `ss -tulpn \| grep :8080` | match found |
| Port 22 listening | `ss -tulpn \| grep :22` | match found |

**Why:** Confirms the service is actually bound to the network interface,
not just reported as active by systemd.

---

### 4. Firewall Tests

| Check | Command | Expected Result |
|---|---|---|
| ufw is active | `ufw status \| grep active` | Status: active |
| Port 8080 allowed | `ufw status \| grep 8080` | ALLOW |
| SSH allowed | `ufw status \| grep OpenSSH` | ALLOW |

**Why:** Confirms the firewall is enforcing rules and not just installed.
Both SSH and the demo port must be explicitly allowed to avoid lockout.

---

### 5. User and Group Tests

| Check | Command | Expected Result |
|---|---|---|
| infra-demo user exists | `id infra-demo` | uid shown |
| infra-demo has no login shell | `getent passwd infra-demo \| cut -d: -f7` | /usr/sbin/nologin |
| opsadmin user exists | `id opsadmin` | uid shown |
| opsadmin is in sudo group | `id -nG opsadmin \| grep sudo` | sudo |

**Why:** Confirms the principle of least privilege — the service runs as
a system user with no login capability, while operational work is done
via a dedicated sudo user, not root.

---

### 6. File Permission Tests

| Path | Expected Owner | Expected Mode | Reason |
|---|---|---|---|
| /opt/infra-demo/ | infra-demo | 750 | No world access to app dir |
| /opt/infra-demo/infra-demo.py | infra-demo | 750 | Executable by service only |
| /etc/infra-demo/infra-demo.env | root | 640 | Config not world-readable |
| /var/log/infra-demo/ | infra-demo | 750 | Logs not world-readable |

**Why:** Incorrect permissions are a common misconfiguration in real
deployments. World-readable config files can expose runtime parameters
to other users on the system.

---

### 7. Log Tests

| Check | Command | Expected Result |
|---|---|---|
| journalctl has logs | `journalctl -u infra-demo -n 30` | non-empty output |
| Log file exists | `test -f /var/log/infra-demo/infra-demo.log` | file present |

**Why:** Confirms the service is actually logging — both to the systemd
journal (for `journalctl`) and to the application log file. Both paths
are required for FR3.

---

### 8. Reboot Survival Test

**Procedure:**
1. Run `validate.sh` — record output (pre-reboot baseline)
2. Run `sudo reboot`
3. Reconnect after ~30 seconds
4. Run `validate.sh` again without starting anything manually

**Expected result:** Identical pass count before and after reboot.
Service, timer, and firewall must all recover automatically.

**Why:** systemd `enable` and ufw persistence are only proven by an
actual reboot — not by checking configuration files alone.

---

### 9. Idempotency Test

**Procedure:**
1. Run `sudo ./scripts/provision.sh` (first run — full provisioning)
2. Run `sudo ./scripts/provision.sh` (second run — should skip existing items)
3. Run `sudo ./scripts/validate.sh`

**Expected result:**
- Second run completes without errors
- All "already exists" checks print skipping messages
- validate.sh still passes 21/21 after second run

**Why:** Idempotency is critical for real provisioning pipelines where
scripts may be re-run due to partial failures or routine re-deployments.

---

## Running All Tests

```bash
# Full automated validation
sudo ./scripts/validate.sh

# Manual idempotency test
sudo ./scripts/provision.sh
sudo ./scripts/validate.sh

# Reboot survival test
sudo reboot
# (reconnect)
sudo ./scripts/validate.sh

Evidence
Test
Evidence File
Base VM setup
evidence/milestone-1-setup.png
Service + systemd
evidence/milestone-2-service.png
Hardening + idempotency
evidence/milestone-3-hardening.png
Validation + reboot
evidence/milestone-4-reboot-validation.png
