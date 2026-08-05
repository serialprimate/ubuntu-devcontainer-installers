#!/usr/bin/env bash

# Provides the complete APT installation lifecycle used by Ubuntu package installers.

# Usage: apt_install_packages <installer_name> <package...>
# Description:
# - Refresh package metadata and install requested packages without recommendations
# - Remove APT package metadata and caches after a successful installation
# Side Effects: Installs system packages and removes local APT caches and package lists.
# Returns: Non-zero when an APT operation fails or no package was supplied.
apt_install_packages() {
    local installer_name="$1"
    shift
    local -a packages=("$@")

    if ((${#packages[@]} == 0)); then
        die "${installer_name}" 'internal error: no APT packages were supplied.'
        return 1
    fi

    log_info "${installer_name}" 'refreshing APT package metadata.'
    if ! apt-get update; then
        die "${installer_name}" 'APT metadata refresh failed; verify configured repositories and network access.'
        return 1
    fi

    log_info "${installer_name}" 'installing requested Ubuntu packages.'
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -- \
        "${packages[@]}"; then
        die "${installer_name}" \
            'APT package installation failed; verify package names, versions and configured repositories.'
        return 1
    fi

    apt-get clean
    rm -rf -- /var/lib/apt/lists/*
}
