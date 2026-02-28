#!/bin/bash

set -euo pipefail

log() {
	echo "[INFO] $1"
}

warn() {
	echo "[WARN] $1" >&2
}

fail() {
	echo "[ERROR] $1" >&2
	exit 1
}

# Check whether a command exists.
has_cmd() {
	command -v "$1" >/dev/null 2>&1
}

# Check whether a service unit exists in systemd.
service_exists() {
	local svc="$1"
	systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "${svc}.service"
}

# Pick the first available service name from candidates.
lookup_service() {
	local name
	for name in "$@"; do
		if service_exists "${name}"; then
			echo "${name}"
			return 0
		fi
	done
	return 1
}

# Run action on a resolved service.
run_action() {
	local action="$1"
	local service_name="$2"

	if ! has_cmd systemctl; then
		fail "systemctl is required for this script."
	fi

	case "${action}" in
		start|stop|restart|status)
			if [[ "${action}" != "status" && "${EUID}" -ne 0 ]]; then
				fail "Action '${action}' requires sudo/root privileges."
			fi
			log "${action} -> ${service_name}"
			systemctl "${action}" "${service_name}"
			;;
		*)
			fail "Unsupported action: ${action}"
			;;
	esac
}

# Resolve service list for LAMP stack.
resolve_lamp_services() {
	local apache mysql php_fpm
	apache="$(lookup_service apache2 httpd || true)"
	mysql="$(lookup_service mysql mariadb mysqld || true)"
	php_fpm="$(lookup_service php-fpm php8.3-fpm php8.2-fpm php8.1-fpm php8.0-fpm php7.4-fpm || true)"

	[[ -n "${apache}" ]] && echo "${apache}"
	[[ -n "${mysql}" ]] && echo "${mysql}"
	[[ -n "${php_fpm}" ]] && echo "${php_fpm}"
}

# Resolve service list for LNMP stack.
resolve_lnmp_services() {
	local nginx mysql php_fpm
	nginx="$(lookup_service nginx || true)"
	mysql="$(lookup_service mysql mariadb mysqld || true)"
	php_fpm="$(lookup_service php-fpm php8.3-fpm php8.2-fpm php8.1-fpm php8.0-fpm php7.4-fpm || true)"

	[[ -n "${nginx}" ]] && echo "${nginx}"
	[[ -n "${mysql}" ]] && echo "${mysql}"
	[[ -n "${php_fpm}" ]] && echo "${php_fpm}"
}

# Resolve service list for Java stack.
resolve_java_services() {
	local java_app
	java_app="$(lookup_service tomcat tomcat9 tomcat10 jetty springboot || true)"

	if [[ -n "${java_app}" ]]; then
		echo "${java_app}"
	else
		warn "No common Java service unit found (tomcat/jetty/springboot)."
	fi
}

usage() {
	cat <<'EOF'
Usage:
	service-mgmt.sh <start|stop|restart|status> <lamp|lnmp|java>

Examples:
	sudo bash service-mgmt.sh start lamp
	sudo bash service-mgmt.sh restart lnmp
	bash service-mgmt.sh status java
EOF
}

main() {
	local action="${1:-}"
	local stack="${2:-}"
	local services=()

	if [[ -z "${action}" || -z "${stack}" ]]; then
		usage
		exit 1
	fi

	case "${stack}" in
		lamp)
			mapfile -t services < <(resolve_lamp_services)
			;;
		lnmp)
			mapfile -t services < <(resolve_lnmp_services)
			;;
		java)
			mapfile -t services < <(resolve_java_services)
			;;
		*)
			fail "Unsupported stack: ${stack}"
			;;
	esac

	if [[ "${#services[@]}" -eq 0 ]]; then
		fail "No services resolved for stack: ${stack}"
	fi

	local svc
	for svc in "${services[@]}"; do
		if service_exists "${svc}"; then
			run_action "${action}" "${svc}"
		else
			warn "Skip '${svc}': service not found on this host."
		fi
	done
}

main "$@"
