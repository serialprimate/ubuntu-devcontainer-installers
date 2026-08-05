#!/usr/bin/env bash
set -euo pipefail

# Verifies shared diagnostics, root checks and command prerequisite failures.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
source "${repository_root}/tests/lib/assertions.sh"
source "${repository_root}/lib/common.sh"

# Qualify informational diagnostics with the installer name on standard output.
output="$(log_info example 'installation started')"
assert_equal 'example: info: installation started' "${output}"

# Qualify warning diagnostics with the installer name on standard error.
output="$(log_warning example 'review this choice' 2>&1)"
assert_equal 'example: warning: review this choice' "${output}"

# Reject a non-root effective UID supplied through the pure-test override.
set +e
output="$(require_root example 1000 2>&1)"
status=$?
set -e
assert_equal '1' "${status}" 'require_root accepted a non-root effective UID'
assert_contains 'example: error: must be run as root.' "${output}"

# Reject an absent prerequisite with the caller's actionable composition advice.
missing_command="ubuntu-installers-command-that-does-not-exist"
set +e
output="$(require_command example "${missing_command}" 'Run the prerequisite installer first.' 2>&1)"
status=$?
set -e
assert_equal '1' "${status}" 'require_command accepted a missing command'
assert_contains "required command not found: ${missing_command}" "${output}"
assert_contains 'Run the prerequisite installer first.' "${output}"
