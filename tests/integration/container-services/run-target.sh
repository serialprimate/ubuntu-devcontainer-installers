#!/usr/bin/env bash
set -euo pipefail

# Runs privileged runtime assertions for the container-services integration suite.

readonly image="$1"
readonly target="$2"
readonly source_label="$3"
readonly project_label="$4"
readonly run_label="$5"
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
temporary_directory="${repository_root}/tmp"
readonly temporary_directory
mkdir -p -- "${temporary_directory}"

if [[ "${target}" != 'runtime-success' && "${target}" != 'forced-termination' ]]; then
    exit 0
fi

readonly container_name="${image//[:\/]/-}-${target}"
event_log="$(mktemp "${temporary_directory}/container-services.XXXXXX")"
readonly event_log
wait_output="$(mktemp "${temporary_directory}/container-services-wait.XXXXXX")"
readonly wait_output

# Remove the labelled runtime container and temporary host files after every assertion path.
cleanup() {
    docker container rm --force --volumes -- "${container_name}" >/dev/null 2>&1 || true
    rm -f -- "${event_log}" "${wait_output}"
}
trap cleanup EXIT

if [[ "${target}" == 'forced-termination' ]]; then
    # Prove the outer runtime eventually forces a deliberately uncooperative adapter down.
    docker run --detach \
        --name "${container_name}" \
        --label "${source_label}" \
        --label "${project_label}" \
        --label "${run_label}" \
        "${image}" \
        container-services entrypoint -- sleep infinity >/dev/null
    timeout 8 docker stop --time 2 -- "${container_name}" >/dev/null 2>&1
    exit_code="$(docker container inspect --format '{{.State.ExitCode}}' "${container_name}")"
    [[ "${exit_code}" == '137' || "${exit_code}" == '143' ]]
    exit 0
fi

# Start the root entrypoint with a main command that remains alive for signal forwarding.
docker run --detach \
    --name "${container_name}" \
    --label "${source_label}" \
    --label "${project_label}" \
    --label "${run_label}" \
    "${image}" \
    container-services entrypoint -- sleep infinity >/dev/null

# Wait as the development user while startup is still allowed to be delayed.
wait_pid=''
docker exec --user dev "${container_name}" container-services wait >"${wait_output}" 2>&1 &
wait_pid=$!
sleep 1
if ! kill -0 "${wait_pid}" 2>/dev/null; then
    wait "${wait_pid}"
fi
wait "${wait_pid}"
wait_pid=''
grep -Fq 'container-services: info: all registered services are ready.' "${wait_output}"
if grep -Fq 'starting' "${wait_output}"; then
    exit 1
fi

docker exec --user dev "${container_name}" container-services status >/dev/null

# Stop the root entrypoint and verify declaration-order startup and reverse shutdown.
docker stop --time 10 -- "${container_name}" >/dev/null
# A stopped container remains available until explicit labelled cleanup below.
docker cp "${container_name}:/tmp/container-services-events" "${event_log}"
expected_events=$'start\nstart\nstart\nstatus\nstatus\nstatus\nstatus\nstatus\nstatus\nstop\nstop\nstop'
event_contents="$(<"${event_log}")"
[[ "${event_contents}" == "${expected_events}" ]]
