#!/usr/bin/env bash
set -euo pipefail

# Runs privileged assertions required after building Docker-in-Docker lifecycle targets.

readonly image="$1"
readonly target="$2"
readonly source_label="$3"
readonly project_label="$4"
readonly run_label="$5"

# Leave build-only installation and failure targets unchanged
if [[ "${target}" != 'daemon-lifecycle-success' &&
    "${target}" != 'missing-data-volume-failure' ]]; then
    exit 0
fi

readonly container_name="${image//[:\/]/-}-runtime"
anonymous_volume=''

# Remove this exact runtime container and its anonymous volumes after interrupted assertions
cleanup() {
    docker container rm --force --volumes -- "${container_name}" >/dev/null 2>&1 || true
    if [[ -n "${anonymous_volume}" ]]; then
        docker volume rm --force -- "${anonymous_volume}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

if [[ "${target}" == 'missing-data-volume-failure' ]]; then

    # Prove startup rejects outer containers without the required dedicated data mount
    docker run --rm --privileged \
        --name "${container_name}" \
        --label "${source_label}" \
        --label "${project_label}" \
        --label "${run_label}" \
        "${image}" \
        bash -euo pipefail -c '
            output="$(docker-in-docker start 2>&1)" && exit 1
            [[ "${output}" == *"--rm --mount type=volume"* ]]
            test ! -S /var/run/docker.sock
        '
    exit 0
fi

# Create a disposable runtime container whose unnamed data volume is tied to --rm
container_id="$(docker run --rm --privileged --detach \
    --name "${container_name}" \
    --label "${source_label}" \
    --label "${project_label}" \
    --label "${run_label}" \
    --mount type=volume,destination=/var/lib/docker-in-docker \
    "${image}" sleep infinity)"
readonly container_id
anonymous_volume="$(docker container inspect --format \
    '{{range .Mounts}}{{if eq .Destination "/var/lib/docker-in-docker"}}{{.Name}}{{end}}{{end}}' \
    "${container_id}")"
readonly anonymous_volume
[[ -n "${anonymous_volume}" ]]

# Start Docker with the default copy-on-write storage backend and verify root lifecycle control
docker exec "${container_id}" bash -euo pipefail -c '
    if docker-in-docker status; then
        exit 1
    fi
    mountpoint --quiet /var/lib/docker-in-docker
    docker-in-docker start
    docker-in-docker status
    /usr/local/libexec/ubuntu-devcontainer-installers/services/docker-in-docker status
    docker info
    test "$(docker info --format "{{.Driver}}")" != vfs
    test -S /var/run/docker.sock
    useradd --create-home --shell /bin/bash --groups docker dev
'

# Verify read-only lifecycle and adapter status work for a development user without root authority
docker exec --user dev "${container_id}" bash -euo pipefail -c '
    docker-in-docker status
    /usr/local/libexec/ubuntu-devcontainer-installers/services/docker-in-docker status
    docker info
'

# Stop the managed daemon and verify its owned socket is removed
docker exec "${container_id}" bash -euo pipefail -c '
    docker-in-docker stop
    if docker-in-docker status; then
        exit 1
    fi
    test ! -S /var/run/docker.sock
'

# Exercise automatic startup, stale-state invalidation and reverse adapter shutdown.
docker exec "${container_id}" bash -euo pipefail -c '
    container-services register --service docker-in-docker
    install --directory --owner=root --group=root --mode=0755 \
        /run/ubuntu-devcontainer-installers/container-services
    printf "pid=999999\\nstart_time=0\\nstate=stopped\\n" \
        >/run/ubuntu-devcontainer-installers/container-services/state
    chmod 0644 /run/ubuntu-devcontainer-installers/container-services/state
    chown root:root /run/ubuntu-devcontainer-installers/container-services/state
    container-services entrypoint -- docker info >/dev/null
    test ! -S /var/run/docker.sock
'

# Stop the --rm container and prove Docker automatically removes its anonymous volume
docker container stop --time 30 -- "${container_id}" >/dev/null
for _ in {1..30}; do
    if ! docker container inspect "${container_id}" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
if docker container inspect "${container_id}" >/dev/null 2>&1; then
    exit 1
fi
if docker volume inspect "${anonymous_volume}" >/dev/null 2>&1; then
    exit 1
fi
