#!/usr/bin/env bash
set -euo pipefail

# Verifies option-value checks and literal file-list collection.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
source "${repository_root}/tests/lib/assertions.sh"
source "${repository_root}/lib/common.sh"
source "${repository_root}/lib/arguments.sh"

temporary_root="$(mktemp -d /tmp/ubuntu-devcontainer-installers.arguments.XXXXXX)"
readonly temporary_root
trap 'rm -rf -- "${temporary_root}"' EXIT

# Preserve non-blank lines literally, including whitespace, leading dashes and a final partial line.
input_file="${temporary_root}/packages.txt"
printf 'first package\n\n  literal whitespace  \n-last-value' >"${input_file}"
values=('existing')
append_literal_lines example "${input_file}" values
assert_equal '4' "${#values[@]}" 'unexpected literal-line count'
assert_equal 'existing' "${values[0]}"
assert_equal 'first package' "${values[1]}"
assert_equal '  literal whitespace  ' "${values[2]}"
assert_equal '-last-value' "${values[3]}"

# Reject an option occurrence without its required following value.
set +e
output="$(require_option_value example --package 1 2>&1)"
status=$?
set -e
assert_equal '1' "${status}" 'require_option_value accepted a missing value'
assert_contains 'option requires a value: --package' "${output}"

# Accept an option occurrence when its required value remains.
require_option_value example --package 2

# Reject an input path that does not identify a readable file.
set +e
output="$(append_literal_lines example "${temporary_root}/missing" values 2>&1)"
status=$?
set -e
assert_equal '1' "${status}" 'append_literal_lines accepted a missing file'
assert_contains 'cannot read input file' "${output}"
