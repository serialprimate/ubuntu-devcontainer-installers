#!/usr/bin/env bash
set -euo pipefail

# Installs Ubuntu's Python runtime with optional pip and virtual-environment tooling.

# Define installer metadata and resolve bundled libraries
readonly installer='apt-python'
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
source "${repository_lib_dir}/platform.sh"
# Resolve the bundled library through the installer-relative path
# shellcheck disable=SC1091
source "${repository_lib_dir}/apt.sh"

# Usage: usage
# Description: Writes command usage and option details to standard output.
usage() {
    cat <<'EOF'
Usage: install.sh [OPTIONS]

Install Ubuntu Python on Ubuntu 26.04 (linux/amd64).

Options:
  --without-pip   Do not install the python3-pip package.
  --without-venv  Do not install the python3-venv package.
  --help          Show this help and exit without changing system state.

By default, python3, python3-pip and python3-venv are installed.
EOF
}

# Usage: main <argument...>
# Description: Validates options and installs the selected Ubuntu Python packages.
# Side Effects: Installs system packages and removes APT caches and package lists.
# Returns: Non-zero when validation, platform checks, prerequisites or installation fail.
main() {
    local install_pip='true'
    local install_venv='true'
    local without_pip_seen='false'
    local without_venv_seen='false'

    # Collect options and reject ambiguous duplicate scalar flags
    while (($# > 0)); do
        case "$1" in
            --without-pip)
                if [[ "${without_pip_seen}" == 'true' ]]; then
                    die "${installer}" 'option may be specified only once: --without-pip'
                    return 1
                fi
                install_pip='false'
                without_pip_seen='true'
                shift
                ;;
            --without-venv)
                if [[ "${without_venv_seen}" == 'true' ]]; then
                    die "${installer}" 'option may be specified only once: --without-venv'
                    return 1
                fi
                install_venv='false'
                without_venv_seen='true'
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

    # Verify execution context and intrinsic APT prerequisite
    require_root "${installer}"
    require_supported_platform "${installer}"
    require_command "${installer}" apt-get

    # Build and install the selected package collection
    local -a packages=(python3)
    if [[ "${install_pip}" == 'true' ]]; then
        packages+=(python3-pip)
    fi
    if [[ "${install_venv}" == 'true' ]]; then
        packages+=(python3-venv)
    fi

    apt_install_packages "${installer}" "${packages[@]}"
    log_info "${installer}" 'installation complete.'
}

main "$@"
