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
    fail "This script must be run with sudo (example: sudo bash manage-swap.sh)."
  fi
}

# Note: You SHOULD NOT modify other parts except the TODO sections in the script.

# Detect physical memory size and recommend swap size based on it.
recommend_swap_size() {
  local mem_kb mem_gb recommended_gb
  mem_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
  mem_gb=$(( (mem_kb + 1024 * 1024 - 1) / (1024 * 1024) ))

  if (( mem_gb <= 2 )); then
    recommended_gb=$(( mem_gb * 2 ))
  elif (( mem_gb <= 8 )); then
    recommended_gb="${mem_gb}"
  elif (( mem_gb <= 64 )); then
    recommended_gb=$(( (mem_gb + 1) / 2 ))
  else
    recommended_gb=4
  fi

  if (( recommended_gb < 1 )); then
    recommended_gb=1
  fi

  echo "${recommended_gb}"
}

# Read and validate the desired swap size from user input.
get_swap_size() {
  local recommended_size user_input
  recommended_size="$(recommend_swap_size)"

  note "Recommended swap size: ${recommended_size}G"
  read -r -p "Enter swap size in GB (e.g. 2 or 2G, default ${recommended_size}G): " user_input

  if [[ -z "${user_input}" ]]; then
    echo "${recommended_size}"
    return
  fi

  user_input="${user_input%[Gg]}"
  if ! [[ "${user_input}" =~ ^[1-9][0-9]*$ ]]; then
    fail "Invalid swap size: '${user_input}'. Please provide a positive integer (GB)."
  fi

  echo "${user_input}"
  # Note: The recommended swap size can be used as a default value if the user just presses Enter without typing anything.
}

# Check if there is enough free disk space to create the swap file.
check_disk_space() {
  local requested_size_gb="$1"
  local available_kb required_kb safety_buffer_kb available_gb required_gb

  available_kb="$(df --output=avail -k / | tail -n 1 | tr -d ' ')"
  safety_buffer_kb=$((256 * 1024))
  required_kb=$(( requested_size_gb * 1024 * 1024 + safety_buffer_kb ))

  if (( available_kb < required_kb )); then
    available_gb=$(( available_kb / 1024 / 1024 ))
    required_gb=$(( (required_kb + 1024 * 1024 - 1) / (1024 * 1024) ))
    fail "Insufficient disk space on '/': need about ${required_gb}G free, but only ${available_gb}G available."
  fi
}

# Create the swap file, set permissions, and enable it.
create_and_enable_swap() {
  local swap_size_gb="$1"

  if [[ -f /swapfile ]]; then
    fail "Swap file '/swapfile' already exists. Delete it first, then retry."
  fi

  log "Creating /swapfile (${swap_size_gb}G)..."
  if ! fallocate -l "${swap_size_gb}G" /swapfile; then
    warn "fallocate failed on this filesystem, falling back to dd (this may take longer)."
    dd if=/dev/zero of=/swapfile bs=1G count="${swap_size_gb}" status=progress
  fi

  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile

  if ! grep -qE '^\s*/swapfile\s+none\s+swap\s+sw\s+0\s+0\s*$' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi

  log "Swap enabled successfully."
  swapon --show
}

# Delete the swap file and disable it.
delete_swap() {
  if swapon --show=NAME | grep -qx '/swapfile'; then
    log "Disabling /swapfile..."
    swapoff /swapfile
  else
    note "'/swapfile' is not currently enabled as swap."
  fi

  if [[ -f /swapfile ]]; then
    log "Removing /swapfile..."
    rm -f /swapfile
  fi

  if grep -qE '^\s*/swapfile\s+none\s+swap\s+sw\s+0\s+0\s*$' /etc/fstab; then
    sed -i '/^\s*\/swapfile\s\+none\s\+swap\s\+sw\s\+0\s\+0\s*$/d' /etc/fstab
  fi

  log "Swap file removed (if it existed) and fstab entry cleaned up."
}

# Warn the user when physical memory is small but would like to delete the swap file.
warn_small_memory() {
  local mem_kb mem_gb
  mem_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
  mem_gb=$(( (mem_kb + 1024 * 1024 - 1) / (1024 * 1024) ))

  if (( mem_gb < 4 )); then
    warn "This machine has only about ${mem_gb}G RAM. Removing swap may cause OOM issues under load."
  fi
}

# The CLI for the script.
cli_app() {
  local choice swap_size confirm

  check_root_permissions

  echo "==== Swap Management ===="
  note "Current memory/swap status:"
  free -h
  echo

  echo "1) Create/Enable swap (/swapfile)"
  echo "2) Delete swap (/swapfile)"
  echo "3) Exit"
  read -r -p "Choose an option [1-3]: " choice

  case "${choice}" in
    1)
      if swapon --show=NAME | grep -qx '/swapfile' || [[ -f /swapfile ]]; then
        warn "Detected existing /swapfile or active swap entry."
        read -r -p "Replace it? [y/N]: " confirm
        if [[ "${confirm}" =~ ^[Yy]$ ]]; then
          delete_swap
        else
          note "Operation cancelled by user."
          return
        fi
      fi

      swap_size="$(get_swap_size)"
      check_disk_space "${swap_size}"
      create_and_enable_swap "${swap_size}"
      ;;
    2)
      warn_small_memory
      read -r -p "Are you sure you want to delete /swapfile? [y/N]: " confirm
      if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        delete_swap
      else
        note "Operation cancelled by user."
      fi
      ;;
    3)
      note "Bye."
      ;;
    *)
      fail "Invalid option: ${choice}"
      ;;
  esac
}

# Main execution flow.
main() {
  cli_app
}

main "$@"