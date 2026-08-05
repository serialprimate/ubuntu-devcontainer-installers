#!/usr/bin/env bash
set -euo pipefail

# Installs a pinned pipx release in an isolated system-wide virtual environment.

# Define installer metadata, secure defaults and bundled libraries
readonly installer='pipx'
readonly default_pipx_version='1.16.6'
readonly bootstrap_pip_version='26.2.1'
readonly minimum_supported_pipx_version='1.16.0'
readonly default_minimum_release_age_days='7'
readonly pipx_home='/usr/local/lib/pipx'
readonly pipx_command='/usr/local/bin/pipx'
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

Install pipx on Ubuntu 26.04 (linux/amd64).

Options:
  --pipx-version VERSION             Install an exact pipx version
                                     (default: 1.16.6; minimum: 1.16.0).
  --minimum-release-age-days DAYS   Require pipx and its dependencies to be at
                                     least DAYS old (default: 7).
  --without-minimum-release-age     Disable the default release-age check.
  --help                            Show this help and exit without changing state.
EOF
}

# Usage: version_at_least <installed_version> <minimum_version>
# Description: Compares numeric dotted versions and succeeds at or above the minimum.
# Returns: Non-zero when a version is malformed or the installed version is below the minimum.
version_at_least() {
    local installed_version="$1"
    local minimum_version="$2"
    local -a installed_parts=()
    local -a minimum_parts=()
    local index
    local installed_part
    local minimum_part

    if [[ ! "${installed_version}" =~ ^[0-9]+(\.[0-9]+)*$ ]] ||
        [[ ! "${minimum_version}" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        return 1
    fi
    IFS=. read -r -a installed_parts <<<"${installed_version}"
    IFS=. read -r -a minimum_parts <<<"${minimum_version}"

    for ((index = 0; index < ${#installed_parts[@]} || index < ${#minimum_parts[@]}; index++)); do
        installed_part="${installed_parts[index]:-0}"
        minimum_part="${minimum_parts[index]:-0}"
        if ((10#${installed_part} > 10#${minimum_part})); then
            return 0
        fi
        if ((10#${installed_part} < 10#${minimum_part})); then
            return 1
        fi
    done
}

# Usage: require_python_venv
# Description: Verifies that the existing Python installation can create virtual environments.
# Returns: Non-zero when Python's venv module is unavailable.
require_python_venv() {
    if ! python3 -c 'import venv' >/dev/null 2>&1; then
        die "${installer}" \
            'required Python module not found: venv. Run installers/apt-python/install.sh before invoking pipx.'
    fi
}

# Usage: verify_existing_installation <requested_version>
# Description: Accepts the canonical requested installation and rejects conflicting pipx state.
# Returns: Non-zero when existing state is incomplete, unreadable or at another version.
verify_existing_installation() {
    local requested_version="$1"
    local installed_version
    local command_target=''

    if [[ ! -e "${pipx_home}" && ! -e "${pipx_command}" && ! -L "${pipx_command}" ]]; then
        return 1
    fi
    if [[ -L "${pipx_command}" ]]; then
        command_target="$(readlink -- "${pipx_command}")"
    fi
    if [[ ! -x "${pipx_home}/bin/pipx" ]] ||
        [[ "${command_target}" != "${pipx_home}/bin/pipx" ]]; then
        die "${installer}" \
            "conflicting pipx installation state exists under ${pipx_home} or ${pipx_command}; remove it first."
        return 2
    fi
    if ! installed_version="$("${pipx_command}" --version)" ||
        [[ ! "${installed_version}" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        die "${installer}" 'could not determine the installed pipx version.'
        return 2
    fi
    if [[ "${installed_version}" != "${requested_version}" ]]; then
        die "${installer}" \
            "pipx ${installed_version} is already installed; remove it before requesting pipx ${requested_version}."
        return 2
    fi
    return 0
}

# Usage: main <argument...>
# Description: Validates and installs one supported pipx release.
# Side Effects: Creates a system-wide virtual environment and pipx command symlink.
# Returns: Non-zero when validation, prerequisites or installation fail.
main() {
    local pipx_version="${default_pipx_version}"
    local minimum_release_age_days="${default_minimum_release_age_days}"
    local pipx_version_seen='false'
    local minimum_release_age_seen='false'
    local without_minimum_release_age_seen='false'
    local existing_status
    local -a pip_install_arguments=()

    # Collect version and release-age options
    while (($# > 0)); do
        case "$1" in
            --pipx-version)
                require_option_value "${installer}" "$1" "$#"
                if [[ "${pipx_version_seen}" == 'true' ]]; then
                    die "${installer}" 'option may be specified only once: --pipx-version'
                    return 1
                fi
                pipx_version="$2"
                pipx_version_seen='true'
                shift 2
                ;;
            --minimum-release-age-days)
                require_option_value "${installer}" "$1" "$#"
                if [[ "${minimum_release_age_seen}" == 'true' ]]; then
                    die "${installer}" 'option may be specified only once: --minimum-release-age-days'
                    return 1
                fi
                minimum_release_age_days="$2"
                minimum_release_age_seen='true'
                shift 2
                ;;
            --without-minimum-release-age)
                if [[ "${without_minimum_release_age_seen}" == 'true' ]]; then
                    die "${installer}" 'option may be specified only once: --without-minimum-release-age'
                    return 1
                fi
                without_minimum_release_age_seen='true'
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

    # Validate the complete request before execution-context checks
    if [[ ! "${pipx_version}" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        die "${installer}" "invalid pipx version: ${pipx_version}; expected a numeric dotted version."
        return 1
    fi
    # The comparison function intentionally communicates an ordinary false result through status.
    # shellcheck disable=SC2310
    if ! version_at_least "${pipx_version}" "${minimum_supported_pipx_version}"; then
        die "${installer}" \
            "unsupported pipx version: ${pipx_version}; minimum supported version is ${minimum_supported_pipx_version}."
        return 1
    fi
    if [[ "${minimum_release_age_seen}" == 'true' &&
        "${without_minimum_release_age_seen}" == 'true' ]]; then
        die "${installer}" \
            '--minimum-release-age-days and --without-minimum-release-age cannot be used together.'
        return 1
    fi
    if [[ ! "${minimum_release_age_days}" =~ ^(0|[1-9][0-9]*)$ ]] ||
        ((10#${minimum_release_age_days} > 3650)); then
        die "${installer}" 'minimum release age must be an integer from 0 through 3650 days.'
        return 1
    fi

    # Verify composition order and collision-relevant state before installation
    require_root "${installer}"
    require_supported_platform "${installer}"
    require_command "${installer}" python3 \
        'Run installers/apt-python/install.sh before invoking pipx.'
    require_command "${installer}" ln
    require_command "${installer}" readlink
    require_python_venv
    set +e
    verify_existing_installation "${pipx_version}"
    existing_status=$?
    set -e
    if ((existing_status == 0)); then
        log_info "${installer}" "pipx ${pipx_version} is already installed."
        return 0
    fi
    if ((existing_status != 1)); then
        return "${existing_status}"
    fi

    # Create installer-owned state and remove it automatically if installation is incomplete
    mkdir -p -- "$(dirname -- "${pipx_home}")" "$(dirname -- "${pipx_command}")"
    trap 'rm -rf -- "${pipx_home}"' EXIT
    if ! python3 -m venv "${pipx_home}"; then
        die "${installer}" 'could not create the isolated pipx virtual environment.'
        return 1
    fi
    if ! "${pipx_home}/bin/python" -m pip install --disable-pip-version-check --no-input \
        "pip==${bootstrap_pip_version}"; then
        die "${installer}" \
            "could not install bootstrap pip ${bootstrap_pip_version}; verify index and network access."
        return 1
    fi
    if [[ "${without_minimum_release_age_seen}" != 'true' ]]; then
        pip_install_arguments+=("--uploaded-prior-to=P${minimum_release_age_days}D")
    fi

    # Install the selected application and expose only its canonical command
    log_info "${installer}" "installing pipx ${pipx_version}."
    if ! "${pipx_home}/bin/python" -m pip install --disable-pip-version-check --no-input \
        "${pip_install_arguments[@]}" "pipx==${pipx_version}"; then
        die "${installer}" \
            'pipx installation failed; verify the version, release age and network access.'
        return 1
    fi
    ln -s -- "${pipx_home}/bin/pipx" "${pipx_command}"
    trap - EXIT
    log_info "${installer}" 'installation complete.'
}

main "$@"
