#!/usr/bin/env bash
set -euo pipefail

# Verifies user help and validation failures before account state can change.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# Resolve project-owned assertions from the repository root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
readonly installer="${repository_root}/installers/user/install.sh"

# Return all identity and controlled-risk options without requiring root.
output="$("${installer}" --help)"
assert_contains '--username NAME' "${output}"
assert_contains '--group NAME' "${output}"
assert_contains '--allow-passwordless-sudo' "${output}"
assert_contains 'Passwords and password hashes are intentionally not accepted.' "${output}"

# Reject unknown options and missing values with installer-qualified errors.
set +e
output="$("${installer}" --password secret 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'user: error: unknown option: --password' "${output}"

set +e
output="$("${installer}" --uid 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'option requires a value: --uid' "${output}"

# Reject names, root identities, numeric boundaries and unavailable shells before inspection.
invalid_arguments=(
    '--username|root|user name must not be root'
    '--username|Bad.Name|invalid user name'
    '--uid|0|UID must be an integer from 1'
    '--uid|-1|UID must be an integer from 1'
    '--gid|4294967295|GID must be an integer from 1'
    '--uid|999999999999999999999999|UID must be an integer from 1'
    '--shell|/does/not/exist|shell must be an installed executable absolute path'
)
for scenario in "${invalid_arguments[@]}"; do
    IFS='|' read -r option value expected <<<"${scenario}"
    set +e
    output="$("${installer}" "${option}" "${value}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains "${expected}" "${output}"
done

# Reject duplicate scalar options and a supplementary copy of the primary group.
set +e
output="$("${installer}" --username dev --username developer 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'option may be specified only once: --username' "${output}"

set +e
output="$("${installer}" --group dev 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'supplementary group duplicates the requested primary group: dev' "${output}"
