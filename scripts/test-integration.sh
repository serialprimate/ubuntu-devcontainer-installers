#!/usr/bin/env bash
set -euo pipefail

# Builds selected integration targets in isolated Ubuntu 26.04 stages.

# Initialise repository, qualification and run-scoped state
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
readonly project_label='io.github.serialprimate.project=ubuntu-devcontainer-installers'
readonly source_label='org.opencontainers.image.source=https://github.com/serialprimate/ubuntu-devcontainer-installers'
readonly ubuntu_image='ubuntu:26.04'
run_id="integration-$(date -u +%Y%m%d%H%M%S)-$$-${RANDOM}"
readonly run_id
readonly run_label="io.github.serialprimate.test-run=${run_id}"
readonly log_directory="/tmp/ubuntu-devcontainer-installers/${run_id}"
mkdir -p -- "${log_directory}"

# Validate selector shape before external operations
if (($# > 2)); then
    printf 'Usage: %s [SUITE [TARGET]]\n' "${0##*/}" >&2
    exit 2
fi

# Validate the local Docker endpoint before pulling images or creating resources.
if ! command -v docker >/dev/null 2>&1; then
    printf 'integration: error: required command not found: docker\n' >&2
    exit 2
fi

prerequisite_log="${log_directory}/docker-prerequisite.log"
if ! docker info >"${prerequisite_log}" 2>&1; then
    printf 'integration: error: docker info failed; verify the Docker daemon (log: %s)\n' \
        "${prerequisite_log}" >&2
    exit 2
fi

# Pull explicitly so the runner can report the exact moving base-image digest.
pull_log="${log_directory}/ubuntu-image.log"
if ! docker pull --platform linux/amd64 "${ubuntu_image}" >"${pull_log}" 2>&1; then
    printf 'integration: error: cannot pull %s (log: %s)\n' \
        "${ubuntu_image}" "${pull_log}" >&2
    exit 1
fi
ubuntu_digest="$(docker image inspect --format '{{join .RepoDigests ","}}' "${ubuntu_image}")"
printf 'Ubuntu qualification image: %s (%s)\n' "${ubuntu_image}" "${ubuntu_digest}"

# Discover all integration suites unless the caller selected one explicitly.
if (($# >= 1)); then
    suites=("$1")
else
    suites=()
    for suite_path in "${repository_root}"/tests/integration/*; do
        if [[ -d "${suite_path}" ]]; then
            suites+=("${suite_path##*/}")
        fi
    done
fi

# Validate each suite and run every selected target independently
passed=0
failed=0
for suite in "${suites[@]}"; do
    suite_directory="${repository_root}/tests/integration/${suite}"
    dockerfile="${suite_directory}/Dockerfile"
    target_file="${suite_directory}/targets.txt"
    if [[ ! -f "${dockerfile}" || ! -f "${target_file}" ]]; then
        printf 'integration: error: unknown or incomplete integration suite: %s\n' \
            "${suite}" >&2
        exit 2
    fi

    if (($# == 2)); then
        targets=("$2")
        if ! grep -Fxq -- "$2" "${target_file}"; then
            printf 'integration: error: unknown target for %s: %s\n' "${suite}" "$2" >&2
            exit 2
        fi
    else
        targets=()
        while IFS= read -r target || [[ -n "${target}" ]]; do
            if [[ -n "${target}" ]]; then
                targets+=("${target}")
            fi
        done <"${target_file}"
    fi

    if ((${#targets[@]} == 0)); then
        printf 'integration: error: no targets declared for suite: %s\n' "${suite}" >&2
        exit 2
    fi

    for target in "${targets[@]}"; do

        # Unique tags and labels isolate concurrent runs and bound routine cleanup.
        image_tag="ubuntu-devcontainer-installers-test:${run_id}-${suite}-${target}"
        log_path="${log_directory}/${suite}-${target}.log"
        if docker build \
            --pull \
            --no-cache \
            --platform linux/amd64 \
            --file "${dockerfile}" \
            --target "${target}" \
            --tag "${image_tag}" \
            --label "${source_label}" \
            --label "${project_label}" \
            --label "${run_label}" \
            "${repository_root}" >"${log_path}" 2>&1; then
            printf 'PASS integration %s/%s\n' "${suite}" "${target}"
            ((passed += 1))
        else
            printf 'FAIL integration %s/%s (log: %s)\n' \
                "${suite}" "${target}" "${log_path}" >&2
            ((failed += 1))
        fi

        # A failed build may not create the tag, so cleanup must tolerate absence.
        docker image rm --force -- "${image_tag}" >/dev/null 2>&1 || true
    done
done

# Report the aggregate result after attempting every valid target
printf 'Integration tests: %d passed, %d failed\n' "${passed}" "${failed}"
if ((failed > 0)); then
    exit 1
fi
