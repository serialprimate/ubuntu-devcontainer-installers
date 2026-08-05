#!/usr/bin/env bash
set -euo pipefail

# Verifies pipx version and release-age validation without changing system state.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# Resolve project-owned assertions from the repository root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
readonly installer="${repository_root}/installers/pipx/install.sh"

# Return exact-version and secure-default details without requiring Python.
output="$("${installer}" --help)"
assert_contains 'default: 1.16.6' "${output}"
assert_contains 'minimum: 1.16.0' "${output}"
assert_contains 'default: 7' "${output}"

# Reject malformed and unsupported product versions before execution-context checks.
for version in 'latest' '1.16rc1' '1..16'; do
    set +e
    output="$("${installer}" --pipx-version "${version}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains "invalid pipx version: ${version}" "${output}"
done

set +e
output="$("${installer}" --pipx-version 1.15.0 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'minimum supported version is 1.16.0' "${output}"

# Reject malformed bounds and incompatible supply-chain controls before requiring Python.
for days in '-1' '1.5' '3651' '01'; do
    set +e
    output="$("${installer}" --minimum-release-age-days "${days}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains 'minimum release age must be an integer from 0 through 3650 days' "${output}"
done

set +e
output="$("${installer}" --minimum-release-age-days 7 --without-minimum-release-age 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'cannot be used together' "${output}"

# Reject missing values, duplicate scalar options and unknown options.
set +e
output="$("${installer}" --pipx-version 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'option requires a value: --pipx-version' "${output}"

set +e
output="$("${installer}" --without-minimum-release-age --without-minimum-release-age 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'option may be specified only once: --without-minimum-release-age' "${output}"
