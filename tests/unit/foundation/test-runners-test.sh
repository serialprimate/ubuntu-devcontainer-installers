#!/usr/bin/env bash
set -euo pipefail

# Verifies scheduling, failure reporting, selectors and cleanup without a Docker daemon.

# Build an isolated repository fixture so runner tests cannot recurse into themselves
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
# The fixture resolves helpers relative to the checkout like other foundation tests.
# shellcheck disable=SC1091
source "${repository_root}/tests/lib/assertions.sh"
workspace="$(mktemp -d "${repository_root}/tmp/test-runners.XXXXXXXX")"
readonly workspace
trap 'rm -rf -- "${workspace}"' EXIT
mkdir -p -- "${workspace}/scripts" "${workspace}/tests/lib" \
    "${workspace}/tests/unit/sample" "${workspace}/tests/integration/sample" "${workspace}/bin"
cp -- "${repository_root}/scripts/test-unit.sh" "${repository_root}/scripts/test-integration.sh" \
    "${repository_root}/scripts/test-docker-in-docker.sh" "${workspace}/scripts/"
cp -- "${repository_root}/tests/lib/test-runner.sh" \
    "${repository_root}/tests/lib/integration-target.sh" "${workspace}/tests/lib/"
export RUNNER_FIXTURE="${workspace}"

# Keep serial failure aggregation observable, including literal diagnostic text
printf 'exit 0\n' >"${workspace}/tests/unit/sample/a-test.sh"
printf 'printf "failure detail\\n"; exit 7\n' >"${workspace}/tests/unit/sample/b-test.sh"
printf 'exit 0\n' >"${workspace}/tests/unit/sample/c-test.sh"
status=0
output="$(TEST_JOBS=1 bash "${workspace}/scripts/test-unit.sh" sample)" || status=$?
assert_equal 1 "${status}"
assert_contains '2 passed, 1 failed' "${output}"
assert_contains 'exit 7' "${output}"
assert_contains '  | failure detail' "${output}"
assert_contains 'PASS unit sample/c-test.sh' "${output}"

# Prove two workers overlap, while a third cannot start until a slot is free
cat >"${workspace}/tests/unit/sample/a-test.sh" <<'FIXTURE'
touch "${RUNNER_FIXTURE}/first"
for ((attempt=0; attempt<200; attempt++)); do
    if [[ -f "${RUNNER_FIXTURE}/second" ]]; then
        test ! -f "${RUNNER_FIXTURE}/third"
        exit 0
    fi
    sleep 0.01
done
exit 1
FIXTURE
cat >"${workspace}/tests/unit/sample/b-test.sh" <<'FIXTURE'
touch "${RUNNER_FIXTURE}/second"
for ((attempt=0; attempt<200; attempt++)); do
    if [[ -f "${RUNNER_FIXTURE}/first" ]]; then
        sleep 0.1
        exit 0
    fi
    sleep 0.01
done
exit 1
FIXTURE
cat >"${workspace}/tests/unit/sample/c-test.sh" <<'FIXTURE'
touch "${RUNNER_FIXTURE}/third"
FIXTURE
output="$(TEST_JOBS=2 bash "${workspace}/scripts/test-unit.sh" sample)"
assert_contains '3 passed, 0 failed' "${output}"
assert_contains 'START unit sample/a-test.sh' "${output}"
assert_contains 'active 2/2' "${output}"

# Force completion order to differ from launch order without depending on timing ratios
mkdir -- "${workspace}/tests/unit/ordered"
cat >"${workspace}/tests/unit/ordered/a-test.sh" <<'FIXTURE'
for ((attempt=0; attempt<500; attempt++)); do
    if [[ -f "${RUNNER_FIXTURE}/replacement-started" ]]; then
        exit 0
    fi
    sleep 0.01
done
exit 1
FIXTURE
printf 'exit 0\n' >"${workspace}/tests/unit/ordered/b-test.sh"
cat >"${workspace}/tests/unit/ordered/c-test.sh" <<'FIXTURE'
touch "${RUNNER_FIXTURE}/replacement-started"
FIXTURE
output="$(TEST_JOBS=2 bash "${workspace}/scripts/test-unit.sh" ordered)"
assert_contains '3 passed, 0 failed, 0 aborted' "${output}"
first_result="$(awk '/^PASS / { print $3; exit }' <<<"${output}")"
assert_equal 'ordered/b-test.sh' "${first_result}"

