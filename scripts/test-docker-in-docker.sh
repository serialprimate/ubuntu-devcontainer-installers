#!/usr/bin/env bash
set -euo pipefail

# Runs the complete project suite through a freshly installed nested Docker daemon.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
# shellcheck source=tests/lib/test-runner.sh
source "${repository_root}/tests/lib/test-runner.sh"
test_runner_validate_jobs docker-in-docker
readonly project_label='io.github.serialprimate.project=ubuntu-devcontainer-installers'
readonly source_label='org.opencontainers.image.source=https://github.com/serialprimate/ubuntu-devcontainer-installers'
run_id="dind-qualification-$(date -u +%Y%m%d%H%M%S)-$$-${RANDOM}"
readonly run_id
readonly run_label="io.github.serialprimate.test-run=${run_id}"
readonly image="ubuntu-devcontainer-installers-test:${run_id}"
readonly container="ubuntu-devcontainer-installers-${run_id}"
readonly temporary_directory="${repository_root}/tmp"
readonly log_directory="${temporary_directory}/${run_id}"
readonly log_path="${log_directory}/qualification.log"
readonly work_directory="${log_directory}/work"
test_uid="$(id -u)"
test_gid="$(id -g)"

# Keep the coordinator non-root even when qualification is launched by root
if [[ "${test_uid}" == '0' ]]; then
    test_uid=1000
    test_gid=1000
fi
readonly test_uid test_gid
mkdir -p -- "${work_directory}"

# Remove only this run's disposable outer resources on every exit path
cleanup() {
    docker container rm --force --volumes -- "${container}" >/dev/null 2>&1 || true
    docker image rm --force -- "${image}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Build the installed qualification environment from the ordinary integration Dockerfile
printf 'Docker-in-Docker qualification: building environment (log: %s)\n' "${log_path}"
if ! docker build \
    --pull \
    --no-cache \
    --platform linux/amd64 \
    --file "${repository_root}/tests/integration/docker-in-docker/Dockerfile" \
    --target qualification-environment \
    --tag "${image}" \
    --label "${source_label}" \
    --label "${project_label}" \
    --label "${run_label}" \
    "${repository_root}" >"${log_path}" 2>&1; then
    printf 'docker-in-docker qualification: error: image build failed (log: %s)\n' \
        "${log_path}" >&2
    tail -n 40 -- "${log_path}" | while IFS= read -r line; do
        printf '  | %s\n' "${line}"
    done
    exit 1
fi

# Keep source read-only and confine nested test writes to this run's workspace
# Start the installed daemon, run every project test through it and stop it explicitly
if ! docker run --rm --privileged \
    --name "${container}" \
    --label "${source_label}" \
    --label "${project_label}" \
    --label "${run_label}" \
    --mount "type=bind,source=${repository_root},target=/source,readonly" \
    --mount "type=bind,source=${work_directory},target=/source/tmp" \
    --mount type=volume,destination=/var/lib/docker-in-docker \
    --workdir /source \
    --env DIND_QUALIFICATION_ACTIVE=1 \
    --env "TEST_JOBS=${TEST_JOBS:-1}" \
    --env "QUALIFICATION_UID=${test_uid}" \
    --env "QUALIFICATION_GID=${test_gid}" \
    "${image}" \
    bash -euo pipefail -c '
        cleanup_daemon() {
            docker-in-docker stop >/dev/null 2>&1 || true
        }
        trap cleanup_daemon EXIT
        # Bootstrap independently of the user installer being qualified
        # Duplicate numeric IDs accommodate accounts already present in the base image
        groupadd --non-unique --gid "${QUALIFICATION_GID}" qualification
        useradd --non-unique --uid "${QUALIFICATION_UID}" --gid qualification \
            --groups docker --create-home --shell /bin/bash qualification
        chown qualification:qualification /source/tmp
        runuser --user qualification -- git config --global --add safe.directory /source

        # Keep daemon authority with root and run the coordinator without sudo
        docker-in-docker start
        runuser --user qualification -- ./scripts/test.sh
        docker-in-docker stop
        trap - EXIT
    ' 2>&1 | tee -a "${log_path}" | while IFS= read -r line; do
    printf 'nested | %s\n' "${line}"
done; then
    printf 'docker-in-docker qualification: error: complete nested suite failed (log: %s)\n' \
        "${log_path}" >&2
    exit 1
fi

printf 'PASS Docker-in-Docker complete-suite qualification\n'
