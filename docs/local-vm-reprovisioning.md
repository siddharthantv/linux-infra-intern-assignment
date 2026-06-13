# Local VM Reprovisioning Guide  

## Overview  
This document describes how to reprovision the infra-demo server from a clean  
VM state using VirtualBox snapshots. This simulates a real-world image  
customization and redeployment workflow entirely on a local machine.  

---

## Prerequisites  

- VirtualBox installed on the host machine  
- Ubuntu Server 26.04 VM created and base OS installed  
- This repository cloned inside the VM  
- No cloud provider required or used  

---

## Workflow Overview

Fresh VM Install
|
v
Take "clean-baseline" snapshot  <--- restore point
|
v
Clone repo + run provision.sh
|
v
Validate with validate.sh
|
v
(Optional) Take "provisioned" snapshot
|
v
Restore "clean-baseline" snapshot
|
v
Run provision.sh again (idempotency test)
---

## Step-by-Step Instructions

### Step 1: Fresh VM Install

1. Create a new VM in VirtualBox:
   - Name: `linux-infra-intern-assignment`
   - Type: Linux / Ubuntu 64-bit
   - RAM: 2048 MB
   - Disk: 20 GB (dynamically allocated)
2. Attach Ubuntu Server 24.04 ISO and boot
3. Complete the installer:
   - Hostname: `infra-intern-assignment-server`
   - Username: your preferred username
   - Enable OpenSSH server during install
4. After first boot, log in and confirm:

```bash
cat /etc/os-release
uname -a
```
Step 2: Take the Clean Baseline Snapshot
Before running any provisioning, take a snapshot so you can restore to
a truly fresh state at any time.
From the host machine:
```bash
VBoxManage snapshot "linux-infra-intern-assignment" take "clean-baseline" \
  --description "Fresh Ubuntu Server 24.04 install, no provisioning applied"
```
Or via VirtualBox GUI:
Machine → Snapshots → Take Snapshot → name it clean-baseline
Verify:
```bash
VBoxManage snapshot "linux-infra-intern-assignment" list
```
Step 3: Clone the Repo and Provision
Inside the VM:
```bash
sudo apt install -y git
git clone https://github.com/siddharthantv/linux-infra-intern-assignment.git
cd linux-infra-intern-assignment
sudo ./scripts/provision.sh
```
Step 4: Validate
```bash
sudo ./scripts/validate.sh
```
Expected output: RESULT: 21 passed, 0 failed
Optionally take a second snapshot of the provisioned state:
```bash
VBoxManage snapshot "linux-infra-intern-assignment" take "provisioned" \
  --description "Post-provisioning: service running, firewall active, hardening applied"
```
Step 5: Restore to Clean Baseline (Reprovisioning Simulation)
Power off the VM first:
```bash
sudo poweroff
```
From the host, restore the clean snapshot:
```bash
VBoxManage snapshot "linux-infra-intern-assignment" restore "clean-baseline"
```
Start the VM again:
```bash
VBoxManage startvm "linux-infra-intern-assignment" --type gui
```
Step 6: Re-run Provisioning from Scratch
Log in and run the full provisioning again:
Log in and run the full provisioning again:
```bash
sudo ./scripts/provision.sh  # first run
sudo ./scripts/provision.sh  # second run - should show "already exists / skipping"
```
Both runs should complete without errors and validate.sh should pass
after each.


Notes
All work is performed inside the local VM only
No cloud provider, cloud image, or external server is used at any point
The snapshot/restore workflow is equivalent to deploying from a
golden image in a real infrastructure environment
VirtualBox appliance export (.ova) can also be used to share the
VM state: Machine → Export Appliance
