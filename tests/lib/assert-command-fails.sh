#!/usr/bin/env bash
set -euo pipefail

# Asserts a command's non-zero status and a literal fragment of its combined output.

if (($# < 3)); then
    printf 'Usage: %s STATUS OUTPUT-FRAGMENT COMMAND [ARGUMENT ...]\n' "${0##*/}" >&2
    exit 2
fi

readonly expected_status="$1"
readonly expected_fragment="$2"
shift 2

if [[ ! "${expected_status}" =~ ^[1-9][0-9]*$ || "${expected_status}" -gt 255 ]]; then
    printf '%s: expected STATUS must be between 1 and 255\n' "${0##*/}" >&2
    exit 2
fi

output_file="$(mktemp "${TMPDIR:-/tmp}/assert-command-fails.XXXXXX")"
readonly output_file
trap 'rm -f -- "${output_file}"' EXIT

# Disable fail-fast only while capturing the failure this helper expects.
set +e
"$@" >"${output_file}" 2>&1
actual_status=$?
set -e
readonly actual_status

if [[ "${actual_status}" -ne "${expected_status}" ]]; then
    printf 'assertion failed: expected status %s, got %s\n' \
        "${expected_status}" "${actual_status}" >&2
    printf '%s\n' '--- command output ---' >&2
    printf '%s' "$(<"${output_file}")" >&2
    exit 1
fi

if ! grep -Fq -- "${expected_fragment}" "${output_file}"; then
    printf 'assertion failed: output does not contain <%s>\n' \
        "${expected_fragment}" >&2
    printf '%s\n' '--- command output ---' >&2
    printf '%s' "$(<"${output_file}")" >&2
    exit 1
fi
