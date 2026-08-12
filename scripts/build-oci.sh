#!/usr/bin/env bash
set -euo pipefail

# Builds one locally loaded linux/amd64 OCI release candidate with required source metadata.

# Resolve the build context independently of the caller's working directory
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root

# Validate release identity before invoking Docker
if (($# != 3)); then
    printf 'Usage: %s IMAGE VERSION REVISION\n' "${0##*/}" >&2
    exit 2
fi
readonly image="$1"
readonly version="$2"
readonly revision="$3"
created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
readonly created

if [[ ! "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    printf 'build-oci: error: version must be an exact SemVer release: %s\n' "${version}" >&2
    exit 2
fi
if [[ ! "${revision}" =~ ^[0-9a-f]{40}$ ]]; then
    printf 'build-oci: error: revision must be a full Git commit SHA.\n' >&2
    exit 2
fi

# Build once and load the candidate into the local daemon for packaged verification
exec docker buildx build \
    --load \
    --platform linux/amd64 \
    --file "${repository_root}/Dockerfile" \
    --tag "${image}" \
    --build-arg "VERSION=${version}" \
    --build-arg "REVISION=${revision}" \
    --build-arg "CREATED=${created}" \
    "${repository_root}"
