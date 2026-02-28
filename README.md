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
- Linux (systemd-based environments are mandatory for some scripts)

## Disclaimer

This toolkit is still in beta. Make sure you adhere to the following:

- Use it carefully in production environments.
- Review each operation before execution.
- Prefer testing on non-critical/staging hosts first.
- Be responsible for validating outcomes on your own infrastructure.

## Quick Start

```bash
python3 main.py
```

Typically, there is no need to create a virtual environment, however you can if you wish.

The launcher runs in an interactive loop. After a script finishes, it returns to the menu and waits for the next command.

## Complete Toolkit Usage

1. **Prepare the project on target host**

   Clone the repo:
   ```bash
   git clone https://www.github.com/NakamuraSama072/pyopsbox.git
   ```

   Make sure these files exist together:
   - `main.py`
   - `scripts/` (with `general/` and `specific/init/`)

2. **Enter project directory**

   ```bash
   cd pyopsbox
   ```

3. **(Optional) Ensure script permissions**

   ```bash
   chmod +x scripts/general/*.sh scripts/specific/init/*.sh
   ```

4. **Run the launcher**

   ```bash
   python3 main.py
   ```

   For privileged operations (recommended for most menu actions):

   ```bash
   sudo python3 main.py
   ```

5. **Use the menu**

   - Choose `1-8` to run a task.
   - For option `7`, input action and stack when prompted.
   - For option `8`, provide a path relative to `scripts/` and optional arguments.

6. **Exit safely**

   - Choose `0` to exit the toolkit.

### Typical operator flow

```text
sudo python3 main.py
-> 5 (health check)
-> 3 (swap management)
-> 7 (service status)
-> 0 (exit)
```

## What you can run

This toolbox supports the following operations:

- Debian/Ubuntu server initialization
- RHEL/CentOS server initialization
- Swap management
- Admin account bootstrap
- Health check (run once)
- Health check (install cron)
- Service management (`start|stop|restart|status` with `lamp|lnmp|java`)
- Custom script execution under `scripts/`

## Why applying script dispatch instead of direct implementation?

To put it simply, there are two reasons:

1. **No need to rebuild what already works**
   The scripts are already available, tested in practice, and designed for ops workflows. Rewriting them would add avoidable development and maintenance cost.

2. **Python stays as a thin orchestration layer**
   For low-level system paths, this project prefers C/C++-style implementation concerns over Python in terms of readability style and performance characteristics. So Python is kept simple: menu + dispatch.

## Design Principles

- KISS: keep the launcher simple and stupid
- Offline-first operation
- Keep operational logic in shell scripts

## Reference

Original script collection and design inspiration:

- https://www.github.com/NakamuraSama072/fast-server-mgmt-scripts
