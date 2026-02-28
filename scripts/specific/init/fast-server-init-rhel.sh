#!/bin/bash

set -euo pipefail

# Basic log helpers.
log() {
  echo "[INFO] $1"
}

note() {
  echo "[NOTE] $1"
}

warn() {
  echo "[WARN] $1"
}

fail() {
  echo "[ERROR] $1" >&2
  exit 1
}

# Require sudo/root execution.
check_root_permissions() {
  if [[ "${EUID}" -ne 0 ]]; then
    fail "This script must be run with sudo (example: sudo bash fast-server-init-rhel.sh). Initialization terminated with errors."
  fi
}

# Prefer newer package manager first: dnf -> yum.
detect_package_manager() {
  if command -v dnf >/dev/null 2>&1; then
    log "'dnf' detected. It will be used as the package manager."
    PKG_MGR="dnf"
  elif command -v yum >/dev/null 2>&1; then
    log "'yum' detected instead. Note that 'yum' is older and may have different behavior compared to 'dnf'."
    PKG_MGR="yum"
  else
    fail "Neither dnf nor yum was found on this system. Initialization terminated with errors."
  fi
}

# Validate OS family before running CentOS/RHEL-specific operations.
ensure_rhel_family() {
  if [[ ! -f /etc/os-release ]]; then
    fail "Cannot detect OS: /etc/os-release was not found. Initialization terminated with errors."
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  local os_like="${ID_LIKE:-}"
  local os_id="${ID:-}"

  if [[ "${os_id}" != "rhel" && "${os_id}" != "centos" && "${os_id}" != "rocky" && "${os_id}" != "almalinux" && "${os_like}" != *"rhel"* && "${os_like}" != *"fedora"* ]]; then
    note "This script only supports CentOS/RHEL family systems. Detected: ${PRETTY_NAME:-unknown}."
    note "If you are using Debian/Ubuntu, please run the Debian/Ubuntu-specific initialization script instead:"
    note "curl -fsSL https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/specific/init/fast-server-init-debian.sh | sudo bash"
    fail "Initialization terminated with errors."
  fi
}

# Always update system before initialization tasks.
update_system() {
  log "Updating system packages..."
  ${PKG_MGR} -y update
}

# Install and refresh EPEL metadata as required for RHEL-family systems.
# This function includes a fallback mechanism to directly install the EPEL release RPM if the package is not found in current repositories,
# which is also the idea from GPT-5.2.
install_epel() {
  log "Installing and enabling EPEL repository..."
  if ${PKG_MGR} -y install epel-release; then
    ${PKG_MGR} -y makecache
    return
  fi

  warn "Package 'epel-release' was not found in current repositories."

  if [[ ! -f /etc/os-release ]]; then
    fail "Cannot detect OS version for EPEL fallback installation. Initialization terminated with errors."
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  local major_version
  major_version="${VERSION_ID%%.*}"

  if [[ -z "${major_version}" ]]; then
    fail "Cannot parse major version from VERSION_ID='${VERSION_ID:-unknown}'."
    fail "Initialization terminated with errors."
    exit 1
  fi

  local epel_rpm_url
  epel_rpm_url="https://dl.fedoraproject.org/pub/epel/epel-release-latest-${major_version}.noarch.rpm"

  log "Trying EPEL fallback RPM: ${epel_rpm_url}"
  ${PKG_MGR} -y install "${epel_rpm_url}"
  ${PKG_MGR} -y makecache
}

# Install baseline tools used in RHCSA-related setup workflows.
install_base_packages() {
  log "Installing base packages..."
  ${PKG_MGR} -y install \
    openssh-server \
    firewalld \
    rsync \
    lrzsz \
    sysstat \
    elinks \
    wget \
    curl \
    net-tools \
    bash-completion \
    vim \
    ca-certificates \
    policycoreutils \
    policycoreutils-python-utils
}

# Ensure SSH service is enabled and started.
configure_ssh() {
  log "Enabling and starting SSH service..."
  systemctl enable --now sshd
}

# Allow root login via SSH by editing /etc/ssh/sshd_config.
# This function is completed by GPT-5.2 but tested on AlmaLinux 9+ and Rocky Linux 9+.
configure_sshd_root_login() {
  local sshd_config="/etc/ssh/sshd_config"

  if [[ ! -f "${sshd_config}" ]]; then
    fail "${sshd_config} was not found."
  fi

  log "Updating ${sshd_config} to allow root SSH login..."
  if grep -Eq '^[[:space:]]*#?[[:space:]]*PermitRootLogin[[:space:]]+' "${sshd_config}"; then
    sed -i -E 's|^[[:space:]]*#?[[:space:]]*PermitRootLogin[[:space:]]+.*$|PermitRootLogin yes|' "${sshd_config}"
  else
    echo -e '\nPermitRootLogin yes\n' >> "${sshd_config}"
  fi

  if command -v sshd >/dev/null 2>&1; then
    sshd -t
  fi

  systemctl reload sshd || systemctl restart sshd
}

# Configure firewalld with persistent rules for SSH/HTTP/HTTPS.
configure_firewalld() {
  log "Configuring firewalld rules..."
  systemctl enable --now firewalld
  # Using --add-service may not work on some instances, so
  # we will add ports directly to ensure they are open.
  firewall-cmd --permanent --add-port=22/tcp
  firewall-cmd --permanent --add-port=80/tcp
  firewall-cmd --permanent --add-port=443/tcp
  firewall-cmd --reload
}

# Report current SELinux mode and provide guidance when needed.
check_selinux() {
  if command -v getenforce >/dev/null 2>&1; then
    local mode
    mode="$(getenforce)"
    log "Current SELinux mode: ${mode}"
    if [[ "${mode}" == "Permissive" ]]; then
      warn "SELinux is permissive. Consider setting enforcing mode after validating your services."
    elif [[ "${mode}" == "Disabled" ]]; then
      warn "SELinux is disabled. Enabling it requires policy configuration and a reboot."
    fi
  fi
}

# Main execution flow.
main() {
  check_root_permissions
  ensure_rhel_family
  detect_package_manager

  update_system
  install_epel
  install_base_packages
  configure_ssh
  configure_sshd_root_login
  configure_firewalld
  check_selinux

  log "Initialization completed for CentOS/RHEL family."
}

main "$@"
