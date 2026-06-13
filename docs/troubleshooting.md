# Troubleshooting

## Overview
This document covers real issues encountered during the development and
provisioning of the infra-demo server baseline, along with their root
causes and fixes. It also covers common issues that may arise when
reproducing this setup.

---

## Issue 1: VirtualBox AMD-V Conflict (VERR_SVM_IN_USE)

### Symptom
```
VirtualBox can't enable the AMD-V extension.
Please disable the KVM kernel extension, recompile your kernel and reboot.
Result Code: NS_ERROR_FAILURE (0x80004005)
```

### Root Cause
The host machine (Ubuntu 24.04) had KVM kernel modules (`kvm_amd`, `kvm`)
loaded, which held exclusive ownership of the AMD-V virtualization extension.
VirtualBox could not acquire it while KVM had it.

### Fix
Stop libvirt services and unload the KVM modules:

```bash
sudo systemctl stop libvirtd
sudo systemctl stop virtlogd
sudo modprobe -r kvm_amd
sudo modprobe -r kvm
```

To make this permanent across reboots, blacklist the modules:

```bash
echo "blacklist kvm_amd" | sudo tee /etc/modprobe.d/blacklist-kvm.conf
echo "blacklist kvm" | sudo tee -a /etc/modprobe.d/blacklist-kvm.conf
sudo update-initramfs -u
sudo reboot
```

> [!NOTE]
> After reboot, VirtualBox 7.x on Linux uses KVM as its own backend
(`kvm` will appear loaded with `vboxdrv` as the dependent module).
This is expected and is not a conflict — VirtualBox manages KVM
directly in this mode.

---

## Issue 2: Python AttributeError in Health Endpoint

### Symptom
```
AttributeError: 'datetime.timedelta' object has no attribute 'total_second'.
Did you mean: 'total_seconds'?
curl: (52) Empty reply from server
```

### Root Cause
Typo in `infra-demo.py`: `.total_second()` instead of `.total_seconds()`.
The request handler crashed mid-response, causing curl to receive an
empty reply.

### Fix
Edit `scripts/infra-demo.py` and correct the method name:

```python
# Wrong
uptime = (datetime.now(timezone.utc) - START_TIME).total_second()

# Correct
uptime = (datetime.now(timezone.utc) - START_TIME).total_seconds()
```

Restart the service after fixing:

```bash
sudo systemctl restart infra-demo
curl -i http://localhost:8080/health
```

---

## Issue 3: git remote add Fails (remote origin already exists)

### Symptom
```
error: remote origin already exists.
```

### Root Cause
`git remote add origin` was run twice. The first run succeeded but
the second run failed because the remote was already registered.

### Fix
Use `set-url` instead of `add` to update an existing remote:

```bash
git remote set-url origin https://github.com/<username>/<repo>.git
git remote -v  # verify
```

---

## Issue 4: git push Authentication Failure

### Symptom
```
fatal: 'origin' does not appear to be a git repository
fatal: Could not read from remote repository.
Please make sure you have the correct access rights and the repository exists.
```

### Root Cause
Either:
- The GitHub repository had not been created yet, or
- GitHub requires a Personal Access Token (PAT) for HTTPS pushes —
  password authentication was deprecated in 2021.

### Fix
1. Create the repo on GitHub first (empty, no README)
2. Generate a PAT: GitHub → Settings → Developer settings →
   Personal access tokens → Generate new token (scope: repo)
3. Push using the token embedded in the URL:

```bash
git remote set-url origin https://<username>:<TOKEN>@github.com/<username>/<repo>.git
git push -u origin main
```

---

## Issue 5: ufw Blocks SSH After Enabling

### Symptom
SSH connection drops immediately after `ufw --force enable`.

### Root Cause
ufw was enabled before the `allow OpenSSH` rule was applied,
blocking all incoming connections including SSH.

### Prevention
`provision.sh` applies firewall rules in the correct order:
1. `ufw allow OpenSSH` (first)
2. `ufw allow 8080/tcp` (second)
3. `ufw --force enable` (last)

If you are ever locked out, use the VirtualBox console window
(not SSH) to log in directly and run:

```bash
sudo ufw allow OpenSSH
sudo ufw reload
```

---

## Issue 6: sshd Config Validation Fails

### Symptom
```
sshd config test failed, restoring backup
```

### Root Cause
A syntax error was introduced into `/etc/ssh/sshd_config` during
the hardening step.

### Fix
`provision.sh` automatically restores the backup if `sshd -t` fails.
To manually restore:

```bash
sudo cp /etc/ssh/sshd_config.orig /etc/ssh/sshd_config
sudo systemctl reload ssh
```

Always verify the config before reloading:

```bash
sudo sshd -t && echo "Config OK"
```

---

## Issue 7: infra-demo Service Fails to Start

### Symptom
```
systemctl status infra-demo → failed / activating
```

### Diagnosis Steps

```bash
# Check the full error
sudo systemctl status infra-demo --no-pager
sudo journalctl -u infra-demo -n 50 --no-pager

# Check the script exists and is executable
ls -la /opt/infra-demo/infra-demo.py

# Check the env file exists
ls -la /etc/infra-demo/infra-demo.env

# Check the service user exists
id infra-demo

# Test running the script manually as the service user
sudo -u infra-demo INFRA_DEMO_PORT=8080 \
  INFRA_DEMO_LOG_PATH=/var/log/infra-demo/infra-demo.log \
  python3 /opt/infra-demo/infra-demo.py
```

### Common Causes
- Script not copied to `/opt/infra-demo/` (run `provision.sh` again)
- Wrong permissions on log directory (infra-demo user cannot write)
- Port 8080 already in use by another process (`ss -tulpn | grep 8080`)

---

## Issue 8: validate.sh Permission Denied on ufw

### Symptom
```
[FAIL] ufw is NOT active
```
Even though ufw is active.

### Root Cause
`ufw status` requires root privileges. Running `validate.sh` without
sudo causes the ufw check to fail silently.

### Fix
Always run validate.sh with sudo:

```bash
sudo ./scripts/validate.sh
```

---

## General Debugging Commands

```bash
# Service status and recent logs
sudo systemctl status infra-demo --no-pager
sudo journalctl -u infra-demo -n 50 --no-pager

# Check all listening ports
ss -tulpn

# Check firewall rules
sudo ufw status verbose

# Check file ownership and permissions
stat -c "%U %G %a %n" /opt/infra-demo/infra-demo.py
stat -c "%U %G %a %n" /etc/infra-demo/infra-demo.env

# Check systemd unit file loaded correctly
systemctl cat infra-demo

# Re-run provisioning (safe, idempotent)
sudo ./scripts/provision.sh

# Full validation
sudo ./scripts/validate.sh
```

