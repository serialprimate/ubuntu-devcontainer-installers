#!/usr/bin/env bash
set -euo pipefail

# Verifies container-services CLI boundaries and pure service-name behaviour.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
# shellcheck disable=SC1091
source "${repository_root}/installers/container-services/container-services"
readonly command_path="${repository_root}/installers/container-services/container-services"

# Report the stable help contract without inspecting runtime state.
output="$("${command_path}" --help)"
assert_contains 'register --service NAME' "${output}"
assert_contains 'entrypoint -- COMMAND' "${output}"
assert_contains '  5  Readiness or aggregate status failed.' "${output}"

# Reject missing, unknown, repeated-help and incomplete entrypoint operations as CLI misuse.
for arguments in '' '--help extra' 'restart' 'register' 'register --service' \
    'entrypoint' 'entrypoint --' 'wait extra' 'status extra'; do
    read -r -a argument_list <<<"${arguments}"
    set +e
    output="$("${command_path}" "${argument_list[@]}" 2>&1)"
    status=$?
    set -e
    assert_equal '2' "${status}" "accepted invalid CLI: ${arguments}"
done

# Accept valid names and reject traversal, empty values, uppercase and leading hyphens.
for name in docker-in-docker service-a a1 1-service; do
    service_name_is_valid "${name}"
done
for name in '' '../service' 'Service' '-service' 'service-' 'service/name' \
    'service_name' 'service--name'; do
    set +e
    service_name_is_valid "${name}"
    status=$?
    set -e
    if ((status == 0)); then
        fail "accepted invalid service name: ${name}"
    fi
done

# Construct only the fixed provider path and preserve complete declaration order.
adapter_path="$(adapter_path_for docker-in-docker)"
assert_equal \
    '/usr/local/libexec/ubuntu-devcontainer-installers/services/docker-in-docker' \
    "${adapter_path}"
manifest="$(manifest_content alpha beta)"
assert_equal $'alpha\nbeta' "${manifest}"
