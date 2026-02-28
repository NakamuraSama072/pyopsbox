#!/bin/bash

set -euo pipefail

# Absolute path of this script (used when installing cron jobs).
SCRIPT_PATH="$(readlink -f "$0")"
# Default report directory and daily cron schedule (06:15).
DEFAULT_REPORT_DIR="/var/log/server-health"
DEFAULT_CRON_SCHEDULE="15 6 * * *"
# Common services to monitor.
TARGET_SERVICES=(ssh sshd cron crond firewalld ufw)

# Basic info logger.
log() {
	echo "[INFO] $1"
}

# Warning logger (stderr).
warn() {
	echo "[WARN] $1" >&2
}

# Error logger (stderr) and exit.
fail() {
	echo "[ERROR] $1" >&2
	exit 1
}

# Unified root privilege check for privileged actions.
require_root() {
	if [[ "${EUID}" -ne 0 ]]; then
		fail "This action requires sudo/root privileges."
	fi
}

# Check whether a command is available.
check_cmd() {
	command -v "$1" >/dev/null 2>&1
}

# Standardized timestamp format for auditing.
human_timestamp() {
	date '+%Y-%m-%d %H:%M:%S %z'
}

# Capture a single CPU usage snapshot (fallback to N/A if top is unavailable).
collect_cpu_snapshot() {
	if check_cmd top; then
		top -bn1 | awk -F'[, ]+' '/^%Cpu\(s\)|^Cpu\(s\)/ {print "user=" $2 "% system=" $4 "% idle=" $8 "%"; found=1} END {if (!found) print "N/A"}'
		return
	fi
	echo "N/A"
}

# Show top memory-consuming processes.
collect_top_memory_processes() {
	if check_cmd ps; then
		ps -eo pid,comm,%cpu,%mem --sort=-%mem | head -n 6
		return
	fi
	echo "ps command not available"
}

# Count pending package updates based on available package manager.
collect_updates_status() {
    if check_cmd apt; then
        local count
        count="$(apt list --upgradable 2>/dev/null | grep -v 'Listing...' | wc -l | tr -d ' ')"
        echo "pending_updates=${count} (apt)"
        return
    fi

	if check_cmd apt-get; then
		local count
		count="$(apt-get -s upgrade 2>/dev/null | awk '/^Inst / {c++} END {print c+0}')"
		echo "pending_updates=${count} (apt-get)"
		return
	fi

	if check_cmd dnf; then
		local count
		count="$(dnf -q check-update 2>/dev/null | awk 'BEGIN{c=0} /^[[:alnum:]_.-]+[[:space:]]+[[:alnum:]_.:-]+[[:space:]]/ {c++} END {print c+0}')"
		echo "pending_updates=${count} (dnf)"
		return
	fi

	if check_cmd yum; then
		local count
		count="$(yum -q check-update 2>/dev/null | awk 'BEGIN{c=0} /^[[:alnum:]_.-]+[[:space:]]+[[:alnum:]_.:-]+[[:space:]]/ {c++} END {print c+0}')"
		echo "pending_updates=${count} (yum)"
		return
	fi

	echo "pending_updates=unknown (no supported package manager found)"
}

# Collect status for target services that exist on this host.
collect_service_status() {
	if ! check_cmd systemctl; then
		echo "systemctl not available"
		return
	fi

	local seen=0
	for service in "${TARGET_SERVICES[@]}"; do
		if systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "${service}.service"; then
			echo "${service}: $(systemctl is-active "${service}" 2>/dev/null || true)"
			seen=1
		fi
	done

	if (( seen == 0 )); then
		echo "No target services found (${TARGET_SERVICES[*]})"
	fi
}

# Report count and details of failed systemd services.
collect_failed_services() {
	if check_cmd systemctl; then
		local failed
		failed="$(systemctl --failed --no-legend --plain 2>/dev/null | wc -l | tr -d ' ')"
		echo "failed_services=${failed}"
		if (( failed > 0 )); then
			systemctl --failed --no-legend --plain 2>/dev/null
		fi
		return
	fi
	echo "failed_services=unknown (systemctl not available)"
}

