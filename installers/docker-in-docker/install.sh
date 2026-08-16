#!/usr/bin/env bash
set -euo pipefail

# Installs Docker Engine and explicit manual and adapter lifecycle control.

# Define installer metadata and the official Docker repository identity.
readonly installer='docker-in-docker'
readonly docker_key_url='https://download.docker.com/linux/ubuntu/gpg'
readonly docker_key_fingerprint='9DC858229FC7DD38854AE2D88D81803C0EBFCD88'
readonly docker_key_path='/etc/apt/keyrings/docker.gpg'
readonly docker_source_path='/etc/apt/sources.list.d/docker.sources'
readonly lifecycle_command_path='/usr/local/sbin/docker-in-docker'
readonly adapter_path='/usr/local/libexec/ubuntu-devcontainer-installers/services/docker-in-docker'
readonly support_root='/usr/local/libexec/ubuntu-devcontainer-installers/docker-in-docker'
readonly common_path="${support_root}/common.sh"
installer_dir="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
        pwd
)"
readonly installer_dir
readonly lifecycle_command_source="${installer_dir}/docker-in-docker"
readonly adapter_source="${installer_dir}/container-service"
readonly repository_lib_dir="${installer_dir}/../../lib"
readonly common_source="${repository_lib_dir}/common.sh"
# Resolve bundled libraries through installer-relative paths.
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

Install Docker Engine and explicit Docker-in-Docker lifecycle control on Ubuntu
26.04 (linux/amd64).

Options:
  --help  Show this help and exit without changing system state.

Prerequisites: ca-certificates, curl and gnupg must be installed first.
Runtime: use --rm, --privileged and an anonymous volume at /var/lib/docker-in-docker,
then invoke docker-in-docker start or register docker-in-docker with container-services.
The service adapter is installed whether or not container-services is present.
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

# Usage: validate_directory <path> <mode>
# Description: Accepts an absent path or verifies an existing root-owned directory.
# Returns: Non-zero when an existing path is unsafe or has the wrong type.
validate_directory() {
    local path="$1"
    local mode="$2"
    local owner
    local actual_mode

    if [[ ! -e "${path}" && ! -L "${path}" ]]; then
        return 0
    fi
    if [[ -L "${path}" || ! -d "${path}" ]]; then
        die "${installer}" "conflicting path is not a directory: ${path}"
        return 1
    fi
    owner="$(stat -c '%u' -- "${path}")" || return 1
    actual_mode="$(stat -c '%a' -- "${path}")" || return 1
    if [[ "${owner}" != '0' || "${actual_mode}" != "${mode}" ]]; then
        die "${installer}" "directory has unsafe ownership or mode: ${path}"
        return 1
    fi
}

# Usage: verify_file_state <source> <destination> <mode>
# Description: Rejects unsafe destinations and accepts only an identical installed file.
# Returns: Non-zero when the destination conflicts with the requested file.
verify_file_state() {
    local source_path="$1"
    local destination_path="$2"
    local mode="$3"
    local owner
    local actual_mode

    [[ -f "${source_path}" && ! -L "${source_path}" ]] || {
        die "${installer}" "bundled file is missing: ${source_path}"
        return 1
    }
    if [[ ! -e "${destination_path}" && ! -L "${destination_path}" ]]; then
        return 0
    fi
    if [[ -L "${destination_path}" || ! -f "${destination_path}" ]] ||
        ! cmp --silent -- "${source_path}" "${destination_path}"; then
        die "${installer}" "conflicting installed file exists: ${destination_path}; remove it first."
        return 1
    fi
    owner="$(stat -c '%u' -- "${destination_path}")" || return 1
    actual_mode="$(stat -c '%a' -- "${destination_path}")" || return 1
    if [[ "${owner}" != '0' || "${actual_mode}" != "${mode}" ]]; then
        die "${installer}" "installed file has unsafe ownership or mode: ${destination_path}"
        return 1
    fi
}

# Usage: verify_existing_state <expected_definition>
# Description: Rejects repository or runtime files not owned in canonical format.
# Returns: Non-zero when existing state conflicts with the requested installation.
verify_existing_state() {
    local expected_definition="$1"
    local existing_definition
    local source_metadata

    if [[ -e /etc/apt/sources.list.d/docker.list || -L /etc/apt/sources.list.d/docker.list ]]; then
        die "${installer}" 'conflicting Docker source exists: /etc/apt/sources.list.d/docker.list; remove it first.'
        return 1
    fi
    if [[ -L "${docker_key_path}" || (-e "${docker_key_path}" && ! -f "${docker_key_path}") ]]; then
        die "${installer}" "Docker keyring path must be a regular file: ${docker_key_path}"
        return 1
    fi
    if [[ -e "${docker_source_path}" || -L "${docker_source_path}" ]]; then
        source_metadata="$(stat -c '%u:%a' -- "${docker_source_path}")" || return 1
        if [[ -L "${docker_source_path}" || ! -f "${docker_source_path}" ]] ||
            ! existing_definition="$(<"${docker_source_path}")" ||
            [[ "${existing_definition}" != "${expected_definition}" ]] ||
            [[ "${source_metadata}" != '0:644' ]]; then
            die "${installer}" "conflicting Docker source exists: ${docker_source_path}; remove it first."
            return 1
        fi
    fi
    verify_file_state "${lifecycle_command_source}" "${lifecycle_command_path}" 755
    verify_file_state "${adapter_source}" "${adapter_path}" 755
    verify_file_state "${common_source}" "${common_path}" 644
    validate_directory '/usr/local/sbin' 755
    validate_directory '/usr/local/libexec' 755
    validate_directory '/usr/local/libexec/ubuntu-devcontainer-installers' 755
    validate_directory '/usr/local/libexec/ubuntu-devcontainer-installers/services' 755
    validate_directory "${support_root}" 755
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

    install --directory --owner=root --group=root --mode=0755 -- "$(dirname -- "${docker_key_path}")"
    if ! gpg --batch --yes --dearmor --output "${docker_key_path}" -- "${downloaded_key}"; then
        die "${installer}" 'could not create the Docker repository keyring.'
        return 1
    fi
    chmod 0644 -- "${docker_key_path}"
}

