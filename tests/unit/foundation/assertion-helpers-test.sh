#!/usr/bin/env bash
set -euo pipefail

# Smoke-tests the executable success and expected-failure assertion helpers.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
readonly succeeds="${repository_root}/tests/lib/assert-command-succeeds.sh"
readonly fails="${repository_root}/tests/lib/assert-command-fails.sh"

# Accept a command that returns zero.
"${succeeds}" bash -c 'exit 0'

# Accept the declared non-zero status and literal diagnostic fragment.
"${fails}" 7 'expected diagnostic' \
    bash -c 'printf "%s\n" "expected diagnostic" >&2; exit 7'
