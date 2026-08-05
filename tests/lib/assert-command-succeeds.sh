#!/usr/bin/env bash
set -euo pipefail

# Asserts that a command exits successfully while preserving its output.

if (($# < 1)); then
    printf 'Usage: %s COMMAND [ARGUMENT ...]\n' "${0##*/}" >&2
    exit 2
fi

"$@"
