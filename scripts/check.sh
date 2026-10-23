#!/usr/bin/env bash
set -euo pipefail

# Runs fast, Docker-free repository checks suitable for an explicit pre-commit command.

# Resolve repository inputs without depending on the caller's working directory
repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
cd -- "${repository_root}"
for required_command in shfmt shellcheck markdownlint-cli2; do
    if ! command -v "${required_command}" >/dev/null 2>&1; then
        printf 'check: error: required command not found: %s; use the development container\n' \
            "${required_command}" >&2
        exit 2
    fi
done
mkdir -p -- "${repository_root}/tmp"
workspace="$(mktemp -d "${repository_root}/tmp/check.XXXXXXXX")"
readonly workspace
trap 'rm -rf -- "${workspace}"' EXIT
git ls-files -z --cached --others --exclude-standard -- '*.sh' >"${workspace}/shell-files"
git ls-files -z --cached --others --exclude-standard -- '*.md' >"${workspace}/markdown-files"
mapfile -d '' -t shell_files <"${workspace}/shell-files"
mapfile -d '' -t markdown_files <"${workspace}/markdown-files"

# Use the same read-only static checks locally and in CI
printf 'Checking Bash formatting\n'
shfmt -d -i 4 -ci "${shell_files[@]}"
printf 'Checking Bash diagnostics\n'
shellcheck --enable=all "${shell_files[@]}"
printf 'Checking Markdown\n'
markdownlint-cli2 --config .markdownlint-cli2.jsonc "${markdown_files[@]}"

# Run all unit suites, or the caller's explicitly selected suites
"${repository_root}/scripts/test-unit.sh" "$@"
