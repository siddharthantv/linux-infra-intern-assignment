# Linux Infrastructure Intern Assignment

# Overview
Provisioning, automation, and hardening mini-lab on a local Ubuntu server 26.04 server VM (VirtualBox).

# Status
- [x] Base VM setup
- [x] Demo service + systemd
- [x] Hardening + automation
- [x] Validation + reboot testing 
- [x] Documentation + demo


# Scripts
- ``infra-demo.py``
- ``maintenance.sh``
- ``provision.sh``
- ``validate.sh``

# Directorties
```bash
.
├── config
│   └── infra-demo.env
├── docs
│   ├── hardening-checklist.md
│   ├── local-vm-reprovisioning.md
│   ├── test-plan.md
│   └── troubleshooting.md
├── evidence
├── README.md
├── scripts
│   ├── infra-demo.py
│   ├── maintenance.sh
│   ├── provision.sh
│   └── validate.sh
└── systemd
    ├── infra-demo.service
    ├── infra-maintenance.service
    └── infra-maintenance.timer

6 directories, 13 files

```
