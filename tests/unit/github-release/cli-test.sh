#!/usr/bin/env bash
set -euo pipefail

# Verifies GitHub Release source, digest and destination validation without network access.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# Resolve project-owned assertions from the repository root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
readonly installer="${repository_root}/installers/github-release/install.sh"
readonly digest='823a86dfd06734fee84371e9b9c08a89dbad7691fbf43dad217a9c5658827fa0'

# Describe the exact required selectors and integrity control without requiring prerequisites.
output="$("${installer}" --help)"
assert_contains '--repository OWNER/REPOSITORY' "${output}"
assert_contains '--release-tag TAG' "${output}"
assert_contains '--asset-name NAME' "${output}"
assert_contains '--sha256 DIGEST' "${output}"
assert_contains '--install-path PATH' "${output}"

# Reject every omitted required selector before execution-context checks.
for option in --repository --release-tag --asset-name --sha256 --install-path; do
    arguments=(
        --repository brave/brave-search-cli
        --release-tag v1.5.0
        --asset-name bx-1.5.0-linux-amd64
        --sha256 "${digest}"
        --install-path /usr/local/bin/bx
    )
    filtered=()
    for ((index = 0; index < ${#arguments[@]}; index += 2)); do
        if [[ "${arguments[index]}" != "${option}" ]]; then
            filtered+=("${arguments[index]}" "${arguments[index + 1]}")
        fi
    done
    set +e
    output="$("${installer}" "${filtered[@]}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains "required option not provided: ${option}" "${output}"
done

# Reject mutable, path-like and malformed source selectors.
for invalid_tag in latest '../v1' 'release/v1'; do
    set +e
    output="$("${installer}" --repository brave/brave-search-cli --release-tag "${invalid_tag}" \
        --asset-name bx --sha256 "${digest}" --install-path /usr/local/bin/bx 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains 'invalid release tag' "${output}"
done

for invalid_asset in '../bx' 'linux/bx' '-bx'; do
    set +e
    output="$("${installer}" --repository brave/brave-search-cli --release-tag v1.5.0 \
        --asset-name "${invalid_asset}" --sha256 "${digest}" \
        --install-path /usr/local/bin/bx 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains 'invalid asset name' "${output}"
done

# Reject invalid repository, digest and destination forms before requiring root or curl.
set +e
output="$("${installer}" --repository brave --release-tag v1 --asset-name bx \
    --sha256 "${digest}" --install-path /usr/local/bin/bx 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'invalid repository' "${output}"

for invalid_digest in abc "${digest}00"; do
    set +e
    output="$("${installer}" --repository brave/brave-search-cli --release-tag v1 \
        --asset-name bx --sha256 "${invalid_digest}" --install-path /usr/local/bin/bx 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains 'invalid SHA-256 digest' "${output}"
done

set +e
output="$("${installer}" --repository brave/brave-search-cli --release-tag v1 \
    --asset-name bx --sha256 "${digest}" --install-path relative/bx 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'invalid install path' "${output}"

# Reject duplicate scalar and unknown options consistently.
set +e
output="$("${installer}" --repository one/repo --repository two/repo 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'option may be specified only once: --repository' "${output}"

set +e
output="$("${installer}" --unknown 2>&1)"
status=$?
set -e
assert_equal '1' "${status}"
assert_contains 'unknown option: --unknown' "${output}"
