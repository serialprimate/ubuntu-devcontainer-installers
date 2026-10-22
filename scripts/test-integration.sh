#!/usr/bin/env bash
set -euo pipefail

# Builds selected integration targets with bounded workers and independent cold state.

# Initialise repository, qualification and run-scoped scheduling
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
readonly project_label='io.github.serialprimate.project=ubuntu-devcontainer-installers'
readonly source_label='org.opencontainers.image.source=https://github.com/serialprimate/ubuntu-devcontainer-installers'
readonly ubuntu_image='ubuntu:26.04'
# shellcheck source=tests/lib/test-runner.sh
source "${repository_root}/tests/lib/test-runner.sh"
test_runner_init integration "${repository_root}"
run_id="${runner_log_directory##*/}"
readonly run_id
readonly run_label="io.github.serialprimate.test-run=${run_id}"

# Validate selectors and discover the complete plan before contacting Docker
if (($# > 2)); then
    printf 'Usage: %s [SUITE [TARGET]]\n' "${0##*/}" >&2
    exit 2
fi
suites=()
if (($# >= 1)); then
    suites=("$1")
else
    for suite_path in "${repository_root}"/tests/integration/*; do
        suite_name="${suite_path##*/}"
        if [[ -d "${suite_path}" &&
            ("${suite_name}" != 'packaged-artefact' || -n "${INSTALLER_IMAGE:-}") ]]; then
            suites+=("${suite_name}")
        fi
    done
fi
if [[ "${suites[0]:-}" == 'packaged-artefact' && -z "${INSTALLER_IMAGE:-}" ]]; then
    printf 'integration: error: packaged-artefact requires INSTALLER_IMAGE. Use scripts/test-oci.sh.\n' >&2
    exit 2
fi
for suite in "${suites[@]}"; do
    suite_directory="${repository_root}/tests/integration/${suite}"
    if [[ ! "${suite}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ||
        ! -f "${suite_directory}/Dockerfile" || ! -f "${suite_directory}/targets.txt" ]]; then
        printf 'integration: error: unknown or incomplete integration suite: %s\n' "${suite}" >&2
        exit 2
    fi
    targets=()
    while IFS= read -r target || [[ -n "${target}" ]]; do
        if [[ -z "${target}" ]]; then
            continue
        fi
        if [[ ! "${target}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
            printf 'integration: error: invalid target in %s: %s\n' "${suite}" "${target}" >&2
            exit 2
        fi
        if (($# < 2)) || [[ "${target}" == "$2" ]]; then
            targets+=("${target}")
        fi
    done <"${suite_directory}/targets.txt"
    if ((${#targets[@]} == 0)); then
        printf 'integration: error: no matching targets for suite: %s\n' "${suite}" >&2
        exit 2
    fi
    for target in "${targets[@]}"; do
        image_tag="ubuntu-devcontainer-installers-test:${run_id}-${suite}-${target}"
        test_runner_add "${suite}/${target}" bash "${repository_root}/tests/lib/integration-target.sh" \
            "${repository_root}" "${suite}" "${target}" "${image_tag}" \
            "${source_label}" "${project_label}" "${run_label}"
    done
done
if ((${#runner_names[@]} == 0)); then
    printf 'integration: error: no integration targets found\n' >&2
    exit 2
fi

# Validate Docker and report the exact moving Ubuntu image before starting workers
if ! command -v docker >/dev/null 2>&1; then
    printf 'integration: error: required command not found: docker\n' >&2
    exit 2
fi
prerequisite_log="${runner_log_directory}/docker-prerequisite.log"
if ! docker info >"${prerequisite_log}" 2>&1; then
    printf 'integration: error: docker info failed; verify the Docker daemon (log: %s)\n' \
        "${prerequisite_log}" >&2
    exit 2
fi
pull_log="${runner_log_directory}/ubuntu-image.log"
if ! docker pull --platform linux/amd64 "${ubuntu_image}" >"${pull_log}" 2>&1; then
    printf 'integration: error: cannot pull %s (log: %s)\n' "${ubuntu_image}" "${pull_log}" >&2
    exit 1
fi
ubuntu_digest="$(docker image inspect --format '{{join .RepoDigests ","}}' "${ubuntu_image}")"
printf 'Ubuntu qualification image: %s (%s)\n' "${ubuntu_image}" "${ubuntu_digest}"

# Preserve assertion failures but stop queueing work if the Docker endpoint disappears
test_runner_run timeout 10 docker info