# Usage: install_runtime_files
# Description: Publishes the manual lifecycle command, adapter and private logger atomically.
# Side Effects: Creates installer-owned runtime files and support directories.
# Returns: Non-zero when a runtime file cannot be published.
install_runtime_files() {
    local destination_directory
    local temporary_path
    local source_path
    local destination_path
    local mode

    install --directory --owner=root --group=root --mode=0755 -- \
        '/usr/local/sbin' \
        '/usr/local/libexec' \
        '/usr/local/libexec/ubuntu-devcontainer-installers' \
        '/usr/local/libexec/ubuntu-devcontainer-installers/services' \
        "${support_root}"
    for source_path in "${lifecycle_command_source}" "${adapter_source}" "${common_source}"; do
        case "${source_path}" in
            "${lifecycle_command_source}")
                destination_path="${lifecycle_command_path}"
                mode=755
                destination_directory="$(dirname -- "${destination_path}")"
                ;;
            "${adapter_source}")
                destination_path="${adapter_path}"
                mode=755
                destination_directory="$(dirname -- "${destination_path}")"
                ;;
            *)
                destination_path="${common_path}"
                mode=644
                destination_directory="${support_root}"
                ;;
        esac
        if [[ -e "${destination_path}" || -L "${destination_path}" ]]; then
            continue
        fi
        temporary_path="$(mktemp "${destination_directory}/.docker-in-docker.XXXXXX")"
        if ! install --owner=root --group=root --mode="${mode}" -- \
            "${source_path}" "${temporary_path}" ||
            ! mv -- "${temporary_path}" "${destination_path}"; then
            rm -f -- "${temporary_path}"
            die "${installer}" "could not install runtime file: ${destination_path}"
            return 1
        fi
    done
}

# Usage: main <argument...>
# Description: Validates state, configures Docker's repository and installs lifecycle files.
# Side Effects: Adds signed APT files, packages and explicit service lifecycle commands.
# Returns: Non-zero when validation, repository setup or installation fails.
main() {
    local expected_definition
    local temporary_directory
    local cleanup_command

    # Accept only the state-free help request.
    if (($# > 0)); then
        if (($# == 1)) && [[ "$1" == '--help' ]]; then
            usage
            return 0
        fi
        die "${installer}" "unknown option: $1"
        return 1
    fi

    # Validate platform, prerequisites and every collision before changing state.
    expected_definition="$(expected_docker_definition)"
    require_root "${installer}"
    require_supported_platform "${installer}"
    require_command "${installer}" apt-get
    require_command "${installer}" cmp
    require_command "${installer}" dpkg-query
    require_command "${installer}" install
    require_command "${installer}" mktemp
    require_command "${installer}" stat
    require_apt_package ca-certificates
    require_apt_package curl
    require_apt_package gnupg
    require_command "${installer}" curl
    require_command "${installer}" gpg
    [[ -r "${lifecycle_command_source}" ]] ||
        die "${installer}" "bundled lifecycle command is missing: ${lifecycle_command_source}"
    [[ -r "${adapter_source}" ]] ||
        die "${installer}" "bundled service adapter is missing: ${adapter_source}"
    [[ -r "${common_source}" ]] ||
        die "${installer}" "bundled common library is missing: ${common_source}"
    verify_existing_state "${expected_definition}"

    # Verify the remote key before configuring the signed Docker repository.
    temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/docker-in-docker-installer.XXXXXX")"
    printf -v cleanup_command 'rm -rf -- %q' "${temporary_directory}"
    # Expand the shell-escaped local path now so it remains available to the EXIT trap.
    # shellcheck disable=SC2064
    trap "${cleanup_command}" EXIT
    install_docker_key "${temporary_directory}"
    printf '%s\n' "${expected_definition}" >"${docker_source_path}"
    chmod 0644 -- "${docker_source_path}"

    # Install the engine, CLI plugins and explicit lifecycle files.
    apt_install_packages "${installer}" \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    install_runtime_files
    log_info "${installer}" 'Docker-in-Docker installation complete; daemon remains stopped and unregistered.'
}

main "$@"
