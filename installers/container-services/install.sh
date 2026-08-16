#!/usr/bin/env bash
set -euo pipefail

# Installs the explicit root service orchestrator without packages or network access.

# Define installer metadata and resolve bundled sources.
readonly installer='container-services'
readonly command_path='/usr/local/bin/container-services'
readonly support_root='/usr/local/libexec/ubuntu-devcontainer-installers/container-services'
readonly common_path="${support_root}/common.sh"
readonly configuration_root='/etc/ubuntu-devcontainer-installers/container-services'
readonly manifest_path="${configuration_root}/services"
installer_dir="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
        pwd
)"
readonly installer_dir
readonly command_source="${installer_dir}/container-services"
readonly repository_lib_dir="${installer_dir}/../../lib"
readonly common_source="${repository_lib_dir}/common.sh"
# Resolve bundled libraries through installer-relative paths.
# shellcheck disable=SC1091
source "${repository_lib_dir}/common.sh"
# shellcheck disable=SC1091
source "${repository_lib_dir}/platform.sh"

# Usage: usage
# Description: Writes command usage and composition prerequisites to standard output.
usage() {
    cat <<'EOF'
Usage: install.sh

Install the explicit container-services runtime orchestrator on Ubuntu 26.04
(linux/amd64). The installer performs no network access and installs no package.

Options:
  --help  Show this help and exit without changing system state.

After installing one or more trusted service adapters, register them explicitly:
  container-services register --service NAME
  ENTRYPOINT ["container-services", "entrypoint", "--"]
EOF
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
        die "${installer}" "conflicting directory has unsafe ownership or mode: ${path}"
        return 1
    fi
}

# Usage: verify_optional_manifest
# Description: Retains an existing canonical manifest without allowing a foreign path.
# Returns: Non-zero when existing registration state is unsafe or non-canonical.
verify_optional_manifest() {
    local owner
    local mode

    if [[ ! -e "${manifest_path}" && ! -L "${manifest_path}" ]]; then
        return 0
    fi
    if [[ -L "${manifest_path}" || ! -f "${manifest_path}" ]]; then
        die "${installer}" "conflicting registration path is not a regular file: ${manifest_path}"
        return 1
    fi
    owner="$(stat -c '%u' -- "${manifest_path}")" || return 1
    mode="$(stat -c '%a' -- "${manifest_path}")" || return 1
    if [[ "${owner}" != '0' || "${mode}" != '644' ]]; then
        die "${installer}" "conflicting registration file has unsafe ownership or mode: ${manifest_path}"
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

# Usage: install_file_atomically <source> <destination> <mode>
# Description: Installs one canonical file through a same-directory temporary path.
# Side Effects: Creates an installer-owned file at the destination.
# Returns: Non-zero when the file cannot be published.
install_file_atomically() {
    local source_path="$1"
    local destination_path="$2"
    local mode="$3"
    local destination_directory
    local temporary_path

    if [[ -e "${destination_path}" || -L "${destination_path}" ]]; then
        return 0
    fi
    destination_directory="$(dirname -- "${destination_path}")"
    temporary_path="$(mktemp "${destination_directory}/.container-services.XXXXXX")"
    if ! install --owner=root --group=root --mode="${mode}" -- "${source_path}" "${temporary_path}"; then
        rm -f -- "${temporary_path}"
        return 1
    fi
    if ! mv -- "${temporary_path}" "${destination_path}"; then
        rm -f -- "${temporary_path}"
        return 1
    fi
}

# Usage: main <argument...>
# Description: Validates all paths and installs the stable orchestrator runtime files.
# Side Effects: Creates the orchestrator command, private logger and registration directory.
# Returns: Non-zero when validation or installation fails.
main() {
    if (($# > 0)); then
        if (($# == 1)) && [[ "$1" == '--help' ]]; then
            usage
            return 0
        fi
        die "${installer}" "unknown option: $1"
        return 1
    fi

    # Validate request, platform and all collision-relevant paths before changing state.
    require_root "${installer}"
    require_supported_platform "${installer}"
    require_command "${installer}" cmp
    require_command "${installer}" install
    require_command "${installer}" mktemp
    require_command "${installer}" mv
    require_command "${installer}" stat
    require_command "${installer}" chown
    [[ -r "${command_source}" ]] || die "${installer}" "bundled runtime command is missing: ${command_source}"
    [[ -r "${common_source}" ]] || die "${installer}" "bundled common library is missing: ${common_source}"

    validate_directory '/usr/local/libexec' 755
    validate_directory '/usr/local/libexec/ubuntu-devcontainer-installers' 755
    validate_directory '/usr/local/bin' 755
    validate_directory "${support_root}" 755
    validate_directory '/etc/ubuntu-devcontainer-installers' 755
    validate_directory "${configuration_root}" 755
    verify_file_state "${command_source}" "${command_path}" 755
    verify_file_state "${common_source}" "${common_path}" 644
    verify_optional_manifest

    # Create owned directories only after every request and collision has been validated.
    install --directory --owner=root --group=root --mode=0755 -- \
        '/usr/local/libexec' \
        '/usr/local/libexec/ubuntu-devcontainer-installers' \
        '/usr/local/bin' \
        "${support_root}" \
        '/etc/ubuntu-devcontainer-installers' \
        "${configuration_root}"

    # Publish the command and private common library without overwriting any collision.
    install_file_atomically "${command_source}" "${command_path}" 755
    install_file_atomically "${common_source}" "${common_path}" 644
    log_info "${installer}" 'installation complete; no service is registered or started.'
}

main "$@"
