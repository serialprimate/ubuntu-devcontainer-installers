#!/usr/bin/env bash
set -euo pipefail

# Installs Docker Engine and explicit daemon lifecycle control for development containers.

# Define installer metadata and the official Docker repository identity
readonly installer='docker-in-docker'
readonly docker_key_url='https://download.docker.com/linux/ubuntu/gpg'
readonly docker_key_fingerprint='9DC858229FC7DD38854AE2D88D81803C0EBFCD88'
readonly docker_key_path='/etc/apt/keyrings/docker.gpg'
readonly docker_source_path='/etc/apt/sources.list.d/docker.sources'
readonly lifecycle_command_path='/usr/local/sbin/docker-in-docker'
installer_dir="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
        pwd
)"
readonly installer_dir
readonly lifecycle_command_source="${installer_dir}/docker-in-docker"
readonly repository_lib_dir="${installer_dir}/../../lib"
# Resolve bundled libraries through installer-relative paths
# shellcheck disable=SC1091
source "${repository_lib_dir}/common.sh"
# shellcheck disable=SC1091
source "${repository_lib_dir}/platform.sh"
# shellcheck disable=SC1091
source "${repository_lib_dir}/apt.sh"

# Usage: usage
# Description: Writes command usage and prerequisite details to standard output.
usage() {
    cat <<'EOF'
Usage: install.sh

Install Docker Engine for explicit Docker-in-Docker use on Ubuntu 26.04 (linux/amd64).

Options:
  --help  Show this help and exit without changing system state.

Prerequisites: ca-certificates, curl and gnupg must be installed first.
Runtime: use --rm, --privileged and an anonymous volume at /var/lib/docker-in-docker,
then invoke docker-in-docker start.
EOF
}

# Usage: expected_docker_definition
# Description: Writes the canonical official Docker DEB822 source definition.
expected_docker_definition() {
    cat <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: resolute
Components: stable
Architectures: amd64
Signed-By: ${docker_key_path}
EOF
}

# Usage: require_apt_package <package>
# Description: Verifies one caller-owned repository-bootstrap package is installed.
# Returns: Non-zero when the package is absent or not fully installed.
require_apt_package() {
    local package="$1"
    local package_status

    if ! package_status="$(dpkg-query --show --showformat='${db:Status-Abbrev}' -- \
        "${package}" 2>/dev/null)" || [[ "${package_status}" != 'ii ' ]]; then
        die "${installer}" \
            "required APT package not installed: ${package}. Run installers/apt-packages/install.sh" \
            '--package ca-certificates --package curl --package gnupg before invoking docker-in-docker.'
    fi
}

# Usage: verify_existing_state <expected_definition>
# Description: Rejects repository or lifecycle-command state not owned in canonical format.
# Returns: Non-zero when existing state conflicts with the requested installation.
verify_existing_state() {
    local expected_definition="$1"
    local existing_definition

    if [[ -e /etc/apt/sources.list.d/docker.list ]]; then
        die "${installer}" 'conflicting Docker source exists: /etc/apt/sources.list.d/docker.list; remove it first.'
        return 1
    fi
    if [[ -e "${docker_source_path}" ]]; then
        if [[ ! -f "${docker_source_path}" ]] ||
            ! existing_definition="$(<"${docker_source_path}")" ||
            [[ "${existing_definition}" != "${expected_definition}" ]]; then
            die "${installer}" "conflicting Docker source exists: ${docker_source_path}; remove it first."
            return 1
        fi
    fi
    if [[ -e "${lifecycle_command_path}" ]] &&
        ! cmp --silent -- "${lifecycle_command_source}" "${lifecycle_command_path}"; then
        die "${installer}" "conflicting lifecycle command exists: ${lifecycle_command_path}; remove it first."
    fi
}

# Usage: install_docker_key <temporary_directory>
# Description: Downloads, verifies and installs the official Docker repository signing key.
# Side Effects: Creates or replaces the installer-owned Docker keyring.
# Returns: Non-zero when download, identity verification or conversion fails.
install_docker_key() {
    local temporary_directory="$1"
    local downloaded_key="${temporary_directory}/docker.asc"
    local key_fingerprint=''
    local key_records
    local record
    local field

    log_info "${installer}" 'downloading the Docker repository signing key.'
    if ! curl --fail --silent --show-error --location --output "${downloaded_key}" \
        "${docker_key_url}"; then
        die "${installer}" 'could not download the Docker signing key; verify network access.'
        return 1
    fi
    if ! key_records="$(gpg --batch --show-keys --with-colons -- "${downloaded_key}" 2>/dev/null)"; then
        die "${installer}" 'could not inspect the downloaded Docker signing key.'
        return 1
    fi
    while IFS=: read -r record _ _ _ _ _ _ _ _ field _; do
        if [[ "${record}" == 'fpr' ]]; then
            key_fingerprint="${field}"
            break
        fi
    done <<<"${key_records}"
    if [[ "${key_fingerprint}" != "${docker_key_fingerprint}" ]]; then
        die "${installer}" 'Docker signing-key fingerprint verification failed; refusing repository setup.'
        return 1
    fi

    mkdir -p -- "$(dirname -- "${docker_key_path}")"
    if ! gpg --batch --yes --dearmor --output "${docker_key_path}" -- "${downloaded_key}"; then
        die "${installer}" 'could not create the Docker repository keyring.'
        return 1
    fi
    chmod 0644 -- "${docker_key_path}"
}

# Usage: main <argument...>
# Description: Validates state, configures Docker's repository and installs Docker Engine.
# Side Effects: Adds signed APT files, packages and an explicit daemon lifecycle command.
# Returns: Non-zero when validation, prerequisites, repository setup or installation fail.
main() {
    local expected_definition
    local temporary_directory
    local cleanup_command

    # Accept only the state-free help request
    if (($# > 0)); then
        if (($# == 1)) && [[ "$1" == '--help' ]]; then
            usage
            return 0
        fi
        die "${installer}" "unknown option: $1"
        return 1
    fi

    # Validate platform, prerequisites and collision-relevant state before changes
    expected_definition="$(expected_docker_definition)"
    require_root "${installer}"
    require_supported_platform "${installer}"
    require_command "${installer}" apt-get
    require_command "${installer}" cmp
    require_command "${installer}" dpkg-query
    require_apt_package ca-certificates
    require_apt_package curl
    require_apt_package gnupg
    require_command "${installer}" curl
    require_command "${installer}" gpg
    [[ -r "${lifecycle_command_source}" ]] ||
        die "${installer}" "bundled lifecycle command is missing: ${lifecycle_command_source}."
    verify_existing_state "${expected_definition}"

    # Verify the remote key before configuring the signed Docker repository
    temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/docker-in-docker-installer.XXXXXX")"
    printf -v cleanup_command 'rm -rf -- %q' "${temporary_directory}"
    # Expand the shell-escaped local path now so it remains available to the EXIT trap
    # shellcheck disable=SC2064
    trap "${cleanup_command}" EXIT
    install_docker_key "${temporary_directory}"
    printf '%s\n' "${expected_definition}" >"${docker_source_path}"
    chmod 0644 -- "${docker_source_path}"

    # Install the engine, CLI plugins and explicit lifecycle command
    apt_install_packages "${installer}" \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    install -m 0755 -- "${lifecycle_command_source}" "${lifecycle_command_path}"
    log_info "${installer}" 'Docker-in-Docker installation complete; daemon remains stopped.'
}

main "$@"
