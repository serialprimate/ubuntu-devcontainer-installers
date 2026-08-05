#!/usr/bin/env bash
set -euo pipefail

# Runs selected dependency-free unit suites and retains per-test failure logs.

# Initialise repository and run-scoped state
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
run_id="unit-$(date -u +%Y%m%d%H%M%S)-$$-${RANDOM}"
readonly run_id
readonly log_directory="/tmp/ubuntu-devcontainer-installers/${run_id}"
mkdir -p -- "${log_directory}"

# With no selector, discover every suite while preserving lexical glob order.
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

# Run every test independently so one failure does not hide later results.
passed=0
failed=0
for suite in "${selected_suites[@]}"; do
    suite_directory="${repository_root}/tests/unit/${suite}"
    if [[ ! -d "${suite_directory}" ]]; then
        printf 'unit: error: unknown unit test suite: %s\n' "${suite}" >&2
        exit 2
    fi

    test_files=()
    for test_file in "${suite_directory}"/*-test.sh; do
        if [[ -f "${test_file}" ]]; then
            test_files+=("${test_file}")
        fi
    done

    if ((${#test_files[@]} == 0)); then
        printf 'unit: error: no tests found in suite: %s\n' "${suite}" >&2
        exit 2
    fi

    for test_file in "${test_files[@]}"; do
        test_name="${suite}/${test_file##*/}"
        log_path="${log_directory}/${suite}-${test_file##*/}.log"
        if bash "${test_file}" >"${log_path}" 2>&1; then
            printf 'PASS unit %s\n' "${test_name}"
            ((passed += 1))
        else
            printf 'FAIL unit %s (log: %s)\n' "${test_name}" "${log_path}" >&2
            ((failed += 1))
        fi
    done
done

# Report the aggregate result after attempting every valid test
printf 'Unit tests: %d passed, %d failed\n' "${passed}" "${failed}"
if ((failed > 0)); then
    exit 1
fi
