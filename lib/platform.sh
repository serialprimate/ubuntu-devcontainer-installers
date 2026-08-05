#!/usr/bin/env bash

# Provides Ubuntu release and architecture checks without changing caller shell options.

# Usage: _os_release_value <key> <os_release_path>
# Description:
# - Read one literal os-release field without executing metadata as shell code
# - Write its unquoted value to standard output
# Returns: Non-zero when the field is absent.
_os_release_value() {
    local key="$1"
    local os_release_path="$2"
    local line
    local value

    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" == "${key}="* ]]; then
            value="${line#*=}"
            if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
                value="${value:1:${#value}-2}"
            elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
                value="${value:1:${#value}-2}"
            fi
            printf '%s\n' "${value}"
            return 0
        fi
    done <"${os_release_path}"

    return 1
}

# Usage: require_supported_platform <installer_name> [os_release_path] [machine]
# Description:
# - Verify the supported Ubuntu release and linux/amd64 architecture
# - Write an actionable error to standard error when validation fails
# Returns: Non-zero when metadata is unreadable or the platform is unsupported.
require_supported_platform() {
    local installer_name="$1"
    local os_release_path="${2:-/etc/os-release}"
    local machine="${3:-}"
    local distribution_id
    local version_id

    if [[ ! -r "${os_release_path}" ]]; then
        die "${installer_name}" "cannot read operating-system metadata: ${os_release_path}"
        return 1
    fi

    if ! distribution_id="$(_os_release_value ID "${os_release_path}")" ||
        ! version_id="$(_os_release_value VERSION_ID "${os_release_path}")"; then
        die "${installer_name}" \
            "operating-system metadata must define ID and VERSION_ID: ${os_release_path}"
        return 1
    fi

    if [[ "${distribution_id}" != "ubuntu" || "${version_id}" != "26.04" ]]; then
        die "${installer_name}" \
            "unsupported platform: requires Ubuntu 26.04; found ${distribution_id} ${version_id}."
        return 1
    fi

    if [[ -z "${machine}" ]]; then
        require_command "${installer_name}" uname
        machine="$(uname -m)"
    fi

    if [[ "${machine}" != "x86_64" ]]; then
        die "${installer_name}" \
            "unsupported architecture: requires linux/amd64; found ${machine}."
    fi
}
