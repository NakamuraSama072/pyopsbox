#!/bin/bash

set -euo pipefail

# Basic info logger.
log() {
	echo "[INFO] $1"
}

# Informational note logger.
note() {
	echo "[NOTE] $1"
}

# Warning logger.
warn() {
	echo "[WARN] $1"
}

# Error logger and exit.
fail() {
	echo "[ERROR] $1" >&2
	exit 1
}

# Ensure the script runs with root/sudo privileges.
check_root_permissions() {
	if [[ "${EUID}" -ne 0 ]]; then
		fail "This script must be run with sudo/root privileges (example: sudo bash create-admin.sh)."
	fi
}

# Detect admin group automatically (sudo on Debian-like, wheel on RHEL-like systems).
get_admin_group() {
	if getent group sudo >/dev/null 2>&1; then
		echo "sudo"
		return
	fi

	if getent group wheel >/dev/null 2>&1; then
		echo "wheel"
		return
	fi

	fail "No supported admin group found (expected 'sudo' or 'wheel')."
}

# Read and validate the admin username to create.
ask_admin_username() {
	local username

	read -r -p "Enter admin username to create: " username
	if [[ -z "${username}" ]]; then
		fail "Username cannot be empty."
	fi

	if [[ "${username}" == "root" ]]; then
		fail "Username 'root' is not allowed for this operation."
	fi

	if ! [[ "${username}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
		fail "Invalid username '${username}'. Use lowercase letters (a-z), numbers (0-9), underscore (_), or hyphen (-)."
	fi

	echo "${username}"
}

# Create user if missing, then set password.
create_or_prepare_user() {
	local username="$1"

	if id -u "${username}" >/dev/null 2>&1; then
		note "User '${username}' already exists."
	else
		log "Creating user '${username}'..."
		if command -v useradd >/dev/null 2>&1; then
			useradd -m -s /bin/bash "${username}"
		elif command -v adduser >/dev/null 2>&1; then
			adduser --disabled-password --gecos "" "${username}"
		else
			fail "Neither useradd nor adduser was found on this system."
		fi
	fi

	log "Setting password for '${username}'..."
	passwd "${username}"
}

# Add user to the admin group.
grant_admin_privilege() {
	local username="$1"
	local admin_group="$2"

	log "Granting admin privileges via '${admin_group}' group..."
	usermod -aG "${admin_group}" "${username}"
}

# Disable root password-based SSH login (keep key-based login).
configure_sshd_root_password_auth() {
	local sshd_config="/etc/ssh/sshd_config"

	if [[ ! -f "${sshd_config}" ]]; then
		fail "${sshd_config} was not found."
	fi

	log "Disabling SSH password login for root (PermitRootLogin prohibit-password)..."
	if grep -Eq '^[[:space:]]*#?[[:space:]]*PermitRootLogin([[:space:]]+|[[:space:]]*=[[:space:]]*).*$' "${sshd_config}"; then
		sed -i -E 's|^[[:space:]]*#?[[:space:]]*PermitRootLogin([[:space:]]+|[[:space:]]*=[[:space:]]*).*$|PermitRootLogin prohibit-password|' "${sshd_config}"
	else
		echo -e '\nPermitRootLogin prohibit-password\n' >> "${sshd_config}"
	fi

	if command -v sshd >/dev/null 2>&1; then
		sshd -t
	fi

	if systemctl list-unit-files --type=service | awk '{print $1}' | grep -qx 'ssh.service'; then
		systemctl reload ssh || systemctl restart ssh
		return
	fi

	if systemctl list-unit-files --type=service | awk '{print $1}' | grep -qx 'sshd.service'; then
		systemctl reload sshd || systemctl restart sshd
		return
	fi

	warn "SSH service unit not found for reload. Please restart SSH service manually."
}

# Main flow: check privileges -> detect group/user -> create user -> grant admin -> harden SSH.
main() {
	local username admin_group

	check_root_permissions
	admin_group="$(get_admin_group)"
	username="$(ask_admin_username)"

	create_or_prepare_user "${username}"
	grant_admin_privilege "${username}" "${admin_group}"
	configure_sshd_root_password_auth

	log "Done. User '${username}' is now an admin and root SSH password login is disabled."
	note "If you rely on root SSH access, make sure root public key authentication is configured before disconnecting."
}

# Program entry point.
main "$@"