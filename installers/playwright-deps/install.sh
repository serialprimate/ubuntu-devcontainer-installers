#!/usr/bin/env bash
set -euo pipefail

# Installs reviewed Ubuntu Chromium dependencies for an explicit supported Playwright target.

# Define the release-fixed target and reviewed Chromium package profile
readonly installer='playwright-deps'
readonly default_playwright_version='1.64.0'
# Preserve upstream's ubuntu26.04-x64 tools + chromium groups from Playwright v1.64.0
# Source commit: 606ecd8b34bac100db32561b6278ffd76e5eb3cd (nativeDeps.ts)
readonly -a chromium_packages=(
    fonts-freefont-ttf
    fonts-ipafont-gothic
    fonts-liberation
    fonts-noto-color-emoji
    fonts-tlwg-loma-otf
    fonts-unifont
    fonts-wqy-zenhei
    libasound2t64
    libatk-bridge2.0-0t64
    libatk1.0-0t64
    libatspi2.0-0t64
    libcairo2
    libcups2t64
    libdbus-1-3
    libdrm2
    libfontconfig1
    libfreetype6
    libgbm1
    libglib2.0-0t64
    libnspr4
    libnss3
    libpango-1.0-0
    libx11-6
    libxcb1
    libxcomposite1
    libxdamage1
    libxext6
    libxfixes3
    libxkbcommon0
    libxrandr2
    xfonts-cyrillic
    xfonts-scalable
    xvfb
)

# Resolve installer-relative libraries without requiring Node.js or npm
installer_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly installer_dir
readonly repository_lib_dir="${installer_dir}/../../lib"
# shellcheck disable=SC1091
source "${repository_lib_dir}/common.sh"
# shellcheck disable=SC1091
source "${repository_lib_dir}/arguments.sh"
# shellcheck disable=SC1091
source "${repository_lib_dir}/platform.sh"
# shellcheck disable=SC1091
source "${repository_lib_dir}/apt.sh"

# Usage: usage
# Description: Writes the supported target, default and dependency-only installation contract.
usage() {
    cat <<'EOF'
Usage: install.sh [--playwright-version VERSION] [--help]

Install Ubuntu 26.04 (linux/amd64) dependencies for bundled Chromium and its headless shell.

Options:
  --playwright-version VERSION  Select an exact supported Playwright target;
                                may be specified once (default: 1.64.0).
  --help                        Show this help without changing state.

Supported Playwright versions: 1.64.0
Installs Ubuntu libraries, fonts and tools only, not Node.js, npm packages or browsers.
Firefox and WebKit are not supported by this profile. No browser selector is provided.
EOF
}

# Usage: main <argument...>
# Description: Validates a local target selection and installs its reviewed Ubuntu packages.
# Side Effects: Installs Ubuntu packages and cleans APT metadata and caches.
# Returns: Non-zero for invalid input, unsupported execution context or APT failure.
main() {
    local playwright_version="${default_playwright_version}"
    local version_seen='false'
    local -a packages=()

    # Collect the optional exact target without normalising or evaluating its value
    while (($# > 0)); do
        case "$1" in
            --playwright-version)
                require_option_value "${installer}" "$1" "$#"
                if [[ "${version_seen}" == 'true' ]]; then
                    die "${installer}" 'option may be specified only once: --playwright-version'
                    return 1
                fi
                playwright_version="$2"
                version_seen='true'
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

    # Resolve only reviewed stable targets before checking privileges or changing APT state
    if [[ ! "${playwright_version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
        die "${installer}" "invalid Playwright version: ${playwright_version}; use an exact stable major.minor.patch."
        return 1
    fi
    case "${playwright_version}" in
        1.64.0) packages=("${chromium_packages[@]}") ;;
        *)
            die "${installer}" "unsupported Playwright version: ${playwright_version}; supported versions: 1.64.0."
            return 1
            ;;
    esac

    # Verify the intrinsic Ubuntu prerequisites without installing a JavaScript toolchain
    require_root "${installer}"
    require_supported_platform "${installer}"
    require_command "${installer}" apt-get

    # Install the selected dependency profile through one complete APT lifecycle
    log_info "${installer}" "installing Chromium dependencies for Playwright ${playwright_version}."
    apt_install_packages "${installer}" "${packages[@]}"
    log_info "${installer}" 'installation complete; install project-local Playwright packages and browsers separately.'
}

main "$@"
