#!/usr/bin/env bash
set -euo pipefail

# Verifies exact target selection and early CLI failures without changing operating-system state.

# Resolve the installer and project-owned assertions
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
readonly installer="${repository_root}/installers/playwright-deps/install.sh"

# Check help without requiring root, a supported host or APT access
output="$("${installer}" --help)"
assert_contains 'default: 1.64.1' "${output}"
assert_contains 'Supported Playwright versions: 1.64.0, 1.64.1' "${output}"
assert_contains 'not Node.js, npm packages or browsers' "${output}"

# Reject malformed versions, including empty values, before root or platform checks
# shellcheck disable=SC2016
for version in '' latest lts 1 1.64 01.64.1 1.064.1 1.64.01 '^1.64.1' '1.64.*' \
    '1.64.1-alpha.1' '1.64.1+build' '--help' '1.64.1 1.64.2' '$(touch unexpected)'; do
    set +e
    output="$("${installer}" --playwright-version "${version}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains 'playwright-deps: error: invalid Playwright version:' "${output}"
done

# Report well-formed but unsupported targets with the exact supported-version list
for version in 0.0.0 1.63.0 1.64.2 2.0.0 999999999999999999999.0.0; do
    set +e
    output="$("${installer}" --playwright-version "${version}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains "unsupported Playwright version: ${version}; supported versions: 1.64.0, 1.64.1" "${output}"
done

# Reject missing values, repeated selectors, unknown options and positional arguments
for arguments in '--playwright-version' '--playwright-version 1.64.0 --playwright-version 1.64.0' \
    '--version' '--browser chromium' '--playwright-version=1.64.1' '1.64.1'; do
    read -r -a argument_list <<<"${arguments}"
    set +e
    output="$("${installer}" "${argument_list[@]}" 2>&1)"
    status=$?
    set -e
    assert_equal '1' "${status}"
    assert_contains 'playwright-deps: error:' "${output}"
done

# Isolate copied bundled libraries so successful selection never calls the host package manager
mkdir -p -- "${repository_root}/tmp"
workspace="$(mktemp -d "${repository_root}/tmp/playwright-deps-unit.XXXXXX")"
readonly workspace
trap 'rm -rf -- "${workspace}"' EXIT
mkdir -p -- "${workspace}/installers/playwright-deps" "${workspace}/lib"
cp -- "${installer}" "${workspace}/installers/playwright-deps/install.sh"
cp -- "${repository_root}/lib/arguments.sh" "${workspace}/lib/arguments.sh"
# shellcheck disable=SC2016
printf 'source %q\nrequire_root() { printf "root\\n" >>"$TRACE"; }\n' \
    "${repository_root}/lib/common.sh" >"${workspace}/lib/common.sh"
# shellcheck disable=SC2016
printf 'require_supported_platform() { printf "platform\\n" >>"$TRACE"; }\n' \
    >"${workspace}/lib/platform.sh"
# shellcheck disable=SC2016
printf 'apt_install_packages() { shift; printf "apt\\n" >>"$TRACE"; printf "%%s\\n" "$@" >"$PACKAGES"; }\n' \
    >"${workspace}/lib/apt.sh"
export TRACE="${workspace}/trace" PACKAGES="${workspace}/packages"
readonly copied_installer="${workspace}/installers/playwright-deps/install.sh"

# Resolve the release-fixed default to the reviewed non-empty profile
output="$(cd / && "${copied_installer}")"
assert_contains 'Chromium dependencies for Playwright 1.64.1' "${output}"
assert_equal $'root\nplatform\napt' "$(<"${TRACE}")"
package_count="$(wc -l <"${PACKAGES}" | tr -d ' ')"
unique_count="$(sort -u "${PACKAGES}" | wc -l | tr -d ' ')"
assert_equal '33' "${package_count}"
assert_equal '33' "${unique_count}"
cp -- "${PACKAGES}" "${workspace}/default-packages"

# Both explicit versions share the reviewed profile without silently changing the selected target
for version in 1.64.0 1.64.1; do
    : >"${TRACE}"
    output="$(cd / && "${copied_installer}" --playwright-version "${version}")"
    assert_contains "Chromium dependencies for Playwright ${version}" "${output}"
    cmp -- "${workspace}/default-packages" "${PACKAGES}"
    assert_equal $'root\nplatform\napt' "$(<"${TRACE}")"
done

# Invalid selection and help never reach privilege checks or package installation
: >"${TRACE}"
set +e
"${copied_installer}" --playwright-version 1.64.2 >"${workspace}/failure" 2>&1
status=$?
set -e
assert_equal '1' "${status}"
"${copied_installer}" --help >/dev/null
assert_file_empty "${TRACE}"