# Collect already-finished child statuses even with many immediately exiting workers
mkdir -- "${workspace}/tests/unit/fast"
for ((index = 0; index < 64; index++)); do
    printf 'exit 0\n' >"${workspace}/tests/unit/fast/${index}-test.sh"
done
output="$(TEST_JOBS=32 bash "${workspace}/scripts/test-unit.sh" fast)"
assert_contains '64 passed, 0 failed' "${output}"

# Reject invalid concurrency and all invalid selectors before any test starts
for jobs in 0 -1 01 33 invalid; do
    status=0
    output="$(TEST_JOBS="${jobs}" bash "${workspace}/scripts/test-unit.sh" sample 2>&1)" || status=$?
    assert_equal 2 "${status}"
    assert_contains 'TEST_JOBS must be' "${output}"
done
rm -- "${workspace}/third"
status=0
output="$(TEST_JOBS=1 bash "${workspace}/scripts/test-unit.sh" sample missing 2>&1)" || status=$?
assert_equal 2 "${status}"
assert_contains 'unknown unit test suite' "${output}"
test ! -f "${workspace}/third"

# Record Docker calls while keeping all integration state inside the fixture
cat >"${workspace}/bin/docker" <<'FIXTURE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${RUNNER_FIXTURE}/docker-calls"
if [[ "$1" == info && -e "${RUNNER_FIXTURE}/daemon-down" ]]; then
    touch "${RUNNER_FIXTURE}/health-checked"
    printf 'fixture Docker endpoint unavailable\n' >&2
    exit 1
elif [[ "$1 ${2:-}" == 'image inspect' ]]; then
    printf 'ubuntu@sha256:fixture\n'
elif [[ "$1" == build && " $* " == *' --target fail '* ]]; then
    printf 'fixture build failure\n'
    if [[ "${RUNNER_FIXTURE_OUTAGE:-0}" == 1 ]]; then
        touch "${RUNNER_FIXTURE}/daemon-down"
    fi
    exit 17
elif [[ "$1" == build && " $* " == *' --target drain '* ]]; then
    for ((attempt=0; attempt<500; attempt++)); do
        if [[ -e "${RUNNER_FIXTURE}/health-checked" ]]; then
            touch "${RUNNER_FIXTURE}/drained"
            exit 0
        fi
        sleep 0.01
    done
    exit 1
elif [[ "$1" == run ]]; then
    printf 'fixture nested progress\n'
fi
FIXTURE
chmod +x "${workspace}/bin/docker"
export PATH="${workspace}/bin:${PATH}"
printf 'FROM scratch\n' >"${workspace}/tests/integration/sample/Dockerfile"
printf 'success\nfail\n' >"${workspace}/tests/integration/sample/targets.txt"
cat >"${workspace}/tests/integration/sample/run-target.sh" <<'FIXTURE'
#!/usr/bin/env bash
printf 'runtime %s\n' "$2" >>"${RUNNER_FIXTURE}/runtime-calls"
FIXTURE
chmod +x "${workspace}/tests/integration/sample/run-target.sh"
status=0
output="$(TEST_JOBS=2 bash "${workspace}/scripts/test-integration.sh" sample)" || status=$?
assert_equal 1 "${status}"
assert_contains '1 passed, 1 failed' "${output}"
assert_contains 'fixture build failure' "${output}"
assert_contains 'runtime success' "$(<"${workspace}/runtime-calls")"
assert_equal 'runtime success' "$(<"${workspace}/runtime-calls")"
calls="$(<"${workspace}/docker-calls")"
assert_contains '--no-cache --progress plain --platform linux/amd64' "${calls}"
assert_contains 'io.github.serialprimate.test-run=integration.' "${calls}"
assert_contains 'image rm --force --' "${calls}"

