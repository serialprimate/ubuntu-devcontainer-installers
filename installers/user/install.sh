#!/usr/bin/env bash
set -euo pipefail

# Establishes a development user and primary group with explicit numeric identities.

# Define installer metadata, defaults and bundled libraries
readonly installer='user'
readonly maximum_id='4294967294'
sudoers_temp_path=''
installer_dir="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
        pwd
)"
readonly installer_dir
readonly repository_lib_dir="${installer_dir}/../../lib"
# Resolve the bundled library through the installer-relative path
# shellcheck disable=SC1091
source "${repository_lib_dir}/common.sh"
# Resolve the bundled library through the installer-relative path
# shellcheck disable=SC1091
source "${repository_lib_dir}/arguments.sh"
# Resolve the bundled library through the installer-relative path
# shellcheck disable=SC1091
source "${repository_lib_dir}/platform.sh"

# Usage: usage
# Description: Writes command usage and option details to standard output.
usage() {
    cat <<'EOF'
Usage: install.sh [OPTIONS]

Establish a development user and same-named primary group on Ubuntu 26.04
(linux/amd64).

Options:
  --username NAME       User and primary-group name (default: dev).
  --uid ID              Numeric user ID, excluding 0 (default: 1000).
  --gid ID              Numeric primary-group ID, excluding 0 (default: 1000).
  --shell PATH          Installed executable login shell (default: /bin/bash).
  --group NAME          Existing supplementary group; may be repeated.
  --allow-passwordless-sudo
                        Exception: grant unrestricted passwordless sudo.
  --help                Show this help and exit without changing system state.

Conflicting non-root accounts are replaced only after all conflicts pass safety
checks. Passwords and password hashes are intentionally not accepted.
EOF
}

# Usage: cleanup
# Description: Removes the installer-owned temporary sudoers candidate, when present.
# Side Effects: Removes the temporary file identified by sudoers_temp_path.
cleanup() {
    if [[ -n "${sudoers_temp_path}" ]]; then
        rm -f -- "${sudoers_temp_path}"
    fi
}

