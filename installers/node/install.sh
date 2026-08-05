#!/usr/bin/env bash
set -euo pipefail

# Installs a supported Node.js major release from the signed NodeSource APT repository.

# Define installer metadata, supported releases and repository identity
readonly installer='node'
readonly default_node_version='lts'
readonly nodesource_key_url='https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key'
readonly nodesource_key_fingerprint='6F71F525282841EEDAF851B42F59B5F99B1BE0B4'
readonly nodesource_key_path='/usr/share/keyrings/nodesource.gpg'
readonly nodesource_source_path='/etc/apt/sources.list.d/nodesource.sources'
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
Usage: install.sh [--node-version VERSION]

Install Node.js from NodeSource on Ubuntu 26.04 (linux/amd64).

Options:
  --node-version VERSION  Select 24, 26, lts, or current (default: lts, currently 24).
  --help                  Show this help and exit without changing system state.
EOF
}

# Usage: resolve_node_version <version>
# Description: Writes the supported numeric Node.js major represented by a selector.
# Returns: Non-zero when the selector is unsupported.
resolve_node_version() {
    case "$1" in
        24 | lts) printf '24\n' ;;
        26 | current) printf '26\n' ;;
        *)
            die "${installer}" "unsupported Node.js version: $1; supported values are 24, 26, lts and current."
            return 1
            ;;
    esac
}

# Usage: expected_nodesource_definition <node_major>
# Description: Writes the canonical NodeSource DEB822 source definition.
expected_nodesource_definition() {
    local node_major="$1"

    cat <<EOF
Types: deb
URIs: https://deb.nodesource.com/node_${node_major}.x
Suites: nodistro
Components: main
Architectures: amd64
Signed-By: ${nodesource_key_path}
EOF
}

# Usage: verify_existing_installation <node_major>
# Description: Rejects an installed Node.js major that conflicts with the requested release.
# Returns: Non-zero when the installed version cannot be read or has a different major.
verify_existing_installation() {
    local node_major="$1"
    local installed_version
    local installed_major

    if ! command -v node >/dev/null 2>&1; then
        return 0
    fi
    if ! installed_version="$(node --version)" ||
        [[ ! "${installed_version}" =~ ^v([0-9]+)(\.[0-9]+){2} ]]; then
        die "${installer}" 'could not determine the installed Node.js version.'
        return 1
    fi
    installed_major="${BASH_REMATCH[1]}"
    if [[ "${installed_major}" != "${node_major}" ]]; then
        die "${installer}" \
            "Node.js ${installed_major} is already installed; remove it before requesting Node.js ${node_major}."
    fi
}

# Usage: verify_existing_repository <expected_definition>
# Description: Rejects NodeSource repository state not owned in the canonical installer format.
# Returns: Non-zero when an existing source conflicts with the requested definition.
verify_existing_repository() {
    local expected_definition="$1"
    local existing_definition

    if [[ -e /etc/apt/sources.list.d/nodesource.list ]]; then
        die "${installer}" \
            'conflicting NodeSource source exists: /etc/apt/sources.list.d/nodesource.list; remove it first.'
        return 1
    fi
    if [[ -e "${nodesource_source_path}" ]]; then
        if [[ ! -f "${nodesource_source_path}" ]] ||
            ! existing_definition="$(<"${nodesource_source_path}")" ||
            [[ "${existing_definition}" != "${expected_definition}" ]]; then
            die "${installer}" \
                "conflicting NodeSource source exists: ${nodesource_source_path}; remove it first."
        fi
    fi
}

# Usage: require_apt_package <package>
# Description:
# - Verify that a required Ubuntu package is already installed
# - Write the supported apt-packages composition order when it is absent
# Returns: Non-zero when the package is absent or not fully installed.
require_apt_package() {
    local package="$1"
    local package_status

    if ! package_status="$(dpkg-query --show --showformat='${db:Status-Abbrev}' -- "${package}" 2>/dev/null)" ||
        [[ "${package_status}" != 'ii ' ]]; then
        die "${installer}" \
            "required APT package not installed: ${package}. Run installers/apt-packages/install.sh" \
            '--package ca-certificates --package curl --package gnupg before invoking node.'
    fi
}

