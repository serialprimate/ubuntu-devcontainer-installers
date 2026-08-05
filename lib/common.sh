#!/usr/bin/env bash

# Provides shared diagnostics and prerequisite checks without changing caller shell options.

# Usage: log_info <installer_name> <message...>
# Description: Writes an installer-qualified informational message to standard output.
log_info() {
    local installer_name="$1"
    shift

    printf '%s: info: %s\n' "${installer_name}" "$*"
}

# Usage: log_warning <installer_name> <message...>
# Description: Writes an installer-qualified warning to standard error.
log_warning() {
    local installer_name="$1"
    shift

    printf '%s: warning: %s\n' "${installer_name}" "$*" >&2
}

# Usage: log_error <installer_name> <message...>
# Description: Writes an installer-qualified error to standard error.
log_error() {
    local installer_name="$1"
    shift

    printf '%s: error: %s\n' "${installer_name}" "$*" >&2
}

# Usage: die <installer_name> <message...>
# Description: Writes an installer-qualified error and returns failure.
# Returns: Always returns 1.
die() {
    log_error "$@"
    return 1
}

# Usage: require_command <installer_name> <command_name> [advice]
# Description:
# - Verify that the required command can be resolved
# - Write an actionable error to standard error when it is absent
# Returns: Non-zero when the command is absent.
require_command() {
    local installer_name="$1"
    local command_name="$2"
    local advice="${3:-Install it before invoking this installer.}"

    if ! command -v -- "${command_name}" >/dev/null 2>&1; then
        die "${installer_name}" \
            "required command not found: ${command_name}. ${advice}"
    fi
}

# Usage: require_root <installer_name> [effective_uid]
# Description:
# - Verify that the effective user is root
# - Write an actionable error to standard error when it is not
# Returns: Non-zero when the effective UID is not zero.
require_root() {
    local installer_name="$1"
    local effective_uid="${2:-${EUID}}"

    if [[ "${effective_uid}" != "0" ]]; then
        die "${installer_name}" "must be run as root."
    fi
}
