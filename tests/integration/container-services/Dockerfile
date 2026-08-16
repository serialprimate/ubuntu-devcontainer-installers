# syntax=docker/dockerfile:1
# check=error=true

# Provides a clean Ubuntu image with the source-tree orchestrator and trusted fake adapters
FROM ubuntu:26.04 AS installation-base

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the container-services installer and bundled runtime command
COPY installers/container-services /workspace/installers/container-services

# Preserves the source-tree bundled-library relationship
COPY lib /workspace/lib

# Copies the trusted fake adapters used for orchestration assertions
COPY tests/integration/container-services/adapters /workspace/adapters

# Installs the orchestrator and fixed root-owned fake service adapters
RUN /workspace/installers/container-services/install.sh \
    && install --directory --owner=root --group=root --mode=0755 \
        /usr/local/libexec/ubuntu-devcontainer-installers/services \
    && for adapter in /workspace/adapters/*; do \
        install --owner=root --group=root --mode=0755 "${adapter}" \
            "/usr/local/libexec/ubuntu-devcontainer-installers/services/$(basename "${adapter}")"; \
    done

# Verifies canonical installation and repeated installation without registration
FROM installation-base AS installation-success

# Checks ownership, modes, absence of registration and idempotent installation
RUN /workspace/installers/container-services/install.sh \
    && test "$(stat -c '%a:%u' /usr/local/bin/container-services)" = '755:0' \
    && test "$(stat -c '%a:%u' \
        /usr/local/libexec/ubuntu-devcontainer-installers/container-services/common.sh)" = '644:0' \
    && test "$(stat -c '%a:%u' \
        /usr/local/libexec/ubuntu-devcontainer-installers/services/alpha)" = '755:0' \
    && test ! -e /etc/ubuntu-devcontainer-installers/container-services/services

# Verifies registration order and literal no-service entrypoint behaviour
FROM installation-base AS registration-and-entrypoint-success

# Registers one complete ordered list and passes literal arguments through the orchestrator
RUN container-services register --service beta --service alpha \
    && test "$(cat /etc/ubuntu-devcontainer-installers/container-services/services)" = $'beta\nalpha' \
    && container-services entrypoint -- bash -c 'test "$1" = "literal value"' -- 'literal value'

# Proves startup failure rolls back the successfully started prefix
FROM installation-base AS startup-rollback-failure

# Uses the project assertion helper to verify failed startup and reverse rollback
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Registers the failing service sequence and checks the reverse rollback events
RUN container-services register --service alpha --service fail-start \
    && /workspace/tests/lib/assert-command-fails.sh \
        4 'startup failed for service: fail-start' \
        container-services entrypoint -- true \
    && test "$(cat /tmp/container-services-events)" = $'start\nstart\nstop'

# Rejects duplicate, conflicting and missing registrations without changing state
FROM installation-base AS registration-failure

# Copies the expected-failure assertion helper
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Validates all registration failures before publishing a manifest
RUN container-services register --service alpha \
    && /workspace/tests/lib/assert-command-fails.sh \
        3 'service declared more than once' \
        container-services register --service alpha --service alpha \
    && /workspace/tests/lib/assert-command-fails.sh \
        3 'different registration already exists' \
        container-services register --service beta \
    && chmod 0666 /etc/ubuntu-devcontainer-installers/container-services/services \
    && /workspace/tests/lib/assert-command-fails.sh \
        3 'registration manifest state is unsafe' \
        container-services register --service alpha \
    && chmod 0644 /etc/ubuntu-devcontainer-installers/container-services/services \
    && chmod 0775 /usr/local/libexec/ubuntu-devcontainer-installers/services/beta \
    && /workspace/tests/lib/assert-command-fails.sh \
        3 'service adapter is missing or unsafe' \
        container-services register --service beta \
    && /workspace/tests/lib/assert-command-fails.sh \
        3 'service adapter is missing or unsafe' \
        container-services register --service missing-service

# Proves no-registration entrypoint pass-through and explicit no-service readiness
FROM installation-base AS no-registration-success

# Runs the main command directly and reports no registered services
RUN container-services entrypoint -- bash -c 'test "$1" = "literal value"' -- 'literal value' \
    && container-services wait \
    && container-services status

# Provides an installed image for runtime signal, wait and status assertions
FROM installation-base AS runtime-success

# Registers a delayed ordered service list and creates a non-root readiness user
RUN container-services register \
        --service alpha \
        --service slow-start \
        --service beta \
    && useradd --create-home --uid 1001 --shell /bin/bash dev

# Rejects malformed state before starting any registered adapter
FROM installation-base AS malformed-state-failure

# Copies the expected-failure assertion helper
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Publishes malformed state and proves the entrypoint fails closed
RUN container-services register --service alpha \
    && install --directory --owner=root --group=root --mode=0755 \
        /run/ubuntu-devcontainer-installers/container-services \
    && printf 'malformed\\n' \
        >/run/ubuntu-devcontainer-installers/container-services/state \
    && chmod 0644 /run/ubuntu-devcontainer-installers/container-services/state \
    && /workspace/tests/lib/assert-command-fails.sh \
        4 'runtime state is malformed' \
        container-services entrypoint -- true

# Verifies shutdown failure aggregation and main-command status precedence
FROM installation-base AS exit-status-precedence

# Copies the expected-failure assertion helper
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Continues reverse shutdown and preserves a non-zero main-command result
RUN container-services register --service alpha --service fail-stop \
    && /workspace/tests/lib/assert-command-fails.sh \
        6 'service stop failed at position 2: fail-stop' \
        container-services entrypoint -- true \
    && test "$(cat /tmp/container-services-events)" = $'start\nstart\nstop\nstop' \
    && rm -f /tmp/container-services-events \
    && /workspace/tests/lib/assert-command-fails.sh \
        23 'main command exited with status 23' \
        container-services entrypoint -- bash -c 'exit 23'

# Verifies aggregate status reports every service even when the orchestrator is absent
FROM installation-base AS aggregate-status-failure

# Copies the expected-failure assertion helper
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Invokes every adapter status operation before returning the aggregate failure
RUN container-services register --service alpha --service beta \
    && /workspace/tests/lib/assert-command-fails.sh \
        5 'checking service 2/2: beta' \
        container-services status \
    && test "$(cat /tmp/container-services-events)" = $'status\nstatus'

# Provides an installed image for the deliberately hanging adapter limitation
FROM installation-base AS forced-termination

# Registers only the trusted adapter whose start operation intentionally never returns
RUN container-services register --service hang
