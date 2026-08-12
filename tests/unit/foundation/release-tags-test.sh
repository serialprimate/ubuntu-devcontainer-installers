#!/usr/bin/env bash
set -euo pipefail

# Verifies exact Semantic Versioning release-tag derivation and rejection boundaries.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# The repository-relative source is resolved dynamically like comparable tests.
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
readonly release_tags="${repository_root}/scripts/release-tags.sh"

# Derive exact, minor and major convenience tags in publication order.
output="$("${release_tags}" 0.1.0)"
assert_equal $'0.1.0\n0.1\n0' "${output}"
output="$("${release_tags}" 12.34.56)"
assert_equal $'12.34.56\n12.34\n12' "${output}"

# Reject aliases, prefixes, prereleases and numeric components with leading zeroes.
for invalid_tag in v0.1.0 0.1 0.1.0-rc.1 00.1.0 latest; do
    set +e
    output="$("${release_tags}" "${invalid_tag}" 2>&1)"
    status=$?
    set -e
    assert_equal 2 "${status}"
    assert_contains 'expected an exact SemVer tag without a v prefix' "${output}"
done
