#!/usr/bin/env bash
set -euo pipefail

# Installs literal PyPI applications globally through pipx with a configurable cooldown.

# Define installer metadata, secure defaults and bundled libraries
readonly installer='pipx-packages'
readonly default_cooldown_days='7'
readonly minimum_pipx_version_for_cooldown='1.16.0'
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
Usage: install.sh --package PACKAGE [--package PACKAGE ...] [OPTIONS]

Install literal global pipx applications on Ubuntu 26.04 (linux/amd64).

Options:
  --package PACKAGE          Install one PyPI package name or name==version;
                             may be repeated.
  --cooldown-days DAYS       Ignore artifacts uploaded fewer than DAYS days ago
                             (default: 7; requires pipx 1.16.0 or newer).
  --without-cooldown         Disable the default package cooldown.
  --help                     Show this help and exit without changing state.
EOF
}

# Usage: validate_package <package>
# Description: Rejects option-like, remote and malformed Python package specifications.
# Returns: Non-zero when the package is not a supported PyPI registry specification.
validate_package() {
    local package="$1"
    local name='[A-Za-z0-9][A-Za-z0-9._-]*'
    local version='[A-Za-z0-9][A-Za-z0-9.!+_-]*'

    if [[ ! "${package}" =~ ^${name}(==${version})?$ ]]; then
        die "${installer}" "invalid pipx package specification: ${package}"
    fi
}

# Usage: normalize_package_name <name>
# Description: Writes the lowercase hyphen-normalized Python project name.
normalize_package_name() {
    local name="${1,,}"

    name="${name//./-}"
    name="${name//_/-}"
    while [[ "${name}" == *--* ]]; do
        name="${name//--/-}"
    done
    printf '%s\n' "${name}"
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

# Usage: require_cooldown_support
# Description: Verifies that the installed pipx supports the requested cooldown control.
# Returns: Non-zero when pipx's version is unreadable or older than 1.16.0.
require_cooldown_support() {
    local pipx_version

    if ! pipx_version="$(pipx --version)" || [[ -z "${pipx_version}" ]]; then
        die "${installer}" 'could not determine the installed pipx version.'
        return 1
    fi
    # The comparison function intentionally communicates an ordinary false result through status.
    # shellcheck disable=SC2310
    if ! version_at_least "${pipx_version}" "${minimum_pipx_version_for_cooldown}"; then
        die "${installer}" \
            "package cooldown requires pipx ${minimum_pipx_version_for_cooldown} or newer; found ${pipx_version}."
    fi
}

# Usage: main <argument...>
# Description: Validates and installs one literal global pipx application collection.
# Side Effects: Downloads packages and modifies pipx's global environments and command directory.
# Returns: Non-zero when validation, prerequisites or pipx installation fail.
main() {
    local -a packages=()
    local cooldown_days="${default_cooldown_days}"
    local cooldown_seen='false'
    local without_cooldown_seen='false'
    local package
    local package_name
    local package_version
    local normalized_name
    local installed_name
    local installed_version
    local installed_packages
    local -a packages_to_install=()
    local -a pipx_arguments=(install --global)
    local -A requested_versions=()
    local -A installed_versions=()
    local -A selected_names=()

    # Collect literal package values and scalar cooldown options
    while (($# > 0)); do
        case "$1" in
            --package)
                require_option_value "${installer}" "$1" "$#"
                packages+=("$2")
                shift 2
                ;;
            --cooldown-days)
                require_option_value "${installer}" "$1" "$#"
                if [[ "${cooldown_seen}" == 'true' ]]; then
                    die "${installer}" 'option may be specified only once: --cooldown-days'
                    return 1
                fi
                cooldown_days="$2"
                cooldown_seen='true'
                shift 2
                ;;
            --without-cooldown)
                if [[ "${without_cooldown_seen}" == 'true' ]]; then
                    die "${installer}" 'option may be specified only once: --without-cooldown'
                    return 1
                fi
                without_cooldown_seen='true'
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

    # Validate the complete request and incompatible cooldown controls before system checks
    if ((${#packages[@]} == 0)); then
        die "${installer}" 'at least one --package is required.'
        return 1
    fi
    if [[ "${cooldown_seen}" == 'true' && "${without_cooldown_seen}" == 'true' ]]; then
        die "${installer}" '--cooldown-days and --without-cooldown cannot be used together.'
        return 1
    fi
    if [[ ! "${cooldown_days}" =~ ^(0|[1-9][0-9]*)$ ]] ||
        ((10#${cooldown_days} > 3650)); then
        die "${installer}" 'cooldown must be an integer from 0 through 3650 days.'
        return 1
    fi
    for package in "${packages[@]}"; do
        validate_package "${package}"
        package_name="${package%%==*}"
        package_version=''
        if [[ "${package}" == *'=='* ]]; then
            package_version="${package#*==}"
        fi
        normalized_name="$(normalize_package_name "${package_name}")"
        if [[ -v "requested_versions[${normalized_name}]" ]] &&
            [[ "${requested_versions[${normalized_name}]}" != "${package_version}" ]]; then
            die "${installer}" \
                "conflicting versions requested for normalized package name ${normalized_name}."
            return 1
        fi
        requested_versions["${normalized_name}"]="${package_version}"
    done

    # Verify composition order and package-manager support before inspecting global pipx state
    require_root "${installer}"
    require_supported_platform "${installer}"
    require_command "${installer}" pipx \
        'Run installers/pipx/install.sh before invoking pipx-packages.'
    if [[ "${without_cooldown_seen}" != 'true' ]]; then
        require_cooldown_support
        pipx_arguments+=("--cooldown=${cooldown_days}")
    fi
    if ! installed_packages="$(pipx list --global --short --skip-maintenance)"; then
        die "${installer}" 'could not inspect existing global pipx packages.'
        return 1
    fi
    while read -r installed_name installed_version _; do
        if [[ -z "${installed_name}" ]]; then
            continue
        fi
        normalized_name="$(normalize_package_name "${installed_name}")"
        installed_versions["${normalized_name}"]="${installed_version}"
    done <<<"${installed_packages}"

    # Reject version collisions and omit exact existing requests before changing package state
    for package in "${packages[@]}"; do
        package_name="${package%%==*}"
        package_version=''
        if [[ "${package}" == *'=='* ]]; then
            package_version="${package#*==}"
        fi
        normalized_name="$(normalize_package_name "${package_name}")"
        if [[ -v "selected_names[${normalized_name}]" ]]; then
            continue
        fi
        selected_names["${normalized_name}"]='true'
        if [[ ! -v "installed_versions[${normalized_name}]" ]]; then
            packages_to_install+=("${package}")
            continue
        fi
        installed_version="${installed_versions[${normalized_name}]}"
        if [[ -n "${package_version}" && "${installed_version}" != "${package_version}" ]]; then
            die "${installer}" \
                "${normalized_name} ${installed_version} is already installed; remove or upgrade it before requesting ${package_version}."
            return 1
        fi
        log_info "${installer}" "${normalized_name} ${installed_version} is already installed."
    done

    # Install each new application in its own global pipx environment
    for package in "${packages_to_install[@]}"; do
        log_info "${installer}" "installing ${package}."
        if ! pipx "${pipx_arguments[@]}" -- "${package}"; then
            die "${installer}" \
                "pipx package installation failed for ${package}; verify the specification, cooldown and network access."
            return 1
        fi
    done
    log_info "${installer}" 'installation complete.'
}

main "$@"
