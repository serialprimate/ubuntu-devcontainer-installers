#!/usr/bin/env bash
set -euo pipefail

# Installs a validated literal collection of Ubuntu packages through APT.

# Define installer metadata and resolve bundled libraries
readonly installer='apt-packages'
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
# Resolve the bundled library through the installer-relative path
# shellcheck disable=SC1091
source "${repository_lib_dir}/apt.sh"

# Usage: usage
# Description: Writes command usage and option details to standard output.
usage() {
    cat <<'EOF'
Usage: install.sh (--package PACKAGE | --package-file PATH)...

Install literal Ubuntu package specifications on Ubuntu 26.04 (linux/amd64).

Options:
  --package PACKAGE    Install one package specification; may be repeated.
  --package-file PATH  Read one literal package specification per non-blank line;
                       may be repeated.
  --help               Show this help and exit without changing system state.
EOF
}

# Usage: validate_package <package>
# Description: Rejects values that are not valid APT package specifications.
# Returns: Non-zero when the package specification is invalid.
validate_package() {
    local package="$1"

    if [[ ! "${package}" =~ ^[a-z0-9][a-z0-9+.-]*(:[a-z0-9][a-z0-9-]*)?(=[^[:space:]]+)?$ ]]; then
        die "${installer}" "invalid package specification: ${package}"
    fi
}

# Usage: main <argument...>
# Description: Validates the request and performs one complete APT installation lifecycle.
# Side Effects: Installs requested system packages and removes APT caches and package lists.
# Returns: Non-zero when validation, platform checks, prerequisites or installation fail.
main() {
    local -a packages=()

    # Collect literal package values before performing system checks
    while (($# > 0)); do
        case "$1" in
            --package)
                require_option_value "${installer}" "$1" "$#"
                packages+=("$2")
                shift 2
                ;;
            --package-file)
                require_option_value "${installer}" "$1" "$#"
                append_literal_lines "${installer}" "$2" packages
                shift 2
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

    # Validate the complete request before changing system state
    if ((${#packages[@]} == 0)); then
        die "${installer}" 'at least one --package or non-blank --package-file value is required.'
        return 1
    fi

    local package
    for package in "${packages[@]}"; do
        validate_package "${package}"
    done

    # Verify execution context and intrinsic APT prerequisite
    require_root "${installer}"
    require_supported_platform "${installer}"
    require_command "${installer}" apt-get

    # Install the requested package collection
    apt_install_packages "${installer}" "${packages[@]}"
    log_info "${installer}" 'installation complete.'
}

main "$@"