# Usage: validate_account_name <kind> <name>
# Description: Validates a portable Ubuntu user or group name.
# Returns: Non-zero when the name is empty, reserved, too long or malformed.
validate_account_name() {
    local kind="$1"
    local name="$2"

    if [[ "${name}" == 'root' ]]; then
        die "${installer}" "${kind} name must not be root."
        return 1
    fi
    if ((${#name} > 32)) || [[ ! "${name}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        die "${installer}" "invalid ${kind} name: ${name}"
    fi
}

# Usage: validate_numeric_id <kind> <id>
# Description: Validates a non-root Linux UID or GID within the supported numeric range.
# Returns: Non-zero when the identifier is not an integer from 1 through 4294967294.
validate_numeric_id() {
    local kind="$1"
    local identifier="$2"
    local normalized_identifier="${identifier}"

    if [[ ! "${identifier}" =~ ^[0-9]+$ ]]; then
        die "${installer}" "${kind} must be an integer from 1 through ${maximum_id}."
        return 1
    fi

    while [[ "${normalized_identifier}" == 0* ]]; do
        normalized_identifier="${normalized_identifier#0}"
    done
    if [[ -z "${normalized_identifier}" || ${#normalized_identifier} -gt ${#maximum_id} ]]; then
        die "${installer}" "${kind} must be an integer from 1 through ${maximum_id}."
        return 1
    fi
    if [[ ${#normalized_identifier} -eq ${#maximum_id} ]] &&
        ((10#${normalized_identifier} > maximum_id)); then
        die "${installer}" "${kind} must be an integer from 1 through ${maximum_id}."
    fi
}

# Usage: array_contains <destination_name> <value>
# Description: Reports whether a Bash array contains one literal value.
# Returns: Zero when the value is present and one otherwise.
array_contains() {
    local destination_name="$1"
    local value="$2"
    local -n destination="${destination_name}"
    local candidate

    for candidate in "${destination[@]}"; do
        if [[ "${candidate}" == "${value}" ]]; then
            return 0
        fi
    done
    return 1
}

# Usage: append_unique <destination_name> <value>
# Description: Appends one literal value to a Bash array unless it is already present.
# Side Effects: May append an element to the named destination array.
append_unique() {
    local destination_name="$1"
    local value="$2"
    local -n destination="${destination_name}"

    # Treat array absence as the expected branch condition
    # shellcheck disable=SC2310
    if ! array_contains "${destination_name}" "${value}"; then
        destination+=("${value}")
    fi
}

# Usage: main <argument...>
# Description: Validates account conflicts and establishes the requested development identity.
# Side Effects: May remove conflicting accounts and groups and create account and sudoers state.
# Returns: Non-zero when validation, safety checks, prerequisites or account operations fail.
main() {
    local username='dev'
    local user_uid='1000'
    local user_gid='1000'
    local login_shell='/bin/bash'
    local configure_sudo='false'
    local -a supplementary_groups=()
    local username_seen='false'
    local uid_seen='false'
    local gid_seen='false'
    local shell_seen='false'
    local sudo_seen='false'

    # Collect explicit scalar and repeatable group options
    while (($# > 0)); do
        case "$1" in
            --username | --uid | --gid | --shell | --group)
                require_option_value "${installer}" "$1" "$#"
                case "$1" in
                    --username)
                        [[ "${username_seen}" == 'false' ]] || {
                            die "${installer}" 'option may be specified only once: --username'
                            return 1
                        }
                        username="$2"
                        username_seen='true'
                        ;;
                    --uid)
                        [[ "${uid_seen}" == 'false' ]] || {
                            die "${installer}" 'option may be specified only once: --uid'
                            return 1
                        }
                        user_uid="$2"
                        uid_seen='true'
                        ;;
                    --gid)
                        [[ "${gid_seen}" == 'false' ]] || {
                            die "${installer}" 'option may be specified only once: --gid'
                            return 1
                        }
                        user_gid="$2"
                        gid_seen='true'
                        ;;
                    --shell)
                        [[ "${shell_seen}" == 'false' ]] || {
                            die "${installer}" 'option may be specified only once: --shell'
                            return 1
                        }
                        login_shell="$2"
                        shell_seen='true'
                        ;;
                    --group)
                        supplementary_groups+=("$2")
                        ;;
                    *)
                        die "${installer}" "internal error while parsing option: $1"
                        return 1
                        ;;
                esac
                shift 2
                ;;
            --allow-passwordless-sudo)
                if [[ "${sudo_seen}" == 'true' ]]; then
                    die "${installer}" \
                        'option may be specified only once: --allow-passwordless-sudo'
                    return 1
                fi
                configure_sudo='true'
                sudo_seen='true'
                shift
                ;;
            --help)
                usage
                return 0
                ;;
            *)
                die "${installer}" "unknown option: $1"
                return 1
                ;;
        esac
    done

    # Validate every caller-provided value before inspecting or changing account state
    validate_account_name user "${username}"
    validate_numeric_id UID "${user_uid}"
    validate_numeric_id GID "${user_gid}"
    if [[ "${login_shell}" != /* || ! -x "${login_shell}" ]]; then
        die "${installer}" "shell must be an installed executable absolute path: ${login_shell}"
        return 1
    fi

    local group
    local -a unique_groups=()
    for group in "${supplementary_groups[@]}"; do
        validate_account_name group "${group}"
        if [[ "${group}" == "${username}" ]]; then
            die "${installer}" "supplementary group duplicates the requested primary group: ${group}"
            return 1
        fi
        append_unique unique_groups "${group}"
    done
    supplementary_groups=("${unique_groups[@]}")

    # Verify execution context, platform and account-management prerequisites
    require_root "${installer}"
    require_supported_platform "${installer}"
    local command_name
    local -a required_commands=(getent groupadd groupdel useradd userdel usermod)
    for command_name in "${required_commands[@]}"; do
        require_command "${installer}" "${command_name}"
    done
    if [[ "${configure_sudo}" == 'true' ]]; then
        require_command "${installer}" visudo \
            'Install sudo before invoking user --allow-passwordless-sudo.'
        require_command "${installer}" install
    fi

    for group in "${supplementary_groups[@]}"; do
        if ! getent group "${group}" >/dev/null; then
            die "${installer}" "required supplementary group does not exist: ${group}"
            return 1
        fi
    done

    # Discover all name and numeric-identity conflicts before changing account state
    local user_by_name=''
    local user_by_uid=''
    local group_by_name=''
    local group_by_gid=''
    user_by_name="$(getent passwd "${username}" || true)"
    user_by_uid="$(getent passwd "${user_uid}" || true)"
    group_by_name="$(getent group "${username}" || true)"
    group_by_gid="$(getent group "${user_gid}" || true)"

    local desired_user_matches='false'
    local desired_group_matches='false'
    local record_name record_uid record_gid record_home record_shell
    if [[ -n "${group_by_name}" && "${group_by_name}" == "${group_by_gid}" ]]; then
        IFS=: read -r record_name _ record_gid _ <<<"${group_by_name}"
        if [[ "${record_name}" == "${username}" && "${record_gid}" == "${user_gid}" ]]; then
            desired_group_matches='true'
        fi
    fi
    if [[ -n "${user_by_name}" && "${user_by_name}" == "${user_by_uid}" &&
        "${desired_group_matches}" == 'true' ]]; then
        IFS=: read -r record_name _ record_uid record_gid _ record_home record_shell \
            <<<"${user_by_name}"
        if [[ "${record_name}" == "${username}" && "${record_uid}" == "${user_uid}" &&
            "${record_gid}" == "${user_gid}" && "${record_home}" == "/home/${username}" &&
            "${record_shell}" == "${login_shell}" ]]; then
            desired_user_matches='true'
        fi
    fi

    local -a user_records_to_remove=()
    local -a users_to_remove=()
    if [[ "${desired_user_matches}" == 'false' ]]; then
        [[ -z "${user_by_name}" ]] || append_unique user_records_to_remove "${user_by_name}"
        [[ -z "${user_by_uid}" ]] || append_unique user_records_to_remove "${user_by_uid}"
    fi

    local record
    for record in "${user_records_to_remove[@]}"; do
        IFS=: read -r record_name _ record_uid record_gid _ record_home record_shell <<<"${record}"
        if [[ "${record_name}" == 'root' || "${record_uid}" == '0' ]]; then
            die "${installer}" 'refusing to remove or modify the root account.'
            return 1
        fi
        if [[ "${record_home}" != "/home/${record_name}" ]]; then
            die "${installer}" \
                "cannot safely replace ${record_name}: unexpected home directory ${record_home}."
            return 1
        fi
        append_unique users_to_remove "${record_name}"
    done

    local -a group_records_to_remove=()
    local -a groups_to_remove=()
    if [[ "${desired_group_matches}" == 'false' ]]; then
        [[ -z "${group_by_name}" ]] || append_unique group_records_to_remove "${group_by_name}"
        [[ -z "${group_by_gid}" ]] || append_unique group_records_to_remove "${group_by_gid}"
    fi

    local member members primary_gid
    local passwd_records
    local -a group_members=()
    passwd_records="$(getent passwd)"
    for record in "${group_records_to_remove[@]}"; do
        IFS=: read -r record_name _ record_gid members <<<"${record}"
        if [[ "${record_name}" == 'root' || "${record_gid}" == '0' ]]; then
            die "${installer}" 'refusing to remove or modify the root group.'
            return 1
        fi

        while IFS=: read -r member _ _ primary_gid _ _ _; do
            # Treat a user outside the removal set as the conflict condition
            # shellcheck disable=SC2310
            if [[ "${primary_gid}" == "${record_gid}" ]] &&
                ! array_contains users_to_remove "${member}"; then
                die "${installer}" \
                    "cannot remove group ${record_name}: it is the primary group of ${member}."
                return 1
            fi
        done <<<"${passwd_records}"

        IFS=, read -r -a group_members <<<"${members}"
        for member in "${group_members[@]}"; do
            # Treat a member outside the removal set as the conflict condition
            # shellcheck disable=SC2310
            if [[ -n "${member}" ]] && ! array_contains users_to_remove "${member}"; then
                die "${installer}" \
                    "cannot remove group ${record_name}: it is still required by ${member}."
                return 1
            fi
        done
        append_unique groups_to_remove "${record_name}"
    done

    for group in "${supplementary_groups[@]}"; do
        # Reject groups that replacement would remove explicitly or as a same-named private group
        # shellcheck disable=SC2310
        if array_contains groups_to_remove "${group}" || array_contains users_to_remove "${group}"; then
            die "${installer}" \
                "cannot preserve requested supplementary group during account replacement: ${group}"
            return 1
        fi
    done

    # Prepare and validate sudo configuration before account replacement begins
    local sudoers_path="/etc/sudoers.d/${username}"
    local sudoers_line="${username} ALL=(root) NOPASSWD: ALL"
    if [[ "${configure_sudo}" == 'true' ]]; then
        if [[ -L "${sudoers_path}" || (-e "${sudoers_path}" && ! -f "${sudoers_path}") ]]; then
            die "${installer}" "sudoers path must be a regular file: ${sudoers_path}"
            return 1
        fi
        if [[ -e "${sudoers_path}" && "$(<"${sudoers_path}")" != "${sudoers_line}" ]]; then
            die "${installer}" "refusing to overwrite existing sudoers configuration: ${sudoers_path}"
            return 1
        fi
        sudoers_temp_path="$(mktemp "${TMPDIR:-/tmp}/user-sudoers.XXXXXX")"
        printf '%s\n' "${sudoers_line}" >"${sudoers_temp_path}"
        chmod 0440 "${sudoers_temp_path}"
        visudo -cf "${sudoers_temp_path}" >/dev/null
    fi

    # Replace only the conflicts proven removable by the complete preflight
    for record_name in "${users_to_remove[@]}"; do
        log_info "${installer}" "removing conflicting user ${record_name} and its home directory."
        userdel --remove "${record_name}"
    done
    for record_name in "${groups_to_remove[@]}"; do
        # Remove the group only when userdel did not already remove the unused private group
        if getent group "${record_name}" >/dev/null; then
            log_info "${installer}" "removing conflicting group ${record_name}."
            groupdel "${record_name}"
        fi
    done

    # Establish the requested primary identity or retain its exact existing state
    if [[ "${desired_group_matches}" == 'false' ]]; then
        groupadd --gid "${user_gid}" "${username}"
    fi
    if [[ "${desired_user_matches}" == 'false' ]]; then
        useradd --uid "${user_uid}" --gid "${user_gid}" --create-home \
            --shell "${login_shell}" "${username}"
    fi

    # Add requested supplementary access and optional validated sudo policy
    for group in "${supplementary_groups[@]}"; do
        usermod --append --groups "${group}" "${username}"
    done
    if [[ "${configure_sudo}" == 'true' ]]; then
        log_warning "${installer}" \
            "granting ${username} unrestricted root access without authentication; prefer no sudo" \
            'or grant only the commands required by the development workflow.'
        install --mode=0440 -- "${sudoers_temp_path}" "${sudoers_path}"
        visudo -cf "${sudoers_path}" >/dev/null
    fi

    log_info "${installer}" "development user ${username} is ready."
}

trap cleanup EXIT
main "$@"
