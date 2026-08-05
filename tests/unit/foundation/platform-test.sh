#!/usr/bin/env bash
set -euo pipefail

# Verifies supported and rejected platforms through injected metadata and machine values.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
source "${repository_root}/tests/lib/assertions.sh"
source "${repository_root}/lib/common.sh"
source "${repository_root}/lib/platform.sh"

temporary_root="$(mktemp -d /tmp/ubuntu-devcontainer-installers.platform.XXXXXX)"
readonly temporary_root
trap 'rm -rf -- "${temporary_root}"' EXIT

# Accept supported Ubuntu metadata and the qualified architecture.
ubuntu_release="${temporary_root}/ubuntu"
printf 'NAME="Ubuntu"\nID=ubuntu\nVERSION_ID="26.04"\n' >"${ubuntu_release}"
require_supported_platform foundation "${ubuntu_release}" x86_64

# Reject another distribution using injected metadata instead of host state.
unsupported_release="${temporary_root}/unsupported"
printf "ID='debian'\nVERSION_ID='13'\n" >"${unsupported_release}"
set +e
output="$(require_supported_platform foundation "${unsupported_release}" x86_64 2>&1)"
status=$?
set -e
assert_equal '1' "${status}" 'require_supported_platform accepted Debian'
assert_contains 'requires Ubuntu 26.04; found debian 13' "${output}"

# Reject an architecture outside the initial linux/amd64 qualification.
set +e
output="$(require_supported_platform foundation "${ubuntu_release}" aarch64 2>&1)"
status=$?
set -e
assert_equal '1' "${status}" 'require_supported_platform accepted linux/arm64'
assert_contains 'requires linux/amd64; found aarch64' "${output}"

# Reject metadata that omits a field required for deterministic validation.
incomplete_release="${temporary_root}/incomplete"
printf 'ID=ubuntu\n' >"${incomplete_release}"
set +e
output="$(require_supported_platform foundation "${incomplete_release}" x86_64 2>&1)"
status=$?
set -e
assert_equal '1' "${status}" 'require_supported_platform accepted incomplete metadata'
assert_contains 'must define ID and VERSION_ID' "${output}"
