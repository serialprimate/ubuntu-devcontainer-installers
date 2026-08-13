#!/usr/bin/env bash
set -euo pipefail

# Runs the complete project suite through a freshly installed nested Docker daemon.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
readonly project_label='io.github.serialprimate.project=ubuntu-devcontainer-installers'
readonly source_label='org.opencontainers.image.source=https://github.com/serialprimate/ubuntu-devcontainer-installers'
run_id="dind-qualification-$(date -u +%Y%m%d%H%M%S)-$$-${RANDOM}"
readonly run_id
readonly run_label="io.github.serialprimate.test-run=${run_id}"
readonly image="ubuntu-devcontainer-installers-test:${run_id}"
readonly container="ubuntu-devcontainer-installers-${run_id}"
readonly log_directory="/tmp/ubuntu-devcontainer-installers/${run_id}"
readonly log_path="${log_directory}/qualification.log"
mkdir -p -- "${log_directory}"

# Remove only this run's disposable outer resources on every exit path
cleanup() {
    docker container rm --force --volumes -- "${container}" >/dev/null 2>&1 || true
    docker image rm --force -- "${image}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Build the installed qualification environment from the ordinary integration Dockerfile
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
    exit 1
fi

# Start the installed daemon, run every project test through it and stop it explicitly
if ! docker run --rm --privileged \
    --name "${container}" \
    --label "${source_label}" \
    --label "${project_label}" \
    --label "${run_label}" \
    --mount "type=bind,source=${repository_root},target=/source" \
    --mount "type=bind,source=${log_directory},target=/tmp/ubuntu-devcontainer-installers" \
    --mount type=volume,destination=/var/lib/docker-in-docker \
    --workdir /source \
    --env DIND_QUALIFICATION_ACTIVE=1 \
    "${image}" \
    bash -euo pipefail -c '
        cleanup_daemon() {
            docker-in-docker stop >/dev/null 2>&1 || true
        }
        trap cleanup_daemon EXIT
        git config --global --add safe.directory /source
        docker-in-docker start
        ./scripts/test.sh
        docker-in-docker stop
        trap - EXIT
    ' >>"${log_path}" 2>&1; then
    printf 'docker-in-docker qualification: error: complete nested suite failed (log: %s)\n' \
        "${log_path}" >&2
    exit 1
fi

printf 'PASS Docker-in-Docker complete-suite qualification\n'
