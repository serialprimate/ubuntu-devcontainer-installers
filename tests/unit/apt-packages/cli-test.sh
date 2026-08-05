#!/usr/bin/env bash
set -euo pipefail

# Verifies apt-packages help, required input and literal package validation.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# Resolve project-owned assertions from the repository root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
readonly installer="${repository_root}/installers/apt-packages/install.sh"

# Return help without requiring root, platform checks or APT operations.
output="$("${installer}" --help)"
assert_contains 'Usage: install.sh' "${output}"
assert_contains '--package-file PATH' "${output}"

# Reject an empty request before any state-changing prerequisite is reached.
set +e
output="$("${installer}" 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'at least one --package' "${output}"

# Reject unknown options and missing separate values with qualified diagnostics.
set +e
output="$("${installer}" --packages curl 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'apt-packages: error: unknown option: --packages' "${output}"

set +e
output="$("${installer}" --package 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'option requires a value: --package' "${output}"

# Preserve a package-file line literally so surrounding whitespace is rejected, not trimmed.
package_file="$(mktemp "${TMPDIR:-/tmp}/apt-packages-unit.XXXXXX")"
readonly package_file
trap 'rm -f -- "${package_file}"' EXIT
printf 'curl\n xz-utils\n' >"${package_file}"
set +e
output="$("${installer}" --package-file "${package_file}" 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'invalid package specification:  xz-utils' "${output}"

# Reject values that could be interpreted as APT options or multiple packages.
for invalid_package in '--allow-unauthenticated' 'curl xz-utils' 'Curl'; do
    set +e
    output="$("${installer}" --package "${invalid_package}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains "invalid package specification: ${invalid_package}" "${output}"
done
