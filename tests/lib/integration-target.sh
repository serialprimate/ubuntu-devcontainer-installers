#!/usr/bin/env bash
set -euo pipefail

# Builds, exercises and removes one isolated integration target within a worker group.

# Bind the validated target and this run's resource ownership labels
readonly repository_root="$1" suite="$2" target="$3" image_tag="$4"
readonly source_label="$5" project_label="$6" run_label="$7"
readonly suite_directory="${repository_root}/tests/integration/${suite}"

# Usage: cleanup
# Description: Removes this target's tag on success, failure or a catchable interruption.
# Side Effects:
# - Removes only the image tag assigned to this worker
cleanup() {
    docker image rm --force -- "${image_tag}" >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Preserve independent cold builds and explicit candidate-only packaged scenarios
build_source_options=(--pull)
if [[ -n "${INSTALLER_IMAGE:-}" ]]; then
    build_source_options=(--build-arg "INSTALLER_IMAGE=${INSTALLER_IMAGE}")
fi
docker build "${build_source_options[@]}" \
    --no-cache --progress plain --platform linux/amd64 \
    --file "${suite_directory}/Dockerfile" --target "${target}" \
    --tag "${image_tag}" --label "${source_label}" --label "${project_label}" \
    --label "${run_label}" "${repository_root}"

# Keep runtime assertions and their cleanup within the same worker slot
if [[ -x "${suite_directory}/run-target.sh" ]]; then
    "${suite_directory}/run-target.sh" "${image_tag}" "${target}" \
        "${source_label}" "${project_label}" "${run_label}"
fi
