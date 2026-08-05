#!/usr/bin/env bash

# Provides argument helpers for installer-specific parsers without changing caller shell options.

# Usage: require_option_value <installer_name> <option_name> <remaining_argument_count>
# Description:
# - Verify that a separate option value remains in the argument list
# - Write an error to standard error when it is absent
# Returns: Non-zero when the option has no value.
require_option_value() {
    local installer_name="$1"
    local option_name="$2"
    local remaining_argument_count="$3"

    if ((remaining_argument_count < 2)); then
        die "${installer_name}" "option requires a value: ${option_name}"
    fi
}

# Usage: append_literal_lines <installer_name> <input_path> <destination_name>
# Description:
# - Append every non-blank input line literally, including whitespace and leading dashes
# - Write an error to standard error when the input file cannot be read
# Side Effects: Appends elements to the named destination array.
# Returns: Non-zero when the input file cannot be read.
append_literal_lines() {
    local installer_name="$1"
    local input_path="$2"
    local destination_name="$3"
    local line
    local -n destination="${destination_name}"

    if [[ ! -f "${input_path}" || ! -r "${input_path}" ]]; then
        die "${installer_name}" "cannot read input file: ${input_path}"
        return 1
    fi

    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ -n "${line}" ]]; then
            destination+=("${line}")
        fi
    done <"${input_path}"
}
