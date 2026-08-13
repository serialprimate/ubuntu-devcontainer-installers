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
        = 'apt-packages apt-python docker-in-docker github-release node npm-packages pipx pipx-packages user ' \
    && while IFS= read -r packaged_file; do \
        test "$(stat -c '%a' "${packaged_file}")" = 644; \
    done < <(find /opt/ubuntu-devcontainer-installers -type f ! -name install.sh \
        ! -path '*/docker-in-docker/docker-in-docker') \
    && test "$(stat -c '%a' \
        /opt/ubuntu-devcontainer-installers/installers/docker-in-docker/docker-in-docker)" = 755 \
    && for installer in apt-packages apt-python docker-in-docker github-release node npm-packages \
        pipx pipx-packages user; do \
        test "$(stat -c '%a' \
            "/opt/ubuntu-devcontainer-installers/installers/${installer}/install.sh")" = 755 \
            && "/opt/ubuntu-devcontainer-installers/installers/${installer}/install.sh" --help \
            >/dev/null; \
    done

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
