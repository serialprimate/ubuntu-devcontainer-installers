#!/usr/bin/env bash
set -euo pipefail

# Verifies Docker-in-Docker installer and lifecycle CLI boundaries without system changes.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# Resolve project-owned assertions from the repository root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
readonly installer="${repository_root}/installers/docker-in-docker/install.sh"
readonly lifecycle_command="${repository_root}/installers/docker-in-docker/docker-in-docker"

# Report explicit prerequisites and runtime privilege without platform checks.
output="$("${installer}" --help)"
assert_contains 'ca-certificates, curl and gnupg' "${output}"
assert_contains 'use --rm, --privileged and an anonymous volume' "${output}"

# Reject every installer argument other than the state-free help option.
for arguments in '--version' '--unknown' '--help extra'; do
    read -r -a argument_list <<<"${arguments}"
    set +e
    output="$("${installer}" "${argument_list[@]}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
done
assert_contains 'unknown option: --help' "${output}"

# Expose only explicit lifecycle operations and reject absent or excessive arguments.
output="$("${lifecycle_command}" --help)"
assert_contains 'start|stop|status' "${output}"
assert_contains 'must use --rm and an anonymous volume' "${output}"
for arguments in '' 'start extra'; do
    read -r -a argument_list <<<"${arguments}"
    set +e
    output="$("${lifecycle_command}" "${argument_list[@]}" 2>&1)"
    status=$?
    set -e
    assert_equal '2' "${status}"
done
assert_contains 'Usage: docker-in-docker' "${output}"

# Reject an unknown single command with a command-qualified diagnostic.
set +e
output="$("${lifecycle_command}" restart 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'unknown command: restart' "${output}"