# Usage: install_nodesource_key <temporary_directory>
# Description: Downloads, identifies and installs the NodeSource repository signing key.
# Side Effects: Creates or replaces the installer-owned NodeSource keyring.
# Returns: Non-zero when download, identity verification or conversion fails.
install_nodesource_key() {
    local temporary_directory="$1"
    local downloaded_key="${temporary_directory}/nodesource-repo.gpg.key"
    local key_fingerprint=''
    local key_records
    local record
    local field

    log_info "${installer}" 'downloading the NodeSource repository signing key.'
    if ! curl --fail --silent --show-error --location --output "${downloaded_key}" \
        "${nodesource_key_url}"; then
        die "${installer}" 'could not download the NodeSource repository signing key; verify network access.'
        return 1
    fi

    if ! key_records="$(
        gpg --batch --show-keys --with-colons -- "${downloaded_key}" 2>/dev/null
    )"; then
        die "${installer}" 'could not inspect the downloaded NodeSource signing key.'
        return 1
    fi
    while IFS=: read -r record _ _ _ _ _ _ _ _ field _; do
        if [[ "${record}" == 'fpr' ]]; then
            key_fingerprint="${field}"
            break
        fi
    done <<<"${key_records}"
    if [[ "${key_fingerprint}" != "${nodesource_key_fingerprint}" ]]; then
        die "${installer}" 'NodeSource signing-key fingerprint verification failed; refusing repository setup.'
        return 1
    fi

    mkdir -p -- "$(dirname -- "${nodesource_key_path}")"
    if ! gpg --batch --yes --dearmor --output "${nodesource_key_path}" -- "${downloaded_key}"; then
        die "${installer}" 'could not create the NodeSource repository keyring.'
        return 1
    fi
    chmod 0644 -- "${nodesource_key_path}"
}

# Usage: main <argument...>
# Description: Validates the request, configures NodeSource and installs the selected Node.js major.
# Side Effects: Adds signed APT repository files, installs packages and removes APT cache state.
# Returns: Non-zero when validation, prerequisites, repository setup or installation fail.
main() {
    local requested_version="${default_node_version}"
    local node_version_seen='false'
    local node_major
    local expected_definition
    local temporary_directory
    local cleanup_command

    # Collect the scalar version selector before performing system checks
    while (($# > 0)); do
        case "$1" in
            --node-version)
                require_option_value "${installer}" "$1" "$#"
                if [[ "${node_version_seen}" == 'true' ]]; then
                    die "${installer}" 'option may be specified only once: --node-version'
                    return 1
                fi
                requested_version="$2"
                node_version_seen='true'
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

    # Validate selector and collision-relevant state before changing the image
    node_major="$(resolve_node_version "${requested_version}")"
    expected_definition="$(expected_nodesource_definition "${node_major}")"
    require_root "${installer}"
    require_supported_platform "${installer}"
    require_command "${installer}" apt-get
    verify_existing_installation "${node_major}"
    verify_existing_repository "${expected_definition}"

    # Require caller-owned repository-bootstrap dependencies before changing system state
    require_command "${installer}" dpkg-query
    require_apt_package ca-certificates
    require_apt_package curl
    require_apt_package gnupg
    require_command "${installer}" curl
    require_command "${installer}" gpg

    # Verify the remote key before configuring the signed NodeSource repository
    temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/node-installer.XXXXXX")"
    printf -v cleanup_command 'rm -rf -- %q' "${temporary_directory}"
    # Expand the shell-escaped local path now so it remains available when the EXIT trap runs.
    # shellcheck disable=SC2064
    trap "${cleanup_command}" EXIT
    install_nodesource_key "${temporary_directory}"
    printf '%s\n' "${expected_definition}" >"${nodesource_source_path}"
    chmod 0644 -- "${nodesource_source_path}"

    # Install Node.js and verify the requested major before reporting success
    apt_install_packages "${installer}" nodejs
    verify_existing_installation "${node_major}"
    log_info "${installer}" "Node.js ${node_major} installation complete."
}

main "$@"
