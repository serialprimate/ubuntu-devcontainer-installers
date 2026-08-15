#!/usr/bin/env bash
set -euo pipefail

# Installs literal global npm registry packages with a configurable release-age delay.

# Define installer metadata, secure defaults and bundled libraries
readonly installer='npm-packages'
readonly default_minimum_release_age_days='7'
readonly minimum_npm_version_for_release_age='11.10.0'
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

Install literal global npm registry packages on Ubuntu 26.04 (linux/amd64).

Options:
  --package PACKAGE                 Install one package name or name@version/tag;
                                    may be repeated.
  --minimum-release-age-days DAYS  Require releases to be at least DAYS old
                                    (default: 7; requires npm 11.10.0 or newer).
  --without-minimum-release-age     Disable the default release-age check.
  --allow-package-scripts           Allow package and dependency lifecycle scripts
                                    to execute as root (disabled by default).
  --help                            Show this help and exit without changing state.

Dependency lifecycle scripts are disabled unless explicitly allowed.
EOF
}

# Usage: validate_package <package>
# Description: Rejects option-like, remote and malformed npm package specifications.
# Returns: Non-zero when the package is not a supported registry specification.
validate_package() {
    local package="$1"
    local unscoped_name='[a-z0-9][a-z0-9._-]*'
    local scoped_name="@[a-z0-9][a-z0-9._-]*/${unscoped_name}"
    local selector='[A-Za-z0-9][A-Za-z0-9._-]*'

    if [[ ! "${package}" =~ ^(${unscoped_name}|${scoped_name})(@${selector})?$ ]]; then
        die "${installer}" "invalid npm package specification: ${package}"
    fi
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

# Usage: require_release_age_support
# Description: Verifies that npm supports the requested minimum-release-age control.
# Returns: Non-zero when npm's version is unreadable or older than 11.10.0.
require_release_age_support() {
    local npm_version

    if ! npm_version="$(npm --version)" || [[ -z "${npm_version}" ]]; then
        die "${installer}" 'could not determine the installed npm version.'
        return 1
    fi
    # The comparison function intentionally communicates an ordinary false result through status.
    # shellcheck disable=SC2310
    if ! version_at_least "${npm_version}" "${minimum_npm_version_for_release_age}"; then
        die "${installer}" \
            "minimum release age requires npm ${minimum_npm_version_for_release_age} or newer; found ${npm_version}."
    fi
}

# Usage: main <argument...>
# Description: Validates and installs one literal global npm package collection.
# Side Effects: Downloads packages and modifies npm's global installation prefix.
# Returns: Non-zero when validation, prerequisites or npm installation fail.
main() {
    local -a packages=()
    local minimum_release_age_days="${default_minimum_release_age_days}"
    local minimum_release_age_seen='false'
    local without_minimum_release_age_seen='false'
    local allow_package_scripts_seen='false'
    local package
    local -a npm_arguments=(install --global --ignore-scripts)

    # Collect literal package values and scalar release-age options
    while (($# > 0)); do
        case "$1" in
            --package)
                require_option_value "${installer}" "$1" "$#"
                packages+=("$2")
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
            --allow-package-scripts)
                if [[ "${allow_package_scripts_seen}" == 'true' ]]; then
                    die "${installer}" 'option may be specified only once: --allow-package-scripts'
                    return 1
                fi
                allow_package_scripts_seen='true'
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

    # Validate the complete request and incompatible age controls before system checks
    if ((${#packages[@]} == 0)); then
        die "${installer}" 'at least one --package is required.'
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
    for package in "${packages[@]}"; do
        validate_package "${package}"
    done

    # Verify composition order and package-manager support before changing global npm state
    require_root "${installer}"
    require_supported_platform "${installer}"
    require_command "${installer}" npm \
        'Run installers/node/install.sh before invoking npm-packages.'
    if [[ "${without_minimum_release_age_seen}" != 'true' ]]; then
        require_release_age_support
        npm_arguments+=("--min-release-age=${minimum_release_age_days}")
    fi

    # Select the explicitly requested package-script policy
    if [[ "${allow_package_scripts_seen}" == 'true' ]]; then
        npm_arguments[2]='--ignore-scripts=false'
    fi

    # Install the complete package set under the selected package-script policy
    log_info "${installer}" 'installing requested global npm packages.'
    if [[ "${allow_package_scripts_seen}" == 'true' ]]; then
        log_warning "${installer}" \
            'allowing package and dependency lifecycle scripts to execute as root; scripts may modify' \
            'the image or access the network. Prefer the default, review dependencies, and pin exact versions.'
    fi
    if ! npm "${npm_arguments[@]}" -- "${packages[@]}"; then
        die "${installer}" \
            'npm package installation failed; verify package specifications, release age and network access.'
        return 1
    fi
    log_info "${installer}" 'installation complete.'
}

main "$@"
