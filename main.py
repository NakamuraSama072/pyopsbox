from __future__ import annotations

import shlex
import subprocess
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
SCRIPTS_DIR = ROOT_DIR / "scripts"


def info(message: str) -> None:
	print(f"[INFO] {message}")


def warn(message: str) -> None:
	print(f"[WARN] {message}", file=sys.stderr)
	
def error(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)


def run_script(script_rel_path: str, script_args: list[str] | None = None) -> int:
	script_args = script_args or []
	script_path = (SCRIPTS_DIR / script_rel_path).resolve()

	try:
		script_path.relative_to(SCRIPTS_DIR.resolve())
	except ValueError:
		error("Script path must stay inside scripts/ directory.")
		return 1

	if not script_path.exists():
		error(f"Script not found: {script_path}")
		return 1

	command = ["bash", str(script_path), *script_args]
	info(f"Running: {' '.join(command)}")

	stdin_stream = None
	try:
		if Path("/dev/tty").exists():
			stdin_stream = open("/dev/tty", "r", encoding="utf-8", errors="ignore")
	except OSError:
		stdin_stream = None

	try:
		if stdin_stream is not None:
			result = subprocess.run(command, check=False, stdin=stdin_stream)
		else:
			result = subprocess.run(command, check=False)
	finally:
		if stdin_stream is not None:
			stdin_stream.close()

	info(f"Script exit code: {result.returncode}")
	return int(result.returncode)


def show_menu() -> None:
	print("\n=== PyOpsBox Script Launcher ===")
	print("1) Init Debian/Ubuntu Server")
	print("2) Init RHEL/CentOS Server")
	print("3) Manage swap")
	print("4) Create admin user")
	print("5) Health check (run once)")
	print("6) Health check (install cron)")
	print("7) Service management (LAMP/LNMP/Java)")
	print("8) Run custom script under scripts/")
	print("0) Exit")


def show_last_result(last_command: str | None, last_exit_code: int | None) -> None:
	if last_command is None:
		return
	print(f"Last run: {last_command}")
	print(f"Last exit code: {last_exit_code}")


def run_service_management() -> int:
	action = input("Action (start|stop|restart|status): ").strip()
	stack = input("Stack (lamp|lnmp|java): ").strip()
	if not action or not stack:
		error("Action and stack are required.")
		return 1
	return run_script("general/service-mgmt.sh", [action, stack])


def run_custom_script() -> int:
	rel_path = input("Script path under scripts/ (example: general/health-check.sh): ").strip()
	if not rel_path:
		error("Script path cannot be empty.")
		return 1

	args_text = input("Args (optional, shell style): ").strip()
	args = shlex.split(args_text) if args_text else []
	return run_script(rel_path, args)


def command_label(choice: str) -> str:
	labels = {
		"1": "specific/init/fast-server-init-debian.sh",
		"2": "specific/init/fast-server-init-rhel.sh",
		"3": "general/manage-swap.sh",
		"4": "general/create-admin.sh",
		"5": "general/health-check.sh --run",
		"6": "general/health-check.sh --install-cron",
		"7": "general/service-mgmt.sh",
		"8": "custom script",
	}
	return labels.get(choice, "unknown")


def dispatch_choice(choice: str) -> int:
	if choice == "1":
		return run_script("specific/init/fast-server-init-debian.sh")
	if choice == "2":
		return run_script("specific/init/fast-server-init-rhel.sh")
	if choice == "3":
		return run_script("general/manage-swap.sh")
	if choice == "4":
		return run_script("general/create-admin.sh")
	if choice == "5":
		return run_script("general/health-check.sh", ["--run"])
	if choice == "6":
		return run_script("general/health-check.sh", ["--install-cron"])
	if choice == "7":
		return run_service_management()
	if choice == "8":
		return run_custom_script()
	if choice == "0":
		return 999

	warn("Invalid menu option.")
	return 1


def main() -> int:
	if sys.platform != "linux":
		error("This launcher supports Linux only. However your platform is:" f" {sys.platform}")
		raise SystemExit(1)

	if not SCRIPTS_DIR.exists():
		error(f"Missing scripts directory: {SCRIPTS_DIR}")
		raise SystemExit(1)

	print("PyOpsBox started. This tool only dispatches local scripts in scripts/.")
	print("Tip: many operations require sudo/root privileges.")
	last_command: str | None = None
	last_exit_code: int | None = None

	while True:
		show_last_result(last_command, last_exit_code)
		show_menu()
		try:
			choice = input("Choose [0-8]: ").strip()
		except (EOFError, KeyboardInterrupt):
			print()
			return 0

		result = dispatch_choice(choice)
		if result == 999:
			print("Bye.")
			return 0
		last_command = command_label(choice)
		last_exit_code = result


if __name__ == "__main__":
	raise SystemExit(main())
