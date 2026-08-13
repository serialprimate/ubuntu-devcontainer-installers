# syntax=docker/dockerfile:1
# check=error=true

# Installs and repeats one exact digest-pinned GitHub Release executable.
FROM ubuntu:26.04 AS binary-idempotent-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the explicit APT prerequisite installer.
COPY installers/apt-packages /workspace/installers/apt-packages

# Copies the GitHub Release installer beside its prerequisite.
COPY installers/github-release /workspace/installers/github-release

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Installs download prerequisites, installs Brave CLI twice and verifies exact state.
RUN /workspace/installers/apt-packages/install.sh \
        --package ca-certificates \
        --package curl \
    && /workspace/installers/github-release/install.sh \
        --repository brave/brave-search-cli \
        --release-tag v1.5.0 \
        --asset-name bx-1.5.0-linux-amd64 \
        --sha256 823a86dfd06734fee84371e9b9c08a89dbad7691fbf43dad217a9c5658827fa0 \
        --install-path /usr/local/bin/bx \
    && /workspace/installers/github-release/install.sh \
        --repository brave/brave-search-cli \
        --release-tag v1.5.0 \
        --asset-name bx-1.5.0-linux-amd64 \
        --sha256 823a86dfd06734fee84371e9b9c08a89dbad7691fbf43dad217a9c5658827fa0 \
        --install-path /usr/local/bin/bx \
    && test "$(sha256sum /usr/local/bin/bx | cut -d ' ' -f 1)" \
        = 823a86dfd06734fee84371e9b9c08a89dbad7691fbf43dad217a9c5658827fa0 \
    && test "$(stat -c '%a:%u:%g' /usr/local/bin/bx)" = '755:0:0' \
    && bx --version | grep -Fq '1.5.0'

# Rejects a downloaded asset whose bytes do not match the caller-owned pin.
FROM ubuntu:26.04 AS digest-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the explicit APT prerequisite installer.
COPY installers/apt-packages /workspace/installers/apt-packages

# Copies the GitHub Release installer and expected-failure helper.
COPY installers/github-release /workspace/installers/github-release

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Downloads the exact asset and proves verification fails closed before installation.
RUN /workspace/installers/apt-packages/install.sh \
        --package ca-certificates \
        --package curl \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'SHA-256 verification failed for bx-1.5.0-linux-amd64' \
        /workspace/installers/github-release/install.sh \
        --repository brave/brave-search-cli \
        --release-tag v1.5.0 \
        --asset-name bx-1.5.0-linux-amd64 \
        --sha256 0000000000000000000000000000000000000000000000000000000000000000 \
        --install-path /usr/local/bin/bx \
    && test ! -e /usr/local/bin/bx

# Rejects an existing destination containing different content.
FROM ubuntu:26.04 AS destination-collision-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the GitHub Release installer and expected-failure helper.
COPY installers/github-release /workspace/installers/github-release

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Creates deterministic prerequisite and conflicting state without permitting network access.
RUN printf '%s\n' '#!/usr/bin/env bash' 'exit 99' >/usr/local/bin/curl \
    && chmod 0755 /usr/local/bin/curl \
    && printf 'different content\n' >/usr/local/bin/bx \
    && chmod 0755 /usr/local/bin/bx \
    && /workspace/tests/lib/assert-command-fails.sh \
        2 'install path contains different content: /usr/local/bin/bx' \
        /workspace/installers/github-release/install.sh \
        --repository brave/brave-search-cli \
        --release-tag v1.5.0 \
        --asset-name bx-1.5.0-linux-amd64 \
        --sha256 823a86dfd06734fee84371e9b9c08a89dbad7691fbf43dad217a9c5658827fa0 \
        --install-path /usr/local/bin/bx

# Rejects unsupported release metadata before network access.
FROM ubuntu:26.04 AS unsupported-platform-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the GitHub Release installer and expected-failure helper.
COPY installers/github-release /workspace/installers/github-release

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Substitutes unsupported metadata and proves platform validation precedes prerequisites.
RUN printf 'ID=debian\nVERSION_ID="13"\n' >/etc/os-release \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'unsupported platform: requires Ubuntu 26.04' \
        /workspace/installers/github-release/install.sh \
        --repository brave/brave-search-cli \
        --release-tag v1.5.0 \
        --asset-name bx-1.5.0-linux-amd64 \
        --sha256 823a86dfd06734fee84371e9b9c08a89dbad7691fbf43dad217a9c5658827fa0 \
        --install-path /usr/local/bin/bx
