# AI Assistance Notes

## Overview
This section documents where AI assistance (Claude by Anthropic) was used
during this assignment, what it helped with, and what was manually verified,
tested, and understood before being submitted.

This is included in the interest of transparency, as required by the
assignment guidelines.

---

## Where AI Was Used

### 1. Initial Project Structure
*What AI helped with:*
Suggested the overall repository layout, file naming conventions, and
the breakdown of provisioning into discrete idempotent steps.

*What I verified:*
- Reviewed the suggested structure against the assignment requirements
- Manually confirmed every file path matched the expected layout
- Made naming decisions myself (e.g., hostname, service name, user names)

---

### 2. Python Health Service (infra-demo.py)
*What AI helped with:*
Provided the initial boilerplate for the HTTP health service using
Python's built-in http.server module, including the ThreadingHTTPServer
pattern and JSON response structure.

*What I verified:*
- Ran the script manually before wiring it into systemd
- Caught and fixed a real bug myself (total_second() → total_seconds())
- Understood every method: do_GET, _send_json, log_message override
- Tested all three endpoints (/health, /, /nonexistent) manually
  with curl and confirmed expected HTTP status codes and JSON payloads
- Added the \n trailing newline fix myself after noticing the output
  formatting issue during manual testing

---

### 3. provision.sh
*What AI helped with:*
Suggested the step function pattern (step_detect_os, step_update_packages,
etc.), the use of install command for deploying files with ownership and
permissions in one step, and the sshd_config backup/validate/reload pattern.

*What I verified:*
- Read and understood every command before running it
- Ran the script twice to confirm idempotency myself
- Verified each step's output manually (user creation, directory permissions,
  systemd unit installation, firewall rules)
- Understood why DEBIAN_FRONTEND=noninteractive is needed for apt in scripts
- Confirmed sshd -t validates config before reload to prevent SSH lockout
- Verified the install command flags (-o, -g, -m) and what they do

---

### 4. validate.sh
*What AI helped with:*
Suggested the ok()/bad() counter pattern for structured pass/fail output
and the use of curl -w "%{http_code}" for programmatic HTTP status checking.

*What I verified:*
- Ran validate.sh and reviewed every check output manually
- Confirmed 21/21 checks pass both before and after reboot
- Understood why each check exists and what it proves (documented in test-plan.md)
- Verified the script exits with non-zero on failure (tested by temporarily
  stopping the service and re-running validate.sh)

---

### 5. systemd Unit Files
*What AI helped with:*
Suggested the security directives (NoNewPrivileges, ProtectSystem,
ProtectHome, ReadWritePaths) and the EnvironmentFile pattern for
separating config from the unit file.

*What I verified:*
- Read the systemd man pages for each directive to understand what they do
- Confirmed systemctl cat infra-demo shows the unit loaded correctly
- Verified ProtectSystem=strict does not block log writes because
  /var/log/infra-demo is explicitly listed in ReadWritePaths
- Tested systemctl enable --now vs separate enable + start

---

### 6. Documentation
*What AI helped with:*
Assisted with structure and professional wording for the hardening checklist,
test plan, troubleshooting guide, and reprovisioning guide.

*What I verified:*
- Every issue in troubleshooting.md was a real issue I actually hit
  during development (AMD-V conflict, AttributeError, git remote errors)
- All commands in the docs were tested and confirmed working on my VM
- Hardening decisions (what to apply vs skip) were my own reasoned choices,
  not just AI suggestions — I understood the trade-offs for each

---

### 7. Design Decisions
*What AI helped with:*
Provided structured reasoning for choosing Python over nginx as the demo
service implementation.

*What I verified:*
- Agreed with and understood all five reasoning points
- Connected the decision to the actual JD requirements (Python listed
  as a required skill, scripting-heavy role)
- The final decision and framing was my own

---

## What Was Done Without AI Assistance

- All git commits and commit messages
- Setting up VirtualBox and debugging the AMD-V/KVM conflict on my machine
- Installing Ubuntu Server 24.04 and configuring the VM
- Developing further from given boilerplate
- Catching and fixing the total_seconds() bug during manual testing
- Running all tests, reboots, and validation checks manually
- Recording the demo video
- All SSH port forwarding setup
- Making judgment calls on what hardening to apply vs skip

---

## Summary

AI was used primarily as a knowledgeable assistant and boilerplate
generator — similar to using Stack Overflow, man pages, or a senior
colleague for guidance. Every piece of code and configuration submitted
was read, understood, tested, and verified by me on the actual VM before
being committed. No AI output was submitted without manual review and
validation.