# Abort unscheduled targets after backend loss instead of manufacturing more test failures
printf 'success\nfail\nnever\n' >"${workspace}/tests/integration/sample/targets.txt"
rm -- "${workspace}/docker-calls"
status=0
output="$(RUNNER_FIXTURE_OUTAGE=1 TEST_JOBS=1 bash "${workspace}/scripts/test-integration.sh" sample)" || status=$?
assert_equal 1 "${status}"
assert_contains '1 passed, 1 failed, 1 aborted' "${output}"
assert_contains 'infrastructure check failed' "${output}"
calls="$(<"${workspace}/docker-calls")"
if [[ "${calls}" == *'--target never'* ]]; then
    printf 'A target started after confirmed infrastructure loss\n' >&2
    exit 1
fi
rm -- "${workspace}/daemon-down" "${workspace}/health-checked"

# Drain an already-active worker after backend loss without launching the queued target
printf 'fail\ndrain\nnever\n' >"${workspace}/tests/integration/sample/targets.txt"
rm -- "${workspace}/docker-calls"
status=0
output="$(RUNNER_FIXTURE_OUTAGE=1 TEST_JOBS=2 bash "${workspace}/scripts/test-integration.sh" sample)" || status=$?
assert_equal 1 "${status}"
assert_contains '1 passed, 1 failed, 1 aborted' "${output}"
test -e "${workspace}/drained"
calls="$(<"${workspace}/docker-calls")"
if [[ "${calls}" == *'--target never'* ]]; then
    printf 'A queued target started while draining active workers\n' >&2
    exit 1
fi
rm -- "${workspace}/daemon-down" "${workspace}/health-checked"

# Invalid integration selectors must not pull or build anything
rm -- "${workspace}/docker-calls"
status=0
output="$(bash "${workspace}/scripts/test-integration.sh" sample unknown 2>&1)" || status=$?
assert_equal 2 "${status}"
test ! -e "${workspace}/docker-calls"

# Nested qualification validates early, isolates writable work and streams labelled progress
status=0
output="$(TEST_JOBS=0 bash "${workspace}/scripts/test-docker-in-docker.sh" 2>&1)" || status=$?
assert_equal 2 "${status}"
test ! -e "${workspace}/docker-calls"
output="$(TEST_JOBS=2 bash "${workspace}/scripts/test-docker-in-docker.sh")"
assert_contains 'nested | fixture nested progress' "${output}"
calls="$(<"${workspace}/docker-calls")"
assert_contains '--env TEST_JOBS=2' "${calls}"
assert_contains '--env DIND_QUALIFICATION_ACTIVE=1' "${calls}"
assert_contains "type=bind,source=${workspace},target=/source,readonly" "${calls}"
qualification_workspaces=("${workspace}"/tmp/dind-qualification-*/work)
assert_equal 1 "${#qualification_workspaces[@]}"
test -d "${qualification_workspaces[0]}"
assert_contains "type=bind,source=${qualification_workspaces[0]},target=/source/tmp" "${calls}"

# A caught interruption must terminate and reap worker descendants promptly
rm -- "${workspace}/tests/unit/sample/b-test.sh" "${workspace}/tests/unit/sample/c-test.sh"
cat >"${workspace}/tests/unit/sample/a-test.sh" <<'FIXTURE'
sleep 60 &
printf '%s\n' "$!" >"${RUNNER_FIXTURE}/descendant"
wait
FIXTURE
TEST_JOBS=1 bash "${workspace}/scripts/test-unit.sh" sample >"${workspace}/interrupted.log" 2>&1 &
runner_pid=$!
for ((attempt = 0; attempt < 200; attempt++)); do
    if [[ -f "${workspace}/descendant" ]]; then
        break
    fi
    sleep 0.01
done
test -f "${workspace}/descendant"
kill -TERM "${runner_pid}"
status=0
wait "${runner_pid}" || status=$?
assert_equal 143 "${status}"
assert_contains 'interrupted; logs:' "$(<"${workspace}/interrupted.log")"
if kill -0 "$(<"${workspace}/descendant")" 2>/dev/null; then
    printf 'Worker descendant survived interruption\n' >&2
    exit 1
fi
