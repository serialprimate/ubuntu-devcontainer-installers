# syntax=docker/dockerfile:1
# check=error=true

# Installs Docker Engine from its verified repository without starting the daemon
FROM ubuntu:26.04 AS installation-base

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the explicit prerequisite installer into the source-tree layout
COPY installers/apt-packages /workspace/installers/apt-packages

# Copies the Docker-in-Docker installer and bundled lifecycle command
COPY installers/docker-in-docker /workspace/installers/docker-in-docker

# Preserves the source-tree bundled-library relationship
COPY lib /workspace/lib

# Installs repository prerequisites followed by Docker Engine
RUN /workspace/installers/apt-packages/install.sh \
        --package ca-certificates \
        --package curl \
        --package gnupg \
    && /workspace/installers/docker-in-docker/install.sh

# Verifies package, repository, command and stopped-daemon installation state
FROM installation-base AS installation-success

# Repeats installation and verifies the canonical stopped state and clean APT lifecycle
RUN /workspace/installers/docker-in-docker/install.sh \
    && docker --version \
    && dockerd --version \
    && docker buildx version \
    && docker compose version \
    && grep -Fxq 'Suites: resolute' /etc/apt/sources.list.d/docker.sources \
    && grep -Fxq 'Signed-By: /etc/apt/keyrings/docker.gpg' \
        /etc/apt/sources.list.d/docker.sources \
    && test "$(stat -c '%a' /etc/apt/keyrings/docker.gpg)" = 644 \
    && test "$(stat -c '%a' /etc/apt/sources.list.d/docker.sources)" = 644 \
    && test "$(stat -c '%a' /usr/local/sbin/docker-in-docker)" = 755 \
    && test ! -S /var/run/docker.sock \
    && ! pgrep -x dockerd \
    && test -z "$(ls -A /var/lib/apt/lists)"

# Provides an installed image for privileged runtime lifecycle assertions
FROM installation-base AS daemon-lifecycle-success

# Provides an installed image for rejecting startup without its dedicated data volume
FROM installation-base AS missing-data-volume-failure

# Rejects missing repository-bootstrap dependencies without changing Docker state
FROM ubuntu:26.04 AS prerequisite-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the Docker-in-Docker installer and lifecycle command
COPY installers/docker-in-docker /workspace/installers/docker-in-docker

# Copies the expected-failure assertion helper
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship
COPY lib /workspace/lib

# Proves failure identifies explicit composition and leaves repository state absent
RUN /workspace/tests/lib/assert-command-fails.sh \
        1 'Run installers/apt-packages/install.sh' \
        /workspace/installers/docker-in-docker/install.sh \
    && test ! -e /etc/apt/sources.list.d/docker.sources \
    && test ! -e /etc/apt/keyrings/docker.gpg \
    && test ! -e /usr/local/sbin/docker-in-docker

# Rejects unsupported Ubuntu metadata before repository or package operations
FROM ubuntu:26.04 AS unsupported-platform-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the Docker-in-Docker installer and lifecycle command
COPY installers/docker-in-docker /workspace/installers/docker-in-docker

# Copies the expected-failure assertion helper
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship
COPY lib /workspace/lib

# Substitutes unsupported metadata and proves no Docker repository is added
RUN printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >/etc/os-release \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'unsupported platform: requires Ubuntu 26.04' \
        /workspace/installers/docker-in-docker/install.sh \
    && test ! -e /etc/apt/sources.list.d/docker.sources

# Builds the disposable environment used to run the complete project suite through its daemon
FROM installation-base AS qualification-environment

# Installs only source-control tooling additionally required by the project unit suite
RUN /workspace/installers/apt-packages/install.sh --package git
