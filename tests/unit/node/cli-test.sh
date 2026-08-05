#!/usr/bin/env bash
set -euo pipefail

# Verifies Node.js selector and option-parser boundaries without changing system state.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# Resolve project-owned assertions from the repository root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
readonly installer="${repository_root}/installers/node/install.sh"

# Return supported selectors and the stable default without performing platform checks.
output="$("${installer}" --help)"
assert_contains 'default: lts, currently 24' "${output}"
assert_contains '24, 26, lts, or current' "${output}"

# Reject unsupported selectors before any package or repository operation.
set +e
output="$("${installer}" --node-version 20 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'unsupported Node.js version: 20' "${output}"

# Reject missing, duplicate and unknown scalar options with qualified diagnostics.
for arguments in '--node-version' '--node-version 24 --node-version 26' '--version'; do
    read -r -a argument_list <<<"${arguments}"
    set +e
    output="$("${installer}" "${argument_list[@]}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
done
assert_contains 'unknown option: --version' "${output}"
