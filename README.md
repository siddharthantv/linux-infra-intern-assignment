# Linux Infrastructure Intern Assignment
### Vyorius Drones Private Limited — Take-Home Assignment



![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)




![Ubuntu Server](https://img.shields.io/badge/Ubuntu-26%2E04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)




![Bash](https://img.shields.io/badge/Bash-5.2-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)




![Python](https://img.shields.io/badge/Python-3.14-3776AB?style=for-the-badge&logo=python&logoColor=white)




![systemd](https://img.shields.io/badge/systemd-259.5-000000?style=for-the-badge&logo=linux&logoColor=white)




![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)




![VirtualBox](https://img.shields.io/badge/VirtualBox-7.0.16-183A61?style=for-the-badge&logo=virtualbox&logoColor=white)



---

## Overview

A fully automated Linux server provisioning pipeline built inside a local
VirtualBox VM running Ubuntu Server 26.04 LTS. The project converts a fresh
VM into a deployment-ready server environment with a running health service,
systemd management, firewall hardening, maintenance automation, and a
validation script that proves everything works — including after a reboot.


> [!NOTE]
> All work is performed inside a local VM only. No cloud provider, cloud image, or external server is used at any point.

---

## Repository Structure

```
linux-infra-intern-assignment/
├── README.md
├── .gitignore
├── scripts/
│   ├── provision.sh          # Main provisioning script (idempotent)
│   ├── validate.sh           # Validation script (21 checks)
│   ├── infra-demo.py         # Python HTTP health service
│   └── maintenance.sh        # Periodic maintenance task
├── systemd/
│   ├── infra-demo.service    # Demo service unit
│   ├── infra-maintenance.service  # Maintenance task unit
│   └── infra-maintenance.timer    # 15-minute periodic timer
├── config/
│   └── infra-demo.env        # Runtime config (port, log path)
├── docs/
│   ├── hardening-checklist.md
│   ├── local-vm-reprovisioning.md
│   ├── test-plan.md
│   ├── troubleshooting.md
│   └── ai-assistance-notes.md
└── evidence/
    ├── milestone-1-setup.png
    ├── milestone-2-service.png
    ├── milestone-3-hardening.png
    ├── milestone-3-manual-verification.png
    ├── final-post-reboot-validation.png
    └── demo-video.mp4


```

---

## Tech Stack

| Component | Technology | Purpose |
|---|---|---|
| OS | Ubuntu Server 26.04 LTS | Base operating system |
| Virtualization | VirtualBox 7.x | Local VM host |
| Provisioning | Bash 5.2 | Automated setup script |
| Demo Service | Python 3.14 | HTTP health endpoint |
| Service Manager | systemd | Service lifecycle management |
| Firewall | ufw | Network access control |
| Version Control | Git | Source control |

---

## Quick Start

### Prerequisites
- VirtualBox installed on host machine
- Ubuntu Server 26.04 LTS VM created (2GB RAM, 20GB disk)
- OpenSSH installed during Ubuntu setup
- Git available inside the VM

### 1. Clone the repository (inside the VM)

```bash
sudo apt install -y git
git clone https://github.com/siddharthantv/linux-infra-intern-assignment.git
cd linux-infra-intern-assignment
```

### 2. Run provisioning

```bash
sudo ./scripts/provision.sh
```

This will:
- Detect OS and update packages
- Create `opsadmin` sudo user and `infra-demo` service user
- Deploy the Python health service to `/opt/infra-demo/`
- Install and enable systemd service and maintenance timer
- Configure ufw firewall (allow SSH + 8080)
- Apply SSH hardening (PermitRootLogin no, PermitEmptyPasswords no)

### 3. Validate

```bash
sudo ./scripts/validate.sh
```

Expected output: `RESULT: 21 passed, 0 failed`

### 4. Test the health endpoint

```bash
curl -i http://localhost:8080/health
```

Expected response:
```json
{
  "status": "ok",
  "hostname": "infra-intern-assignment-server",
  "uptime_seconds": 42.5,
  "timestamp": "2026-06-14T00:00:00+00:00"
}
```

---

## Idempotency

Running `provision.sh` twice is safe — existing users, directories,
and configurations are detected and skipped:

```bash
sudo ./scripts/provision.sh  # first run - full setup
sudo ./scripts/provision.sh  # second run - skips existing items
sudo ./scripts/validate.sh   # still passes 21/21
```

---

## Reboot Survival

After a reboot, all services recover automatically via systemd:

```bash
sudo reboot
# (reconnect after ~30 seconds)
sudo ./scripts/validate.sh  # still passes 21/21
```

---

## Security Hardening

| Measure | Details |
|---|---|
| SSH hardening | PermitRootLogin no, PermitEmptyPasswords no |
| Firewall | ufw active, only ports 22 and 8080 allowed |
| Service isolation | Dedicated system user with no login shell |
| File permissions | Config 640, app dirs 750, no world access |
| systemd sandboxing | NoNewPrivileges, ProtectSystem=strict, ProtectHome |
| Minimal packages | --no-install-recommends, only 4 packages installed |

See full details: [docs/hardening-checklist.md](docs/hardening-checklist.md)

---

## Documentation

| Document | Description |
|---|---|
| [docs/hardening-checklist.md](docs/hardening-checklist.md) | Security measures applied and intentionally skipped |
| [docs/test-plan.md](docs/test-plan.md) | What validate.sh checks and why |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Real issues encountered and how they were fixed |
| [docs/local-vm-reprovisioning.md](docs/local-vm-reprovisioning.md) | Snapshot/restore reprovisioning workflow |
| [docs/ai-assistance-notes.md](docs/ai-assistance-notes.md) | Where AI helped and what was manually verified |

---

## Validation Checks (21 total)

| Category | Checks |
|---|---|
| Service status | infra-demo active, enabled; timer active, enabled |
| HTTP health | /health returns 200, body contains status:ok |
| Open ports | 8080 listening, 22 listening |
| Firewall | ufw active, 8080 allowed, SSH allowed |
| Users | infra-demo exists (no shell), opsadmin exists (sudo) |
| Permissions | /opt/infra-demo 750, env file 640, log dir 750 |
| Logs | journalctl has entries, log file exists |
| System | uptime displayed |

---

## Demo Video

[Watch Demo Video](evidence/demo-video.mp4)

The demo covers:
- Repository structure walkthrough
- Provisioning script run (idempotency shown)
- Service health check via curl
- Firewall and logs inspection
- validate.sh run (21/21 pass)
- Reboot and post-reboot validation

---

## Milestones

| Milestone | Status | Evidence |
|---|---|---|
| Base VM + repo setup | ✅ Done | evidence/milestone-1-setup.png |
| Service + systemd | ✅ Done | evidence/milestone-2-service.png |
| Hardening + automation | ✅ Done | evidence/milestone-3-hardening.png |
| Validation + reboot | ✅ Done | evidence/milestone-4-reboot-validation.png |
| Docs + demo | ✅ Done | This README + demo video |

---

## Environment

| Property | Value |
|---|---|
| Host OS | Ubuntu 24.04 LTS |
| VM Software | VirtualBox 7.0.16|
| Guest OS | Ubuntu Server 26.04 LTS |
| Kernel | 6.17.0-35-generic |
| Python | 3.14 |
| RAM | 2048 MB |
| Disk | 20 GB |

---

## Assumptions

- The VM has internet access via NAT for apt package installation
- OpenSSH server was selected during Ubuntu Server installation
- The provisioning script is run from inside the cloned repository directory
- `sudo` privileges are available to the logged-in user

---

## AI Assistance Notes

AI tooling (Claude by Anthropic) was used for research, boilerplate
generation, and documentation structure. Every command and configuration
was manually read, understood, tested, and verified on the actual VM
before being committed.

Full details: [docs/ai-assistance-notes.md](docs/ai-assistance-notes.md)

---

## Author

**Siddharthan T V**
* Linux Infrastructure Intern Candidate
* Vyorius Drones Private Limited — Take-Home Assignment

> [!NOTE]
> This assignment was completed to fulfill the requirements for further assessment for the **Linux Infrastructure Intern** role at **Vyorius Drones Private Limited**.
> This document remains the property of the author and is intended solely for evaluation purposes.
