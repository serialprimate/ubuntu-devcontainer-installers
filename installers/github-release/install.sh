#!/usr/bin/env bash
set -euo pipefail

# Installs one SHA-256-pinned raw executable from an exact GitHub Release asset.

# Define installer metadata and bundled libraries
readonly installer='github-release'
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
Usage: install.sh OPTIONS

Install one pinned raw executable from an exact GitHub Release on Ubuntu 26.04
(linux/amd64).

Required options:
  --repository OWNER/REPOSITORY   Select the exact GitHub repository.
  --release-tag TAG               Select the exact release tag; latest is rejected.
  --asset-name NAME               Select one exact raw executable asset.
  --sha256 DIGEST                 Require the exact asset SHA-256 digest.
  --install-path PATH             Install to an absolute, non-existing or matching file.

Other options:
  --help                          Show this help and exit without changing state.
EOF
}

# Usage: set_once <option_name> <seen_name> <destination_name> <value>
# Description: Assigns one scalar option and rejects duplicate occurrences.
# Side Effects: Updates the named seen flag and destination variable.
# Returns: Non-zero when the option was already supplied.
set_once() {
    local option_name="$1"
    local seen_name="$2"
    local destination_name="$3"
    local value="$4"
    local -n seen_ref="${seen_name}"
    local -n destination_ref="${destination_name}"

    if [[ "${seen_ref}" == 'true' ]]; then
        die "${installer}" "option may be specified only once: ${option_name}"
        return 1
    fi
    # ShellCheck cannot follow assignments through namerefs.
    # shellcheck disable=SC2034
    destination_ref="${value}"
    seen_ref='true'
}

# Usage: require_value <option_name> <value>
# Description: Rejects an omitted required option after argument collection.
# Returns: Non-zero when the value is empty.
require_value() {
    local option_name="$1"
    local value="$2"

    if [[ -z "${value}" ]]; then
        die "${installer}" "required option not provided: ${option_name}"
    fi
}

