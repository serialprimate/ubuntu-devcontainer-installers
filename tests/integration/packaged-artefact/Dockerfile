# syntax=docker/dockerfile:1
# check=error=true

ARG INSTALLER_IMAGE=ubuntu-devcontainer-installers:packaged-candidate

# Provides the exact locally verified OCI candidate without source-tree fallback
FROM ${INSTALLER_IMAGE} AS candidate

# Copies the complete packaged payload into a fresh supported Ubuntu image
FROM ubuntu:26.04 AS packaged-base

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies only the candidate payload while preserving bundled-library paths
COPY --from=candidate /ubuntu-devcontainer-installers /opt/ubuntu-devcontainer-installers

# Verifies the complete release payload, executable modes and bundled-library resolution
FROM packaged-base AS payload-layout

# Checks every expected release file and invokes every packaged installer entry point
RUN test -f /opt/ubuntu-devcontainer-installers/LICENSE \
    && test -f /opt/ubuntu-devcontainer-installers/README.md \
    && test "$(find /opt/ubuntu-devcontainer-installers -mindepth 1 -maxdepth 1 -printf '%f\n' \
        | sort | tr '\n' ' ')" = 'LICENSE README.md installers lib ' \
    && test "$(find /opt/ubuntu-devcontainer-installers/installers -mindepth 1 -maxdepth 1 \
        -type d -printf '%f\n' | sort | tr '\n' ' ')" \
        = 'apt-packages apt-python container-services docker-in-docker github-release node npm-packages pipx pipx-packages playwright-deps user ' \
    && while IFS= read -r packaged_file; do \
        test "$(stat -c '%a' "${packaged_file}")" = 644; \
    done < <(find /opt/ubuntu-devcontainer-installers -type f ! -name install.sh \
        ! -path '*/container-services/container-services' \
        ! -path '*/docker-in-docker/docker-in-docker' \
        ! -path '*/docker-in-docker/container-service') \
    && test "$(stat -c '%a' \
        /opt/ubuntu-devcontainer-installers/installers/container-services/container-services)" = 755 \
    && test "$(stat -c '%a' \
        /opt/ubuntu-devcontainer-installers/installers/docker-in-docker/docker-in-docker)" = 755 \
    && test "$(stat -c '%a' \
        /opt/ubuntu-devcontainer-installers/installers/docker-in-docker/container-service)" = 755 \
    && for installer in apt-packages apt-python container-services docker-in-docker github-release node npm-packages \
        pipx pipx-packages playwright-deps user; do \
        test "$(stat -c '%a' \
            "/opt/ubuntu-devcontainer-installers/installers/${installer}/install.sh")" = 755 \
            && "/opt/ubuntu-devcontainer-installers/installers/${installer}/install.sh" --help \
            >/dev/null; \
    done

# Exercises installed runtime independence from the packaged source payload
FROM packaged-base AS container-services-runtime

# Installs the orchestrator, removes the candidate payload and runs its no-service path
RUN /opt/ubuntu-devcontainer-installers/installers/container-services/install.sh \
    && rm -rf -- /opt/ubuntu-devcontainer-installers \
    && container-services --help >/dev/null \
    && container-services entrypoint -- true

# Exercises independent repeated installer invocations from the packaged artefact
FROM packaged-base AS apt-repeated

# Installs two package sets through separate complete APT lifecycles
RUN /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package ca-certificates \
    && /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package xz-utils \
    && dpkg-query --show --showformat='${db:Status-Abbrev}' ca-certificates | grep -Fxq 'ii ' \
    && dpkg-query --show --showformat='${db:Status-Abbrev}' xz-utils | grep -Fxq 'ii ' \
    && test ! -e /var/lib/apt/lists/lock

# Registers the packaged Docker-in-Docker adapter after both packaged installers run
FROM packaged-base AS docker-adapter-registration

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Installs Docker prerequisites and both packaged runtime installers before registration
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -- \
        ca-certificates curl gnupg \
    && apt-get clean \
    && rm -rf -- /var/lib/apt/lists/* \
    && /opt/ubuntu-devcontainer-installers/installers/docker-in-docker/install.sh \
    && /opt/ubuntu-devcontainer-installers/installers/container-services/install.sh \
    && container-services register --service docker-in-docker \
    && test "$(cat /etc/ubuntu-devcontainer-installers/container-services/services)" = docker-in-docker \
    && rm -rf -- /opt/ubuntu-devcontainer-installers \
    && /usr/local/sbin/docker-in-docker --help >/dev/null \
    && if /usr/local/libexec/ubuntu-devcontainer-installers/services/docker-in-docker status; then \
        exit 1; \
    fi \
    && container-services --help >/dev/null

# Exercises packaged account replacement and its declared idempotent outcome
FROM packaged-base AS user-idempotent

# Establishes the requested identity twice and verifies the stable account state
RUN /opt/ubuntu-devcontainer-installers/installers/user/install.sh \
        --username devcontainer \
        --uid 1000 \
        --gid 1000 \
        --shell /bin/bash \
    && /opt/ubuntu-devcontainer-installers/installers/user/install.sh \
        --username devcontainer \
        --uid 1000 \
        --gid 1000 \
        --shell /bin/bash \
    && test "$(id -u devcontainer)" = 1000 \
    && test "$(id -g devcontainer)" = 1000

# Adds only independent test assertions to the candidate-only installer payload
FROM packaged-base AS playwright-checks

# Copies the expected package state without copying a source-tree installer or library
COPY tests/integration/playwright-deps/assert-dependencies.sh tests/integration/playwright-deps/expected-packages.txt /checks/

# Verifies default selection through the packaged entry point
FROM playwright-checks AS playwright-default

# Installs from the exact OCI candidate and verifies dependency-only state and APT cleanup
RUN /opt/ubuntu-devcontainer-installers/installers/playwright-deps/install.sh \
    && /checks/assert-dependencies.sh

# Verifies explicit target selection independently through the packaged entry point
FROM playwright-checks AS playwright-explicit

# Resolves the approved target without source-tree fallback
RUN /opt/ubuntu-devcontainer-installers/installers/playwright-deps/install.sh --playwright-version 1.64.0 \
    && /checks/assert-dependencies.sh

# Rejects unsupported targets through the packaged entry point without APT changes
FROM packaged-base AS playwright-unsupported

# Captures the rejection and proves the package database and clean APT state remain unchanged
RUN before="$(sha256sum /var/lib/dpkg/status)" \
    && if /opt/ubuntu-devcontainer-installers/installers/playwright-deps/install.sh \
        --playwright-version 1.64.2 >/tmp/playwright-error 2>&1; then exit 1; fi \
    && test "${before}" = "$(sha256sum /var/lib/dpkg/status)" \
    && test -z "$(ls -A /var/lib/apt/lists)" \
    && [[ "$(</tmp/playwright-error)" == *'unsupported Playwright version: 1.64.2; supported versions: 1.64.0, 1.64.1'* ]]
