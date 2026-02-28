# pyopsbox
A lightweight Linux InfraOps launcher.

`pyopsbox` is built for one practical goal: give operators a single entry point to run local server-management scripts, especially on hosts without reliable Internet access.

Instead of re-implementing everything, it calls the scripts under `scripts/`:

- `specific/init/fast-server-init-debian.sh`
- `specific/init/fast-server-init-rhel.sh`
- `general/manage-swap.sh`
- `general/create-admin.sh`
- `general/health-check.sh`
- `general/service-mgmt.sh`

## Requirements

- Python 3.8+
- Linux (systemd-based environments are recommended)

## Quick Start

```bash
python3 main.py
```

The launcher runs in an interactive loop. After a script finishes, it returns to the menu and waits for the next command.

## What you can run

- Debian/Ubuntu server initialization
- RHEL/CentOS server initialization
- Swap management
- Admin account bootstrap
- Health check (run once)
- Health check (install cron)
- Service management (`start|stop|restart|status` with `lamp|lnmp|java`)
- Custom script execution under `scripts/`

## Why script dispatch instead of direct implementation?

Two reasons:

1. **No need to rebuild what already works**
   The scripts are already available, tested in practice, and designed for ops workflows. Rewriting them would add avoidable development and maintenance cost.

2. **Python stays as a thin orchestration layer**
   For low-level system paths, this project prefers C/C++-style implementation concerns over Python in terms of readability style and performance characteristics. So Python is kept simple: menu + dispatch.

## Design Principles

- KISS: keep the launcher simple
- Python standard library only
- Offline-first operation
- Keep operational logic in shell scripts

## Reference

Original script collection and design inspiration:

- https://www.github.com/NakamuraSama072/fast-server-mgmt-scripts