# Usage: verify_destination_parent <parent_path>
# Description: Requires a root-owned directory that is not writable by group or other users.
# Returns: Non-zero when the destination parent is absent, unsafe or not root-owned.
verify_destination_parent() {
    local parent_path="$1"
    local owner_id
    local mode

    if [[ ! -d "${parent_path}" || -L "${parent_path}" ]]; then
        die "${installer}" "install path parent must be an existing non-symlink directory: ${parent_path}"
        return 1
    fi
    owner_id="$(stat -c '%u' -- "${parent_path}")"
    mode="$(stat -c '%a' -- "${parent_path}")"
    if [[ "${owner_id}" != '0' ]] || (((8#${mode} & 8#022) != 0)); then
        die "${installer}" \
            "install path parent must be root-owned and not group- or world-writable: ${parent_path}"
    fi
}

# Usage: main <argument...>
# Description: Validates, downloads, verifies and installs one exact GitHub Release executable.
# Side Effects: Creates the requested executable file.
# Returns: Non-zero when validation, verification or installation fails.
main() {
    local repository=''
    local release_tag=''
    local asset_name=''
    local expected_sha256=''
    local install_path=''
    # These flags are read and updated through set_once namerefs.
    # shellcheck disable=SC2034
    local repository_seen='false'
    # shellcheck disable=SC2034
    local release_tag_seen='false'
    # shellcheck disable=SC2034
    local asset_name_seen='false'
    # shellcheck disable=SC2034
    local sha256_seen='false'
    # shellcheck disable=SC2034
    local install_path_seen='false'
    local destination_parent
    local downloaded_sha256
    local download_url
    local temporary_directory=''
    local downloaded_asset
    local existing_metadata

    # Collect exact source identity, integrity and destination options
    while (($# > 0)); do
        case "$1" in
            --repository | --release-tag | --asset-name | --sha256 | --install-path)
                require_option_value "${installer}" "$1" "$#"
                case "$1" in
                    --repository) set_once "$1" repository_seen repository "$2" ;;
                    --release-tag) set_once "$1" release_tag_seen release_tag "$2" ;;
                    --asset-name) set_once "$1" asset_name_seen asset_name "$2" ;;
                    --sha256) set_once "$1" sha256_seen expected_sha256 "$2" ;;
                    --install-path) set_once "$1" install_path_seen install_path "$2" ;;
                    *)
                        die "${installer}" "internal option dispatch failure: $1"
                        return 1
                        ;;
                esac
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

    # Validate the complete request before execution-context checks
    require_value --repository "${repository}"
    require_value --release-tag "${release_tag}"
    require_value --asset-name "${asset_name}"
    require_value --sha256 "${expected_sha256}"
    require_value --install-path "${install_path}"
    if [[ ! "${repository}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        die "${installer}" 'invalid repository; expected OWNER/REPOSITORY.'
        return 1
    fi
    if [[ "${release_tag}" == 'latest' ]] ||
        [[ ! "${release_tag}" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then
        die "${installer}" 'invalid release tag; expected an exact tag without path separators.'
        return 1
    fi
    if [[ ! "${asset_name}" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then
        die "${installer}" 'invalid asset name; expected one filename without path separators.'
        return 1
    fi
    expected_sha256="${expected_sha256,,}"
    if [[ ! "${expected_sha256}" =~ ^[0-9a-f]{64}$ ]]; then
        die "${installer}" 'invalid SHA-256 digest; expected exactly 64 hexadecimal characters.'
        return 1
    fi
    if [[ "${install_path}" != /* ]] || [[ "${install_path}" == '/' ]] ||
        [[ "${install_path}" == */ ]] || [[ "${install_path}" == *//* ]] ||
        [[ "${install_path}" == */. ]] || [[ "${install_path}" == */.. ]] ||
        [[ "${install_path}" == *'/../'* ]] || [[ "${install_path}" == *'/./'* ]]; then
        die "${installer}" 'invalid install path; expected a normalized absolute file path.'
        return 1
    fi

    # Verify platform, prerequisites and collision-relevant destination state
    require_root "${installer}"
    require_supported_platform "${installer}"
    require_command "${installer}" curl \
        'Run installers/apt-packages/install.sh --package curl before invoking github-release.'
    require_command "${installer}" sha256sum
    require_command "${installer}" install
    require_command "${installer}" stat
    destination_parent="$(dirname -- "${install_path}")"
    verify_destination_parent "${destination_parent}"
    if [[ -e "${install_path}" || -L "${install_path}" ]]; then
        if [[ ! -f "${install_path}" || -L "${install_path}" ]]; then
            log_error "${installer}" "conflicting non-regular install path exists: ${install_path}"
            return 2
        fi
        downloaded_sha256="$(sha256sum -- "${install_path}")"
        downloaded_sha256="${downloaded_sha256%% *}"
        if [[ "${downloaded_sha256}" != "${expected_sha256}" ]]; then
            log_error "${installer}" \
                "install path contains different content: ${install_path}; remove it before installation."
            return 2
        fi
        existing_metadata="$(stat -c '%a:%u:%g' -- "${install_path}")"
        if [[ "${existing_metadata}" != '755:0:0' ]]; then
            log_error "${installer}" \
                "matching install path has unexpected mode or ownership: ${install_path}; expected 0755 root:root."
            return 2
        fi
        log_info "${installer}" "the requested asset is already installed at ${install_path}."
        return 0
    fi

    # Download through HTTPS-only redirects into installer-owned temporary state
    temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/github-release-installer.XXXXXX")"
    trap 'rm -rf -- "${temporary_directory}"' EXIT
    downloaded_asset="${temporary_directory}/${asset_name}"
    download_url="https://github.com/${repository}/releases/download/${release_tag}/${asset_name}"
    log_info "${installer}" "downloading ${repository} ${release_tag} asset ${asset_name}."
    if ! curl --fail --silent --show-error --location --max-redirs 5 \
        --proto '=https' --proto-redir '=https' --output "${downloaded_asset}" -- "${download_url}"; then
        die "${installer}" 'asset download failed; verify the repository, tag, asset and network access.'
        return 1
    fi
    if [[ ! -s "${downloaded_asset}" || ! -f "${downloaded_asset}" ]]; then
        die "${installer}" 'downloaded asset is empty or not a regular file.'
        return 1
    fi

    # Verify exact content before creating persistent installation state
    downloaded_sha256="$(sha256sum -- "${downloaded_asset}")"
    downloaded_sha256="${downloaded_sha256%% *}"
    if [[ "${downloaded_sha256}" != "${expected_sha256}" ]]; then
        die "${installer}" \
            "SHA-256 verification failed for ${asset_name}; expected ${expected_sha256}, got ${downloaded_sha256}."
        return 1
    fi
    install --owner=root --group=root --mode=0755 -- "${downloaded_asset}" "${install_path}"
    trap - EXIT
    rm -rf -- "${temporary_directory}"
    log_info "${installer}" "installed ${asset_name} at ${install_path}."
}

main "$@"
