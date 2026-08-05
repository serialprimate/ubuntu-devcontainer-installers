#!/usr/bin/env bash
set -euo pipefail

# Validates shared-library and Dockerfile comment contracts.

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly repository_root
cd -- "${repository_root}"

# Usage: validate_shared_library_contracts <library...>
# Description: Rejects legacy fields and malformed contracts in shared Bash libraries.
# Returns: Non-zero when a library contract violates the commenting convention.
validate_shared_library_contracts() {
    awk '
        {
            lines[NR] = $0

            if ($0 ~ /^# (Arguments|Outputs|Side effects):/) {
                printf "%s:%d: legacy function-contract field: %s\n", FILENAME, NR, $0 > "/dev/stderr"
                failed = 1
            }

            if ($0 ~ /^[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{/) {
                function_name = $0
                sub(/\(\).*/, "", function_name)
                contract = ""
                for (line_number = NR - 1; line_number > 0 && lines[line_number] ~ /^# /; line_number--) {
                    contract = lines[line_number] "\n" contract
                }

                if (contract !~ /^# Usage: /) {
                    printf "%s:%d: %s is missing an adjacent Usage field\n", FILENAME, NR, function_name > "/dev/stderr"
                    failed = 1
                }
                if (contract !~ /\n# Description:([[:space:]]|$)/) {
                    printf "%s:%d: %s is missing a Description field\n", FILENAME, NR, function_name > "/dev/stderr"
                    failed = 1
                }
                if (contract ~ /\n# Returns:.*(standard output|standard error|stdout|stderr|writes|prints)/) {
                    printf "%s:%d: %s describes output in Returns\n", FILENAME, NR, function_name > "/dev/stderr"
                    failed = 1
                }
            }
        }

        END {
            exit failed
        }
    ' "$@"
}

# Enforce the shared-library contract fields and their output-status separation.
shared_library_list="$(git -C "${repository_root}" ls-files --cached --others \
    --exclude-standard -- 'lib/*.sh' 'tests/lib/*.sh')"
readonly shared_library_list
mapfile -t shared_libraries <<<"${shared_library_list}"
readonly -a shared_libraries
validate_shared_library_contracts "${shared_libraries[@]}"

# Usage: validate_dockerfile_comment_contracts <dockerfile...>
# Description: Rejects malformed parser, stage and filesystem-layer comments in Dockerfiles.
# Returns: Non-zero when a Dockerfile violates the commenting convention.
validate_dockerfile_comment_contracts() {
    local dockerfile

    for dockerfile in "$@"; do
        awk '
            NR == 1 && $0 != "# syntax=docker/dockerfile:1" {
                printf "%s:1: missing current stable Dockerfile syntax directive\n", FILENAME > "/dev/stderr"
                failed = 1
            }
            NR == 2 && $0 != "# check=error=true" {
                printf "%s:2: missing BuildKit error-check directive\n", FILENAME > "/dev/stderr"
                failed = 1
            }
            NR == 3 && $0 != "" {
                printf "%s:3: parser directives must be followed by one blank line\n", FILENAME > "/dev/stderr"
                failed = 1
            }
            {
                lines[NR] = $0

                if ($0 ~ /^FROM([[:space:]]|$)/ || $0 ~ /^(RUN|COPY|ADD)([[:space:]]|$)/) {
                    comment_start = NR - 1
                    if (lines[comment_start] !~ /^# /) {
                        printf "%s:%d: instruction requires an immediately preceding comment\n", FILENAME, NR > "/dev/stderr"
                        failed = 1
                    } else {
                        while (comment_start > 0 && lines[comment_start] ~ /^# /) {
                            comment_start--
                        }
                        if (lines[comment_start] != "") {
                            printf "%s:%d: instruction comment requires a preceding blank line\n", FILENAME, NR > "/dev/stderr"
                            failed = 1
                        }
                    }
                }
            }

            END {
                exit failed
            }
        ' "${dockerfile}"
    done
}

# Enforce parser, stage and filesystem-layer comment placement in every Dockerfile.
dockerfile_list="$(git -C "${repository_root}" ls-files --cached --others \
    --exclude-standard -- 'Dockerfile' '*Dockerfile')"
readonly dockerfile_list
mapfile -t dockerfiles <<<"${dockerfile_list}"
readonly -a dockerfiles
validate_dockerfile_comment_contracts "${dockerfiles[@]}"

# Enforce readable comment lines across every Bash program and Dockerfile.
code_file_list="$(git -C "${repository_root}" ls-files --cached --others \
    --exclude-standard -- '*.sh' 'Dockerfile' '*Dockerfile')"
readonly code_file_list
mapfile -t code_files <<<"${code_file_list}"
readonly -a code_files
awk '
    /^[[:space:]]*#/ && !/^#!/ && length($0) > 100 {
        printf "%s:%d: comment exceeds 100 characters\n", FILENAME, FNR > "/dev/stderr"
        failed = 1
    }

    END {
        exit failed
    }
' "${code_files[@]}"
