#!/usr/bin/env bash
set -euo pipefail

# Verifies apt-python help and option-parser failure boundaries without changing system state.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# Resolve project-owned assertions from the repository root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
readonly installer="${repository_root}/installers/apt-python/install.sh"

# Return documented defaults without checking the execution platform or invoking APT.
output="$("${installer}" --help)"
assert_contains 'python3, python3-pip and python3-venv' "${output}"
assert_contains '--without-pip' "${output}"

# Reject unknown options before execution-context and package checks.
set +e
output="$("${installer}" --with-pip 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'apt-python: error: unknown option: --with-pip' "${output}"

# Reject duplicate scalar flags rather than silently accepting ambiguous input.
for option in --without-pip --without-venv; do
    set +e
    output="$("${installer}" "${option}" "${option}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains "option may be specified only once: ${option}" "${output}"
done
