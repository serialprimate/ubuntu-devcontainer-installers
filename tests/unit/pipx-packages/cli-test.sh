#!/usr/bin/env bash
set -euo pipefail

# Verifies pipx package and cooldown validation without changing system state.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# Resolve project-owned assertions from the repository root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
readonly installer="${repository_root}/installers/pipx-packages/install.sh"

# Return repeatable package and secure-default details without requiring pipx.
output="$("${installer}" --help)"
assert_contains '--package PACKAGE' "${output}"
assert_contains 'default: 7' "${output}"
assert_contains 'pipx 1.16.0 or newer' "${output}"

# Require an explicit package collection before execution-context checks.
set +e
output="$("${installer}" 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'at least one --package is required' "${output}"

# Reject malformed or non-registry specifications as literal values.
for package in '--force' 'https://example.com/package.whl' '../package' \
    'name>=1.0.0' 'name[extra]' 'name with-space'; do
    set +e
    output="$("${installer}" --package "${package}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains "invalid pipx package specification: ${package}" "${output}"
done

# Reject malformed bounds and incompatible cooldown controls before requiring pipx.
for days in '-1' '1.5' '3651' '01'; do
    set +e
    output="$("${installer}" --package pycowsay==0.0.0.2 --cooldown-days "${days}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains 'cooldown must be an integer from 0 through 3650 days' "${output}"
done

set +e
output="$("${installer}" --package pycowsay --cooldown-days 7 --without-cooldown 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'cannot be used together' "${output}"

set +e
output="$("${installer}" --package Example_Name==1.0 --package example-name==2.0 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'conflicting versions requested for normalized package name example-name' "${output}"

# Reject missing values, duplicate scalar options and unknown options.
set +e
output="$("${installer}" --package 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'option requires a value: --package' "${output}"

set +e
output="$("${installer}" --package pycowsay --without-cooldown --without-cooldown 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'option may be specified only once: --without-cooldown' "${output}"
