#!/usr/bin/env bash

# Provides sourceable test assertions without changing caller shell options.

# Usage: fail <message...>
# Description: Writes an assertion diagnostic and returns failure.
# Returns: Always returns 1.
fail() {
    printf 'assertion failed: %s\n' "$*" >&2
    return 1
}

# Usage: assert_equal <expected> <actual> [description]
# Description:
# - Assert that two literal values are equal
# - Write an assertion diagnostic to standard error when they differ
# Returns: Non-zero when the values differ.
assert_equal() {
    local expected="$1"
    local actual="$2"
    local description="${3:-values differ}"

    if [[ "${actual}" != "${expected}" ]]; then
        fail "${description}; expected <${expected}>, got <${actual}>"
    fi
}

# Usage: assert_contains <expected_fragment> <actual> [description]
# Description:
# - Assert that a literal value contains an expected fragment
# - Write an assertion diagnostic to standard error when it is absent
# Returns: Non-zero when the fragment is absent.
assert_contains() {
    local expected_fragment="$1"
    local actual="$2"
    local description="${3:-text does not contain expected fragment}"

    if [[ "${actual}" != *"${expected_fragment}"* ]]; then
        fail "${description}; missing <${expected_fragment}> in <${actual}>"
    fi
}

# Usage: assert_file_empty <path>
# Description:
# - Assert that a file is empty or absent
# - Write an assertion diagnostic to standard error for a non-empty file
# Returns: Non-zero when the path identifies a non-empty file.
assert_file_empty() {
    local path="$1"

    if [[ -s "${path}" ]]; then
        fail "expected an empty file: ${path}"
    fi
}