# Generate full health report and write it to today's log file.
generate_report() {
	local report_dir="$1"
	mkdir -p "${report_dir}"

	local hostname short_date report_file
	hostname="$(hostname -f 2>/dev/null || hostname)"
	short_date="$(date +%Y%m%d)"
	report_file="${report_dir}/health-${hostname//[^a-zA-Z0-9._-]/_}-${short_date}.log"

	{
		echo "===== Server Health Report ====="
		echo "Generated: $(human_timestamp)"
		echo "Host: ${hostname}"
		echo "Kernel: $(uname -srmo)"
		echo

		echo "[Uptime & Load]"
		uptime
		echo

		echo "[CPU Snapshot]"
		collect_cpu_snapshot
		echo

		echo "[Memory]"
		free -h
		echo

		echo "[Disk Usage]"
		df -hT -x tmpfs -x devtmpfs
		echo

		echo "[Filesystem Inodes]"
		df -ih -x tmpfs -x devtmpfs
		echo

		echo "[Top Memory Processes]"
		collect_top_memory_processes
		echo

		echo "[Service Status]"
		collect_service_status
		echo

		echo "[Failed Services]"
		collect_failed_services
		echo

		echo "[Last Reboots]"
		last reboot | head -n 5
		echo

		echo "[Security/Login Summary]"
		echo "Recent failed SSH logins (if available):"
		if check_cmd journalctl; then
			journalctl -u ssh -u sshd --since "24 hours ago" --no-pager 2>/dev/null | grep -Ei 'failed|invalid|authentication failure' | tail -n 10 || true
		else
			echo "journalctl not available"
		fi
		echo

		echo "[Updates]"
		collect_updates_status
		echo
	} | tee "${report_file}"

	log "Health report written to: ${report_file}"
}

# Install a cron job for the current user to run daily checks.
install_cron_job() {
	local schedule="$1"
	local report_dir="$2"
	require_root

	if ! check_cmd crontab; then
		fail "crontab command not found. Install cron/cronie first."
	fi

	mkdir -p "${report_dir}"

	local cron_line
	cron_line="${schedule} ${SCRIPT_PATH} --run --report-dir ${report_dir} >/dev/null 2>&1"

	local current_cron temp_file
	current_cron="$(crontab -l 2>/dev/null || true)"

	if printf '%s\n' "${current_cron}" | grep -Fqx "${cron_line}"; then
		log "Cron job already exists. No changes made."
		return
	fi

	temp_file="$(mktemp)"
	{
		printf '%s\n' "${current_cron}"
		printf '%s\n' "${cron_line}"
	} | sed '/^[[:space:]]*$/d' > "${temp_file}"

	crontab "${temp_file}"
	rm -f "${temp_file}"
	log "Cron job installed: ${cron_line}"
}

# Command-line help.
usage() {
	cat <<'EOF'
Usage:
	health-check.sh --run [--report-dir DIR]
	health-check.sh --install-cron [--schedule "CRON_EXPR"] [--report-dir DIR]
	health-check.sh --help

Examples:
	sudo bash health-check.sh --run
	sudo bash health-check.sh --install-cron
	sudo bash health-check.sh --install-cron --schedule "0 7 * * *" --report-dir /var/log/server-health
EOF
}

# Argument parsing and action dispatcher.
main() {
	local action=""
	local schedule="${DEFAULT_CRON_SCHEDULE}"
	local report_dir="${DEFAULT_REPORT_DIR}"

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--run)
				action="run"
				shift
				;;
			--install-cron)
				action="install_cron"
				shift
				;;
			--schedule)
				[[ $# -lt 2 ]] && fail "Missing value for --schedule"
				schedule="$2"
				shift 2
				;;
			--report-dir)
				[[ $# -lt 2 ]] && fail "Missing value for --report-dir"
				report_dir="$2"
				shift 2
				;;
			--help|-h)
				usage
				exit 0
				;;
			*)
				fail "Unknown argument: $1"
				;;
		esac
	done

	case "${action}" in
		run)
			generate_report "${report_dir}"
			;;
		install_cron)
			install_cron_job "${schedule}" "${report_dir}"
			;;
		*)
			usage
			exit 1
			;;
	esac
}

# Program entry point.
main "$@"