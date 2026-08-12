#!/usr/bin/env bash
set -euo pipefail

# Inspects one OCI candidate and runs packaged-layout scenarios against its copied payload.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root

# Validate required identity arguments before using the local Docker endpoint
if (($# != 3)); then
    printf 'Usage: %s IMAGE VERSION REVISION\n' "${0##*/}" >&2
    exit 2
fi
readonly image="$1"
readonly version="$2"
readonly revision="$3"

# Usage: require_image_value <description> <expected> <inspect-format>
# Description: Verifies one candidate metadata value and reports an actionable mismatch.
# Returns: Non-zero when inspection fails or the value differs.
require_image_value() {
    local description="$1"
    local expected="$2"
    local format="$3"
    local actual

    actual="$(docker image inspect --format "${format}" "${image}")"
    if [[ "${actual}" != "${expected}" ]]; then
        printf 'test-oci: error: invalid %s: expected %s, found %s\n' \
            "${description}" "${expected}" "${actual}" >&2
        return 1
    fi
}

# Verify release labels, platform and the intentionally non-runtime image configuration
require_image_value platform 'linux/amd64' '{{.Os}}/{{.Architecture}}'
require_image_value source-label \
    'https://github.com/serialprimate/ubuntu-devcontainer-installers' \
    '{{index .Config.Labels "org.opencontainers.image.source"}}'
require_image_value version-label "${version}" \
    '{{index .Config.Labels "org.opencontainers.image.version"}}'
require_image_value revision-label "${revision}" \
    '{{index .Config.Labels "org.opencontainers.image.revision"}}'
require_image_value command null '{{json .Config.Cmd}}'
require_image_value entrypoint null '{{json .Config.Entrypoint}}'

# Build fresh Ubuntu scenarios that copy only from the candidate image
INSTALLER_IMAGE="${image}" "${repository_root}/scripts/test-integration.sh" packaged-artefact
