#!/usr/bin/env bash
set -euo pipefail

# Checks the reviewed Ubuntu package state without requiring Node.js or any browser download.

# Verify every package in the independent reviewed expectation snapshot
script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly script_directory
while IFS= read -r package; do
    status="$(dpkg-query --show --showformat='${db:Status-Abbrev}' "${package}")"
    [[ "${status}" == 'ii ' ]]
done <"${script_directory}/expected-packages.txt"

# Verify complete APT cleanup and absence of unrelated JavaScript tools or browser caches
apt_lists="$(ls -A /var/lib/apt/lists)"
[[ -z "${apt_lists}" ]]
if command -v node >/dev/null || command -v npm >/dev/null || command -v playwright >/dev/null; then
    printf 'Unexpected JavaScript toolchain or Playwright command\n' >&2
    exit 1
fi
[[ ! -e /ms-playwright && ! -e /root/.cache/ms-playwright ]]
printf 'PASS reviewed Chromium packages, APT cleanup and dependency-only boundary\n'
