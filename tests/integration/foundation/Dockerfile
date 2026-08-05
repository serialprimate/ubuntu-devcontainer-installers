# syntax=docker/dockerfile:1
# check=error=true

# Defines a clean Ubuntu 26.04 baseline for shared platform qualification.
FROM ubuntu:26.04 AS clean-ubuntu-26-04

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies only shared libraries so the clean target contains no installer payload.
COPY lib /workspace/lib

# Sources the shared checks and validates the platform without changing system configuration.
RUN source /workspace/lib/common.sh \
    && source /workspace/lib/platform.sh \
    && require_supported_platform foundation \
    && test ! -e /workspace/installers
