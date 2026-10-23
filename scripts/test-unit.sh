#!/usr/bin/env bash
set -euo pipefail

# Runs selected dependency-free unit suites with bounded workers and per-test logs.

# Initialise repository and shared scheduling without requiring Docker
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
# shellcheck source=tests/lib/test-runner.sh
source "${repository_root}/tests/lib/test-runner.sh"
test_runner_init unit "${repository_root}"

# Discover suites in lexical order when the caller supplies no selectors
selected_suites=("$@")
if ((${#selected_suites[@]} == 0)); then
    for suite_path in "${repository_root}"/tests/unit/*; do
        if [[ -d "${suite_path}" ]]; then
            selected_suites+=("${suite_path##*/}")
        fi
    done
fi
if ((${#selected_suites[@]} == 0)); then
    printf 'unit: error: no unit test suites found\n' >&2
    exit 2
fi

# Validate the complete selection before starting any worker
for suite in "${selected_suites[@]}"; do
    suite_directory="${repository_root}/tests/unit/${suite}"
    if [[ ! "${suite}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ || ! -d "${suite_directory}" ]]; then
        printf 'unit: error: unknown unit test suite: %s\n' "${suite}" >&2
        exit 2
    fi
    test_count=0
    for test_file in "${suite_directory}"/*-test.sh; do
        if [[ -f "${test_file}" ]]; then
            test_runner_add "${suite}/${test_file##*/}" bash "${test_file}"
            ((test_count += 1))
        fi
    done
    if ((test_count == 0)); then
        printf 'unit: error: no tests found in suite: %s\n' "${suite}" >&2
        exit 2
    fi
done

# Report every result without a backend health command for dependency-free unit tests
# shellcheck disable=SC2119
test_runner_run
