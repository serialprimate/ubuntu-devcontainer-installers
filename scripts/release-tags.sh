#!/usr/bin/env bash
set -euo pipefail

# Derives exact, minor and major OCI tags from one exact Semantic Versioning Git tag.

# Validate the release tag without accepting mutable aliases or prereleases
if (($# != 1)); then
    printf 'Usage: %s VERSION\n' "${0##*/}" >&2
    exit 2
fi
readonly version="$1"
if [[ ! "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    printf 'release-tags: error: expected an exact SemVer tag without a v prefix: %s\n' \
        "${version}" >&2
    exit 2
fi

# Emit tags from most specific to least specific for direct array consumption
printf '%s\n' "${version}" "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}" "${BASH_REMATCH[1]}"
