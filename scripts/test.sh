#!/usr/bin/env bash
set -euo pipefail

# Runs unit and integration tests for all suites or each selected suite.

# Resolve sibling runners independently of the caller's working directory
script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly script_directory

# Allow CI to schedule source and nested qualification on separate machines
source_only=0
if [[ "${1:-}" == '--source' ]]; then
    source_only=1
    shift
fi
if [[ "${1:-}" == --* ]]; then
    printf 'Usage: %s [--source] [SUITE...]\n' "${0##*/}" >&2
    exit 2
fi

# Run both complete test levels when no suite is selected
if (($# == 0)); then
    "${script_directory}/test-unit.sh"
    "${script_directory}/test-integration.sh"
    if ((source_only == 0)) && [[ "${DIND_QUALIFICATION_ACTIVE:-0}" != '1' ]]; then
        "${script_directory}/test-docker-in-docker.sh"
    fi
    exit 0
fi

# Run both test levels for every selected suite
for suite in "$@"; do
    "${script_directory}/test-unit.sh" "${suite}"
    "${script_directory}/test-integration.sh" "${suite}"
done
