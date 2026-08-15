#!/usr/bin/env bash
set -euo pipefail

# Verifies npm package and release-age validation without changing system state.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# Resolve project-owned assertions from the repository root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
readonly installer="${repository_root}/installers/npm-packages/install.sh"

# Return repeatable package and secure-default details without requiring npm.
output="$("${installer}" --help)"
assert_contains '--package PACKAGE' "${output}"
assert_contains 'default: 7' "${output}"
assert_contains '--allow-package-scripts' "${output}"
assert_contains 'Dependency lifecycle scripts are disabled unless explicitly allowed' "${output}"

# Require an explicit package collection before execution-context checks.
set +e
output="$("${installer}" 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'at least one --package is required' "${output}"

# Reject malformed or non-registry specifications as literal values.
for package in '--foreground-scripts' 'https://example.com/package.tgz' '../package' \
    'name@^1.0.0' 'name with-space'; do
    set +e
    output="$("${installer}" --package "${package}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains "invalid npm package specification: ${package}" "${output}"
done

# Reject malformed bounds and incompatible supply-chain controls before requiring npm.
for days in '-1' '1.5' '3651' '01'; do
    set +e
    output="$("${installer}" --package is-number@7.0.0 \
        --minimum-release-age-days "${days}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains 'minimum release age must be an integer from 0 through 3650 days' "${output}"
done

set +e
output="$("${installer}" --package is-number@7.0.0 \
    --minimum-release-age-days 7 --without-minimum-release-age 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'cannot be used together' "${output}"

# Reject missing values, duplicate scalar options and unknown options.
set +e
output="$("${installer}" --package 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'option requires a value: --package' "${output}"

set +e
output="$("${installer}" --package is-number \
    --without-minimum-release-age --without-minimum-release-age 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'option may be specified only once: --without-minimum-release-age' "${output}"

set +e
output="$("${installer}" --package is-number \
    --allow-package-scripts --allow-package-scripts 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'option may be specified only once: --allow-package-scripts' "${output}"
