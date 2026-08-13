#!/usr/bin/env bash
set -euo pipefail

# Removes only Docker resources carrying the repository's project label.

readonly project_label='io.github.serialprimate.project=ubuntu-devcontainer-installers'

# Validate Docker before querying or removing resources
if ! command -v docker >/dev/null 2>&1; then
    printf 'cleanup: error: required command not found: docker\n' >&2
    exit 2
fi

if ! docker info >/dev/null 2>&1; then
    printf 'cleanup: error: docker info failed; verify the Docker daemon\n' >&2
    exit 2
fi

# Usage: remove_resources <resource_type> <query_command> [query_argument ...]
# Description:
# - Remove resources of one Docker type after a project-labelled query
# - Write results to standard output and query errors to standard error
# Side Effects:
# - Force-removes only the resource IDs returned by the project-labelled query
# - Removes anonymous volumes attached to matching containers
# Returns: Non-zero when listing or removal fails.
remove_resources() {
    local resource_type="$1"
    shift
    local query_output
    local resource_id
    local resource_ids=()
    local -A seen_ids=()
    local -a removal_options=(--force)

    if ! query_output="$("$@")"; then
        printf 'cleanup: error: cannot list project-labelled %s resources\n' \
            "${resource_type}" >&2
        return 1
    fi

    while IFS= read -r resource_id; do
        if [[ -n "${resource_id}" && ! -v "seen_ids[${resource_id}]" ]]; then
            resource_ids+=("${resource_id}")
            seen_ids["${resource_id}"]=1
        fi
    done <<<"${query_output}"

    if ((${#resource_ids[@]} == 0)); then
        printf 'cleanup: %s: no project-labelled resources\n' "${resource_type}"
        return
    fi

    if [[ "${resource_type}" == 'container' ]]; then
        removal_options+=(--volumes)
    fi
    docker "${resource_type}" rm "${removal_options[@]}" -- "${resource_ids[@]}" >/dev/null
    printf 'cleanup: %s: removed %d project-labelled resources\n' \
        "${resource_type}" "${#resource_ids[@]}"
}

# Remove each supported resource type through a project-labelled query
remove_resources container docker container ls --all --quiet --filter "label=${project_label}"
remove_resources network docker network ls --quiet --filter "label=${project_label}"
remove_resources volume docker volume ls --quiet --filter "label=${project_label}"
remove_resources image docker image ls --quiet --filter "label=${project_label}"
