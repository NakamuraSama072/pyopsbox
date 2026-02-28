# fast-server-mgmt-scripts

Lightweight server management scripts for common Linux initialization tasks within 1 click.

## Current Scope

This repository currently provides:

- Two distribution-specific server initialization scripts
- Three distribution-agnostic general management scripts

- Debian/Ubuntu script: [specific/fast-server-init-debian.sh](specific/fast-server-init-debian.sh)
- CentOS/RHEL script: [specific/fast-server-init-rhel.sh](specific/fast-server-init-rhel.sh)
- Swap management script: [general/manage-swap.sh](general/manage-swap.sh)
- Admin account bootstrap script: [general/create-admin.sh](general/create-admin.sh)
- Common service management script: [general/service-mgmt.sh](general/service-mgmt.sh)

> [!TIP]
> Arch Linux and Arch-based distribution support is planned and will be released in a future update.
> Until then, use the existing scripts only on their matching distribution families.

## Tested distributions

The table below shows the testing status of the scripts on various distributions:

| Distribution | Test status |
|---|---|
| Debian 13 | ✅ Passed |
| RHEL 10 | ✅ Passed |
| AlmaLinux 10 | ✅ Passed |
| Debian 12 | ⚠️ Testing |
| Ubuntu 24.04 | ⚠️ Testing |
| Ubuntu 22.04 | ⚠️ Testing |
| Rocky Linux 10 | ⚠️ Testing |
| AlmaLinux 9 | ❌ Not tested |
| CentOS 10 Stream | ❌ Not tested |
| CentOS 7 | ❌ Not tested |
| Rocky Linux 9 | ❌ Not tested |
| openSUSE Leap 16 | ❌ Not tested |

Status key: ✅ = Passed testing; ⚠️ = Testing in progress or tested with compatibility issues; ❌ = Not tested

## What These Scripts Do

### Initialization scripts (`specific/`)

The two initialization scripts are designed for first-pass server bootstrap and include:

- System update at the beginning of execution
- OpenSSH server installation and service enablement (completed with the help of GPT-5.2)
- Common baseline package installation
- Firewall setup for SSH (22), HTTP (80), and HTTPS (443)

Distribution-specific behavior:

- Debian/Ubuntu:
	- Uses UFW
	- Uses package manager **fallback** order: **`apt`**, then **`apt-get`**
	- Installs SELinux tools and attempts to enable SELinux (permissive) when disabled
- CentOS/RHEL family:
	- Uses firewalld (i.e. firewall-cmd)
	- Uses package manager **fallback** order: **`dnf`**, then **`yum`**
	- Installs and refreshes EPEL repository metadata

### General scripts (`general/`)

- `general/manage-swap.sh`
	- Interactive swap management CLI
	- Recommends swap size based on RAM
	- Creates/enables `/swapfile` and persists it in `/etc/fstab`
	- Supports safe swap removal and warns on low-memory hosts
- `general/create-admin.sh`
	- Creates (or reuses) a non-root admin user
	- Sets user password and grants admin group access (`sudo`/`wheel`)
	- Hardens SSH by setting `PermitRootLogin prohibit-password`
	- Validates SSH config and reloads SSH service
- `general/service-mgmt.sh`
	- Provides a common service control entrypoint for LAMP, LNMP and `java`
	- Supports `start`, `stop`, `restart`, and `status`
	- Handles service-name differences across distributions (for example `apache2`/`httpd`, `mysql`/`mariadb`)

## Requirements

- Linux server (Debian/Ubuntu or CentOS/RHEL family)
- sudo/root privileges
- systemd-based environment
- Internet access for package installation and updates

## Usage

> [!TIP]
> You might need to install `sudo` and configure Internet connections first on some distributions.

### Option A: Run from a local clone

First, clone the repository:

```bash
git clone --depth=1 https://www.github.com/nakamurasama072/fast-server-mgmt-scripts.git
```

Then change to the directory of the repository:

```bash
cd fast-server-mgmt-scripts
```

From the repository root:

```bash
chmod +x specific/init/fast-server-init-debian.sh specific/init/fast-server-init-rhel.sh general/manage-swap.sh general/create-admin.sh general/service-mgmt.sh
```

Run on Debian/Ubuntu:

```bash
sudo ./specific/init/fast-server-init-debian.sh
```

Run on CentOS/RHEL family:

```bash
sudo ./specific/init/fast-server-init-rhel.sh
```

Run general scripts (on supported Linux distributions):

```bash
sudo ./general/manage-swap.sh
sudo ./general/create-admin.sh
sudo ./general/service-mgmt.sh restart lamp
```

### Option B: One-liner clean execution (no local clone)

This requires `curl` or `wget`, either of which is already included in most distributions.

Run on Debian/Ubuntu:

```bash
curl -fsSL https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/specific/init/fast-server-init-debian.sh | sudo bash
wget -qO- https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/specific/init/fast-server-init-debian.sh | sudo bash
```

Run on CentOS/RHEL family:

```bash
curl -fsSL https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/specific/init/fast-server-init-rhel.sh | sudo bash
wget -qO- https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/specific/init/fast-server-init-rhel.sh | sudo bash
```

Run general scripts:

```bash
curl -fsSL https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/general/manage-swap.sh | sudo bash
wget -qO- https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/general/manage-swap.sh | sudo bash

curl -fsSL https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/general/create-admin.sh | sudo bash
wget -qO- https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/general/create-admin.sh | sudo bash

curl -fsSL https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/general/service-mgmt.sh | sudo bash -s -- restart lamp
wget -qO- https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/general/service-mgmt.sh | sudo bash -s -- status java
```

## Notes

- Run each script only on its matching distribution family.
- `general/manage-swap.sh`, `general/create-admin.sh`, and `general/service-mgmt.sh` require sudo/root for privileged operations.
- On Debian/Ubuntu, a reboot may be required after SELinux activation changes.
- These scripts intentionally do not modify software mirror/repository source lists.

 
