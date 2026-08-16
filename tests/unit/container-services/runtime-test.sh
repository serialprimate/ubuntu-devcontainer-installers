#!/usr/bin/env bash
set -euo pipefail

# Verifies runtime identity helpers and component-qualified diagnostics without state changes.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
# shellcheck disable=SC1091
source "${repository_root}/installers/container-services/container-services"

# Match the current shell identity and reject a PID incarnation with another start time.
current_start_time="$(process_start_time "$$")"
[[ -n "${current_start_time}" ]]
process_is_live "$$" "${current_start_time}"
set +e
process_is_live "$$" 0
status=$?
set -e
if ((status == 0)); then
    fail 'accepted a mismatched process start time'
fi

# Preserve exact component-qualified stream routing through the private shared logger.
output="$(log_info container-services 'ready')"
assert_equal 'container-services: info: ready' "${output}"
output="$(log_error container-services 'not ready' 2>&1)"
assert_equal 'container-services: error: not ready' "${output}"

# Preserve literal operation values when building adapter invocations.
adapter_path="$(adapter_path_for service-a)"
assert_equal \
    '/usr/local/libexec/ubuntu-devcontainer-installers/services/service-a' \
    "${adapter_path}"

# Parse exact runtime state and reject duplicate or unsupported fields.
temporary_directory="$(mktemp -d '/tmp/ubuntu-devcontainer-installers.container-services-unit.XXXXXX')"
readonly temporary_directory
trap 'rm -rf -- "${temporary_directory}"' EXIT
stat() {
    case "$2" in
        %u) printf '%s\n' 0 ;;
        %a) printf '%s\n' 644 ;;
        *) return 1 ;;
    esac
}
valid_state="${temporary_directory}/valid-state"
printf 'pid=%s\nstart_time=%s\nstate=ready\n' "$$" "${current_start_time}" >"${valid_state}"
declare -A parsed_state=()
parse_state parsed_state "${valid_state}"
assert_equal "$$" "${parsed_state[pid]}"
assert_equal 'ready' "${parsed_state[state]}"
printf 'pid=1\npid=2\nstart_time=3\nstate=ready\n' >"${valid_state}"
set +e
parse_state parsed_state "${valid_state}"
status=$?
set -e
if ((status == 0)); then
    fail 'accepted duplicate runtime-state fields'
fi

# Preserve manifest order while rejecting duplicate declarations through pure injected trust checks.
path_is_root_directory() { return 0; }
adapter_is_trusted() { return 0; }
manifest_path_for_test="${temporary_directory}/services"
printf 'beta\nalpha\n' >"${manifest_path_for_test}"
declare -a parsed_adapters=()
read_manifest parsed_adapters "${manifest_path_for_test}"
assert_equal 'beta' "${parsed_adapters[0]##*/}"
assert_equal 'alpha' "${parsed_adapters[1]##*/}"
printf 'alpha\nalpha\n' >"${manifest_path_for_test}"
set +e
read_manifest parsed_adapters "${manifest_path_for_test}"
status=$?
set -e
if ((status == 0)); then
    fail 'accepted a duplicate service in the registration manifest'
fi
