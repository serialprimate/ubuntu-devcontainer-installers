#!/usr/bin/env bash

# Provides bounded test scheduling without changing the sourcing shell's options or traps.

# Usage: test_runner_validate_jobs <level>
# Description: Rejects invalid TEST_JOBS before a runner performs external operations.
# Returns: 0 for valid concurrency, 2 for invalid concurrency
test_runner_validate_jobs() {
    if [[ ! "${TEST_JOBS:-1}" =~ ^([1-9]|[12][0-9]|3[0-2])$ ]]; then
        printf '%s: error: TEST_JOBS must be an integer from 1 to 32\n' "$1" >&2
        return 2
    fi
}

# Usage: test_runner_init <level> <repository_root>
# Description: Validates concurrency and creates run-local scheduler state and logs.
# Side Effects:
# - Sets runner variables and creates a unique log directory under repository tmp
# Returns: 2 for invalid concurrency, non-zero when log creation fails
test_runner_init() {
    runner_level="$1"
    runner_jobs="${TEST_JOBS:-1}"
    test_runner_validate_jobs "${runner_level}" || return
    if ! command -v setsid >/dev/null 2>&1; then
        printf '%s: error: required command not found: setsid; use the development container\n' \
            "${runner_level}" >&2
        return 2
    fi
    mkdir -p -- "$2/tmp" || return
    runner_log_directory="$(mktemp -d "$2/tmp/${runner_level}.XXXXXXXX")" || return
    runner_names=()
    runner_logs=()
    runner_commands=()
}

# Usage: test_runner_add <name> <command> [argument...]
# Description: Queues one literal command in discovery order without evaluating shell text.
# Side Effects:
# - Adds a test name, log path and argument-array variable to scheduler state
test_runner_add() {
    local name="$1" index="${#runner_names[@]}"
    shift
    runner_names+=("${name}")
    runner_logs+=("${runner_log_directory}/${index}-${name//\//-}.log")
    runner_commands+=("runner_command_${index}")
    declare -ga "runner_command_${index}"
    local -n command_arguments="runner_command_${index}"
    # The nameref fills the indexed command array consumed by test_runner_run
    # shellcheck disable=SC2034
    command_arguments=("$@")
}

# Usage: test_runner_cancel
# Description: Terminates and reaps active worker process groups after interruption.
# Side Effects:
# - Signals only this runner's active workers and their descendants
test_runner_cancel() {
    local pid
    trap '' INT TERM
    for pid in "${!runner_active[@]}"; do
        kill -TERM -- "-${pid}" 2>/dev/null || true
    done
    # Bound shutdown even when a test ignores TERM; descendants share the worker group
    sleep 2
    for pid in "${!runner_active[@]}"; do
        kill -KILL -- "-${pid}" 2>/dev/null || true
        wait "${pid}" || true
    done
    printf '%s: interrupted; logs: %s\n' "${runner_level}" "${runner_log_directory}" >&2
}

# Usage: test_runner_run [health_command [argument...]]
# Description:
# - Runs queued commands and serialises start lines, completion lines, failure tails and totals
# - After a test failure, an optional health command decides whether to stop scheduling
# - Drains active workers after infrastructure loss and reports unstarted tests as aborted
# Side Effects:
# - Starts isolated process groups, writes logs and owns INT/TERM traps until completion
# - Callers must not install competing INT/TERM traps
# Returns: 0 when all tests pass, 1 for failures or aborted tests, 130 or 143 after interruption
test_runner_run() {
    local next=0 completed=0 passed=0 failed=0 aborted=0 pid index status elapsed tail_output
    local total="${#runner_names[@]}" started="${SECONDS}"
    local -A runner_active=() runner_started=()
    printf '%s: %d tests, %d workers (logs: %s)\n' \
        "${runner_level}" "${total}" "${runner_jobs}" "${runner_log_directory}"
    trap 'test_runner_cancel; exit 130' INT
    trap 'test_runner_cancel; exit 143' TERM

    while ((next < total || ${#runner_active[@]} > 0)); do
        # Keep at most the requested number of complete test lifecycles in flight
        while ((next < total && ${#runner_active[@]} < runner_jobs)); do
            local -n worker_arguments="${runner_commands[next]}"
            setsid "${worker_arguments[@]}" >"${runner_logs[next]}" 2>&1 &
            pid=$!
            runner_active[${pid}]="${next}"
            runner_started[${pid}]="${SECONDS}"
            ((next += 1))
            printf 'START %s %s (pid %d; active %d/%d) [%d/%d launched]\n' \
                "${runner_level}" "${runner_names[next - 1]}" "${pid}" \
                "${#runner_active[@]}" "${runner_jobs}" "${next}" "${total}"
        done

        # Explicitly collect each worker status rather than relying on errexit
        status=0
        wait -n -p pid "${!runner_active[@]}" || status=$?
        index="${runner_active[${pid}]}"
        elapsed=$((SECONDS - runner_started[${pid}]))
        unset 'runner_active['"${pid}"']' 'runner_started['"${pid}"']'
        ((completed += 1))
        if ((status == 0)); then
            ((passed += 1))
            printf 'PASS %s %s (%ds) [%d/%d]\n' \
                "${runner_level}" "${runner_names[index]}" "${elapsed}" "${completed}" "${total}"
        else
            ((failed += 1))
            printf 'FAIL %s %s (%ds, exit %d) [%d/%d] (log: %s)\n' \
                "${runner_level}" "${runner_names[index]}" "${elapsed}" "${status}" \
                "${completed}" "${total}" "${runner_logs[index]}"
            # Prefix retained diagnostics so test output cannot become CI workflow commands
            tail_output="$(tail -n 40 -- "${runner_logs[index]}")"
            while IFS= read -r line; do
                printf '  | %s\n' "${line}"
            done <<<"${tail_output}"

            # Do not misclassify a lost backend as failures of every queued test
            if ((aborted == 0 && next < total && $# > 0)) &&
                ! "$@" >"${runner_log_directory}/infrastructure.log" 2>&1; then
                aborted=$((total - next))
                next="${total}"
                printf '%s: error: infrastructure check failed; %d tests aborted (log: %s)\n' \
                    "${runner_level}" "${aborted}" "${runner_log_directory}/infrastructure.log"
            fi
        fi
    done
    trap - INT TERM
    printf '%s tests: %d passed, %d failed, %d aborted (%ds)\n' \
        "${runner_level^}" "${passed}" "${failed}" "${aborted}" "$((SECONDS - started))"
    ((failed == 0 && aborted == 0))
}
